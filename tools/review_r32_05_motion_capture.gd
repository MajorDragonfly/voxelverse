extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless": quit(1); return
	var output: String = args[0]
	root.get_node("LocaleManager").save_preference(args[1] if args.size() > 1 else "de")
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true; saves.autosave_enabled = false
	saves.create_slot("R32-05 motion fixture", 15838, "legacy_plane_v9")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("183743")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d2e4df")
	env.environment.ambient_light_energy = 0.75
	root.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -20, 0)
	root.add_child(light)
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.global_position = Vector3(0, 100, 0); player.fall_acceleration = 0
	player.get_node("CreatureRuntimeVisual").hide(); player.get_node("BodyMesh").hide()
	player.get_node("CreatureScanner").set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in range(4): await physics_frame; await process_frame
	player.toggle_inspection_mode()
	var report: Dictionary = await preload("res://tools/review_r32_05_motion_cases.gd").new().run(self, player, output)
	report.engine = Engine.get_version_info(); report.language = args[1] if args.size() > 1 else "de"
	report.renderer = RenderingServer.get_current_rendering_method()
	report.environment = {"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "driver": RenderingServer.get_video_adapter_api_version()}
	report.limits = "Production scanner/body/HUD in a staged free-space fixture. Controlled 30-step animation is not spontaneous campaign AI. Query CPU and isolated frame samples are not target-PC FPS. UI150 is runtime-set; regular DisplaySettings150 host patch belongs to R32-15/01."
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	for failure: String in report.failures: push_error(failure)
	player.queue_free(); env.queue_free(); light.queue_free()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if report.failures.is_empty() else 1)
