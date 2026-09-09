extends SceneTree

# Headless CPU instrumentation. These timings are not GPU frame-rate claims.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var report_path: String = "user://streaming_cpu_measurements.json"
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		if arguments.size() != 2 or arguments[0] != "--report":
			push_error("Expected --report followed by an absolute output path.")
			await preload("res://core/runtime_shutdown.gd").finish(self, 1)
			return
		report_path = arguments[1]
	if report_path.begins_with("res://") or not report_path.is_absolute_path():
		push_error("Streaming report must be outside res://; use an absolute path or user://.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	var absolute_report: String = ProjectSettings.globalize_path(report_path).simplify_path()
	var project_root: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if absolute_report == project_root or absolute_report.begins_with(project_root + "/"):
		push_error("Streaming report cannot overwrite files inside the source project.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return

	var generator: Node = root.get_node("WorldGenerator")
	generator.call("set_seed_override", 424242)
	var packed := load("res://world/visuals/terrain/terrain_chunk.tscn") as PackedScene
	var measurements: Array[Dictionary] = []
	var spawn: Vector3 = generator.call("get_scenic_spawn")
	var scenic := Vector2i(roundi(spawn.x / 32.0), roundi(spawn.z / 32.0))
	var coordinates: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), scenic, scenic + Vector2i(1, 0), scenic + Vector2i(0, 1)]
	for coords: Vector2i in coordinates:
		var chunk: Node3D = packed.instantiate()
		chunk.set("chunk_coordinates", coords)
		var started: int = Time.get_ticks_usec()
		root.add_child(chunk)
		var create_ms: float = (Time.get_ticks_usec() - started) / 1000.0
		var ecology: Node = chunk.get_node("ProceduralEcosystemV6")
		for frame in range(3600):
			if bool(ecology.get("generation_complete")):
				break
			await process_frame
		if not bool(ecology.get("generation_complete")):
			push_error("Streaming benchmark did not complete.")
			await preload("res://core/runtime_shutdown.gd").finish(self, 1)
			return
		var sample: Dictionary = {"chunk": [coords.x, coords.y], "create_ms": create_ms,
			"upload_ms": chunk.get("upload_ms"), "ecology": ecology.call("get_generation_stats")}
		started = Time.get_ticks_usec()
		ecology.call("set_lod_tier", 2)
		for frame in range(6000):
			await process_frame
			if bool(ecology.call("get_generation_stats")["cluster_complete"]):
				break
		var far_stats: Dictionary = ecology.call("get_generation_stats")
		if not bool(far_stats["cluster_complete"]):
			push_error("Far cluster benchmark did not complete.")
			await preload("res://core/runtime_shutdown.gd").finish(self, 1)
			return
		sample["far_build_wall_ms"] = (Time.get_ticks_usec() - started) / 1000.0
		sample["far"] = far_stats
		measurements.append(sample)
		print(JSON.stringify(sample))
		chunk.queue_free()
		await process_frame
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write streaming report: " + report_path)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	file.store_string(JSON.stringify({"seed": 424242, "godot": Engine.get_version_info()["string"],
		"scope": "Headless CPU: main-thread creation, mesh/collision upload, staged vegetation. No GPU measurement.", "samples": measurements}, "\t") + "\n")
	file.close()
	await preload("res://core/runtime_shutdown.gd").finish(self)
