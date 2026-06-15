shader_type spatial;

render_mode blend_mix,
	depth_prepass_alpha,
	cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;


uniform vec4 deep_color : source_color = vec4(
	0.015,
	0.14,
	0.25,
	0.82
);

uniform vec4 shallow_color : source_color = vec4(
	0.035,
	0.36,
	0.46,
	0.68
);

uniform vec3 reflection_tint : source_color = vec3(
	0.55,
	0.78,
	0.88
);


uniform float wave_height = 0.12;
uniform float wave_speed = 0.70;
uniform float wave_scale = 0.14;

uniform float secondary_wave_height = 0.045;
uniform float secondary_wave_speed = 1.10;
uniform float secondary_wave_scale = 0.31;

uniform float water_roughness = 0.12;
uniform float water_specular = 0.85;


varying vec3 world_position;
varying vec3 world_wave_normal;


void vertex() {
	vec3 original_world_position = (
		MODEL_MATRIX
		* vec4(
			VERTEX,
			1.0
		)
	).xyz;


	float phase_a = (
		original_world_position.x
			* wave_scale
		+ original_world_position.z
			* wave_scale
			* 0.72
		+ TIME
			* wave_speed
	);

	float phase_b = (
		original_world_position.z
			* secondary_wave_scale
		- original_world_position.x
			* secondary_wave_scale
			* 0.43
		+ TIME
			* secondary_wave_speed
	);


	float wave_a = (
		sin(phase_a)
		* wave_height
	);

	float wave_b = (
		sin(phase_b)
		* secondary_wave_height
	);

	VERTEX.y += (
		wave_a
		+ wave_b
	);


	float derivative_x = (
		cos(phase_a)
			* wave_height
			* wave_scale
		- cos(phase_b)
			* secondary_wave_height
			* secondary_wave_scale
			* 0.43
	);

	float derivative_z = (
		cos(phase_a)
			* wave_height
			* wave_scale
			* 0.72
		+ cos(phase_b)
			* secondary_wave_height
			* secondary_wave_scale
	);


	vec3 local_wave_normal = normalize(
		vec3(
			-derivative_x,
			1.0,
			-derivative_z
		)
	);

	world_wave_normal = normalize(
		(
			MODEL_MATRIX
			* vec4(
				local_wave_normal,
				0.0
			)
		).xyz
	);

	world_position = (
		MODEL_MATRIX
		* vec4(
			VERTEX,
			1.0
		)
	).xyz;
}


void fragment() {
	vec3 view_space_normal = normalize(
		(
			VIEW_MATRIX
			* vec4(
				world_wave_normal,
				0.0
			)
		).xyz
	);

	NORMAL = view_space_normal;


	float view_alignment = clamp(
		dot(
			view_space_normal,
			VIEW
		),
		0.0,
		1.0
	);

	float fresnel = pow(
		1.0 - view_alignment,
		3.0
	);


	float color_pattern = (
		sin(
			world_position.x * 0.075
			+ world_position.z * 0.045
			+ TIME * 0.20
		)
		* 0.5
		+ 0.5
	);

	vec3 water_color = mix(
		deep_color.rgb,
		shallow_color.rgb,
		0.28
			+ color_pattern * 0.18
			+ fresnel * 0.36
	);

	water_color = mix(
		water_color,
		reflection_tint,
		fresnel * 0.30
	);


	ALBEDO = water_color;

	ROUGHNESS = water_roughness;
	SPECULAR = water_specular;
	METALLIC = 0.0;

	RIM = 0.35;
	RIM_TINT = 0.65;

	EMISSION = (
		reflection_tint
		* fresnel
		* 0.035
	);

	ALPHA = mix(
		deep_color.a,
		shallow_color.a,
		0.35
			+ fresnel * 0.35
	);
}