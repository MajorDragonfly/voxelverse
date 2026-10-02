extends "res://tests/wildlife_drinking_test.gd"
## Actual production actors/AI on the inherited loaded shore fixture.
## No assigned intent/emotion/pose. Run headless for state/contact checks or
## with a renderer and --fixed-fps 30 for matching PNG/video evidence.
## User args: OUTPUT [--capture-video] [--allow-face-drift] [--group]
const Shapes = preload("res://creatures/behavior/review/int30_creature_shapes.gd")
var shape_index: int = 0
var serial: int = 3201200
var output: String
var caption: Label
var frame_serial: int = 0
var phase_label: String = ""
var samples: Array[Dictionary] = []
var draw_ms: Array[float] = []
var draw_calls: Array[int] = []
var actors: Array[CharacterBody3D] = []
var seen: Dictionary = {}
var capture_video: bool = false
var max_face_drift: float = 0.0
var max_floor_penetration: float = 0.0
var max_contact_step: float = 0.0
var previous_feet: Dictionary = {}
var worst_floor: Dictionary = {}
var animation_cpu_us: Array[int] = []

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("OUTPUT required")
		quit(1)
		return
	output = args[0]
	capture_video = "--capture-video" in args
	DirAccess.make_dir_recursive_absolute(output)
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://r32_12_review.json"
	state.start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	root.size = Vector2i(960, 540)
	caption = Label.new()
	caption.position = Vector2(16, 14)
	caption.size = Vector2(925, 70)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 20)
	caption.add_theme_constant_override("outline_size", 4)
	root.add_child(caption)
	player.position = Vector3(-30, 100.55, 25)
	await _frames(4)
	if "--group" in args:
		await _group_cost()
	else:
		await _all_shapes()
	if not "--allow-face-drift" in args:
		_expect(max_face_drift < 0.001, "Live expression detached face roots from skin")
	_expect(max_floor_penetration < 0.025, "Live foot penetrated loaded shore floor")
	await _finish_review()

func _all_shapes() -> void:
	for index in range(3):
		shape_index = index
		seen = {}
		await _specimen_sequence()
		samples.append({"shape": index, "scale": Shapes.SIZES[index], "legs": (index + 1) * 2, "seen": seen.duplicate(true)})
		for animal in actors:
			if is_instance_valid(animal): animal.queue_free()
		actors.clear()
		previous_feet.clear()
		await _frames(4)

func _finish_review() -> void:
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "production AI on controlled loaded shore; not spherical campaign acceptance",
		"seed": 15838, "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "size": [960, 540], "frames": frame_serial,
		"max_face_root_drift_m": max_face_drift, "max_floor_penetration_m": max_floor_penetration,
		"max_contact_step_m": max_contact_step, "worst_floor": worst_floor, "draw_wait_ms": draw_ms, "draw_calls": draw_calls,
		"samples": samples, "animation_cpu_us": animation_cpu_us, "failures": failures}, "\t"))
	file.close()
	state.set_simulation_speed(1.0)
	scene.free()
	caption.free()
	print("R32_12_ANIMATION_REVIEW " + JSON.stringify({"passed": failures.is_empty(), "frames": frame_serial, "failures": failures}))
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _animal(point: Vector3, _individual: int, role: String = "grazer") -> CharacterBody3D:
	var animal: CharacterBody3D = wildlife.instantiate()
	animal.water_provider = provider
	animal.frozen_blueprint = Shapes.design(shape_index, role)
	animal.visual_scale_min = Shapes.SIZES[shape_index]
	animal.visual_scale_max = Shapes.SIZES[shape_index]
	serial += 1
	animal.configure(2771300 + shape_index, serial, Vector2i.ZERO, role)
	scene.add_child(animal)
	animal.position = point
	animal.current_health = animal.maximum_health
	animal.satiety = 90.0
	animal.hydration = 90.0
	animal._needs["satiety"] = 90.0
	animal._needs["seeking"] = false
	animal._drinking["hydration"] = 90.0
	animal._drinking["seeking"] = false
	animal._visual_root.rotation.y = -PI * 0.5
	animal._ambient_heading = Vector3.ZERO
	animal._decision_timer = 1000.0
	animal._play_cooldown = 1000.0
	actors.append(animal)
	return animal

