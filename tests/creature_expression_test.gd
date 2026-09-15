extends "res://tests/creature_behavior_gameplay_test.gd"
## Real social entry points and renderer plus isolated deterministic pose tests.
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
var checks: int = 0

func _run() -> void:
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://expression_test.json"
	_model()
	await _poses()
	state.start_world_with_seed(12345)
	await process_frame
	player = load("res://creatures/player/player.tscn").instantiate()
	root.add_child(player)
	player.position = Vector3(0, 30, 0)
	player.fall_acceleration = 0.0
	player.set_process(false)
	behavior = player.get_node("BehaviorController")
	behavior.set_process(false)
	await process_frame
	if "--expression-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process load")
		var social: Node = await _spawn(11)
		_expect(social.entry().relation == "ally", "Fresh process relationship")
		_expect(wildlife.get_node("ExpressionBehavior").emotion._reaction == "", "Fresh process replayed gesture")
		_expect(social.greet(player).ok, "Fresh process greeting unavailable")
	else:
		await _interactions()
	await _dispose_wildlife()
	player.free()
	await process_frame
	print(JSON.stringify({"test": "creature_expression", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _model() -> void:
	var a := Emotion.new()
	var b := Emotion.new()
	a.configure(71)
	b.configure(71)
	for tick in range(90):
		_expect(a.advance(1.0 / 30, {"intent": "social"}) == b.advance(1.0 / 30, {"intent": "social"}), "Seed/timeline not deterministic")
	var before: Dictionary = a.pose()
	_expect(a.advance(0.5, {"active": false}) == before and a.advance(NAN, {}) == before, "Inactive/invalid clock advanced")
	a.react("greet")
	a.advance(0.1, {})
	_expect(a.state == "playful", "Greeting not playful")
	a.advance(0.1, {"intent": "flee"})
	_expect(a.state == "afraid", "Danger lost to greeting")
	a.advance(0.1, {})
	_expect(a.state == "calm", "Canceled greeting resumed")
	a.react("hurt")
	a.react("friend")
	a.advance(0.1, {"intent": "chase"})
	_expect(a.state == "hurt", "Friendship suppressed pain")
	a.advance(0.7, {"intent": "chase"})
	_expect(a.state == "angry", "Pain did not recover to actual intent")
	_expect(a.advance(0.1, {"dead": true}).is_empty() and a.clock == 0, "Death retained expression")
	var expected: Dictionary = {"social": "curious", "herd": "curious", "eat": "feeding", "drink": "feeding", "alert": "angry", "flee": "afraid"}
	for intent: String in expected:
		a.advance(0.1, {"intent": intent})
		_expect(a.state == expected[intent], "Intent mapping " + intent)
	var frames: Array[Dictionary] = []
	for hz in [30, 60, 120]:
		a.configure(19)
		for tick in range(hz): a.advance(1.0 / hz, {"friendly_near": true, "look_yaw": 10.0})
		frames.append(a.pose())
	for key: String in ["head_pitch", "body_drop", "tail_yaw", "eye_open", "look_yaw"]:
		_expect(absf(float(frames[0][key]) - float(frames[2][key])) < 0.0001, "Frame-rate dependent " + key)
	_expect(absf(float(frames[0].look_yaw)) <= 0.3, "Unbounded gaze")

func _poses() -> void:
	for pairs in [0, 1, 2, 3]:
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		for index in range(pairs): Assembly.BaseBlueprint.add_part(design, "legs_walker")
		if pairs > 0:
			for id: String in ["eyes_stalks", "mouth_crocodile_snout", "tail_balance"]: Assembly.BaseBlueprint.add_part(design, id)
		Anatomy.reset_all_anchors(design)
		var original: String = var_to_str(design)
		var frame := Node3D.new()
		root.add_child(frame)
		frame.transform = Transform3D(Basis.from_euler(Vector3(0.9, -0.7, 0.4)), Vector3(1500, -700, 2300))
		var preview := Preview.new()
		frame.add_child(preview)
		preview.set_editor_state(design, -1, -1, false)
		preview.set_motion("idle")
		preview.set_process(false)
		var model := Emotion.new()
		model.configure(42)
		var node_count: int = preview.find_children("*", "", true, false).size()
		for intent: String in ["rest", "social", "flee", "alert", "eat"]:
			var pose: Dictionary
			for tick in range(60): pose = model.advance(1.0 / 60, {"intent": intent})
			for mode: String in ["idle", "walk", "run"]:
				preview.set_motion(mode)
				preview.set_process(false)
				preview.set_expression_pose({})
				preview._motion.sample(mode, 1.0)
				var feet: Array[Vector3] = []
				for leg: Dictionary in preview._motion._legs: feet.append(leg.foot.global_position)
				preview.set_expression_pose(pose)
				preview._motion.sample(mode, 1.0)
				for index in range(feet.size()):
					_expect(preview._motion._legs[index].foot.global_position.distance_to(feet[index]) < 0.025, "Expression displaced planted foot (%s, %d legs)" % [mode, pairs * 2])
				var transforms: Array[Transform3D] = []
				for part: Dictionary in preview._motion._parts: transforms.append(part.node.transform)
				preview._motion.sample(mode, 1.0)
				for index in range(transforms.size()): _expect(preview._motion._parts[index].node.transform.is_equal_approx(transforms[index]), "Pose accumulates across frames")
				preview.play_part_action("bite")
				preview._process(0.08)
				_expect(preview._articulation.debug_state().action == "bite", "Emotion replaced bite")
		_expect(node_count == preview.find_children("*", "", true, false).size(), "Expression allocates render nodes")
		var rest: Array[Dictionary] = preview._motion._parts.duplicate()
		preview.set_motion("edit")
		for part: Dictionary in rest:
			_expect(part.node.scale.is_equal_approx(part.scale), "Edit retained blink scaling")
		preview.rebuild()
		_expect(preview._motion.expression_pose.is_empty() and not preview.is_processing(), "Rebuild retained pose")
		_expect(var_to_str(design) == original, "Expression rewrote blueprint")
		frame.free()
		await process_frame

func _interactions() -> void:
	var social: Node = await _spawn(11)
	var driver: Node = wildlife.get_node("ExpressionBehavior")
	driver.set_process(false)
	_expect(not social.greet(player).ok, "Unfamiliar animal accepted greeting")
	_befriend(social)
	driver._process(0.1)
	_expect(driver.emotion.state == "affectionate", "Successful friendship missing expression")
	var before: Dictionary = progression.export_state().duplicate(true)
	wildlife.interact(player)
	driver._process(0.1)
	_expect(driver.emotion.state == "playful" and social.attention_actor == player, "Public interaction did not greet")
	_expect(not social.greet(player).ok and progression.export_state() == before, "Greeting paid rewards or bypassed cooldown")
	social.greet_cooldown = 0.0
	wildlife.ai_state = "flee"
	_expect(not social.greet(player).ok, "Greeting interrupted escape")
	driver._process(0.2)
	_expect(driver.emotion.state == "afraid", "AI escape missing fear")
	wildlife.ai_state = "rest"
	paused = true
	_expect(not social.greet(player).ok, "Paused greeting")
	var clock: float = driver.emotion.clock
	driver.set_process(true)
	for index in range(5): await process_frame
	_expect(driver.emotion.clock == clock, "Paused expression advanced")
	paused = false
	driver.set_process(false)
	player.position.x = 40
	_expect(not social.greet(player).ok, "Distant greeting")
	player.position.x = 0
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	collision.shape = box
	wall.add_child(collision)
	root.add_child(wall)
	wall.position = player.position + Vector3(0, 0.7, -1.0)
	await physics_frame
	await process_frame
	_expect(not social.greet(player).ok, "Greeting through a wall")
	wall.free()
	await physics_frame
	_expect(saves.save_now() and saves.load_now(), "Greeting save/load")
	_expect(driver.emotion.clock == 0 and driver.emotion._reaction == "" and social.greet_cooldown == 0, "Load retained transient gesture")
	_expect(social.entry().relation == "ally", "Load lost friendship")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/creature_expression_test.gd", "--", "--expression-restart"], output, true)
	_expect(code == 0 and "".join(output).contains('"passed":true'), "Fresh process failed: " + str(output))
	# A failed care transaction must not manufacture gratitude.
	social = await _spawn(10)
	driver = wildlife.get_node("ExpressionBehavior")
	driver.set_process(false)
	saves.save_path = "user://missing_expression_folder/save.json"
	_expect(not social.help(player).ok and driver.emotion._reaction == "", "Rejected help animated success")
	saves.save_path = "user://expression_test.json"
	_expect(social.help(player).ok and driver.emotion._reaction == "affectionate", "Accepted care did not animate")
	wildlife.is_dead = true
	driver._process(0.1)
	_expect(driver.emotion._reaction == "" and wildlife._preview._motion.expression_pose.is_empty(), "Death retained gesture")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition and not failures.has(message): failures.append(message)
