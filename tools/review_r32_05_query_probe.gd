extends SceneTree
## Same seeded production bodies/camera/save for all three scanner sources.
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var player: Node3D
var scanner: Node
var camera: Camera3D
var output: String
var profiling := false
var reference: String
var save_sha256: String

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2: quit(1); return
	output = args[0]; reference = args[1]
	profiling = "--profile" in args
	DirAccess.make_dir_recursive_absolute(output)
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true; saves.autosave_enabled = false
	if not FileAccess.file_exists(reference):
		var source: String = saves.create_slot("R32-05 query reference", 15838, "legacy_plane_v9")
		_check(not source.is_empty(), "Reference save creation failed")
		_check(DirAccess.copy_absolute(source, reference) == OK, "Reference save copy failed")
	var raw := FileAccess.get_file_as_bytes(reference)
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(raw)
	save_sha256 = digest.finish().hex_encode()
	DirAccess.make_dir_recursive_absolute("user://saves")
	_check(DirAccess.copy_absolute(reference, "user://saves/r32-query.json") == OK, "Reference save replay copy failed")
	saves.save_path = "user://saves/r32-query.json"
	_check(saves.load_now(), "Reference save replay failed")
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("183743")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d2e4df"); env.environment.ambient_light_energy = 0.75
	root.add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-45, -20, 0); root.add_child(light)
	root.size = Vector2i(1280, 720); root.content_scale_factor = 1.0
	player = load("res://creatures/player/player.tscn").instantiate(); root.add_child(player)
	player.global_position = Vector3(0, 100, 0); player.fall_acceleration = 0
	player.get_node("CreatureRuntimeVisual").hide(); player.get_node("BodyMesh").hide()
	scanner = player.get_node("CreatureScanner"); scanner.set_physics_process(false)
	for tick in range(4): await physics_frame; await process_frame
	player.set_physics_process(false); player.set_process(false)
	var display: Node = root.get_node("DisplaySettings")
	display.display_mode = display.MODE_WINDOWED; display.resolution = Vector2i(1280, 720); display.ui_scale = 1.0; display._apply_settings(false)
	for tick in range(3): await physics_frame; await process_frame
	camera = player._gameplay_camera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var counts: Array[int] = []
	counts.assign([12] if profiling else [1, 12])
	if "--count" in args: counts.assign([int(args[args.find("--count") + 1])])
	for count: int in counts: await _case(count)
	_check(scanner.get_scan_target() == null, "Unloaded actors retained a query target")
	if scanner.silhouette.has_method("cache_sizes"):
		_check(scanner.silhouette.cache_sizes().nodes == 0, "Unloaded actors retained weak cache entries")
	var report := {"save_sha256": save_sha256, "seed": 15838, "camera": var_to_str(camera.global_transform),
		"fov": camera.fov, "resolution": [root.size.x, root.size.y], "ui_scale": root.content_scale_factor,
		"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_video_adapter_api_version(),
		"samples": samples, "failures": failures, "profiling": profiling,
		"limits": "Isolated production-body fixture, exact saved input. Software query timings; no target-PC or FPS acceptance."}
	var file := FileAccess.open(output.path_join("query.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	for failure: String in failures: push_error(failure)
	player.queue_free(); env.queue_free(); light.queue_free(); await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _case(count: int) -> void:
	var animals: Array[Node3D] = []
	for index in range(count):
		var animal: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
		animal.configure(2771337, 950 + index, Vector2i.ZERO, "forager"); root.add_child(animal)
		animal.set_physics_process(false); animal._preview.set_motion("walk"); animal._preview.set_process(false)
		animal.global_position = player.global_position + Vector3((index % 3 - 1) * 0.4, 0, -5.0 - index * 0.15)
		animals.append(animal)
	camera.look_at(player.global_position + Vector3(0, 0.6, -5))
	for tick in range(3): await physics_frame; await process_frame
	var cold: Array[float] = []
	var warm: Array[float] = []
	var rays: Array[int] = []
	var targets: Array[int] = []
	var cold_count := 1 if profiling else 12
	for tick in range(cold_count):
		scanner.reset()
		scanner.silhouette = load("res://tools/review_r32_05_profile_silhouette.gd" if profiling else "res://core/discovery/scan_silhouette.gd").new()
		for animal: Node3D in animals: animal._preview._process(1.0 / 60.0)
		scanner.target = scanner.get_scan_target()
		_check(scanner.target != null, "Cold query lost all visible targets")
		cold.append(scanner.last_query_usec / 1000.0)
		await process_frame
	for tick in range(15 if profiling else 100):
		for animal: Node3D in animals: animal._preview._process(1.0 / 60.0)
		scanner.target = scanner.get_scan_target()
		_check(scanner.target != null, "Warm animated query lost all visible targets")
		warm.append(scanner.last_query_usec / 1000.0); rays.append(scanner.last_scan_rays)
		targets.append(animals.find(scanner.target))
		await process_frame
	var entry := {"count": count, "cold_ms": _stats(cold), "warm_ms": _stats(warm),
		"first_query_ms": cold.front(), "raw_cold_ms": cold, "raw_warm_ms": warm, "raw_rays": rays, "targets": targets}
	var ranks: Array[Dictionary] = []
	var circle: Dictionary = player._scan_circle()
	for animal: Node3D in animals:
		var rank: Dictionary = player._scan_contact(animal, circle)
		ranks.append({"index": animals.find(animal), "rank": rank, "position": var_to_str(animal.global_position)})
	entry.ranks = ranks
	if profiling: entry.inclusive_profile = scanner.silhouette.counters
	if scanner.silhouette.has_method("cache_sizes"): entry.cache = scanner.silhouette.cache_sizes()
	samples.append(entry)
	print("R32_QUERY ", JSON.stringify(entry))
	for animal: Node3D in animals: animal.queue_free()
	scanner.reset()
	for tick in range(3): await physics_frame; await process_frame

func _stats(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate(); sorted.sort()
	return {"samples": sorted.size(), "p50": sorted[sorted.size() / 2],
		"p95": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.95) - 1)],
		"p99": sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.99) - 1)], "max": sorted.back()}

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
