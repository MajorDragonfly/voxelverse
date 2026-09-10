extends SceneTree
## ARCH-02: real spherical player input, no position snapping or speed changes.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
const Stats = preload("res://tools/performance_stats.gd")
const TITLE: String = "res://ui/frontend/main_menu.tscn"
var config: Dictionary
var recipe: Dictionary
var report: Dictionary
var failures: Array[String] = []
var segments: Array = []
var snapshots: Array = []
var saves: Node
var flow: Node
var raw: FileAccess
var samples: Dictionary = {}
var started: int
var last_tick: int
var next_snapshot: int = 0
var stage: String
var cycle: int = -1
var headless: bool
var breadcrumbs: Array[Dictionary] = []
var source_world: WeakRef

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: push_error("Expected performance config path."); await Shutdown.finish(self, 1); return
	config = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	recipe = config.recipe
	saves = root.get_node("SaveGameService")
	flow = root.get_node("SessionFlow")
	headless = DisplayServer.get_name() == "headless"
	Engine.max_fps = recipe.frame_cap
	root.size = Vector2i(recipe.resolution[0], recipe.resolution[1])
	root.content_scale_size = root.size
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	raw = FileAccess.open(str(config.output).path_join("frames.csv"), FileAccess.WRITE)
	if raw == null: push_error("Cannot write raw frames."); await Shutdown.finish(self, 1); return
	raw.store_csv_line(["cycle", "stage", "tick_us", "frame_ms", "process_monitor_ms", "physics_monitor_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"])
	report = {"protocol": 2, "recipe": recipe, "source": config.source,
		"godot": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(),
		"software_renderer": headless or RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU,
		"renderer": "headless" if headless else RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "user_data_dir": OS.get_user_data_dir(),
		"target_pc_acceptance": false, "segments": segments, "snapshots": snapshots, "failures": failures,
		"scope": "Spherical campaign through SessionFlow; actual player physics/input, terrain, flora, population, save/load and menu teardown. Short routes are instrumentation checks, not ten-minute acceptance.",
		"metrics": Stats.metric_notes(), "deferred_routes": ["developed village", "A-B-A body travel", "target-PC ten-minute walk"]}
	_begin("cold_menu")
	change_scene_to_file(TITLE)
	await scene_changed
	await _settle()
	_end()
	report.engine_start_to_menu_ready_ms = Time.get_ticks_usec() / 1000.0
	var slot: String = ""
	var saved_address: Dictionary = {}
	for index in range(recipe.cycles):
		cycle = index
		_begin("cold_world" if index == 0 else "reload_world")
		if index == 0 and config.has("replay_initial_save"):
			var replay_slot: String = config.replay_slot
			if not saves.is_slot_path(replay_slot) or preload("res://core/persistence/atomic_json.gd").write(replay_slot, config.replay_initial_save, false) != OK:
				failures.append("Cannot restore isolated route fixture."); break
			flow.load_game(replay_slot)
		elif index == 0: flow.new_game("ARCH-02 measurement", recipe.seed)
		else: flow.load_game(slot)
		if not await _ready_world(): break
		if index == 0: report.engine_start_to_world_ready_ms = Time.get_ticks_usec() / 1000.0
		slot = saves.save_path
		var player: CharacterBody3D = current_scene.player
		source_world = weakref(current_scene)
		if index > 0 and _distance(player.location(), saved_address) > 0.3:
			failures.append("Reload changed the saved spherical address.")
		_end()
		# Freeze the exact initial snapshot in immutable slot history before walking.
		if not saves.save_now(): failures.append(saves.last_error); break
		if index == 0:
			report.initial_save = saves._read_save(slot)
			report.initial_address = player.location()
			report.surface = current_scene.terrain.surface.body.duplicate(true)
		_begin("settle")
		await _settle()
		_end()
		_begin("walk_outward")
		await _walk_outward(player)
		_end()
		if not failures.is_empty(): break
		_begin("walk_return")
		await _walk_return(player)
		_end()
		if not failures.is_empty(): break
		saved_address = player.location()
		_begin("save_and_menu")
		flow.toggle_pause()
		# Capture counters before the scene and its diagnostic samples disappear.
		report["world_%d" % index] = _world_snapshot()
		report["world_%d" % index]["terrain_upload_samples_ms"] = current_scene.terrain.upload_samples.duplicate()
		report["world_%d" % index]["terrain_job_samples"] = current_scene.terrain.job_samples.duplicate(true)
		report["world_%d" % index]["sample_limits"] = {"upload_samples": 2048, "job_samples": 256,
			"note": "Existing diagnostic arrays retain the first samples; lifetime maxima still cover later work. Not an unbiased full-route percentile."}
		var save_start: int = Time.get_ticks_usec()
		if not saves.save_now(): failures.append(saves.last_error); break
		report["save_%d_ms" % index] = (Time.get_ticks_usec() - save_start) / 1000.0
		saved_address = saves._read_save(slot).player.surface_address
		flow.return_to_title()
		var deadline: int = Time.get_ticks_msec() + int(recipe.stage_timeout_seconds * 1000)
		while current_scene == null or current_scene.scene_file_path != TITLE:
			if Time.get_ticks_msec() > deadline: failures.append("Menu/save transition timed out."); break
			await _tick()
		await _settle()
		_end()
		if source_world.get_ref() != null or not get_nodes_in_group(&"campaign_surface_population").is_empty():
			failures.append("Spherical world survived menu teardown.")
		if not failures.is_empty(): break
	Input.action_release("move_forward")
	raw.close()
	if _is_world(): report.final_world = _world_snapshot()
	report.passed = failures.is_empty() and cycle == recipe.cycles - 1
	report.full_walk_protocol = recipe.walk_seconds >= 600 and report.passed
	report.fixture_slot = slot
	var file := FileAccess.open(str(config.output).path_join("capture.json"), FileAccess.WRITE)
	if file == null: push_error("Cannot write performance capture."); await Shutdown.finish(self, 1); return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	for failure in failures: push_error(failure)
	await Shutdown.finish(self, 0 if report.passed else 1)

