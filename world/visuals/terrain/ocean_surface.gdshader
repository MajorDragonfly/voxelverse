shader_type spatial;

render_mode blend_mix,
	depth_prepass_alpha,
	cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 deep_color : source_color = vec4(0.015, 0.14, 0.25, 0.84);
uniform vec4 shallow_color : source_color = vec4(0.035, 0.36, 0.46, 0.62);
uniform vec3 reflection_tint : source_color = vec3(0.55, 0.78, 0.88);
uniform vec4 foam_color : source_color = vec4(0.70, 0.90, 0.92, 1.0);

uniform float wave_height = 0.07;
uniform float wave_speed = 0.48;
uniform float wave_scale = 0.14;
uniform float secondary_wave_height = 0.024;
uniform float secondary_wave_speed = 0.82;
uniform float secondary_wave_scale = 0.31;
uniform float water_roughness = 0.16;
uniform float water_specular = 0.78;
uniform float foam_distance = 0.90;
uniform float depth_fade_distance = 4.5;
uniform float refraction_strength = 0.025;

varying vec3 world_position;
varying vec3 world_wave_normal;


void vertex() {
	vec3 original_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase_a = original_world_position.x * wave_scale
		+ original_world_position.z * wave_scale * 0.72
		+ TIME * wave_speed;
	float phase_b = original_world_position.z * secondary_wave_scale
		- original_world_position.x * secondary_wave_scale * 0.43
		+ TIME * secondary_wave_speed;
	float wave_a = sin(phase_a) * wave_height;
	float wave_b = sin(phase_b) * secondary_wave_height;
	VERTEX.y += wave_a + wave_b;

	float derivative_x = cos(phase_a) * wave_height * wave_scale
		- cos(phase_b) * secondary_wave_height * secondary_wave_scale * 0.43;
	float derivative_z = cos(phase_a) * wave_height * wave_scale * 0.72
		+ cos(phase_b) * secondary_wave_height * secondary_wave_scale;
	vec3 local_wave_normal = normalize(vec3(-derivative_x, 1.0, -derivative_z));
	world_wave_normal = normalize(
		(MODEL_MATRIX * vec4(local_wave_normal, 0.0)).xyz
	);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


float get_scene_linear_depth() {
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
	#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_position.xyz /= max(view_position.w, 0.00001);
	return -view_position.z;
}


void fragment() {
	vec3 view_space_normal = normalize(
		(VIEW_MATRIX * vec4(world_wave_normal, 0.0)).xyz
	);
	NORMAL = view_space_normal;

	float scene_depth = get_scene_linear_depth();
	float water_surface_depth = max(-VERTEX.z, 0.0);
	float water_depth = max(scene_depth - water_surface_depth, 0.0);
	float depth_weight = smoothstep(
		0.0,
		max(depth_fade_distance, 0.001),
		water_depth
	);
	float shoreline_foam = 1.0 - smoothstep(
		0.02,
		max(foam_distance, 0.03),
		water_depth
	);

	float view_alignment = clamp(dot(view_space_normal, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - view_alignment, 3.0);
	float color_pattern = sin(
		world_position.x * 0.075
		+ world_position.z * 0.045
		+ TIME * 0.20
	) * 0.5 + 0.5;

	vec2 refracted_uv = SCREEN_UV + view_space_normal.xy
		* refraction_strength
		* clamp(water_depth, 0.0, 1.0);
	vec3 scene_color = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_weight);
	water_color = mix(
		water_color,
		reflection_tint,
		fresnel * 0.34 + color_pattern * 0.05
	);
	water_color = mix(
		scene_color,
		water_color,
		0.56 + depth_weight * 0.28
	);
	water_color = mix(
		water_color,
		foam_color.rgb,
		shoreline_foam * 0.68
	);

	ALBEDO = water_color;
	ROUGHNESS = mix(water_roughness, 0.46, shoreline_foam);
	SPECULAR = water_specular;
	METALLIC = 0.0;
	RIM = 0.28;
	RIM_TINT = 0.58;
	EMISSION = reflection_tint * fresnel * 0.022
		+ foam_color.rgb * shoreline_foam * 0.025;
	ALPHA = clamp(
		mix(shallow_color.a, deep_color.a, depth_weight)
		+ fresnel * 0.08
		+ shoreline_foam * 0.12,
		0.0,
		0.92
	);
}
