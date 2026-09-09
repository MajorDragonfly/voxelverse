extends SceneTree

var failures: Array[String] = []
var player: Node3D
var animal: Node3D
var ui: CanvasLayer
var stage: Node3D
var output: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or not "--capture" in args:
		push_error("This acceptance run requires a real graphical viewport and --capture directory.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	output = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1600, 900)
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.get_node("SaveGameService").save_path = "user://behavior_gui.json"
	root.get_node("GameState").start_world_with_seed(12345)
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("19313b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8d1db")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.4
	stage.add_child(sun)
	var floor_body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(50, 0.2, 50)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("516b55")
	mesh.material_override = material
	floor_body.add_child(mesh)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(50, 0.2, 50)
	floor_body.add_child(collision)
	floor_body.position.y = -0.1
	stage.add_child(floor_body)
	player = load("res://creatures/player/player.tscn").instantiate()
	stage.add_child(player)
	player.hunger_loss_per_second = 0.0
	player.thirst_loss_per_second = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.fall_acceleration = 0.0
	await _frames()
	# RuntimeVisual installs body-derived metabolism on a deferred frame.
	player.hunger_loss_per_second = 0.0
	player.thirst_loss_per_second = 0.0
	ui = player.get_node("ProgressionHUD/PlayerProgression")
	await _spawn(11)
	_expect(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Real mouse capture failed.")
	_expect(player.get_node("BehaviorController").find_target() == animal, "Real camera could not select the review creature.")
	await _key(KEY_F, true)
	await create_timer(3.0).timeout
	var trust: float = animal.get_node("SocialBehavior").entry()["trust"]
	_expect(trust > 10.0 and trust < 100.0, "Holding physical F did not progress actual trust.")
	await _capture("befriending.png")
	# Opening K during held F must pause the operation and prevent it resuming.
	await _tap(KEY_K)
	var paused_trust: float = animal.get_node("SocialBehavior").entry()["trust"]
	await create_timer(0.3, true).timeout
	_expect(is_equal_approx(animal.get_node("SocialBehavior").entry()["trust"], paused_trust), "Paused skilltree advanced friendship.")
	_expect(not player.get_node("BehaviorController")._befriending, "Menu pause retained a held social action.")
	await _key(KEY_F, false)
	await _tap(KEY_ESCAPE)
	await _key(KEY_F, true)
	var started: int = Time.get_ticks_msec()
	while animal.get_node("SocialBehavior").entry()["relation"] != "ally" and Time.get_ticks_msec() - started < 12000:
		await process_frame
	await _key(KEY_F, false)
	_expect(root.get_node("ProgressionService").get_behavior_wallet(0)["earned"]["social"] == 3, "Real F input did not earn its completion reward.")
	await _capture("befriended.png")
	await _tap(KEY_K)
	await _click(ui._cards["creature.social.approach"]["button"])
	await _click(ui._purchase)
	_expect(root.get_node("ProgressionService").get_behavior_wallet(0)["available"]["social"] == 1, "Real click did not purchase Offenheit with earned points.")
	await _capture("earned_skill.png")
	# Navigate the separate phase views through the actual OptionButton keyboard popup.
	ui._scroll.ensure_control_visible(ui._phase_choice)
	ui._phase_choice.grab_focus()
	await _tap(KEY_SPACE)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	_expect(ui._phase_choice.selected == 1 and ui._phase_preview.text.contains("Aktueller Spielablauf") and ui._phase_preview.text.contains("Dorfeinstieg"), "Phase view did not show the implemented village separately from creature purchases.")
	ui._scroll.ensure_control_visible(ui._phase_preview)
	await _frames()
	await _capture("tribe_preview.png")
	await _tap(KEY_ESCAPE)
	await _spawn(10)
	var hunger_before: float = player.current_hunger
	await _tap(KEY_H)
	_expect(is_equal_approx(animal.get_health_ratio(), 0.85) and is_equal_approx(player.current_hunger, hunger_before - 12.0), "Real H input did not trade food for care.")
	await create_timer(0.9).timeout
	await _tap(KEY_H)
	_expect(root.get_node("ProgressionService").get_behavior_wallet(0)["earned"]["social"] == 5, "Real care input did not complete the injury reward.")
	await _capture("helped.png")
	stage.queue_free()
	await _frames()
	if failures.is_empty():
		print("BEHAVIOR_GUI_OK: physical F/H/K, pause, earned purchase and phase preview passed")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		for failure in failures:
			push_error(failure)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)


func _spawn(seed: int) -> void:
	if is_instance_valid(animal):
		animal.queue_free()
		await _frames()
	animal = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	animal.configure(2771337 + seed, seed, Vector2i.ZERO, "forager")
	stage.add_child(animal)
	animal.position = player.position + Vector3(0, 0, -2.5)
	animal.set_physics_process(false)
	await physics_frame
	await _frames()


func _key(code: int, pressed_value: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed_value
	Input.parse_input_event(event)
	await _frames()


func _tap(code: int) -> void:
	await _key(code, true)
	await _key(code, false)


func _click(control: Control) -> void:
	ui._scroll.ensure_control_visible(control)
	await _frames()
	for pressed_value in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.pressed = pressed_value
		root.push_input(event, true)
		await _frames()


func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(output.path_join(filename)) == OK, "Could not save " + filename)


func _frames() -> void:
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
