extends SceneTree
## Actual capsule/input boundaries for the owner patch. No altered collision
## profile and no invented floor flag; move_and_slide clears airborne contact.
const Fixture = preload("res://tests/r32_03_step_fixture.gd")
var failures: Array[String] = []
var observations: Array[Dictionary] = []

class FirstTickInput extends Node:
	var done: bool = false
	func _physics_process(_delta: float) -> void:
		if done: return
		done = true
		Input.action_press("jump")
		Input.action_press("move_forward")

class AfterPlayer extends Node:
	signal sampled
	var actor: CharacterBody3D
	var position_value: Vector3
	var velocity_value: Vector3
	func _physics_process(_delta: float) -> void:
		position_value = actor.global_position
		velocity_value = actor.velocity
		set_physics_process(false)
		sampled.emit()

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	await _near_support("near support", 0.0142, false, false, true)
	await _near_support("air above riser", 0.30, false, false, false)
	await _near_support("high wall", 0.0142, true, false, false)
	await _near_support("low ceiling", 0.0142, false, true, false)
	await _immediate_jump_and_look()
	for message in failures: push_error(message)
	print("R32_03_BOUNDARY_EVIDENCE ", JSON.stringify(observations))
	if failures.is_empty(): print("R32_03_BOUNDARIES_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _host() -> Node3D:
	var fixture := Fixture.new()
	root.add_child(fixture)
	current_scene = fixture
	fixture.setup(1.0, false, 3.0)
	return fixture

func _near_support(label: String, height: float, wall: bool, ceiling: bool, expected_step: bool) -> void:
	var fixture := _host()
	# A 1.2 m wall intersects the raised capsule's cylindrical section. A 0.8 m
	# lip can allow a partial approach on the rounded underside, so an initial
	# body rise there does not establish that the player crossed the wall.
	if wall: fixture._box(Vector3(2, 1.2, 18), Vector3(2, 0.6, 0), Color.GRAY)
	if ceiling: fixture._box(Vector3(10, 0.2, 18), Vector3(0, 1.9, 0), Color.GRAY)
	for tick in range(12): await physics_frame
	var actor: CharacterBody3D = fixture.player
	actor.set_physics_process(false)
	# Clear the actual physics contact at a genuinely airborne location.
	actor.position = Vector3(0.579, 0.40, 0)
	actor.velocity = Vector3.UP * 0.1
	actor.move_and_slide()
	_check(not actor.is_on_floor(), label + ": airborne setup retained floor")
	actor.position = Vector3(0.579, height, 0)
	actor.velocity = Vector3.ZERO
	actor._reset_step_camera()
	var body_before: Vector3 = fixture.point(actor)
	var target_before: Vector3 = fixture.point(actor.camera_pivot)
	Input.action_press("move_forward")
	actor._physics_process(1.0 / 60.0)
	Input.action_release("move_forward")
	var body_rise: float = fixture.point(actor).y - body_before.y
	var target_rise: float = fixture.point(actor.camera_pivot).y - target_before.y
	_check(body_rise > 0.30 if expected_step else body_rise < 0.08, label + ": unexpected physical step " + str(body_rise))
	if expected_step:
		_check(absf(target_rise) < 0.22, "Lost-floor step bypassed camera compensation")
		var offset: float = actor._camera_step_offset
		var view: Vector3 = fixture.point(actor.camera)
		var body: Vector3 = fixture.point(actor)
		fixture.shift_origin()
		_check(fixture.point(actor.camera).distance_to(view) < 0.0001, "Rebase moved view during real step compensation")
		_check(fixture.point(actor).distance_to(body) < 0.0001 and actor._camera_step_offset == offset, "Rebase changed body or active offset")
	observations.append({"case": label, "body_rise_m": body_rise, "target_rise_m": target_rise,
		"expected_step": expected_step, "rebase_error_m": fixture.adapter.max_rebase_error_m})
	fixture.close()
	await process_frame

func _immediate_jump_and_look() -> void:
	var fixture := _host()
	for tick in range(12): await physics_frame
	var actor: CharacterBody3D = fixture.player
	_check(actor.is_on_floor(), "Jump input lacked confirmed ground")
	actor._camera_step_offset = -0.4
	actor._apply_step_camera()
	var before: Vector3 = fixture.point(actor)
	# Inject input inside the real physics tick, before the production player.
	# A manual callback outside that tick does not model just-pressed input.
	var driver := FirstTickInput.new()
	driver.process_physics_priority = -100
	fixture.add_child(driver)
	var sample := AfterPlayer.new()
	sample.actor = actor
	sample.process_physics_priority = 200
	fixture.add_child(sample)
	await sample.sampled
	Input.action_release("jump")
	Input.action_release("move_forward")
	var motion: Vector3 = sample.position_value - before
	_check(motion.y > 0.08 and motion.slide(actor.up_direction).length() > 0.04, "Step easing delayed jump or movement input")
	_check(sample.velocity_value.dot(actor.up_direction) > 0.0, "Jump velocity lost")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Look probe requires a graphical captured-mouse viewport")
	var yaw: float = actor.camera_pivot.rotation.y
	var mouse := InputEventMouseMotion.new()
	mouse.screen_relative = Vector2(80, 0)
	actor._unhandled_input(mouse)
	_check(absf(actor.camera_pivot.rotation.y - yaw) > 0.01, "Look input was delayed")
	observations.append({"case": "immediate jump/move/look", "first_tick_motion": str(motion),
		"yaw_delta": actor.camera_pivot.rotation.y - yaw})
	fixture.close()
	await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
