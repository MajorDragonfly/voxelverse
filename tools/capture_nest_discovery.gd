extends SceneTree
## Native nest scan, reload and independent-ID evidence using production services.
const Nest = preload("res://world/resources/nests/wildlife_nest.gd")
const Text = preload("res://core/localization/ui_text.gd")
var failures: Array[String] = []
var frame: int = 0
var output: String
var title: Label

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var saves: Node = root.get_node("SaveGameService")
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	saves.session_managed = true
	saves.autosave_enabled = false
	if "--verify-restart" in args:
		saves.save_path = args[args.find("--verify-restart") + 1]
		_check(saves.load_now(), "Fresh process could not load the nest snapshot")
		var owner: Dictionary = state.get_current_body_record()
		_check(progression.has_nest_scan("render-one", owner.id, owner.seed), "Fresh process lost nest discovery")
		_check(not progression.has_nest_scan("render-two", owner.id, owner.seed), "Fresh process invented second nest")
		await _finish()
		return
	if args.is_empty() or DisplayServer.get_name() == "headless": quit(1); return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.get_node("LocaleManager").save_preference(args[1] if args.size() > 1 else "de")
	root.size = Vector2i(1280, 720)
	var slot: String = saves.create_slot("INT30-05 native nest", 15838, "legacy_plane_v9")
	var owner: Dictionary = state.get_current_body_record()
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
	player.get_node("CreatureRuntimeVisual").hide()
	player.get_node("BodyMesh").hide()
	var scanner: Node = player.get_node("CreatureScanner")
	scanner.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	title = Label.new()
	title.position = Vector2(16, 200)
	root.add_child(title)
	var first: Node3D = _nest("render-one", player.global_position + Vector3(0, 0, -4))
	for tick in range(4): await physics_frame; await process_frame
	player._gameplay_camera.look_at(first.global_position + Vector3.UP * 0.45)
	player.toggle_inspection_mode()
	for tick in range(90):
		await physics_frame
		scanner._physics_process(1.0 / 30.0)
		first.refresh(player, 4)
		if tick == 0: _check(first.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Unknown nest leaked species/count")
		await _record("Nest scan / %d%%" % roundi(scanner.ratio() * 100))
	_check(scanner.known and progression.has_nest_scan("render-one", owner.id, owner.seed), "Scan did not discover first nest")
	_check(saves.save_now(), "Nest snapshot failed")
	var child_output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--verify-restart", slot], child_output, true)
	_check(code == 0 and not str(child_output).contains("ERROR"), "Fresh-process nest persistence failed: " + str(child_output))
	_check(saves.load_now(), "Nest reload failed")
	for tick in range(20):
		scanner._physics_process(1.0 / 30.0)
		first.refresh(player, 2)
		_check(scanner.known and first.label.text.contains("2"), "Reload lost known nest/current count")
		await _record("Saved / fresh process verified / reloaded / current members: 2")
	first.queue_free()
	for tick in range(3): await physics_frame; await process_frame
	var second: Node3D = _nest("render-two", player.global_position + Vector3(0, 0, -4))
	for tick in range(3): await physics_frame; await process_frame
	for tick in range(20):
		scanner._physics_process(1.0 / 30.0)
		second.refresh(player, 3)
		_check(not scanner.known and second.label.text == Text.text("LIVING_NEST_UNKNOWN"), "Second nest inherited discovery")
		await _record("Second nest of same species / independent unknown ID")
	var file := FileAccess.open(output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "frames": frame, "restart_exit": code, "failures": failures}, "\t"))
	file.close()
	second.queue_free(); player.queue_free(); title.queue_free(); environment.queue_free(); light.queue_free()
	await _finish()

func _nest(id: String, position: Vector3) -> Node3D:
	var nest: Node3D = Nest.new()
	root.add_child(nest)
	nest.global_position = position
	nest.setup({"id": id, "name": "Kieselrücken", "seed": 17}, {}, "grassland")
	return nest

func _record(text: String) -> void:
	title.text = "INT30-05 / " + text
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.save_png(output.path_join("frame-%05d.png" % frame)) == OK, "Nest frame could not be saved")
	frame += 1

func _check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _finish() -> void:
	for failure: String in failures: push_error(failure)
	print("NATIVE_NEST_RESULT ", JSON.stringify({"frames": frame, "failures": failures}))
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
