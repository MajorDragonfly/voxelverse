shader_type spatial;
render_mode diffuse_burley;

// UV.x retains the append-only material slot. UV.y selects a species row.
// UV2.x carries individual shade. Far crowns deliberately omit tiny wind motion.
uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;

void fragment() {
	ALBEDO = texture(planet_palette, UV).rgb * UV2.x;
	ROUGHNESS = 0.92;
}
