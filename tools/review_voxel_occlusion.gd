extends "res://tools/review_r32_06_campaign_light.gd"
## One-factor baked-AO comparison in the public, paused spherical campaign.
## The shared campaign probe supplies loading, streaming, clock and raw draws.
var pairs: Array = []

func _choose_views() -> Array:
	var start: Dictionary = scene.player.location()
	var frame: Basis = scene.adapter.frame_at(start)
	var chosen: Dictionary = start.duplicate(true)
	var best: float = -1.0
	for z: int in range(-6, 7):
		for x: int in range(-6, 7):
			var at: Dictionary = scene.adapter.offset(start, frame.x * x * 160 + frame.z * z * 160, 1.1)
			var sample: Dictionary = scene.terrain.surface.sample(at)
			var score: float = float(sample.biome_weights.get("forest", 0.0)) + float(sample.biome_weights.get("dense_forest", 0.0))
			if score > best: best = score; chosen = at
	var sample: Dictionary = scene.terrain.surface.sample(chosen)
	chosen.height = maxf(float(sample.height), float(sample.water_level)) + 1.1
	return [
		{"id": "forest", "address": chosen, "sample": sample,
			"camera_offset": [14, 10, 20], "target_offset": [0, -1, -22]},
		{"id": "forest-floor", "address": chosen.duplicate(true), "sample": sample,
			"camera_offset": [3, 1.8, 5], "target_offset": [0, -0.7, -8]}]

func _add_material(material: Material, result: Dictionary) -> void:
	if material is ShaderMaterial and material.shader != null and material.shader.resource_path in [
		"res://assets/catalog/planet_foliage.gdshader", "res://world/surface/visuals/surface_scenery.gdshader"]:
		result[material.get_instance_id()] = material

func _find_materials(node: Node, result: Dictionary) -> void:
	if node is GeometryInstance3D:
		_add_material(node.material_override, result)
	if node is MeshInstance3D and node.mesh != null:
		for surface: int in range(node.mesh.get_surface_count()):
			_add_material(node.get_active_material(surface), result)
	if node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh != null:
		for surface: int in range(node.multimesh.mesh.get_surface_count()):
			_add_material(node.multimesh.mesh.surface_get_material(surface), result)
	for child: Node in node.get_children(): _find_materials(child, result)

func _capture(id: String, mode: String, view: Dictionary) -> void:
	var materials: Dictionary = {}
	_find_materials(scene, materials)
	if materials.is_empty(): failures.append("No production foliage/scenery materials at " + id)
	var body: Dictionary = state.get_current_body_record().duplicate(true)
	var original_ssao: bool = air.environment.ssao_enabled
	# Isolate baked occlusion from screen-space history on both renderers.
	# This diagnostic override is recorded and restored, not a saved preference.
	air.environment.ssao_enabled = false
	var start: int = captures.size()
	for phase: String in ["before", "after", "restore"]:
		for material: ShaderMaterial in materials.values():
			material.set_shader_parameter("voxel_occlusion_strength", 1.0 if phase == "after" else 0.0)
		await super._capture(id + "-" + phase, mode, view)
		if state.get_current_body_record() != body: failures.append("Body changed during " + id + ": " + phase)
		if not paused: failures.append("Campaign unpaused during " + id)
	var baseline: Dictionary = captures[start]
	for index: int in range(start + 1, captures.size()):
		for field: String in ["clock", "camera", "camera_address", "fov", "size", "lighting", "palette", "material_slots", "draw_calls", "primitives", "debug_draw", "tonemap"]:
			if captures[index][field] != baseline[field]: failures.append("Pair drift: " + id + "/" + field)
	for material: ShaderMaterial in materials.values(): material.set_shader_parameter("voxel_occlusion_strength", 1.0)
	air.environment.ssao_enabled = original_ssao
	pairs.append({"id": id, "captures": [id + "-before", id + "-after", id + "-restore"],
		"materials": materials.size(), "body_unchanged": state.get_current_body_record() == body,
		"ssao_diagnostic": false, "saved_ssao_preference": air.graphics_values.ssao_enabled})

func _finish() -> void:
	if pairs.is_empty() and not bool(config.get("snapshot_only", false)): failures.append("No native AO comparison pairs")
	report["pairs"] = pairs
	report["scope"] = "Regular public spherical campaign; fixed body/save/camera/clock/palette/pose. Only voxel_occlusion_strength changes 0/1/0; SSAO disabled equally for this diagnostic. No FPS or target-PC acceptance."
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var file := FileAccess.open(str(config.output).path_join("voxel-occlusion.json"), FileAccess.WRITE)
	file.store_string(Atomic.stringify(report) + "\n")
	file.close()
	for failure: String in failures: push_error(failure)
	print("VOXEL_OCCLUSION_PASSED" if failures.is_empty() else "VOXEL_OCCLUSION_FAILED")
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)
