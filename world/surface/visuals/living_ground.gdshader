shader_type spatial;
render_mode cull_back, diffuse_lambert;
#include "res://world/surface/visuals/surface_detail.gdshaderinc"
uniform vec3 soil_color : source_color = vec3(0.35, 0.27, 0.17);
uniform vec3 rock_color : source_color = vec3(0.39, 0.42, 0.41);

void fragment() {
	if (!covered(FRAGCOORD.xy)) { discard; }
	float top = smoothstep(0.35, 0.82, dot(normalize(surface_normal), normalize(surface_up)));
	float near_detail = 1.0 - smoothstep(20.0, 52.0, camera_distance);
	float mid_detail = 1.0 - smoothstep(45.0, 110.0, camera_distance);
	// Half- and eighth-metre colour cells match the existing V9 ground rhythm.
	// Fade before subpixel sizes; no second floating mesh or extra collider.
	float footprint = max(length(dFdx(surface_position)), length(dFdy(surface_position)));
	near_detail *= 1.0 - smoothstep(0.05, 0.14, footprint);
	float grain = (voxel_hash(surface_position, 8.0) - 0.5) * 0.09 * near_detail;
	grain += (voxel_hash(surface_position, 2.0) - 0.5) * 0.045 * mid_detail;
	vec3 base = vertex_pigment(COLOR.rgb);
	vec3 side = mix(soil_color, rock_color, smoothstep(38.0, 95.0, surface_altitude));
	float strata = (step(0.65, fract(surface_altitude * 2.0)) - 0.3) * 0.055 * mid_detail;
	base = mix(mix(base, side, 0.68) * (1.0 + strata), base, top);
	float damp = (1.0 - smoothstep(0.1, 1.4, surface_altitude)) * (1.0 - smoothstep(500.0, 1200.0, camera_distance));
	ALBEDO = clamp(base * (1.0 + grain) * (1.0 - damp * 0.16), vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.95, 0.8, damp);
	SPECULAR = 0.06;
}