func _specimen_sequence() -> void:
	var animal: CharacterBody3D = _animal(Vector3(0, 100.55, 0), serial)
	phase_label = "Ruhe"
	await _frames(24)
	var bush: Node3D = load("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.snap_to_terrain = false
	bush.persistent_food_key = "r32-12:%d" % shape_index
	scene.add_child(bush)
	bush.position = Vector3(0.0, 100.5, -4.0)
	animal.satiety = 60.0
	animal._needs["satiety"] = 60.0
	animal._needs["seeking"] = true
	phase_label = "Gehen / Neugier zum echten Futter"
	await _until_intent(animal, "eat", 240)
	phase_label = "Fressen / echtes Futter wird verbraucht"
	await _frames(50)
	await _until_intent(animal, "rest", 200)
	_expect(bush.get_food_remaining() < 30.0, "Feeding footage consumed no actual food")
	bush.queue_free()
	await _frames(3)
	_thirsty(animal, 60.0)
	phase_label = "Wasser suchen / echte Uferpruefung"
	await _until_intent(animal, "drink", 360)
	phase_label = "Trinken / echte Hydration"
	var hydration_before: float = animal.hydration
	await _frames(45)
	_expect(animal.hydration > hydration_before, "Drinking footage restored no hydration")
	await _until_intent(animal, "rest", 180)
	animal.queue_free()
	actors.clear()
	previous_feet.clear()
	await _frames(3)
	var a: CharacterBody3D = _animal(Vector3(-9.0, 100.55, 0), serial)
	var b: CharacterBody3D = _animal(Vector3(-4.0, 100.55, 0), serial)
	a._visual_root.rotation.y = -PI * 0.5
	b._visual_root.rotation.y = PI * 0.5
	for member in [a, b]:
		member._play_cooldown = 0.0
		member._play_search = 0.0
	phase_label = "Gegenseitige Sozialreaktion / echte gemeinsame KI-Session"
	await _frames(8)
	var session: RefCounted = a._play_session
	_expect(session != null and session == b._play_session, "Natural pair did not form shared session")
	for tick in range(420):
		await _frames(1)
		if session != null and not session.active(): break
	_expect(session != null and session.reason == "complete", "Social animation failed to terminate naturally")
	for intent: String in ["rest", "forage", "eat", "seek_water", "drink", "play_greet", "play_play", "play_rest"]:
		_expect(seen.has(intent), "Missing real state in footage: " + intent)
	phase_label = "Pause / alle Koerperuhren stehen"
	state.set_simulation_speed(0.0)
	var paused_clock: float = a._preview._motion_time
	await _frames(15)
	_expect(a._preview._motion_time == paused_clock, "Body clock moved during pause")
	state.set_simulation_speed(1.0)
	b.queue_free()
	actors = [a]
	previous_feet.clear()
	player.is_dead = false
	player.position = a.position + Vector3(0, 0, 1.1)
	phase_label = "Gefahr / Flucht aus realer Wahrnehmung"
	await _until_intent(a, "flee", 30)
	await _frames(40)
	var attacker := Node3D.new()
	scene.add_child(attacker)
	attacker.position = a.position + Vector3(1, 0, 0)
	a.receive_creature_attack(1.0, attacker)
	phase_label = "Schmerz / echte Schadensreaktion"
	await _frames(15)
	attacker.queue_free()
	player.is_dead = true
	player.position = Vector3(-30, 100.55, 25)
	phase_label = "Rueckkehr / Reaktion endet"
	await _frames(240)
	_expect(a.get_node("ExpressionBehavior").emotion._remaining <= 0.0, "Transient pain never ended")
	_expect(a.get_node("ExpressionBehavior").emotion.state != "hurt", "Pain loop remained after threat removal")
	_expect(seen.has("flee"), "No real flight state recorded")
	# A hostile actor supplies the distinct warning/defence pose through
	# ordinary perception; no ai_state or expression value is assigned.
	a.queue_free()
	actors.clear()
	previous_feet.clear()
	await _frames(3)
	var predator: CharacterBody3D = _animal(Vector3(-6, 100.55, 4), serial, "predator")
	player.is_dead = false
	player.position = predator.position + Vector3(1.1, 0, 0)
	phase_label = "Gefahr / echte Warnung eines Raubtiers"
	await _until_intent(predator, "alert", 30)
	await _frames(24)
	_expect(seen.has("alert"), "Missing live hostile warning")
	player.is_dead = true
	player.position = Vector3(-30, 100.55, 25)
	phase_label = "Warnung endet nach Zielverlust"
	await _frames(180)
	_expect(predator.ai_state not in ["alert", "chase"], "Warning animation stayed active after target loss")

func _until_intent(animal: Node, intent: String, limit: int) -> void:
	for tick in range(limit):
		await _frames(1)
		if animal.ai_state == intent: return
	_expect(false, "State deadline: " + intent + " " + JSON.stringify(animal.get_ai_debug_state()))

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame
		# Sample after production idle callbacks, as the renderer sees the pose.
		await create_timer(0.0).timeout
		var camera: Camera3D = root.get_camera_3d()
		if not actors.is_empty() and is_instance_valid(actors[0]):
			var center: Vector3 = actors[0].global_position + Vector3.UP
			camera.position = center + Vector3(4.5, 3.0, 7.0) * Shapes.SIZES[shape_index]
			camera.look_at(center)
		caption.text = "R32-12 · %d Beine · %.2f · %s" % [(shape_index + 1) * 2, Shapes.SIZES[shape_index], phase_label]
		for actor in actors:
			if not is_instance_valid(actor): continue
			seen[actor.ai_state] = true
			for part: Dictionary in actor._preview._motion._parts:
				if str(part.node.get_meta("creature_part_category", "")) in ["mouth", "eyes", "head"]:
					max_face_drift = maxf(max_face_drift, (actor._preview.global_basis * (part.node.position - part.position)).length())
			var contacts: Array[Vector3] = []
			for leg: Dictionary in actor._preview._motion._legs:
				var point: Vector3 = leg.foot.global_position
				_expect(point.is_finite(), "Non-finite live foot")
				if 100.5 - point.y > max_floor_penetration:
					max_floor_penetration = 100.5 - point.y
					worst_floor = {"frame": frame_serial, "shape": shape_index, "phase": phase_label,
						"ai": actor.ai_state, "point": str(point), "actor": str(actor.position), "grounded": actor.is_on_floor(),
						"base_preview": str(actor._preview._motion._base_position), "preview": str(actor._preview.position),
						"contact_rest": str(leg.rest_contact_preview), "rotation": str(actor._preview.rotation),
						"actor_basis": str(actor.global_basis), "visual_basis": str(actor._visual_root.global_basis),
						"up": str(actor.up_direction), "foot_local": str(leg.foot.position)}
				contacts.append(point)
			var key: int = actor.get_instance_id()
			if previous_feet.has(key) and previous_feet[key].size() == contacts.size():
				for i in range(contacts.size()): max_contact_step = maxf(max_contact_step, contacts[i].distance_to(previous_feet[key][i]))
			previous_feet[key] = contacts
			if frame_serial % 10 == 0:
				samples.append({"frame": frame_serial, "shape": shape_index, "phase": phase_label,
					"ai": actor.ai_state, "intent": actor.get_expression_context().intent,
					"emotion": actor.get_node("ExpressionBehavior").emotion.state,
					"mouth": actor._preview._articulation.debug_state().mouth,
					"grounded": actor.is_on_floor(), "position": str(actor.position)})
		if capture_video:
			var start: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			draw_ms.append((Time.get_ticks_usec() - start) / 1000.0)
			draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			_expect(root.get_texture().get_image().save_png(output.path_join("frame_%05d.png" % frame_serial)) == OK, "Capture failed")
		frame_serial += 1


func _group_cost() -> void:
	# Twelve unchanged shapes; measure only driver + preview animation cost.
	# AI initializes normally, then remains outside the timed section.
	capture_video = false
	phase_label = "12 Tiere / reine Animationskosten"
	for index in range(12):
		shape_index = index % 3
		var animal: CharacterBody3D = _animal(Vector3(-18 + (index % 4) * 4, 100.55, -6 + (index / 4) * 5), serial)
		animal.get_node("ExpressionBehavior").set_process(false)
		animal._preview.set_process(false)
	shape_index = 1
	await _frames(12)
	for actor in actors:
		actor.set_physics_process(false)
		actor._preview.set_process(false)
	for frame in range(210):
		var start: int = Time.get_ticks_usec()
		for actor in actors:
			actor.get_node("ExpressionBehavior")._process(1.0 / 30.0)
			actor._preview._process(1.0 / 30.0)
		var cost: int = Time.get_ticks_usec() - start
		if frame >= 30: animation_cpu_us.append(cost)
		await process_frame
		if DisplayServer.get_name() != "headless":
			var draw_start: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			if frame >= 30:
				draw_ms.append(float(Time.get_ticks_usec() - draw_start) / 1000.0)
				draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	for actor in actors: actor.queue_free()
	actors.clear()
	await process_frame
