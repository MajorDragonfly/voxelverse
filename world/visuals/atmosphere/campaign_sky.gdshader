shader_type sky;
render_mode disable_fog;

// Body-fixed 3D cloud field: no world-Y horizon, cube seams or rebase jumps.
// The radiance pass deliberately excludes the expensive cloud field and sun disc.
uniform vec3 radial_up = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_direction = vec3(0.0, 0.6, 0.8);
uniform vec3 zenith_color : source_color = vec3(0.18, 0.42, 0.68);
uniform vec3 horizon_color : source_color = vec3(0.69, 0.81, 0.87);
uniform vec3 sunlight_color : source_color = vec3(1.0, 0.84, 0.64);
uniform float daylight = 1.0;
uniform float sunset = 0.0;
uniform float cloud_cover = 0.5;
uniform vec3 cloud_offset = vec3(0.0);
uniform bool clouds_enabled = true;
uniform int cloud_octaves = 4;
uniform float star_seed = 0.0;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1,0,0)), f.x),
		mix(hash31(i + vec3(0,1,0)), hash31(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0,0,1)), hash31(i + vec3(1,0,1)), f.x),
		mix(hash31(i + vec3(0,1,1)), hash31(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float clouds(vec3 p) {
	float result = 0.0;
	float amplitude = 0.55;
	float total = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= cloud_octaves) { break; }
		result += amplitude * noise3(p);
		total += amplitude;
		p = p * 2.07 + vec3(17.1, 9.2, 13.7);
		amplitude *= 0.48;
	}
	return result / total;
}
void sky() {
	vec3 ray = normalize(EYEDIR);
	float elevation = dot(ray, radial_up);
	float sun_dot = clamp(dot(ray, sun_direction), 0.0, 1.0);
	vec3 night = mix(vec3(0.017,0.025,0.055), vec3(0.003,0.007,0.023), max(elevation,0.0));
	vec3 day = mix(horizon_color, zenith_color, pow(max(elevation,0.0),0.42));
	vec3 color = mix(night, day, daylight);
	float horizon_band = exp(-abs(elevation) * 5.5);
	color = mix(color, sunlight_color * 0.85, sunset * horizon_band * pow(sun_dot,3.0) * 0.72);
	if (elevation < 0.0) { color = mix(color, color * 0.28, smoothstep(0.0,0.5,-elevation)); }
	if (!AT_CUBEMAP_PASS) {
		color += sunlight_color * pow(sun_dot,48.0) * 0.18 * daylight;
		float disc = smoothstep(cos(0.012), cos(0.009), sun_dot);
		color += sunlight_color * disc * 5.0 * smoothstep(-0.025,0.01,dot(sun_direction,radial_up));
		vec3 star_cell = floor(ray * 700.0);
		float star = step(0.9985,hash31(star_cell + vec3(star_seed))) * pow(max(0.0,1.0-length(fract(ray*700.0)-0.5)*2.0),4.0);
		color += vec3(star) * (1.0-daylight) * smoothstep(0.0,0.2,elevation);
		if (clouds_enabled && elevation > 0.015) {
			float field = clouds(ray * 5.5 + cloud_offset);
			float threshold = mix(0.72,0.38,cloud_cover);
			float opacity = smoothstep(threshold,threshold+0.16,field) * smoothstep(0.015,0.16,elevation);
			vec3 shade = mix(vec3(0.025,0.036,0.065), horizon_color * 0.68, daylight);
			vec3 lit = mix(shade, mix(vec3(1.04),sunlight_color,sunset*0.6), daylight);
			vec3 cloud_color = mix(shade,lit,smoothstep(threshold,threshold+0.3,field));
			cloud_color += sunlight_color * pow(sun_dot,16.0) * 0.22 * daylight;
			color = mix(color,cloud_color,opacity*0.95);
		}
	}
	COLOR = color;
}
