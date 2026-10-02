extends SceneTree
## Run against the owner patch in an isolated checkout; baseline must fail.
const Ecosystem = preload("res://world/surface/surface_ecosystem.gd")
const Foliage = preload("res://assets/catalog/planet_foliage.gdshader")
const Transition = preload("res://world/surface/visuals/surface_scenery.gdshader")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var ecosystem := Ecosystem.new()
	ecosystem.scenery_transitions_enabled = true
	var holder := Node3D.new()
	var visual := MultiMeshInstance3D.new()
	holder.add_child(visual)
	var settled := ShaderMaterial.new()
	settled.shader = Foliage
	var transition := ShaderMaterial.new()
	transition.shader = Transition
	visual.set_meta("scenery_settled_material", settled)
	visual.set_meta("scenery_transition_material", transition)
	var data := {"node": holder, "coverage": 0.5}
	ecosystem.patches["test-cell"] = data
	for clock: float in [1.2, 19.5]:
		settled.set_shader_parameter("motion_time", clock)
		settled.set_shader_parameter("wind_strength", 0.05)
		settled.set_shader_parameter("wind_speed", 1.1)
		settled.set_shader_parameter("wind_direction", Vector2(0.8, 0.6))
		# Coverage stays fixed: a pause/resume or weather change cannot leave a
		# duplicate material on the creation-time clock/direction/strength.
		ecosystem._set_patch_coverage(data, 0.5)
		# The weather owner (priority 110) can change the settled material after
		# coverage updates. The final pre-draw copy must see that same frame.
		settled.set_shader_parameter("motion_time", clock + 0.1)
		if ecosystem.has_method("_sync_transition_motion"):
			ecosystem._sync_transition_motion()
		else:
			failures.append("No after-weather pre-draw synchronization")
		for key: String in ["motion_time", "wind_strength", "wind_speed", "wind_direction"]:
			if transition.get_shader_parameter(key) != settled.get_shader_parameter(key): failures.append("Stale transition: " + key)
		if visual.material_override != transition: failures.append("Partial coverage lost transition material")
	ecosystem._set_patch_coverage(data, 1.0)
	if visual.material_override != settled: failures.append("Full coverage lost opaque fast path")
	# No binding/adapter lifecycle is used by this small material-consumer test.
	ecosystem.patches.clear()
	ecosystem.free()
	holder.free()
	print("R32_09_TRANSITION ", JSON.stringify({"passed": failures.is_empty(), "checks": 13, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
