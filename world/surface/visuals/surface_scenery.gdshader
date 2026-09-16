shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D nearby_ownership : filter_nearest, repeat_disable;
uniform float wind_strength = 0.025;
varying float shade;
varying float distance_to_observer;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	distance_to_observer = distance(root, CAMERA_POSITION_WORLD);
	shade = INSTANCE_CUSTOM.r;
	float cell = round(INSTANCE_CUSTOM.b * 2048.0);
	bool owned = texture(nearby_ownership, vec2((cell + 0.5) / 2048.0, 0.5)).r > 0.5;
	if (owned) {
		// Collapse the entire instance only after the detailed patch is published.
		VERTEX = vec3(0.0);
	} else {
		float slot = floor(UV.x * 32.0);
		bool leaf = slot < 4.0 || (slot >= 20.0 && slot <= 22.0);
		if (leaf) {
			VERTEX.x += sin(TIME * 0.85 + VERTEX.y * 0.6 + INSTANCE_CUSTOM.g * 6.2831853)
				* wind_strength * clamp(VERTEX.y * 0.22, 0.0, 1.0);
		}
	}
}

void fragment() {
	// Opaque coverage avoids transparent sorting and softens the outer boundary.
	ivec2 pixel = ivec2(FRAGCOORD.xy) % 4;
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float coverage = 1.0 - smoothstep(224.0, 256.0, distance_to_observer);
	if (coverage < (bayer[pixel.y * 4 + pixel.x] + 0.5) / 16.0) { discard; }
	ALBEDO = texture(planet_palette, UV).rgb * shade;
	ROUGHNESS = 0.92;
}
