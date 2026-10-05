shader_type spatial;
render_mode diffuse_burley;

#include "res://assets/catalog/planet_surface_detail.gdshaderinc"
uniform sampler2D nearby_ownership : filter_nearest, repeat_disable;
uniform float wind_strength = 0.025;
uniform float motion_time = 0.0;
uniform float wind_speed = 0.85;
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform bool detailed_patch = false;
uniform float patch_coverage = 1.0;
varying float shade;
varying float distance_to_observer;
varying float nearby_coverage;
varying vec3 surface_position;

void vertex() {
	// The same authored coordinates as the settled near material: no grain
	// jump when the origin recenters or the complementary LOD mask changes.
	surface_position = VERTEX;
	vec3 root = MODEL_MATRIX[3].xyz;
	distance_to_observer = distance(root, CAMERA_POSITION_WORLD);
	shade = INSTANCE_CUSTOM.r > 0.0 ? INSTANCE_CUSTOM.r : 1.0;
	float cell = round(INSTANCE_CUSTOM.b * 2048.0);
	nearby_coverage = detailed_patch ? patch_coverage : texture(nearby_ownership, vec2((cell + 0.5) / 2048.0, 0.5)).r;
	if (!detailed_patch && nearby_coverage >= 1.0) {
		// Collapse the entire instance only after the detailed patch is published.
		VERTEX = vec3(0.0);
	} else {
		float slot = floor(UV.x * 32.0);
		bool leaf = slot < 4.0 || (slot >= 20.0 && slot <= 22.0);
		if (leaf && detailed_patch) {
			// Match the settled near shader throughout the complementary mask.
			// Proxy scenery remains still; pause and rebase preserve the pose.
			float distance_fade = 1.0 - smoothstep(28.0, 78.0, distance((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, CAMERA_POSITION_WORLD));
			float phase = INSTANCE_CUSTOM.g * 6.2831853;
			float bend = sin(motion_time * wind_speed + VERTEX.y * 0.6 + phase) * wind_strength
				* clamp(VERTEX.y * 0.8, 0.0, 1.0) * distance_fade;
			VERTEX.xz += wind_direction * bend;
		}
	}
}

void fragment() {
	// Opaque coverage avoids transparent sorting and softens the outer boundary.
	ivec2 pixel = ivec2(FRAGCOORD.xy) % 4;
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float threshold = (bayer[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	// One complementary mask in both shaders: geometry/palette stay canonical
	// while the published LOD changes, including on a reversed walking route.
	if (detailed_patch ? threshold >= nearby_coverage : threshold < nearby_coverage) { discard; }
	float coverage = 1.0 - smoothstep(224.0, 256.0, distance_to_observer);
	if (!detailed_patch && coverage < threshold) { discard; }
	ALBEDO = planet_surface_color(UV, surface_position) * shade;
	ROUGHNESS = 0.92;
}
