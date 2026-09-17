extends SceneTree
## Uses SessionFlow once per measured load; no duplicate terrain or SaveService.

const Shutdown = preload("res://core/runtime_shutdown.gd")
var config: Dictionary
var flow: Node
var saves: Node
var report: Dictionary
var failures: Array[String] = []
var cycle: int = -1
var world_starts: int = 0
var save_attempts: int = 0
var phase_started_msec: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected startup profiling config.")
		await Shutdown.finish(self, 1)
		return
	config = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	flow = root.get_node("SessionFlow")
	saves = root.get_node("SaveGameService")
	Engine.max_fps = int(config.recipe.frame_cap)
	root.size = Vector2i(config.recipe.resolution[0], config.recipe.resolution[1])
	root.content_scale_size = root.size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	change_scene_to_file(flow.TITLE_SCENE)
	await scene_changed
	if config.operation == "prepare":
		# Preparation is a separate process and never builds a world. The current
		# slot format already freezes the starter design before the first load.
		var slot: String = saves.create_slot("Startup measurement", int(config.recipe.seed))
		if slot.is_empty():
			push_error(saves.last_error)
			await Shutdown.finish(self, 1)
			return
		_write("startup-fixture.json", {"slot": slot, "sha256": _hash(slot), "seed": config.recipe.seed})
		await Shutdown.finish(self)
		return
	flow.startup_phase_changed.connect(_trace_changed)
	flow.world_started.connect(_world_started)
	saves.save_started.connect(_save_started)
	report = {"protocol": 1, "recipe": config.recipe, "source": config.source,
		"godot": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"logical_cpus": OS.get_processor_count(), "adapter": RenderingServer.get_video_adapter_name(),
		"renderer": "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method(),
		"user_data_dir": OS.get_user_data_dir(), "target_pc_acceptance": false,
		"fixture_slot": config.fixture.slot, "initial_save_sha256": config.fixture.sha256,
		"loads": [], "failures": failures}
	for index in range(int(config.recipe.cycles)):
		cycle = index
		if _hash(config.fixture.slot) != config.fixture.sha256:
			failures.append("Startup fixture changed before load.")
			break
		flow.load_game(config.fixture.slot)
		while flow.loading and Time.get_ticks_msec() - phase_started_msec < int(config.recipe.stage_timeout_seconds * 1000):
			await process_frame
		var trace: Dictionary = flow.startup_diagnostics()
		report.loads.append({"cycle": cycle, "cache_state": "cold_process" if cycle == 0 else "warm_process", "trace": trace})
		if flow.loading or trace.status != "ready":
			failures.append("Startup failed or timed out in phase %s: %s" % [trace.last_phase, trace.error])
			break
		if world_starts != cycle + 1 or current_scene == null or not current_scene.world_initialized:
			failures.append("Expected exactly one initialized campaign per load.")
			break
		var old_world: WeakRef = weakref(current_scene)
		# Measurement ends before simulation resumes. Discard only this isolated
		# in-memory visit: the normal Save & Menu command would change the fixture.
		change_scene_to_file(flow.TITLE_SCENE)
		await scene_changed
		await process_frame
		if old_world.get_ref() != null or not get_nodes_in_group(&"campaign_surface_population").is_empty():
			failures.append("The previous world survived startup teardown.")
			break
		if save_attempts != 0 or _hash(config.fixture.slot) != config.fixture.sha256:
			failures.append("Startup measurement attempted to save or changed its input slot.")
			break
	report.world_starts = world_starts
	report.save_attempts = save_attempts
	report.final_save_sha256 = _hash(config.fixture.slot)
	report.passed = failures.is_empty() and world_starts == int(config.recipe.cycles)
	_write("capture.json", report)
	for failure in failures: push_error(failure)
	await Shutdown.finish(self, 0 if report.passed else 1)


func _world_started() -> void:
	world_starts += 1
	saves.autosave_enabled = false
	paused = true


func _save_started(_path: String) -> void:
	save_attempts += 1


func _trace_changed(snapshot: Dictionary) -> void:
	phase_started_msec = Time.get_ticks_msec()
	# Flush only at phase boundaries. A parent timeout can recover the phase
	# even if ResourceLoader/scene _ready blocks before another process frame.
	var value: Dictionary = {"cycle": cycle, "trace": snapshot}
	print("STARTUP_PHASE ", JSON.stringify(value))
	_write("startup-progress.json", value)


func _hash(path: String) -> String:
	return FileAccess.get_sha256(path)


func _write(name: String, value: Dictionary) -> void:
	var file := FileAccess.open(str(config.output).path_join(name), FileAccess.WRITE)
	if file == null:
		failures.append("Cannot write startup report: " + name)
		return
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()
