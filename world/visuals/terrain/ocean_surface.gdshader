shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 deep_color : source_color = vec4(0.015, 0.14, 0.25, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.035, 0.36, 0.46, 0.66);
uniform vec3 reflection_tint : source_color = vec3(0.55, 0.78, 0.88);
uniform vec4 foam_color : source_color = vec4(0.70, 0.90, 0.92, 1.0);
uniform float wave_height = 0.008;
uniform float wave_speed = 0.38;
uniform float wave_scale = 0.14;
uniform float secondary_wave_height = 0.003;
uniform float secondary_wave_speed = 0.68;
uniform float secondary_wave_scale = 0.31;
uniform float water_roughness = 0.92;
uniform float water_specular = 0.0;
// Retained for existing material settings; stylized water does not refract.
uniform float refraction_strength = 0.0;
uniform float depth_fade_distance = 7.0;
uniform float foam_distance = 0.30;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform bool clip_shared_surface = false;
uniform bool join_shared_surface = false;
uniform vec4 shared_surface_bounds = vec4(0.0);
varying vec3 world_position;
varying float wave_amplitude;
varying vec2 water_flow;

vec3 scene_position(vec2 uv, mat4 inverse_projection) {
	float depth = texture(scene_depth, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

float tile_hash(vec2 point) {
	vec2 p = fract(point * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

void vertex() {
	water_flow = COLOR.rg * 2.0 - 1.0;
	vec3 original = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (join_shared_surface) {
		vec2 gap = max(max(shared_surface_bounds.xy - original.xz, original.xz - shared_surface_bounds.zw), vec2(0.0));
		VERTEX.y = mix(VERTEX.y, UV2.x, 1.0 - smoothstep(0.0, 8.0, length(gap)));
	}
	float phase_a = dot(original.xz, vec2(wave_scale, wave_scale * 0.72)) + TIME * wave_speed;
	float phase_b = dot(original.xz, vec2(-secondary_wave_scale * 0.43, secondary_wave_scale)) + TIME * secondary_wave_speed;
	// World coordinates keep displacement and ripples continuous across chunks.
	wave_amplitude = mix(1.0, 0.25, clamp(COLOR.b, 0.0, 1.0));
	VERTEX.y += (sin(phase_a) * wave_height + sin(phase_b) * secondary_wave_height) * wave_amplitude;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (clip_shared_surface) {
		if (all(greaterThanEqual(world_position.xz, shared_surface_bounds.xy)) && all(lessThan(world_position.xz, shared_surface_bounds.zw))) { discard; }
	}
	// Square, world-anchored colour patches share the terrain's half-metre
	// rhythm. Remove fine detail in the distance to avoid moire on the horizon.
	vec2 tile = floor(world_position.xz * 2.0);
	float distance_to_camera = length(VERTEX);
	float detail = 1.0 - smoothstep(36.0, 90.0, distance_to_camera);
	float patch = (floor(tile_hash(tile) * 4.0) / 3.0 - 0.5) * 0.065 * detail;
	float beat = floor(TIME * 2.0) * 0.5;
	vec2 drift_tile = floor((world_position.xz - water_flow * beat * 0.7) * 2.0);
	float glint = step(0.88, tile_hash(drift_tile + vec2(floor(beat * 0.4)))) * 0.035 * detail;

	vec3 bed_view = scene_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	// Vertical depth does not change when looking obliquely along a shallow
	// shore. No screen-colour emission or lens-like refraction washes it out.
	float thickness = max(world_position.y - bed_world.y, 0.0);
	float depth_weight = smoothstep(0.15, max(depth_fade_distance, 0.5), thickness);
	depth_weight = floor(depth_weight * 6.0 + 0.5) / 6.0;
	vec3 pigment = mix(shallow_color.rgb, deep_color.rgb * 0.65, depth_weight);
	float edge = 1.0 - smoothstep(0.04, max(foam_distance, 0.08), thickness);
	float foam = edge * step(0.52, tile_hash(tile + vec2(19.0, 73.0))) * detail * 0.65;
	vec3 color = pigment * (1.0 + patch + glint);
	color = mix(color, foam_color.rgb, foam);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ROUGHNESS = water_roughness;
	SPECULAR = water_specular;
	METALLIC = 0.0;
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, smoothstep(0.1, 3.5, thickness)) + foam * 0.2, 0.0, 1.0);
}
