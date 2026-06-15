shader_type spatial;

render_mode cull_disabled, diffuse_burley;


uniform vec4 object_tint : source_color = vec4(
	1.0,
	1.0,
	1.0,
	1.0
);

uniform float top_brightness : hint_range(
	0.50,
	1.50,
	0.01
) = 1.08;

uniform float side_brightness : hint_range(
	0.40,
	1.30,
	0.01
) = 0.86;

uniform float bottom_brightness : hint_range(
	0.20,
	1.00,
	0.01
) = 0.62;

uniform float directional_variation : hint_range(
	0.0,
	0.40,
	0.01
) = 0.10;

uniform float emission_strength : hint_range(
	0.0,
	0.40,
	0.01
) = 0.12;

uniform vec3 stylized_light_direction = vec3(
	-0.55,
	0.75,
	0.35
);


varying vec3 world_normal;


void vertex() {
	world_normal = normalize(
		MODEL_NORMAL_MATRIX * NORMAL
	);
}


void fragment() {
	vec3 normal_world = normalize(
		world_normal
	);

	float upward_factor = clamp(
		normal_world.y,
		0.0,
		1.0
	);

	float downward_factor = clamp(
		-normal_world.y,
		0.0,
		1.0
	);

	float side_factor = (
		1.0
		- clamp(
			abs(normal_world.y),
			0.0,
			1.0
		)
	);

	vec3 light_direction = normalize(
		stylized_light_direction
	);

	float directional_factor = (
		dot(
			normal_world,
			light_direction
		)
		* 0.5
		+ 0.5
	);

	float face_brightness = side_brightness;

	face_brightness = mix(
		face_brightness,
		top_brightness,
		upward_factor
	);

	face_brightness = mix(
		face_brightness,
		bottom_brightness,
		downward_factor
	);

	float side_variation = mix(
		1.0 - directional_variation,
		1.0 + directional_variation,
		directional_factor
	);

	face_brightness *= mix(
		1.0,
		side_variation,
		side_factor
	);

	vec3 base_color = (
		COLOR.rgb
		* object_tint.rgb
	);

	ALBEDO = (
		base_color
		* face_brightness
	);

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;

	EMISSION = (
		base_color
		* emission_strength
	);
}