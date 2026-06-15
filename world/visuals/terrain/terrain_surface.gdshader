shader_type spatial;

render_mode
	depth_draw_opaque,
	cull_disabled,
	diffuse_lambert;


uniform sampler2D grass_texture :
	source_color,
	filter_nearest,
	repeat_enable;

uniform sampler2D dirt_texture :
	source_color,
	filter_nearest,
	repeat_enable;

uniform sampler2D sand_texture :
	source_color,
	filter_nearest,
	repeat_enable;

uniform sampler2D stone_texture :
	source_color,
	filter_nearest,
	repeat_enable;


uniform float top_texture_scale : hint_range(
	0.05,
	4.0,
	0.05
) = 0.50;

uniform float side_texture_scale : hint_range(
	0.05,
	4.0,
	0.05
) = 0.50;

uniform float palette_steps : hint_range(
	2.0,
	8.0,
	1.0
) = 4.0;

uniform float texture_darkness : hint_range(
	0.20,
	1.00,
	0.01
) = 0.58;

uniform float texture_brightness : hint_range(
	0.80,
	1.50,
	0.01
) = 1.22;


uniform bool spherical_planet = false;

uniform vec3 planet_center = vec3(
	0.0,
	0.0,
	0.0
);

uniform float planet_radius = 10000.0;

uniform float sea_level = -1.5;

uniform float coast_width = 1.0;

uniform float rocky_height = 4.5;


uniform vec3 rock_color : source_color = vec3(
	0.36,
	0.27,
	0.20
);

uniform vec3 rock_strata_color : source_color = vec3(
	0.50,
	0.35,
	0.23
);

uniform vec3 wet_ground_color : source_color = vec3(
	0.10,
	0.17,
	0.13
);

uniform vec3 snow_color : source_color = vec3(
	0.72,
	0.78,
	0.79
);


uniform float rock_slope_start = 0.28;

uniform float rock_slope_end = 0.62;

uniform float macro_color_strength = 0.16;

uniform float strata_strength = 0.18;

uniform float snow_start_altitude = 4.8;

uniform float snow_end_altitude = 6.5;


varying vec3 world_position;

varying vec3 world_normal;


void vertex() {
	world_position = (
		MODEL_MATRIX
		* vec4(
			VERTEX,
			1.0
		)
	).xyz;

	world_normal = normalize(
		MODEL_NORMAL_MATRIX
		* NORMAL
	);
}


float get_altitude(
	vec3 position
) {
	if (spherical_planet) {
		return (
			length(
				position - planet_center
			)
			- planet_radius
		);
	}

	return position.y;
}


vec2 get_planar_uv(
	vec3 position,
	vec3 normal_value,
	float scale_value
) {
	vec3 absolute_normal = abs(
		normal_value
	);

	if (
		absolute_normal.y >= absolute_normal.x
		&& absolute_normal.y >= absolute_normal.z
	) {
		return position.xz * scale_value;
	}

	if (
		absolute_normal.x
		>= absolute_normal.z
	) {
		return position.zy * scale_value;
	}

	return position.xy * scale_value;
}


float quantize_value(
	float value,
	float step_count
) {
	float safe_step_count = max(
		step_count - 1.0,
		1.0
	);

	return (
		floor(
			clamp(
				value,
				0.0,
				1.0
			)
			* safe_step_count
			+ 0.5
		)
		/ safe_step_count
	);
}


vec3 quantize_color(
	vec3 color_value
) {
	return vec3(
		quantize_value(
			color_value.r,
			palette_steps
		),
		quantize_value(
			color_value.g,
			palette_steps
		),
		quantize_value(
			color_value.b,
			palette_steps
		)
	);
}


float get_texture_brightness(
	vec3 texture_color
) {
	float grayscale_value = dot(
		texture_color,
		vec3(
			0.299,
			0.587,
			0.114
		)
	);

	float quantized_value = (
		quantize_value(
			grayscale_value,
			palette_steps
		)
	);

	return mix(
		texture_darkness,
		texture_brightness,
		quantized_value
	);
}


float get_side_brightness(
	vec3 normal_value
) {
	if (normal_value.x > 0.50) {
		return 0.92;
	}

	if (normal_value.x < -0.50) {
		return 0.76;
	}

	if (normal_value.z > 0.50) {
		return 0.85;
	}

	return 0.70;
}


void fragment() {
	vec3 normal_value = normalize(
		world_normal
	);

	float altitude = get_altitude(
		world_position
	);

	bool horizontal_surface = (
		abs(normal_value.y) > 0.50
	);

	vec2 pixel_uv = get_planar_uv(
		world_position,
		normal_value,
		horizontal_surface
			? top_texture_scale
			: side_texture_scale
	);

	vec3 sampled_texture = vec3(
		1.0
	);

	if (horizontal_surface) {
		if (
			altitude
			<= sea_level + coast_width
		) {
			sampled_texture = texture(
				sand_texture,
				pixel_uv
			).rgb;
		} else {
			sampled_texture = texture(
				grass_texture,
				pixel_uv
			).rgb;
		}
	} else {
		if (
			altitude
			>= rocky_height
		) {
			sampled_texture = texture(
				stone_texture,
				pixel_uv
			).rgb;
		} else {
			sampled_texture = texture(
				dirt_texture,
				pixel_uv
			).rgb;
		}
	}

	float pixel_brightness = (
		get_texture_brightness(
			sampled_texture
		)
	);

	vec3 base_color = quantize_color(
		COLOR.rgb
	);

	if (
		not horizontal_surface
		&& altitude >= rocky_height
	) {
		base_color = mix(
			base_color,
			quantize_color(
				rock_color
			),
			0.20
		);
	}

	float face_brightness = 1.0;

	if (horizontal_surface) {
		face_brightness = (
			normal_value.y >= 0.0
				? 1.06
				: 0.62
		);
	} else {
		face_brightness = (
			get_side_brightness(
				normal_value
			)
		);
	}

	vec3 final_color = (
		base_color
		* pixel_brightness
		* face_brightness
	);

	ALBEDO = clamp(
		quantize_color(
			final_color
		),
		vec3(0.0),
		vec3(1.0)
	);

	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;

	EMISSION = (
		ALBEDO
		* 0.035
	);
}
