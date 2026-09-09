uniform float lod_phase = 1.0;
uniform bool lod_retiring = false;
uniform vec3 origin_phase = vec3(0.0);
uniform vec3 origin_up = vec3(0.0, 1.0, 0.0);
uniform float origin_height = 0.0;
uniform float body_radius = 6371000.0;
uniform float surface_time = 0.0;
varying vec3 surface_position;
varying vec3 surface_normal;
varying vec3 surface_up;
varying float surface_altitude;
varying float camera_distance;

void vertex() {
	vec3 local = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Only the small periodic remainder of the double origin enters shading.
	// Never subtract two Earth-sized float positions to recover pixel detail.
	surface_position = local + origin_phase;
	surface_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	surface_up = normalize(origin_up + local / body_radius);
	float radial = dot(local, origin_up);
	surface_altitude = origin_height + radial + (dot(local, local) - radial * radial) / (2.0 * body_radius);
	camera_distance = distance(CAMERA_POSITION_WORLD, local);
}

bool covered(vec2 screen_pixel) {
	ivec2 pixel = ivec2(screen_pixel) % 4;
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float threshold = (bayer[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	return lod_retiring ? threshold >= lod_phase : threshold < lod_phase;
}

float voxel_hash(vec3 position, float scale) {
	vec3 cell = floor(mod(position, vec3(128.0)) * scale);
	vec3 p = fract(cell * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 vertex_pigment(vec3 value) {
	if (!OUTPUT_IS_SRGB) {
		return mix(value / 12.92, pow((value + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), value));
	}
	return value;
}
