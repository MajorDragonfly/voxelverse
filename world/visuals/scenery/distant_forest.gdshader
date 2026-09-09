shader_type spatial;
render_mode world_vertex_coords, diffuse_burley;

#include "res://world/visuals/terrain/terrain_transition.gdshaderinc"
uniform sampler2D forest_ownership : filter_nearest, repeat_disable;
uniform int species_bit = 1;
uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;
varying float shade;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 cell = floor((root.xz + terrain_chunk_size * 0.5) / terrain_chunk_size);
	vec2 uv = (cell - terrain_coverage_origin + 0.5) / 16.0;
	bool owned = false;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
		int mask = int(round(texture(forest_ownership, uv).r * 255.0));
		owned = (mask & species_bit) != 0;
	}
	float detail = terrain_detail_weight(root.xz);
	float offset = mix(INSTANCE_CUSTOM.b, INSTANCE_CUSTOM.a * terrain_proxy_weight(root.xz), detail);
	// Collapse a whole instance, never cut holes through a stem or crown.
	VERTEX = owned ? root : VERTEX + vec3(0.0, offset, 0.0);
	shade = INSTANCE_CUSTOM.r;
}

void fragment() {
	ALBEDO = texture(planet_palette, UV).rgb * shade;
	ROUGHNESS = 0.92;
}
