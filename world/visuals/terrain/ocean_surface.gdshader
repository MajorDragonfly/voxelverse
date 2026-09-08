shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.015, 0.14, 0.25, 0.82);
uniform vec4 shallow_color : source_color = vec4(0.035, 0.36, 0.46, 0.68);
uniform vec3 reflection_tint : source_color = vec3(0.55, 0.78, 0.88);
uniform vec4 foam_color : source_color = vec4(0.70, 0.90, 0.92, 1.0);
uniform float wave_height = 0.042;
uniform float wave_speed = 0.38;
uniform float wave_scale = 0.14;
uniform float secondary_wave_height = 0.014;
uniform float secondary_wave_speed = 0.68;
uniform float secondary_wave_scale = 0.31;
uniform float water_roughness = 0.18;
uniform float water_specular = 0.78;
uniform float refraction_strength = 0.018;
uniform float depth_fade_distance = 4.8;
uniform float foam_distance = 0.85;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform bool clip_shared_surface = false;
uniform bool join_shared_surface = false;
uniform vec4 shared_surface_bounds = vec4(0.0);
varying vec3 world_position;
varying vec3 world_wave_normal;
varying float wave_amplitude;
varying vec2 water_flow;

float scene_distance(vec2 uv, mat4 inverse_projection) {
	float depth = texture(scene_depth, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inverse_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
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
	float dx = cos(phase_a) * wave_height * wave_scale - cos(phase_b) * secondary_wave_height * secondary_wave_scale * 0.43;
	float dz = cos(phase_a) * wave_height * wave_scale * 0.72 + cos(phase_b) * secondary_wave_height * secondary_wave_scale;
	world_wave_normal = normalize(vec3(-dx * wave_amplitude, 1.0, -dz * wave_amplitude));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (clip_shared_surface) {
		if (all(greaterThanEqual(world_position.xz, shared_surface_bounds.xy)) && all(lessThan(world_position.xz, shared_surface_bounds.zw))) { discard; }
	}
	vec2 ripple_point = world_position.xz - water_flow * TIME * 0.85;
	float ripple_a = cos(dot(ripple_point, vec2(1.7, 0.9)) + TIME * 1.1);
	float ripple_b = cos(dot(ripple_point, vec2(-0.8, 2.5)) - TIME * 0.8);
	vec3 ripple_normal = normalize(world_wave_normal + vec3(ripple_a * 0.055, 0.0, ripple_b * 0.045) * wave_amplitude);
	vec3 view_normal = normalize((VIEW_MATRIX * vec4(ripple_normal, 0.0)).xyz);
	NORMAL = view_normal;
	float surface_distance = -VERTEX.z;
	float thickness = max(scene_distance(SCREEN_UV, INV_PROJECTION_MATRIX) - surface_distance, 0.0);
	// The same rendered bed drives absorption on the whole surface. Per-tile
	// vertex depth estimates produced a visible colour grid at LOD handoff.
	float depth_weight = 1.0 - exp(-thickness * 1.536 / max(depth_fade_distance, 0.001));
	float fresnel = pow(1.0 - clamp(dot(view_normal, VIEW), 0.0, 1.0), 4.0);
	vec2 offset = view_normal.xy * refraction_strength * smoothstep(0.0, 1.5, thickness);
	vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	// Refuse foreground samples so banks and creatures never smear into water.
	if (scene_distance(refracted_uv, INV_PROJECTION_MATRIX) < surface_distance) { refracted_uv = SCREEN_UV; }
	vec3 refracted = texture(scene_color, refracted_uv).rgb;
	float edge = 1.0 - smoothstep(0.03, max(foam_distance, 0.05), thickness);
	float surf = sin(thickness * 15.0 - TIME * 1.3 + sin(world_position.x * 1.1 + world_position.z * 0.7));
	float foam = edge * smoothstep(-0.35, 0.5, surf) * 0.80;
	vec3 pigment = mix(shallow_color.rgb, deep_color.rgb, depth_weight);
	vec3 color = mix(pigment, reflection_tint, fresnel * 0.65);
	color = mix(color, foam_color.rgb, foam);
	ALBEDO = clamp(color, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(water_roughness, 0.65, foam);
	SPECULAR = water_specular;
	METALLIC = 0.0;
	EMISSION = refracted * (1.0 - depth_weight) * 0.22 * (1.0 - foam) + reflection_tint * fresnel * 0.045;
	ALPHA = clamp(mix(shallow_color.a, deep_color.a, depth_weight) + fresnel * 0.14 + foam * 0.18, 0.0, 0.98);
}
