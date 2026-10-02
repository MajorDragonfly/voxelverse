shader_type spatial;
render_mode diffuse_burley;

#include "res://assets/catalog/planet_surface_detail.gdshaderinc"
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float wind_strength : hint_range(0.0, 0.08) = 0.0;
uniform float motion_time = 0.0;
uniform float wind_speed = 0.85;
uniform vec2 wind_direction = vec2(1.0, 0.0);
varying float individual_shade;
varying vec3 surface_position;

void vertex() {
	// Authored coordinates survive origin rebases and both scenery shaders.
	// Sample before wind bending so the grain follows the moving leaf blocks.
	surface_position = VERTEX;
	float slot = floor(UV.x * 32.0);
	bool leaf = slot < 4.0 || (slot >= 20.0 && slot <= 22.0);
	individual_shade = INSTANCE_CUSTOM.r > 0.0 ? INSTANCE_CUSTOM.r : 1.0;
	if (leaf) {
		// The campaign clock freezes on pause. Per-instance phase prevents a
		// synchronized forest; the root/trunk and distant LOD stay still.
		float distance_fade = 1.0 - smoothstep(28.0, 78.0, distance((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, CAMERA_POSITION_WORLD));
		// The authored instance phase survives origin shifts. World translation
		// changes on rebase and must not change the leaf's current pose.
		float phase = INSTANCE_CUSTOM.g * 6.2831853;
		float bend = sin(motion_time * wind_speed + VERTEX.y * 0.6 + phase) * wind_strength
			* clamp(VERTEX.y * 0.8, 0.0, 1.0) * distance_fade;
		VERTEX.xz += wind_direction * bend;
	}
}

void fragment() {
	ALBEDO = planet_surface_color(UV, surface_position) * individual_shade;
	ROUGHNESS = roughness_value;
}
