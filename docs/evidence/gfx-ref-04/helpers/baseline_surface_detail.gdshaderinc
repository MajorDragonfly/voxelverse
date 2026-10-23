// Shared by the near asset and the distant scenery handoff. The atlas keeps
// the authored hue; only the darkest painted faces are brought closer to the
// base tone so a face is not darkened twice by paint and real lighting.
uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;

vec3 planet_slot(float index, float row) {
	return texture(planet_palette, vec2((index + 0.5) / 32.0, row)).rgb;
}

float planet_detail_weight(float phase) {
	// Filter the actual sinusoidal phase, including its orientation/scale.
	// A world-unit cutoff alone allowed the highest frequency to alias.
	float footprint = max(abs(dFdx(phase)), abs(dFdy(phase)));
	return 1.0 - smoothstep(0.65, 2.0, footprint);
}

float planet_cell_hash(vec3 cell) {
	vec3 p = fract(cell * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float planet_cell_grain(vec3 position, vec3 scale) {
	vec3 p = position * scale;
	vec3 footprint = max(abs(dFdx(p)), abs(dFdy(p)));
	float width = max(footprint.x, max(footprint.y, footprint.z));
	// Filter each material's actual frequency. A narrow, smooth transition
	// between authored cells retains a voxel mosaic without hard crawling edges.
	vec3 cell = floor(p);
	vec3 blend = smoothstep(vec3(0.20), vec3(0.80), fract(p));
	float lower = mix(mix(planet_cell_hash(cell), planet_cell_hash(cell + vec3(1, 0, 0)), blend.x),
		mix(planet_cell_hash(cell + vec3(0, 1, 0)), planet_cell_hash(cell + vec3(1, 1, 0)), blend.x), blend.y);
	float upper = mix(mix(planet_cell_hash(cell + vec3(0, 0, 1)), planet_cell_hash(cell + vec3(1, 0, 1)), blend.x),
		mix(planet_cell_hash(cell + vec3(0, 1, 1)), planet_cell_hash(cell + vec3(1, 1, 1)), blend.x), blend.y);
	return (mix(lower, upper, blend.z) - 0.5) * 2.0 * (1.0 - smoothstep(0.45, 1.0, width));
}

vec3 planet_surface_color(vec2 atlas_uv, vec3 surface_position) {
	float slot = floor(atlas_uv.x * 32.0);
	vec3 color = texture(planet_palette, atlas_uv).rgb;
	if (slot == 0.0) {
		color = mix(color, planet_slot(1.0, atlas_uv.y), 0.20);
	} else if (slot == 21.0) {
		color = mix(color, planet_slot(20.0, atlas_uv.y), 0.15);
	} else if (slot == 2.0 || slot == 3.0) {
		color = mix(color, planet_slot(1.0, atlas_uv.y), slot == 3.0 ? 0.30 : 0.22);
	} else if (slot == 6.0) {
		color = mix(color, planet_slot(5.0, atlas_uv.y), 0.28);
	} else if (slot == 14.0) {
		color = mix(color, planet_slot(13.0, atlas_uv.y), 0.25);
	} else if (slot == 22.0) {
		color = mix(color, planet_slot(20.0, atlas_uv.y), 0.22);
	}
	// Asset-space grain crosses adjacent voxel faces without swimming during
	// origin shifts. Each frequency fades before it becomes subpixel detail.
	float grain = 0.0;
	if (slot >= 4.0 && slot <= 6.0) {
		// Longitudinal bark instead of horizontal zebra rings. All sampling is
		// in authored space, shared by settled flora and the scenery handoff.
		grain = planet_cell_grain(surface_position, vec3(11.0, 1.6, 11.0)) * 0.13;
		grain += planet_cell_grain(surface_position, vec3(25.0, 4.0, 25.0)) * 0.045;
	} else if ((slot >= 0.0 && slot <= 3.0) || (slot >= 20.0 && slot <= 22.0)) {
		grain = planet_cell_grain(surface_position, vec3(3.0)) * 0.065;
		grain += planet_cell_grain(surface_position, vec3(10.0)) * 0.04;
	} else if (slot >= 12.0 && slot <= 14.0) {
		grain = planet_cell_grain(surface_position, vec3(4.0, 7.0, 4.0)) * 0.11;
		grain += planet_cell_grain(surface_position, vec3(17.0)) * 0.045;
	}
	return color * (1.0 + grain);
}
