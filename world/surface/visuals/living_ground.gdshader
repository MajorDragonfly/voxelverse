shader_type spatial;
render_mode cull_back, diffuse_lambert;
#include "res://world/surface/visuals/surface_detail.gdshaderinc"
uniform vec3 soil_color : source_color = vec3(0.35, 0.27, 0.17);
uniform vec3 rock_color : source_color = vec3(0.39, 0.42, 0.41);
uniform vec3 grass_color : source_color = vec3(0.31, 0.45, 0.28);
uniform vec3 dry_color : source_color = vec3(0.55, 0.43, 0.27);
uniform vec3 coast_color : source_color = vec3(0.73, 0.64, 0.44);
uniform vec3 snow_color : source_color = vec3(0.83, 0.88, 0.86);

// The mesh already blends the planet's biome palette into vertex pigment.
// Recover soft material weights from those same colours, without another
// biome query, UV atlas or geometry pass. Squared distance avoids five roots.
float material_score(vec3 pigment, vec3 reference) {
	vec3 delta = pigment - reference;
	float score = 1.0 / (0.012 + dot(delta, delta));
	return score * score;
}

void fragment() {
	if (!covered(FRAGCOORD.xy)) { discard; }
	float top = smoothstep(0.35, 0.82, dot(normalize(surface_normal), normalize(surface_up)));
	float near_detail = 1.0 - smoothstep(20.0, 52.0, camera_distance);
	float mid_detail = 1.0 - smoothstep(45.0, 110.0, camera_distance);
	float macro_detail = 1.0 - smoothstep(80.0, 145.0, camera_distance);
	// Body-fixed cells preserve the same pattern across chunks and origin shifts.
	// Screen derivatives remove each frequency before it becomes subpixel noise.
	float footprint = max(length(dFdx(surface_position)), length(dFdy(surface_position)));
	near_detail *= 1.0 - smoothstep(0.05, 0.14, footprint);
	mid_detail *= 1.0 - smoothstep(0.20, 0.48, footprint);
	macro_detail *= 1.0 - smoothstep(0.65, 1.3, footprint);
	vec3 base = vertex_pigment(COLOR.rgb);
	float grass = material_score(base, grass_color);
	float dry = material_score(base, dry_color);
	float sand = material_score(base, coast_color);
	float rock = material_score(base, rock_color);
	float snow = material_score(base, snow_color);
	float total = grass + dry + sand + rock + snow;
	grass /= total;
	dry /= total;
	sand /= total;
	rock /= total;
	snow /= total;
	// Exposed risers use soil at low altitude and stratified rock up high.
	float side_rock = smoothstep(38.0, 95.0, surface_altitude);
	grass *= top;
	dry = dry * top + (1.0 - top) * (1.0 - side_rock);
	sand *= top;
	rock = rock * top + (1.0 - top) * side_rock;
	snow *= top;
	float fine = (voxel_hash(surface_position, 8.0) - 0.5) * 2.0 * near_detail;
	float mid = (voxel_hash(surface_position, 2.0) - 0.5) * 2.0 * mid_detail;
	float patch = (voxel_hash(surface_position, 0.5) - 0.5) * 2.0 * macro_detail;
	float grain = fine * (grass * 0.10 + dry * 0.13 + sand * 0.06 + rock * 0.11 + snow * 0.025);
	grain += mid * (grass * 0.08 + dry * 0.085 + sand * 0.055 + rock * 0.075 + snow * 0.03);
	grain += patch * (grass * 0.14 + dry * 0.11 + sand * 0.085 + rock * 0.085 + snow * 0.035);
	vec3 side = mix(soil_color, rock_color, smoothstep(38.0, 95.0, surface_altitude));
	float strata = (step(0.65, fract(surface_altitude * 2.0)) - 0.3) * 0.09 * mid_detail * rock;
	base = mix(mix(base, side, 0.68) * (1.0 + strata), base, top);
	float damp = (1.0 - smoothstep(0.1, 1.4, surface_altitude)) * (1.0 - smoothstep(500.0, 1200.0, camera_distance));
	ALBEDO = clamp(base * (1.0 + grain) * (1.0 - damp * 0.16), vec3(0.0), vec3(1.0));
	ROUGHNESS = clamp(0.97 - rock * 0.04 - snow * 0.07 - damp * 0.14, 0.78, 0.98);
	SPECULAR = 0.06;
}
