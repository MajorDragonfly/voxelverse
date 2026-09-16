shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_lambert;
#include "res://world/surface/visuals/surface_detail.gdshaderinc"
uniform vec3 deep_color : source_color = vec3(0.035, 0.22, 0.31);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.52, 0.53);
uniform vec3 foam_color : source_color = vec3(0.72, 0.84, 0.80);

void fragment() {
	if (!covered(FRAGCOORD.xy)) { discard; }
	vec3 up = normalize(surface_up);
	// The surface owns depth, so underwater geometry and its screen-space
	// shadows cannot be composited over it. Terrain still occludes dry banks.
	// Signed procedural depth rejects dry/coincident water on both sides.
	if (UV.x < 0.025) { discard; }
	float detail = 1.0 - smoothstep(60.0, 160.0, camera_distance);
	// Depth comes from the same terrain samples as the mesh, not screen depth.
	// It remains valid below water, across a cube edge and in Compatibility.
	float depth = max(UV.x, 0.0);
	float deep = 1.0 - exp(-depth / 9.0);
	vec3 pigment = mix(shallow_color, deep_color, deep);
	vec3 phase = surface_position * (6.28318530718 / 8.0);
	vec3 ripple = vec3(cos(phase.y + phase.z + surface_time * 0.62),
		sin(phase.z - phase.x + surface_time * 0.47), cos(phase.x + phase.y - surface_time * 0.53));
	vec3 tangent = ripple - up * dot(ripple, up);
	vec3 water_normal = normalize(up + tangent * 0.025 * detail);
	float cell = voxel_hash(surface_position, 2.0);
	float patch = (cell - 0.5) * 0.055 * detail;
	float surge = sin(surface_time * 0.8 + dot(phase, vec3(1.0, 1.0, 1.0))) * 0.12;
	float foam = (1.0 - smoothstep(0.1, 0.6 + surge, depth)) * smoothstep(0.55, 0.85, cell) * detail;
	float facing = abs(dot(normalize(VIEW), normalize((VIEW_MATRIX * vec4(up, 0.0)).xyz)));
	pigment = mix(pigment * (1.0 + patch), shallow_color, pow(1.0 - facing, 4.0) * 0.18);
	if (!FRONT_FACING) {
		water_normal = -water_normal;
		foam = 0.0;
		pigment = mix(deep_color, shallow_color, 0.3);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(water_normal, 0.0)).xyz);
	ALBEDO = mix(pigment, foam_color, foam * 0.35);
	ROUGHNESS = 0.72;
	SPECULAR = FRONT_FACING ? 0.12 : 0.0;
}
