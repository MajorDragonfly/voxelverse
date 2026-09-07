extends SceneTree

# Headless CPU instrumentation. These timings are not GPU frame-rate claims.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
			quit(1)
			return
		var sample: Dictionary = {"chunk": [coords.x, coords.y], "create_ms": create_ms,
			"upload_ms": chunk.get("upload_ms"), "ecology": ecology.call("get_generation_stats")}
		measurements.append(sample)
		print(JSON.stringify(sample))
		chunk.queue_free()
		await process_frame
	var file := FileAccess.open("res://art/review/benchmark_v2/streaming_cpu_measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 424242, "godot": Engine.get_version_info()["string"],
		"scope": "Headless CPU: main-thread creation, mesh/collision upload, staged vegetation. No GPU measurement.", "samples": measurements}, "\t") + "\n")
	file.close()
	quit()
