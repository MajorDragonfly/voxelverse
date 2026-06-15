shader_type spatial;

render_mode cull_disabled, diffuse_burley;


uniform vec4 object_tint : source_color = vec4(
	1.0,
	1.0,
	1.0,
	1.0
);

uniform bool use_pixel_texture = false;

uniform sampler2D pixel_texture :
	source_color,
	filter_nearest,
	repeat_enable;

uniform float texture_scale : hint_range(
	0.25,
	16.0,
	0.25
) = 2.0;

uniform float palette_steps : hint_range(
	2.0,
	8.0,
	1.0
) = 4.0;

uniform float texture_darkness : hint_range(
	0.20,
	1.00,
	0.01
) = 0.72;

uniform float texture_brightness : hint_range(
	0.80,
	1.50,
	0.01
) = 1.12;

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
) = 0.12;

uniform float emission_strength : hint_range(
	0.0,
	0.40,
	0.01
) = 0.10;

uniform vec3 stylized_light_direction = vec3(
	-0.55,
	0.75,
	0.35
);


varying vec3 local_position;
varying vec3 local_normal;
varying vec3 world_normal;


void vertex() {
	local_position = VERTEX;
	local_normal = normalize(NORMAL);

	world_normal = normalize(
		MODEL_NORMAL_MATRIX * NORMAL
	);
}


vec2 get_planar_uv(
	vec3 position_local,
	vec3 normal_local
) {
	vec3 absolute_normal = abs(
		normalize(normal_local)
	);

	if (
		absolute_normal.y >= absolute_normal.x
		&& absolute_normal.y >= absolute_normal.z
	) {
		return position_local.xz;
	}

	if (absolute_normal.x >= absolute_normal.z) {
		return position_local.zy;
	}

	return position_local.xy;
}


float get_quantized_texture_value(
	vec2 texture_uv
) {
	float texture_value = dot(
		texture(
			pixel_texture,
			texture_uv
		).rgb,
		vec3(
			0.299,
			0.587,
			0.114
		)
	);

	float safe_steps = max(
		palette_steps - 1.0,
		1.0
	);

	return (
		floor(
			texture_value * safe_steps
			+ 0.5
		)
		/ safe_steps
	);
}


float get_face_brightness(
	vec3 normal_world
) {
	if (normal_world.y > 0.50) {
		return top_brightness;
	}

	if (normal_world.y < -0.50) {
		return bottom_brightness;
	}

	vec3 light_direction = normalize(
		stylized_light_direction
	);

	float facing_value = dot(
		normal_world,
		light_direction
	);

	float directional_band = 1.0;

	if (facing_value > 0.35) {
		directional_band = (
			1.0
			+ directional_variation
		);
	} else if (facing_value < -0.35) {
		directional_band = (
			1.0
			- directional_variation
		);
	}

	return (
		side_brightness
		* directional_band
	);
}


void fragment() {
	vec3 normal_world = normalize(
		world_normal
	);

	float pixel_brightness = 1.0;

	if (use_pixel_texture) {
		vec2 pixel_uv = (
			get_planar_uv(
				local_position,
				local_normal
			)
			* texture_scale
		);

		float texture_value = (
			get_quantized_texture_value(
				pixel_uv
			)
		);

		pixel_brightness = mix(
			texture_darkness,
			texture_brightness,
			texture_value
		);
	}

	float face_brightness = (
		get_face_brightness(
			normal_world
		)
	);

	vec3 base_color = (
		COLOR.rgb
		* object_tint.rgb
	);

	vec3 final_color = (
		base_color
		* pixel_brightness
		* face_brightness
	);

	ALBEDO = final_color;

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;

	EMISSION = (
		base_color
		* pixel_brightness
		* emission_strength
	);
}