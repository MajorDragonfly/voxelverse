extends Node
## Always-process observer: does not write campaign state or drive simulation.
const Stats = preload("res://tools/performance_stats.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Husbandry = preload("res://world/tribe/village_husbandry.gd")
const KEYS: Array[String] = ["frame_ms", "process_monitor_ms", "physics_monitor_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"]
var config: Dictionary
var report: Dictionary
var raw: FileAccess
var samples: Dictionary = {}
var cycle: int = 0
var stage: String = ""
var began: int = 0
var last_tick: int = 0
var next_snapshot: int = 0
var headless: bool
var skip_interval: bool = true

func configure(settings: Dictionary, process_key: String) -> bool:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = settings
	headless = DisplayServer.get_name() == "headless"
	if not headless:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
	var filename: String = "frames.csv" if process_key == "main" else process_key + "-frames.csv"
	raw = FileAccess.open(str(config.output).path_join(filename), FileAccess.WRITE)
	if raw == null: push_error("Cannot write developed frame samples."); return false
	raw.store_csv_line(["process", "cycle", "stage", "tick_us", "paused", "simulation_speed", "frame_cap", "frame_ms", "process_monitor_ms", "physics_monitor_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls"])
	report = {"protocol": 3, "recipe": config.recipe, "source": config.source, "process": process_key,
		"process_id": OS.get_process_id(), "godot": Engine.get_version_info().string,
		"cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(),
		"renderer": "headless" if headless else RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "user_data_dir": OS.get_user_data_dir(),
		"software_renderer": headless or RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU,
		"target_pc_acceptance": false, "full_walk_protocol": false, "segments": [], "snapshots": [],
		"children": [], "metrics": Stats.metric_notes(), "frame_file": filename,
		"scope": "Existing spherical_gameplay_probe: actual village, production animal, physical cargo, A-B-A, pause/write failure and fresh processes. Diagnostic setup includes a conserved reserve and 4x simulation; far-debt exercise uses 2 FPS. Not a normal-speed or target-PC benchmark."}
	return true

func begin(label: String) -> void:
	end()
	stage = label
	began = Time.get_ticks_usec()
	last_tick = began
	skip_interval = true
	samples = {}
	for key in KEYS: samples[key] = []
	_snapshot()

func end() -> void:
	if stage.is_empty(): return
	var segment: Dictionary = {"stage": stage, "cycle": cycle, "elapsed_ms": (Time.get_ticks_usec() - began) / 1000.0}
	for key in KEYS: segment[key] = Stats.distribution(samples[key])
	segment.gpu_timestamps_available = not samples.render_gpu_ms.is_empty() and samples.render_gpu_ms.max() > 0.0
	if not segment.gpu_timestamps_available: segment.render_gpu_ms = null
	report.segments.append(segment)
	_snapshot()
	stage = ""

func _process(_delta: float) -> void:
	if stage.is_empty() or raw == null: return
	var now: int = Time.get_ticks_usec()
	# Stage changes and synchronous child waits are boundaries, not frames.
	# Their complete elapsed wall time remains in segments/children.
	if skip_interval:
		last_tick = now
		skip_interval = false
		return
	var state: Node = get_node("/root/GameState")
	var rid: RID = get_tree().root.get_viewport_rid()
	var values: Array = [(now - last_tick) / 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		null if headless else RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu(),
		null if headless else RenderingServer.viewport_get_measured_render_time_gpu(rid),
		null if headless else RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)]
	last_tick = now
	var row: PackedStringArray = [report.process, str(cycle), stage, str(now), str(get_tree().paused), str(float(state.campaign.data.get("time_scale", 1.0))), str(Engine.max_fps)]
	for index in range(KEYS.size()):
		if values[index] != null: samples[KEYS[index]].append(float(values[index]))
		row.append("" if values[index] == null else str(values[index]))
	raw.store_csv_line(row)
	if now >= next_snapshot:
		_snapshot()
		next_snapshot = now + 1_000_000
		print("PERFORMANCE_PROGRESS ", report.process, " ", cycle, " ", stage)

func _snapshot() -> void:
	var state: Node = get_node("/root/GameState")
	var snapshot: Dictionary = {"process": report.process, "cycle": cycle, "stage": stage,
		"tick_us": Time.get_ticks_usec(), "paused": get_tree().paused, "simulation_speed": float(state.campaign.data.get("time_scale", 1.0)),
		"frame_cap": Engine.max_fps, "static_bytes": OS.get_static_memory_usage(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"physics_active_objects": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"render_memory_bytes": null if headless else RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		"bodies": state.campaign.data.get("bodies", {}).size(), "villages": []}
	snapshot.merge(Stats.process_memory())
	for body: Dictionary in state.campaign.data.get("bodies", {}).values():
		if body.get("tribe", {}).is_empty(): continue
		var tribe: Dictionary = body.tribe
		var simulation: Dictionary = body.get("village_simulation", {})
		var cargo: Dictionary = {}
		var orders: Dictionary = {}
		var production: Dictionary = {}
		for record: Dictionary in tribe.get("husbandry", {}).get("records", {}).values():
			var resource: String = str(Husbandry.production_recipe(record).resource_id)
			production[resource] = int(production.get(resource, 0)) + int(record.get("produced", 0))
		for member: Dictionary in tribe.get("members", []):
			var kind: String = str(member.get("cargo", ""))
			if not kind.is_empty(): cargo[kind] = int(cargo.get(kind, 0)) + 1
			kind = str(member.get("order", "wait"))
			orders[kind] = int(orders.get(kind, 0)) + 1
		snapshot.villages.append({"body_id": body.id, "owner": simulation.get("owner", ""),
			"residents": tribe.get("members", []).size(), "orders": orders, "cargo_units": cargo,
			"stock": tribe.get("stock", {}).duplicate(true), "pens": tribe.get("husbandry", {}).get("pens", []).size(),
			"production": production,
			"simulation_debt_seconds": maxf(0.0, float(state.campaign.data.get("elapsed_seconds", 0)) - float(simulation.get("cursor", 0)))})
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path == Surface.SCENE and is_instance_valid(scene.terrain):
		snapshot.terrain = scene.terrain.streaming_diagnostics()
		if is_instance_valid(scene.population):
			snapshot.active_animals = scene.population.animals.size()
			snapshot.active_plants = scene.population.plants.size()
			snapshot.population_work_max_ms = scene.population.max_frame_work_ms
		if is_instance_valid(scene.flora): snapshot.flora_instances = scene.flora.instance_count()
	report.snapshots.append(snapshot)

func child_process(key: String, code: int, elapsed_ms: float) -> void:
	report.children.append({"process": key, "exit_code": code, "elapsed_ms": elapsed_ms,
		"capture": key + "-capture.json", "note": "Synchronous child wait is excluded from parent frame percentiles."})

func finish(failures: Array[String]) -> bool:
	end()
	raw.flush()
	raw.close()
	report.failures = failures.duplicate()
	report.passed = failures.is_empty()
	var filename: String = "capture.json" if report.process == "main" else str(report.process) + "-capture.json"
	var file := FileAccess.open(str(config.output).path_join(filename), FileAccess.WRITE)
	if file == null: push_error("Cannot write developed performance report."); return false
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	return report.passed
