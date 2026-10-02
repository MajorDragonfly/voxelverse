extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280, 720)
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
	var errors: Array[String] = await preload("res://tools/review_r32_05_visible_occlusion.gd").new().run(self, args[0])
	var report := {"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "failures": errors}
	var file := FileAccess.open(args[0].path_join("result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	env.queue_free(); light.queue_free()
	for error: String in errors: push_error(error)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if errors.is_empty() else 1)
