extends SceneTree
## Render the identical cases used by scan_circle_test with real scene meshes.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		push_error("Native renderer and output directory are required; headless is not visual evidence")
		quit(1)
		return
	var output: String = args[0]
	var language: String = args[1] if args.size() > 1 else "de"
	root.get_node("LocaleManager").save_preference(language)
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	saves.create_slot("INT30-05 render", 15838, "legacy_plane_v9")
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("183743")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d2e4df")
	environment.environment.ambient_light_energy = 0.75
	root.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -20, 0)
	root.add_child(light)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	# Observer fixture: retain the production camera/player/scanner but hide the
	# observer's body so tiny edge fragments can be judged against the backdrop.
	player.get_node("CreatureRuntimeVisual").hide()
	player.get_node("BodyMesh").hide()
	player.get_node("CreatureScanner").set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in range(4): await physics_frame; await process_frame
	player.toggle_inspection_mode()
	var cases: RefCounted = load("res://tools/scanner_visibility_cases.gd").new()
	var report: Dictionary = await cases.run(self, player, output)
	report.engine = Engine.get_version_info()
	report.language = language
	report.renderer = RenderingServer.get_current_rendering_method()
	report.environment = {"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_video_adapter_api_version()}
	report.frame_timing_limit = "Query CPU timings exclude PNG writing and are not whole-game FPS or target-PC acceptance. Video is sampled at 30 steps/s."
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	for failure: String in report.failures: push_error(failure)
	player.queue_free()
	environment.queue_free()
	light.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.failures.is_empty() else 1)
