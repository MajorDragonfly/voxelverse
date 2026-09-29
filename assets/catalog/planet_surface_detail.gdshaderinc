// Shared by the near asset and the distant scenery handoff. The atlas keeps
// the authored hue; only the darkest painted faces are brought closer to the
// base tone so a face is not darkened twice by paint and real lighting.
uniform sampler2D planet_palette : source_color, filter_nearest, repeat_disable;

vec3 planet_slot(float index, float row) {
	return texture(planet_palette, vec2((index + 0.5) / 32.0, row)).rgb;
}

vec3 planet_surface_color(vec2 atlas_uv, vec3 surface_position) {
	float slot = floor(atlas_uv.x * 32.0);
	vec3 color = texture(planet_palette, atlas_uv).rgb;
	if (slot == 2.0 || slot == 3.0) {
		color = mix(color, planet_slot(1.0, atlas_uv.y), slot == 3.0 ? 0.30 : 0.22);
	} else if (slot == 6.0) {
		color = mix(color, planet_slot(5.0, atlas_uv.y), 0.28);
	} else if (slot == 14.0) {
		color = mix(color, planet_slot(13.0, atlas_uv.y), 0.25);
	} else if (slot == 22.0) {
		color = mix(color, planet_slot(20.0, atlas_uv.y), 0.22);
	}
	// World-space grain crosses adjacent voxel faces. Screen derivatives remove
	// the detail before it becomes subpixel flicker at distant LODs.
	float fade = 1.0 - smoothstep(0.07, 0.18, length(fwidth(surface_position)));
	float grain = 0.0;
	if (slot >= 4.0 && slot <= 6.0) {
		grain = sin(surface_position.y * 22.0 + sin(surface_position.x * 6.0 + surface_position.z * 8.0)) * 0.065;
	} else if ((slot >= 0.0 && slot <= 3.0) || (slot >= 20.0 && slot <= 22.0)) {
		grain = sin(dot(surface_position, vec3(13.0, 17.0, 11.0))) * 0.055;
	} else if (slot >= 12.0 && slot <= 14.0) {
		grain = sin(dot(surface_position, vec3(9.0, 11.0, 14.0))) * sin(dot(surface_position, vec3(15.0, 7.0, -8.0))) * 0.075;
	}
	return color * (1.0 + grain * fade);
}
