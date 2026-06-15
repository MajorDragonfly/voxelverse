shader_type spatial;

render_mode depth_draw_opaque,
	cull_back,
	diffuse_burley,
	specular_schlick_ggx;


uniform bool spherical_planet = false;

uniform vec3 planet_center = vec3(
	0.0,
	0.0,
	0.0
);

uniform float planet_radius = 10000.0;
uniform float sea_level = -1.5;


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

uniform float shore_start_offset = 0.10;
uniform float shore_end_offset = 1.60;

uniform float snow_start_altitude = 4.8;
uniform float snow_end_altitude = 6.5;

uniform float macro_color_strength = 0.16;
uniform float strata_strength = 0.18;


varying vec3 world_position;
varying vec3 world_normal;


float get_planet_altitude(
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


vec3 get_planet_up(
	vec3 position
) {
	if (spherical_planet) {
		vec3 radial_direction = (
			position - planet_center
		);

		if (
			length(radial_direction)
			> 0.0001
		) {
			return normalize(
				radial_direction
			);
		}
	}

	return vec3(
		0.0,
		1.0,
		0.0
	);
}


float get_large_pattern(
	vec3 position
) {
	float pattern_a = sin(
		position.x * 0.031
		+ sin(
			position.z * 0.017
		)
	);

	float pattern_b = sin(
		position.z * 0.027
		+ sin(
			position.y * 0.041
		)
	);

	float pattern_c = sin(
		position.y * 0.019
		+ sin(
			position.x * 0.023
		)
	);

	return clamp(
		(
			pattern_a
			+ pattern_b
			+ pattern_c
		)
		/ 6.0
		+ 0.5,
		0.0,
		1.0
	);
}


float get_small_pattern(
	vec3 position
) {
	float detail_a = sin(
		position.x * 0.19
		+ position.z * 0.13
	);

	float detail_b = sin(
		position.z * 0.23
		- position.x * 0.11
	);

	return clamp(
		(
			detail_a
			+ detail_b
		)
		* 0.25
		+ 0.5,
		0.0,
		1.0
	);
}


void vertex() {
	world_position = (
		MODEL_MATRIX
		* vec4(
			VERTEX,
			1.0
		)
	).xyz;

	world_normal = normalize(
		(
			MODEL_MATRIX
			* vec4(
				NORMAL,
				0.0
			)
		).xyz
	);
}


void fragment() {
	vec3 surface_normal = normalize(
		world_normal
	);

	vec3 planet_up = get_planet_up(
		world_position
	);

	float altitude = get_planet_altitude(
		world_position
	);

	float upward_alignment = clamp(
		dot(
			surface_normal,
			planet_up
		),
		0.0,
		1.0
	);

	float slope = (
		1.0
		- upward_alignment
	);

	float large_pattern = get_large_pattern(
		world_position
	);

	float small_pattern = get_small_pattern(
		world_position
	);

	vec3 base_color = COLOR.rgb;

	float macro_variation = mix(
		1.0 - macro_color_strength,
		1.0 + macro_color_strength,
		large_pattern
	);

	base_color *= macro_variation;

	base_color *= mix(
		0.95,
		1.06,
		small_pattern
	);


	float shore_mask = (
		1.0
		- smoothstep(
			sea_level
				+ shore_start_offset,
			sea_level
				+ shore_end_offset,
			altitude
		)
	);

	shore_mask *= smoothstep(
		0.05,
		0.85,
		upward_alignment
	);

	base_color = mix(
		base_color,
		wet_ground_color
			* mix(
				0.72,
				1.0,
				small_pattern
			),
		shore_mask * 0.62
	);


	float rock_mask = smoothstep(
		rock_slope_start,
		rock_slope_end,
		slope
	);

	float strata_pattern = (
		sin(
			altitude * 4.5
			+ large_pattern * 3.0
		)
		* 0.5
		+ 0.5
	);

	vec3 layered_rock_color = mix(
		rock_color,
		rock_strata_color,
		strata_pattern
			* strata_strength
	);

	layered_rock_color *= mix(
		0.86,
		1.10,
		large_pattern
	);

	base_color = mix(
		base_color,
		layered_rock_color,
		rock_mask
	);


	float snow_height_mask = smoothstep(
		snow_start_altitude,
		snow_end_altitude,
		altitude
	);

	float snow_slope_mask = (
		1.0
		- smoothstep(
			0.18,
			0.58,
			slope
		)
	);

	float snow_mask = (
		snow_height_mask
		* snow_slope_mask
		* mix(
			0.72,
			1.0,
			large_pattern
		)
	);

	base_color = mix(
		base_color,
		snow_color
			* mix(
				0.88,
				1.08,
				small_pattern
			),
		snow_mask
	);


	float height_lighting = smoothstep(
		sea_level + 0.5,
		snow_end_altitude,
		altitude
	);

	base_color *= mix(
		0.90,
		1.06,
		height_lighting
	);


	ALBEDO = clamp(
		base_color,
		vec3(0.0),
		vec3(1.0)
	);

	ROUGHNESS = mix(
		0.90,
		1.0,
		rock_mask
	);

	SPECULAR = mix(
		0.18,
		0.26,
		shore_mask
	);

	METALLIC = 0.0;
}
