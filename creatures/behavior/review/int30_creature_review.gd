extends "res://tests/wildlife_ai_test.gd"
## Native-rendered evidence: production pose path and public social/damage APIs.
## -- OUTPUT poses-on|poses-off|encounters. Use --fixed-fps 30 for poses, 15 for encounters.
const Shapes = preload("res://creatures/behavior/review/int30_creature_shapes.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
var output: String
var title: Label
var detail: Label
var observations: Array[Dictionary] = []
var pose_cpu_us: Array[int] = []
var frame_ms: Array[float] = []
var draws: Array[int] = []
var capture_serial: int = 0
var max_contact_gap: float = 0.0
var socket_error: float = 0.0

class ReviewPlayer extends Observer:
	var bite_reach: float = 2.0
	func get_behavior_multiplier(_key: String) -> float: return 1.0
	func show_gameplay_message(_message: String) -> void: pass
	func _has_clear_line_of_sight(target: Node3D, _from: Vector3, _to: Vector3) -> bool:
		return preload("res://creatures/ai/wildlife_steering.gd").clear_sight(self, target)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("OUTPUT and poses-on|poses-off|encounters required")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://int30_review.json"
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_factor = 1.0
	player.free()
	player = ReviewPlayer.new()
	player.add_to_group(&"player")
	scene.add_child(player)
	player.set_physics_process(true)
	player.position = Vector3(25, 100.05, 25)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.20
	capsule.height = 1.1
	mesh.mesh = capsule
	mesh.position.y = 0.55
	player.add_child(mesh)
	var camera: Camera3D = root.get_camera_3d()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.position = Vector3(4, 105, 11)
	camera.look_at(Vector3(0, 101, 0))
	title = Label.new()
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 22)
	title.size = Vector2(920, 80)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)
	detail = Label.new()
	detail.position = Vector2(20, 495)
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_constant_override("outline_size", 4)
	root.add_child(detail)
	if args[1] == "encounters": await _encounters()
	else: await _poses(args[1] == "poses-on")
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode": args[1], "renderer": RenderingServer.get_current_rendering_method(),
		"render_device": RenderingServer.get_video_adapter_name(), "fps": 15 if args[1] == "encounters" else 30, "size": [960, 540],
		"scales": Shapes.SIZES, "shapes": Shapes.SHAPES.map(func(v: Vector3) -> Array: return [v.x, v.y, v.z]),
		"frames": capture_serial, "pose_cpu_us": pose_cpu_us, "frame_ms": frame_ms, "draw_calls": draws,
		"max_flat_contact_gap": max_contact_gap, "max_socket_drift": socket_error,
		"observations": observations, "failures": failures}, "\t"))
	file.close()
	root.get_node("GameState").set_simulation_speed(1.0)
	scene.free()
	title.free()
	detail.free()
	for failure in failures: push_error(failure)
	print("INT30_CREATURE_CAPTURE_PASSED" if failures.is_empty() else "INT30_CREATURE_CAPTURE_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _poses(enabled: bool) -> void:
	var actors: Array[Preview] = []
	var emotions: Array[RefCounted] = []
	for index in range(3):
		var mount := Node3D.new()
		scene.add_child(mount)
		mount.position = Vector3((index - 1) * 4.0, 100.0, 0)
		var actor := Preview.new()
		actor.scale = Vector3.ONE * Shapes.SIZES[index]
		mount.add_child(actor)
		actor.set_editor_state(Shapes.design(index), -1, -1, false)
		actor.position.y = -float(actor.get_meta("ground_y")) * actor.scale.y
		actor.set_motion("idle")
		actor.set_process(false)
		actors.append(actor)
		var emotion := Emotion.new()
		emotion.configure(40 + index)
		emotions.append(emotion)
	for frame in range(210):
		var mode: String = "idle" if frame < 30 or frame >= 150 else "walk" if frame < 90 else "run"
		var intent: String = "rest" if frame < 30 or frame >= 150 else "social" if frame < 90 else "flee"
		title.text = "INT30 · 2 / 4 / 6 Beine · " + {"idle": "Ruhe", "walk": "Gehen / Neugier", "run": "Laufen / Flucht"}[mode]
		detail.text = "Kleine, mittlere, grosse Form · Ausdruck %s · deterministische Pose-Pruefung" % ("an" if enabled else "aus")
		var start: int = Time.get_ticks_usec()
		for index in range(actors.size()):
			var actor: Preview = actors[index]
			actor.set_motion(mode)
			actor.set_process(false)
			if enabled: actor.set_expression_pose(emotions[index].advance(1.0 / 30.0, {"intent": intent}))
			actor._process(1.0 / 30.0)
			for leg: Dictionary in actor._motion._legs:
				max_contact_gap = maxf(max_contact_gap, maxf(0.0, 100.0 - leg.foot.global_position.y))
		pose_cpu_us.append(Time.get_ticks_usec() - start)
		await _frame(start, enabled)
	_expect(max_contact_gap < 0.025, "Scaled pose penetrated the flat reference floor")

func _specimen(index: int, seed_value: int) -> CharacterBody3D:
	var actor: CharacterBody3D = wildlife.instantiate()
	actor.frozen_blueprint = Shapes.design(index)
	actor.visual_scale_min = Shapes.SIZES[index]
	actor.visual_scale_max = Shapes.SIZES[index]
	actor.configure(2771300 + index, seed_value, Vector2i.ZERO, "grazer")
	scene.add_child(actor)
	actor.position = Vector3(0, 100.05, 0)
	actor._ambient_heading = Vector3.ZERO
	actor._decision_timer = 1000.0
	actor._play_cooldown = 1000.0
	actor.satiety = 90.0
	actor.hydration = 90.0
	actor._needs["seeking"] = false
	actor._drinking["seeking"] = false
	return actor

func _action(actor: CharacterBody3D, playful: bool = false) -> void:
	var rejected: bool = playful and actor.get_node("SocialBehavior").social_status().step == 0
	var result: Dictionary = actor.get_node("SocialBehavior").befriend(player, 0.1, playful)
	observations.append({"frame": capture_serial, "action": "befriend", "playful": playful, "result": result})
	_expect(bool(result.get("ok", false)) != rejected, "Unexpected rendered social action result: " + str(result))

func _encounters() -> void:
	var camera: Camera3D = root.get_camera_3d()
	camera.size = 7.0
	for index in range(3):
		player.position = Vector3(0, 100.05, 2.0)
		var actor: CharacterBody3D = _specimen(index, 501 + index * 3)
		var social: Node = actor.get_node("SocialBehavior")
		var attacker: Node3D
		var frames: int = 180 if index == 2 else 120
		var paused_clock: float = 0.0
		var socket: Dictionary = actor._preview.body_socket("saddle.primary")
		for frame in range(frames):
			var tick: int = frame * 2
			var start: int = Time.get_ticks_usec()
			var caption: String = ""
			if index == 0:
				caption = "Erfolgreiche Begegnung · drei echte Aktionen"
				if tick in [0, 60, 120]: _action(actor, social.social_status().playful)
				if tick == 180: paused_clock = actor._preview._motion_time; root.get_node("GameState").set_simulation_speed(0.0)
				if tick == 210:
					_expect(actor._preview._motion_time == paused_clock, "Rendered body moved during zero-speed pause")
					root.get_node("GameState").set_simulation_speed(1.0)
				if tick in range(180, 210): caption = "Simulation angehalten · Koerper und Zeichen stehen"
			elif index == 1:
				caption = "Abgelehnte Spielgeste · Flucht · Beruhigung · neuer Versuch"
				if tick == 0: _action(actor, true)
				if tick == 16: player.position = Vector3(25, 100.05, 25)
				if tick == 210:
					player.position = actor.position + Vector3(0, 0, 2)
					_action(actor)
			else:
				caption = "Unterbrechung · Fremdangriff · Schmerz / Flucht · Wiederaufnahme"
				if tick == 0: _action(actor)
				if tick == 30: player.position = Vector3(25, 100.05, 25)
				if tick == 80:
					player.position = actor.position + Vector3(0, 0, 2)
					_action(actor)
				if tick == 96:
					attacker = Node3D.new()
					scene.add_child(attacker)
					attacker.position = actor.position + Vector3(1.0, 0, 0)
					actor.receive_creature_attack(1.0, attacker)
					observations.append({"frame": capture_serial, "action": "external_damage", "health": actor.current_health})
				if tick == 100: player.position = Vector3(25, 100.05, 25)
				if tick == 120: attacker.free()
				if tick == 330:
					player.position = actor.position + Vector3(0, 0, 2)
					_action(actor, social.social_status().playful)
			var current_socket: Dictionary = actor._preview.body_socket("saddle.primary")
			if not current_socket.is_empty() and not socket.is_empty():
				socket_error = maxf(socket_error, current_socket.body_transform.origin.distance_to(socket.body_transform.origin))
			title.text = "INT30 · %d Beine · Groesse %.2f · %s" % [(index + 1) * 2, Shapes.SIZES[index], caption]
			var context: Dictionary = actor.get_inspection_data()
			detail.text = "Vertrauen %d · %s · %s · echte KI / Begegnungsdaten" % [roundi(social.entry().trust), social.entry().relation, context.ai_description]
			var target: Vector3 = actor.position + Vector3.UP
			camera.position = target + Vector3(4.3, 3.5, 7.2)
			camera.look_at(target)
			await _frame(start, true)
			if frame % 15 == 0:
				observations.append({"frame": capture_serial, "specimen": index, "trust": social.entry().trust,
					"relation": social.entry().relation, "ai": actor.ai_state,
					"emotion": actor.get_node("ExpressionBehavior").emotion.state,
					"marker": actor._label.text if actor._label.visible else "", "grounded": actor.is_on_floor()})
		_expect(social.entry().trust == (35.0 if index == 1 else 100.0), "Rendered encounter did not reach expected saved trust")
		_expect(actor.is_on_floor(), "Rendered creature lost collision ground contact")
		actor.free()
		await process_frame
	_expect(socket_error < 0.00001, "Live animation changed authored body sockets")

func _frame(start: int, capture: bool) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	frame_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if capture:
		var result: Error = root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % capture_serial))
		_expect(result == OK, "Could not save native rendered frame")
	capture_serial += 1
