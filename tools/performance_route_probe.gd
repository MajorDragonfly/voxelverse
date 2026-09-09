extends SceneTree
## Instrumentation only: scripted player positions exercise streaming, not walking physics.
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
const WORLD: String = "res://main/main.tscn"
const TITLE: String = "res://ui/frontend/main_menu.tscn"

var _config: Dictionary
var _recipe: Dictionary
var _report: Dictionary
var _failures: Array[String] = []
var _segments: Array[Dictionary] = []
var _menus: Array[Dictionary] = []
var _worlds: Array[WeakRef] = []
var _saves: Node
var _flow: Node
var _frames: Array[float] = []
var _draws: Array[float] = []
var _process_samples: Array[float] = []
var _physics_samples: Array[float] = []
var _memory_peak: int = 0
var _started: int = 0
var _last_tick: int = 0
var _pending_peak: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Expected the performance configuration path.")
		await Shutdown.finish(self, 1)
		return
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	if not decoded is Dictionary:
		push_error("Invalid performance configuration.")
		await Shutdown.finish(self, 1)
		return
	_config = decoded
	_recipe = _config["recipe"]
	Engine.max_fps = int(_recipe["frame_cap"])
	root.size = Vector2i(int(_recipe["resolution"][0]), int(_recipe["resolution"][1]))
	root.content_scale_size = root.size
	var headless: bool = DisplayServer.get_name() == "headless"
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var adapter: String = RenderingServer.get_video_adapter_name()
	var software: bool = headless
	for token: String in ["llvmpipe", "lavapipe", "softpipe", "software", "swiftshader"]:
		software = software or token in adapter.to_lower()
	_saves = root.get_node("SaveGameService")
	_flow = root.get_node("SessionFlow")
	_report = {"recipe": _recipe, "godot": Engine.get_version_info()["string"],
		"renderer": "headless" if headless else RenderingServer.get_current_rendering_method(),
		"adapter": adapter, "software_renderer": software, "user_data_dir": OS.get_user_data_dir(),
		"scope": "Scripted streaming route and real SessionFlow save/load transitions; capped process-frame timings, not a physics walking test or target-PC FPS acceptance.",
		"monitor_note": "process_ms and physics_ms sample Godot's coarse runtime monitors; they are not independent per-frame CPU timings. Frame intervals include probe work and the configured cap.",
		"segments": _segments, "menu_snapshots": _menus, "failures": _failures}
	change_scene_to_file(TITLE)
	await scene_changed
	await _settle()
	_report["cold_menu"] = _snapshot()
	var slot: String = ""
	var origin := Vector3.ZERO
	for cycle in range(int(_recipe["cycles"])):
		_begin()
		if cycle == 0:
			_flow.new_game("Performance probe", int(_recipe["seed"]))
		else:
			_flow.load_game(slot)
		if not await _ready_world():
			break
		var player: Node3D = current_scene.get_node("Player")
		_worlds.append(weakref(current_scene))
		if cycle == 0:
			origin = player.global_position
			slot = str(_saves.save_path)
		elif Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(origin.x, origin.z)) > 0.1:
			_failures.append("Saved route origin was not restored.")
		_end("world_ready", cycle)
		var manager: Node = current_scene.get_node("WorldManager")
		var initial_chunk: Vector2i = manager.current_player_chunk
		var before: Dictionary = _snapshot()
		_begin()
		await _move_route(player, origin, false)
		if not await _ready_world():
			break
		_end("outward", cycle)
		var origin_unloaded: bool = not manager.loaded_chunks.has(initial_chunk)
		if not origin_unloaded:
			_failures.append("Route did not unload the origin chunk; enlarge the distance.")
		_begin()
		await _move_route(player, origin, true)
		if not await _ready_world():
			break
		_end("return", cycle)
		var returned: bool = manager.loaded_chunks.has(initial_chunk)
		if not returned:
			_failures.append("Return route did not reload the origin chunk.")
		_segments[-1]["visit"] = {"origin_unloaded": origin_unloaded, "origin_reloaded": returned,
			"distance_m": float(_recipe["distance_m"]) * 2.0, "before": before, "after": _snapshot()}
		_begin()
		_flow.return_to_title()
		var deadline: int = Time.get_ticks_usec() + int(float(_recipe["stage_timeout_seconds"]) * 1_000_000)
		while current_scene == null or current_scene.scene_file_path != TITLE:
			if Time.get_ticks_usec() > deadline:
				_failures.append("Return to title timed out or save failed.")
				break
			await _tick()
		await _settle()
		_end("menu_return", cycle)
		var menu: Dictionary = _snapshot()
		menu["cycle"] = cycle
		menu["retained_world_scenes"] = _retained_worlds()
		menu["active_world_managers"] = get_nodes_in_group(&"world_manager").size()
		_menus.append(menu)
		if menu["retained_world_scenes"] != 0 or menu["active_world_managers"] != 0:
			_failures.append("A world scene or manager survived the menu transition.")
		if not _failures.is_empty():
			break
	var observations: Dictionary = {}
	if _menus.size() >= 2:
		for key: String in ["static_bytes", "nodes", "resources", "orphans"]:
			observations[key + "_change_after_warm_cycle"] = int(_menus[-1][key]) - int(_menus[0][key])
		observations["note"] = "Warm-cycle differences include retained caches and the probe's growing report; growth alone is not proof of a leak."
	_report["observations"] = observations
	_report["passed"] = _failures.is_empty() and _menus.size() == int(_recipe["cycles"])
	var file := FileAccess.open(str(_config["output"]).path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write performance capture.")
		await Shutdown.finish(self, 1)
		return
	file.store_string(JSON.stringify(_report, "\t") + "\n")
	file.close()
	for failure: String in _failures:
		push_error(failure)
	await Shutdown.finish(self, 0 if _report["passed"] else 1)


func _tick() -> void:
	await process_frame
	var now: int = Time.get_ticks_usec()
	_frames.append((now - _last_tick) / 1000.0 if _last_tick > 0 else 0.0)
	_last_tick = now
	_process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_memory_peak = maxi(_memory_peak, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	_saves.autosave_enabled = false
	if DisplayServer.get_name() != "headless":
		_draws.append(float(RenderingServer.viewport_get_render_info(root.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)))
	if current_scene != null and current_scene.scene_file_path == WORLD:
		var manager: Node = current_scene.get_node("WorldManager")
		_pending_peak = maxi(_pending_peak, manager.get_pending_chunk_count())
		var player: Node = current_scene.get_node("Player")
		player.set_process(false)
		if manager.world_initialized:
			player.set_physics_process(false)
		for creature: Node in current_scene.get_node("FaunaStreamerV7").get_children():
			if not creature.has_meta(&"performance_safe"):
				creature.set("predator_attack_damage", 0.0)
				creature.set_meta(&"performance_safe", true)


func _ready_world() -> bool:
	var deadline: int = Time.get_ticks_usec() + int(float(_recipe["stage_timeout_seconds"]) * 1_000_000)
	while Time.get_ticks_usec() < deadline:
		await _tick()
		if current_scene == null or current_scene.scene_file_path != WORLD or _flow.loading:
			continue
		var manager: Node = current_scene.get_node("WorldManager")
		if not manager.world_initialized or manager.get_pending_chunk_count() != 0:
			continue
		var complete: bool = manager.get_node("LandscapeHorizon").generation_complete and manager.get_node("DistantForest").generation_complete
		for chunk: Node in manager.loaded_chunks.values():
			var eco: Node = chunk.get_node("ProceduralEcosystemV6")
			complete = complete and eco.generation_complete and not eco.is_processing()
		if complete:
			return true
	_failures.append("World streaming did not settle before the stage timeout.")
	return false


func _move_route(player: Node3D, origin: Vector3, returning: bool) -> void:
	var steps: int = ceili(float(_recipe["distance_m"]) / float(_recipe["step_m"]))
	for index in range(1, steps + 1):
		var progress: float = float(index) / float(steps)
		var offset: float = float(_recipe["distance_m"]) * (1.0 - progress if returning else progress)
		var point: Vector3 = origin + Vector3(offset, 0, 0)
		point.y = root.get_node("WorldGenerator").get_terrain_height(point.x, point.z) + 2.2
		player.global_position = point
		await _tick()
	if returning:
		player.global_position = origin


func _settle() -> void:
	for frame in range(int(_recipe["settle_frames"])):
		await _tick()


func _begin() -> void:
	_frames.clear()
	_draws.clear()
	_process_samples.clear()
	_physics_samples.clear()
	_memory_peak = 0
	_pending_peak = 0
	_started = Time.get_ticks_usec()
	_last_tick = _started


func _end(label: String, cycle: int) -> void:
	var segment: Dictionary = {"stage": label, "cycle": cycle,
		"elapsed_ms": (Time.get_ticks_usec() - _started) / 1000.0,
		"frames": _frames.size(), "frame_ms": _distribution(_frames),
		"process_ms": _distribution(_process_samples), "physics_ms": _distribution(_physics_samples),
		"draw_calls": _distribution(_draws), "static_peak_bytes": _memory_peak,
		"pending_chunks_peak": _pending_peak, "snapshot": _snapshot()}
	_segments.append(segment)
	print("PERFORMANCE_STAGE ", JSON.stringify(segment))


func _snapshot() -> Dictionary:
	return {"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"asset_cache": Assets.get_cache_counts()}


func _retained_worlds() -> int:
	var count: int = 0
	for reference: WeakRef in _worlds:
		count += int(reference.get_ref() != null)
	return count


func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return {"median": ordered[ordered.size() / 2],
		"p95": ordered[mini(ceili(ordered.size() * 0.95) - 1, ordered.size() - 1)],
		"p99": ordered[mini(ceili(ordered.size() * 0.99) - 1, ordered.size() - 1)], "max": ordered[-1]}