func _ready_world() -> bool:
	var deadline: int = Time.get_ticks_msec() + int(recipe.stage_timeout_seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		await _tick()
		if _is_world() and not flow.loading and current_scene.world_initialized:
			return true
	failures.append("Spherical collision/start timed out: " + saves.last_error)
	return false

func _is_world() -> bool:
	return current_scene != null and current_scene.scene_file_path == Surface.SCENE and is_instance_valid(current_scene.player)

func _walk_outward(player: CharacterBody3D) -> void:
	breadcrumbs = [player.location()]
	var initial_forward: Vector3 = player.forward
	var begin: int = Time.get_ticks_msec()
	var duration: float = recipe.walk_seconds
	var last_progress: int = begin
	Input.action_press("move_forward")
	while (Time.get_ticks_msec() - begin) / 1000.0 < duration:
		var elapsed: float = (Time.get_ticks_msec() - begin) / 1000.0
		var leg: int = mini(2, int(elapsed / (duration / 3.0)))
		var up: Vector3 = current_scene.adapter.up_at(player.location())
		player.global_basis = Cube.frame(up, initial_forward.rotated(up, [0.0, PI / 4.0, -PI / 4.0][leg]))
		await _tick()
		if player.is_dead: failures.append("Player died on the route; no survival overrides applied."); break
		if _distance(player.location(), breadcrumbs[-1]) >= 0.75:
			breadcrumbs.append(player.location())
			last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > int(recipe.stage_timeout_seconds * 1000):
			failures.append("Walk blocked; actual progress and terrain wait are retained in raw evidence."); break
	Input.action_release("move_forward")
	segments.append({"stage": "route_outcome", "cycle": cycle, "breadcrumbs": breadcrumbs.duplicate(true),
		"actual_outward_m": _path_length(), "requested_outward_seconds": duration})
	if breadcrumbs.size() < 2: failures.append("Route produced no measurable physical movement.")

func _walk_return(player: CharacterBody3D) -> void:
	var deadline: int = Time.get_ticks_msec() + int((recipe.walk_seconds * 2 + recipe.stage_timeout_seconds) * 1000)
	Input.action_press("move_forward")
	for index in range(breadcrumbs.size() - 1, -1, -1):
		var destination: Dictionary = breadcrumbs[index]
		while _distance(player.location(), destination) > 0.65:
			if player.is_dead or Time.get_ticks_msec() > deadline:
				failures.append("Physical return blocked or player died; no teleport used.")
				Input.action_release("move_forward")
				return
			var up: Vector3 = current_scene.adapter.up_at(player.location())
			var delta: Vector3 = current_scene.adapter.to_local(destination) - player.global_position
			player.global_basis = Cube.frame(up, delta.slide(up).normalized())
			await _tick()
	Input.action_release("move_forward")
	segments.append({"stage": "return_outcome", "cycle": cycle, "distance_from_start_m": _distance(player.location(), breadcrumbs[0])})

func _distance(a: Dictionary, b: Dictionary) -> float:
	# Directional displacement ignores standing-height oscillation on voxel steps.
	var left: Dictionary = a.duplicate(); left.height = 0.0
	var right: Dictionary = b.duplicate(); right.height = 0.0
	var radius: float = current_scene.terrain.surface.body.radius
	return Cube.local_position(Cube.cartesian(left, radius), Cube.cartesian(right, radius)).length()

func _path_length() -> float:
	var result: float = 0.0
	for i in range(1, breadcrumbs.size()): result += _distance(breadcrumbs[i - 1], breadcrumbs[i])
	return result

func _tick() -> void:
	await process_frame
	var now: int = Time.get_ticks_usec()
	var frame: float = (now - last_tick) / 1000.0
	last_tick = now
	saves.autosave_enabled = false
	var rid: RID = root.get_viewport_rid()
	var values: Array = [frame, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		null if headless else RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		null if headless else RenderingServer.viewport_get_measured_render_time_gpu(rid),
		null if headless else RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)]
	var keys: Array = ["frame_ms", "process_monitor_ms", "physics_monitor_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"]
	var row: PackedStringArray = [str(cycle), stage, str(now)]
	for i in range(keys.size()):
		if values[i] != null: samples[keys[i]].append(float(values[i]))
		row.append("" if values[i] == null else str(values[i]))
	raw.store_csv_line(row)
	if now >= next_snapshot:
		var snapshot: Dictionary = _world_snapshot()
		snapshot.merge({"cycle": cycle, "stage": stage, "tick_us": now, "static_bytes": OS.get_static_memory_usage(),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"physics_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
			"physics_collision_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
			"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)})
		snapshots.append(snapshot)
		next_snapshot = now + 1_000_000
		print("PERFORMANCE_PROGRESS ", cycle, " ", stage, " ", now)

func _world_snapshot() -> Dictionary:
	if not _is_world(): return {}
	var terrain: Node = current_scene.terrain
	var flora: Node = current_scene.flora
	var population: Node = current_scene.population
	var store: RefCounted = population.storage.store
	var workers: int = 0
	if terrain._job != null: workers = terrain._job._tasks.size() + int(terrain._job._selection_task >= 0)
	return {"address": current_scene.player.location(), "terrain_wait": current_scene.player.waiting_for_terrain,
		"terrain_tiles": terrain.leaves.size(), "terrain_collisions": terrain.active.size(), "terrain_pending_uploads": terrain._pending.size(),
		"terrain_workers": workers, "terrain_cached_tiles": terrain._cache.size(), "terrain_resident_peak": terrain.peak_resident_meshes,
		"rebases": terrain.rebases, "flora_instances": flora.instance_count(), "flora_worker": int(flora._task >= 0),
		"active_animals": population.animals.size(), "active_plants": population.plants.size(),
		"region_cache": store.cache.size(), "region_pages": store.pages.size(), "region_dirty": store.dirty.size(),
		"region_reads": store.reads, "region_writes": store.writes, "region_io_max_ms": store.max_io_usec / 1000.0,
		"terrain_initial_publish_ms": terrain.max_initial_publish_usec / 1000.0, "terrain_publish_max_ms": terrain.max_publish_usec / 1000.0,
		"terrain_upload_max_ms": terrain.max_build_usec / 1000.0, "terrain_worker_max_ms": terrain.max_worker_usec / 1000.0,
		"flora_work_max_ms": flora.max_frame_work_ms, "population_work_max_ms": population.max_frame_work_ms,
		"render_memory_bytes": null if headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)}

func _settle() -> void:
	for i in range(recipe.settle_frames): await _tick()

func _begin(label: String) -> void:
	stage = label
	samples = {}
	for key in ["frame_ms", "process_monitor_ms", "physics_monitor_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"]: samples[key] = []
	started = Time.get_ticks_usec()
	last_tick = started

func _end() -> void:
	var value: Dictionary = {"stage": stage, "cycle": cycle, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
	for key in samples: value[key] = Stats.distribution(samples[key])
	value.gpu_timestamps_available = not samples.render_gpu_ms.is_empty() and samples.render_gpu_ms.max() > 0.0
	if not value.gpu_timestamps_available: value.render_gpu_ms = null
	segments.append(value)
	print("PERFORMANCE_STAGE ", JSON.stringify(value))
