shader_type spatial;

render_mode blend_mix,
	depth_prepass_alpha,
	cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

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
uniform float refraction_strength = 0.025;

varying vec3 world_position;
varying vec3 world_wave_normal;
varying vec2 water_data;


void vertex() {
	vec3 original_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase_a = original_world_position.x * wave_scale
		+ original_world_position.z * wave_scale * 0.72
		+ TIME * wave_speed;
	float phase_b = original_world_position.z * secondary_wave_scale
		- original_world_position.x * secondary_wave_scale * 0.43
		+ TIME * secondary_wave_speed;
	VERTEX.y += sin(phase_a) * wave_height
		+ sin(phase_b) * secondary_wave_height;
	float derivative_x = cos(phase_a) * wave_height * wave_scale
		- cos(phase_b) * secondary_wave_height * secondary_wave_scale * 0.43;
	float derivative_z = cos(phase_a) * wave_height * wave_scale * 0.72
		+ cos(phase_b) * secondary_wave_height * secondary_wave_scale;
	vec3 local_wave_normal = normalize(vec3(-derivative_x, 1.0, -derivative_z));
	world_wave_normal = normalize((MODEL_MATRIX * vec4(local_wave_normal, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	water_data = COLOR.rg;
}


void fragment() {
	vec3 view_space_normal = normalize((VIEW_MATRIX * vec4(world_wave_normal, 0.0)).xyz);
	NORMAL = view_space_normal;
	float depth_weight = clamp(water_data.r, 0.0, 1.0);
	float shoreline_foam = clamp(water_data.g, 0.0, 1.0);
	float view_alignment = clamp(dot(view_space_normal, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - view_alignment, 3.0);
	float flow_pattern = sin(
		world_position.x * 0.075
		+ world_position.z * 0.045
		+ TIME * 0.20
	) * 0.5 + 0.5;
	float distortion_pattern = sin(
		world_position.x * 0.23
		- world_position.z * 0.19
		+ TIME * 0.55
	) * refraction_strength;
	float foam_breakup = smoothstep(
		0.28,
		0.78,
		flow_pattern + distortion_pattern * 4.0
	);
	shoreline_foam *= mix(0.62, 1.0, foam_breakup);
	vec3 water_color = mix(shallow_color.rgb, deep_color.rgb, depth_weight);
	water_color = mix(
		water_color,
		reflection_tint,
		fresnel * 0.34 + flow_pattern * 0.045
	);
	water_color *= 1.0 + distortion_pattern;
	water_color = mix(water_color, foam_color.rgb, shoreline_foam * 0.70);
	ALBEDO = clamp(water_color, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(water_roughness, 0.48, shoreline_foam);
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
