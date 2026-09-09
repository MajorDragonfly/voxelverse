uniform float lod_phase = 1.0;
uniform bool lod_retiring = false;
uniform bool water = false;
uniform vec4 water_color : source_color = vec4(0.141, 0.486, 0.616, 1.0);

void fragment() {
	// Complementary opaque coverage; no transparent sorting or disappearing cover.
	ivec2 pixel = ivec2(FRAGCOORD.xy) % 4;
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	float threshold = (bayer[pixel.y * 4 + pixel.x] + 0.5) / 16.0;
	if ((lod_retiring && threshold < lod_phase) || (!lod_retiring && threshold >= lod_phase)) {
		discard;
	}
	vec3 pigment = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		pigment = mix(pigment / 12.92, pow((pigment + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), pigment));
	}
	ALBEDO = water ? water_color.rgb : pigment;
	ROUGHNESS = water ? 0.9 : 0.95;
}
