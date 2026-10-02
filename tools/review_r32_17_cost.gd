extends SceneTree
## CPU boundary only: pulse + update of the actual production props, no world FPS.
const Tool = preload("res://world/tribe/village_work_motion.gd")
class Resident extends Node3D:
	var member_id: String = ""
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	state.set_simulation_speed(1.0)
	var groups: Array = []
	for count in [1, 3, 12, 32]:
		var actors: Array[Node3D] = []
		var tools: Array[Node3D] = []
		for index in range(count):
			var actor := Resident.new()
			actor.member_id = "cost-resident-%d" % index
			root.add_child(actor)
			var visual := Node3D.new()
			visual.name = "CreatureRuntimeVisual"
			visual.rotation.y = index * 0.11
			actor.add_child(visual)
			var tool := Tool.new()
			actor.add_child(tool)
			tool.pulse("wood")
			tool.set_process(false)
			actors.append(actor)
			tools.append(tool)
		var values: Array[int] = []
		for frame in range(576):
			var started: int = Time.get_ticks_usec()
			for tool: Node3D in tools:
				tool.pulse("wood")
				tool._process(1.0 / 60.0)
			if frame >= 64: values.append(Time.get_ticks_usec() - started)
		values.sort()
		groups.append({"tools": count, "samples": values.size(), "p50_us": values[255], "p95_us": values[485],
			"p99_us": values[505], "max_us": values.back()})
		for actor in actors: actor.queue_free()
		await process_frame
	print("R32_TOOL_COST ", JSON.stringify({"groups": groups, "engine": Engine.get_version_info(),
		"scope": "512 warm groups, real pulse/update code and GameState.simulation_delta; no walking-route/AI/render/FPS or target-PC acceptance"}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
