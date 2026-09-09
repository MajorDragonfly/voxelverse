shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float wind_strength : hint_range(0.0, 0.08) = 0.025;
varying float individual_shade;

void vertex() {
	float slot = floor(UV.x * 32.0);
	bool leaf = slot < 4.0 || (slot >= 20.0 && slot <= 22.0);
	individual_shade = INSTANCE_CUSTOM.r > 0.0 ? INSTANCE_CUSTOM.r : 1.0;
	if (leaf) {
		// Small crown motion, stable trunk, no per-leaf nodes or animations.
		float phase = INSTANCE_CUSTOM.g * 6.2831853;
		VERTEX.x += sin(TIME * 0.85 + VERTEX.y * 0.6 + phase) * wind_strength * clamp(VERTEX.y * 0.22, 0.0, 1.0);
	}
}

void fragment() {
	ALBEDO = texture(planet_palette, UV).rgb * individual_shade;
	ROUGHNESS = roughness_value;
}
