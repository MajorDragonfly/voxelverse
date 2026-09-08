shader_type spatial;
render_mode cull_back;
uniform sampler2D coverage : filter_nearest, repeat_disable;
uniform vec2 coverage_origin = vec2(0.0);
uniform vec2 chunk_size = vec2(32.0);
varying vec2 world_xz;
void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	vec2 uv = (floor((world_xz + chunk_size * 0.5) / chunk_size) - coverage_origin + 0.5) / 16.0;
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0))) && texture(coverage, uv).g > 0.5) { discard; }
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.98;
}
