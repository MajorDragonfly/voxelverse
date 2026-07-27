shader_type spatial;

render_mode
	depth_draw_opaque,
	cull_back,
	diffuse_lambert;

uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D sand_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_nearest, repeat_enable;

uniform float top_texture_scale : hint_range(0.05, 4.0, 0.05) = 0.75;
uniform float side_texture_scale : hint_range(0.05, 4.0, 0.05) = 0.70;
uniform float palette_steps : hint_range(2.0, 12.0, 1.0) = 8.0;
uniform float texture_darkness : hint_range(0.20, 1.00, 0.01) = 0.82;
uniform float texture_brightness : hint_range(0.80, 1.50, 0.01) = 1.08;

uniform bool spherical_planet = false;
uniform vec3 planet_center = vec3(0.0);
uniform float planet_radius = 10000.0;
uniform float sea_level = -1.5;
uniform float coast_width = 1.0;
uniform float rocky_height = 4.5;
uniform vec3 rock_color : source_color = vec3(0.36, 0.38, 0.39);
uniform vec3 rock_strata_color : source_color = vec3(0.46, 0.36, 0.28);
uniform vec3 wet_ground_color : source_color = vec3(0.10, 0.24, 0.17);
uniform vec3 snow_color : source_color = vec3(0.78, 0.84, 0.83);
uniform float rock_slope_start = 0.28;
uniform float rock_slope_end = 0.62;
uniform float macro_color_strength = 0.16;
uniform float strata_strength = 0.10;
uniform float snow_start_altitude = 10.8;
uniform float snow_end_altitude = 14.3;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 vertex_base_color;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vertex_base_color = COLOR.rgb;
}


float get_altitude(vec3 position_value) {
	if (spherical_planet) {
		return length(position_value - planet_center) - planet_radius;
	}
	return position_value.y;
}


vec2 get_planar_uv(vec3 position_value, vec3 normal_value, float scale_value) {
	vec3 absolute_normal = abs(normal_value);
	if (absolute_normal.y >= absolute_normal.x && absolute_normal.y >= absolute_normal.z) {
		return position_value.xz * scale_value;
	}
	if (absolute_normal.x >= absolute_normal.z) {
		return position_value.zy * scale_value;
	}
	return position_value.xy * scale_value;
}


float texture_luminance(vec3 color_value) {
	return dot(color_value, vec3(0.299, 0.587, 0.114));
}


float quantize_value(float value, float steps) {
	float safe_steps = max(steps - 1.0, 1.0);
	return floor(clamp(value, 0.0, 1.0) * safe_steps + 0.5) / safe_steps;
}


void fragment() {
	vec3 normal_value = normalize(world_normal);
	float altitude = get_altitude(world_position);
	bool top_surface = normal_value.y > 0.50;
	bool side_surface = abs(normal_value.y) <= 0.50;
	float selected_scale = top_surface ? top_texture_scale : side_texture_scale;
	vec2 pixel_uv = get_planar_uv(world_position, normal_value, selected_scale);

	vec3 sampled_texture;
	if (top_surface) {
		bool coast_surface = altitude <= sea_level + coast_width;
		sampled_texture = coast_surface
			? texture(sand_texture, pixel_uv).rgb
			: texture(grass_texture, pixel_uv).rgb;
	} else {
		bool rocky_surface = altitude >= rocky_height;
		sampled_texture = rocky_surface
			? texture(stone_texture, pixel_uv).rgb
			: texture(dirt_texture, pixel_uv).rgb;
	}

	float texture_value = quantize_value(
		texture_luminance(sampled_texture),
		palette_steps
	);
	float pixel_brightness = mix(
		max(texture_darkness, 0.78),
		texture_brightness,
		texture_value
	);

	vec3 base_color = clamp(vertex_base_color, vec3(0.0), vec3(1.0));
	float slope = 1.0 - abs(normal_value.y);
	float rock_weight = smoothstep(rock_slope_start, rock_slope_end, slope);
	rock_weight *= side_surface ? 0.58 : 0.22;
	base_color = mix(base_color, rock_color, rock_weight);

	float snow_weight = smoothstep(
		snow_start_altitude,
		snow_end_altitude,
		altitude
	);
	base_color = mix(base_color, snow_color, snow_weight * 0.78);

	float strata = step(0.64, fract(altitude * 0.68));
	base_color = mix(
		base_color,
		rock_strata_color,
		strata * strata_strength * rock_weight
	);

	// Real scene lighting supplies direction and shadows. This only keeps vertical
	// faces readable, instead of multiplying them by a nearly black fake light.
	float surface_readability = mix(0.86, 1.0, smoothstep(0.0, 0.65, normal_value.y));
	ALBEDO = clamp(base_color * pixel_brightness * surface_readability, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	SPECULAR = 0.06;
}
