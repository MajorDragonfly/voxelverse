extends SceneTree
## A real player crosses a physical voxel ledge; only the camera target eases.
var failures: Array[String] = []
var observations: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	await _case(Vector3.UP)
	await _case(Vector3(1, 2, 3).normalized())
	for failure: String in failures: push_error(failure)
	print("STEP_CAMERA_EVIDENCE ", JSON.stringify(observations))
	if failures.is_empty(): print("STEP_CAMERA_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _case(up: Vector3) -> void:
	var host := Node3D.new()
	host.basis = Basis.looking_at(-Vector3.FORWARD.slide(up).normalized(), up) if absf(up.dot(Vector3.FORWARD)) < 0.95 else Basis.IDENTITY
	root.add_child(host)
	_box(host, Vector3(12, 1, 6), Vector3(0, -0.5, 0))
	_box(host, Vector3(3, 0.5, 4), Vector3(2.5, 0.25, 0))
	var player: CharacterBody3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(-1, 0.03, 0)
	host.add_child(player)
	player.up_direction = host.global_basis.y
	player.move_speed = 4.0
	for tick in range(5): await physics_frame
	var body_peak: float = 0.0
	var camera_peak: float = 0.0
	var previous_body: Vector3 = player.global_position
	var pivot: Node3D = player.camera_pivot
	var previous_camera: Vector3 = pivot.global_position
	var reached: bool = false
	Input.action_press("move_right")
	for tick in range(90):
		await physics_frame
		var body_delta: float = (player.global_position - previous_body).dot(up)
		var camera_delta: float = (pivot.global_position - previous_camera).dot(up)
		body_peak = maxf(body_peak, body_delta)
		camera_peak = maxf(camera_peak, camera_delta)
		previous_body = player.global_position
		previous_camera = pivot.global_position
		if host.to_local(player.global_position).x > 2.3:
			reached = true
			break
	Input.action_release("move_right")
	_check(reached and player.is_on_floor(), "Player did not remain grounded on the ledge: " + str(up))
	_check(body_peak > 0.30, "Step case did not reproduce the physical height change: " + str(up))
	_check(camera_peak < 0.22, "Step jolted the camera target: " + str(up) + " / " + str(camera_peak))
	for tick in range(40): await process_frame
	_check(absf(pivot.position.y - 1.7) < 0.03, "Camera did not settle on the player: " + str(up))
	observations.append({"up": str(up), "body_peak": body_peak, "camera_peak": camera_peak, "reached": reached})
	host.queue_free()
	await process_frame

func _box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
