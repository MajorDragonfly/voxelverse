extends "res://tools/review_r32_06_campaign_light.gd"
## Actual baseline source runs in a separate, non-rendering world. Only its
## presentation resources/light colour are swapped into the frozen campaign.
var pairs: Array = []

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
	var code: String = str(config.baseline_code)
	if code.sha256_text() != str(config.baseline_sha256):
		failures.append("Baseline source digest mismatch"); return
	var script := GDScript.new()
	script.source_code = code
	if script.reload() != OK:
		failures.append("Baseline script failed to compile"); return
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var baseline: Node3D = script.new()
	viewport.add_child(baseline)
	baseline.apply_graphics(air.graphics_values, air.quality)
	baseline.source = Callable(air, "campaign_sample")
	baseline._profile = air._profile.duplicate(true)
	baseline._seed = air._seed
	baseline.sky_material.set_shader_parameter("star_seed", float(posmod(air._seed, 10000)))
	baseline._base_sun_direction = air._base_sun_direction
	baseline._day_axis = air._day_axis
	baseline._configured = true
	baseline.update_view(0.0, true)
	baseline.set_process(false)
	if baseline._sun_direction != air._sun_direction or baseline.sun.light_energy != air.sun.light_energy:
		failures.append("Baseline sun direction/energy differs at " + id)
	var materials: Dictionary = {}
	_find_materials(scene, materials)
	if materials.is_empty(): failures.append("No production foliage/scenery materials at " + id)
	var current: Environment = air.environment
	var current_sky: ShaderMaterial = air.sky_material
	var sun_color: Color = air.sun.light_color
	var original_ssao: bool = current.ssao_enabled
	# Exclude screen-space temporal history equally; the saved setting stays on.
	current.ssao_enabled = false
	baseline.environment.ssao_enabled = false
	var body: Dictionary = state.get_current_body_record().duplicate(true)
	var begin: int = captures.size()
	var world: WorldEnvironment = air.get_node("WorldEnvironment")
	for phase: String in ["before", "lighting-only", "after", "restore"]:
		var old: bool = phase in ["before", "restore"]
		for material: ShaderMaterial in materials.values():
			material.set_shader_parameter("foliage_pigment_strength", 1.0 if phase == "after" else 0.0)
		air.environment = baseline.environment if old else current
		air.sky_material = baseline.sky_material if old else current_sky
		world.environment = air.environment
		air.sun.light_color = baseline.sun.light_color if old else sun_color
		await super._capture(id + "-" + phase, mode, view)
		var capture: Dictionary = captures.back()
		capture["foliage_pigment_strength"] = 1.0 if phase == "after" else 0.0
		capture["haze"] = {"color": str(air.environment.fog_light_color),
			"density": air.environment.fog_density, "curve": air.environment.fog_depth_curve,
			"begin": air.environment.fog_depth_begin, "end": air.environment.fog_depth_end,
			"height_density": air.environment.fog_height_density}
		if state.get_current_body_record() != body or not paused:
			failures.append("Campaign changed during " + id + "/" + phase)
	for index: int in range(begin + 1, captures.size()):
		for field: String in ["clock", "camera", "camera_address", "fov", "size", "palette", "material_slots", "draw_calls", "primitives", "debug_draw", "tonemap"]:
			if captures[index][field] != captures[begin][field]: failures.append("Pair drift " + id + "/" + field)
		for field: String in ["sun", "sun_direction", "sample", "exposure", "white", "fog", "ssao", "bloom", "preset", "graphics"]:
			if captures[index].lighting[field] != captures[begin].lighting[field]: failures.append("Input drift " + id + "/" + field)
	air.environment = current
	air.sky_material = current_sky
	world.environment = current
	air.sun.light_color = sun_color
	current.ssao_enabled = original_ssao
	for material: ShaderMaterial in materials.values(): material.set_shader_parameter("foliage_pigment_strength", 1.0)
	pairs.append({"id": id, "captures": [id + "-before", id + "-after", id + "-restore"],
		"lighting_capture": id + "-lighting-only", "materials": materials.size(),
		"body_unchanged": state.get_current_body_record() == body, "ssao_diagnostic": false,
		"saved_ssao_preference": air.graphics_values.ssao_enabled})
	viewport.free()

func _finish() -> void:
	if pairs.is_empty(): failures.append("No comparable campaign pairs")
	report["pairs"] = pairs
	report["baseline_sha256"] = config.baseline_sha256
	report["baseline_commit"] = config.baseline_commit
	report["scope"] = "Actual baseline atmosphere script/previous pigment (strength 0) vs current atmosphere alone (strength 0), then full production (strength 1) in the public paused spherical campaign, then baseline restore. Identical full body/save/camera/clock/geometry/palette/preferences/sun energy and direction; SSAO disabled equally. Software native visual evidence; no FPS or target-PC acceptance."
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var file := FileAccess.open(str(config.output).path_join("atmosphere-comparison.json"), FileAccess.WRITE)
	file.store_string(Atomic.stringify(report) + "\n")
	file.close()
	for failure: String in failures: push_error(failure)
	print("ATMOSPHERE_COMPARISON_PASSED" if failures.is_empty() else "ATMOSPHERE_COMPARISON_FAILED")
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)
