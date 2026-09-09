uniform bool terrain_coverage_enabled = false;
uniform sampler2D terrain_coverage : filter_nearest, repeat_disable;
uniform vec2 terrain_coverage_origin = vec2(0.0);
uniform vec2 terrain_chunk_size = vec2(32.0);
uniform float terrain_lod_blend = 0.0;
uniform bool terrain_is_proxy = false;

float terrain_presence(vec2 cell) {
	vec2 uv = (cell - terrain_coverage_origin + 0.5) / 16.0;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) { return 0.0; }
	return texture(terrain_coverage, uv).r;
}

float terrain_detail_weight(vec2 point) {
	if (!terrain_coverage_enabled) { return 1.0; }
	vec2 cell = floor((point + terrain_chunk_size * 0.5) / terrain_chunk_size);
	float detail = 1.0;
	for (int z = -1; z <= 1; z++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = cell + vec2(float(x), float(z));
			vec2 gap = max(abs(point - neighbor * terrain_chunk_size) - terrain_chunk_size * 0.5, vec2(0.0));
			if (dot(gap, gap) < 64.0) {
				float interior = smoothstep(0.0, 8.0, length(gap));
				detail = min(detail, mix(terrain_presence(neighbor), 1.0, interior));
			}
		}
	}
	return detail;
}

float terrain_proxy_weight(vec2 point) {
	float blend = terrain_lod_blend;
	if (!terrain_coverage_enabled) { return blend; }
	vec2 cell = floor((point + terrain_chunk_size * 0.5) / terrain_chunk_size);
	for (int z = -1; z <= 1; z++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = cell + vec2(float(x), float(z));
			vec2 uv = (neighbor - terrain_coverage_origin + 0.5) / 16.0;
			if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
				vec2 gap = max(abs(point - neighbor * terrain_chunk_size) - terrain_chunk_size * 0.5, vec2(0.0));
				if (dot(gap, gap) < 16.0) {
					blend = max(blend, texture(terrain_coverage, uv).b * (1.0 - smoothstep(0.0, 4.0, length(gap))));
				}
			}
		}
	}
	return blend;
}
