shader_type spatial;
render_mode diffuse_burley;

// UV.x retains the append-only material slot. UV.y selects a species row.
// UV2.x carries individual shade. Far crowns deliberately omit tiny wind motion.
#include "res://assets/catalog/planet_surface_detail.gdshaderinc"

void fragment() {
	ALBEDO = planet_palette_color(UV) * UV2.x;
	ROUGHNESS = 0.92;
}
