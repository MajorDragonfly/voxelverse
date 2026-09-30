extends SceneTree
## Real player/controller, physical 0.5 m voxels, fixed simulation replay.
## --fixed-fps is a replay clock, never a claim about achieved hardware FPS.
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var output: String = ""
var fps: int = 60
var body_scale: float = 1.0
var diagonal: bool = false
var before: bool = false
var frame_index: int = 0
var player: CharacterBody3D
var label: Label

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args := OS.get_cmdline_user_args()
	fps = int(args[0]) if args.size() > 0 else 60
	body_scale = float(args[1]) if args.size() > 1 else 1.0
	diagonal = args.size() > 2 and args[2] == "diagonal"
	before = args.size() > 3 and args[3] == "before"
	output = args[4] if args.size() > 4 else ""
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172c3b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dfecf2")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	stage.add_child(light)
	_box(stage, Vector3(30, 1, 24), Vector3(0, -0.5, 0), Color("486754"))
	for step in range(3):
		_box(stage, Vector3(2.0, (step + 1) * 0.5, 14), Vector3(2 + step * 2, (step + 1) * 0.25, 0), Color("8c947c") if step % 2 == 0 else Color("758975"))
	# Plateau ends in a true 1.5 m fall; wall checks the native spring arm.
	_box(stage, Vector3(3, 1.5, 14), Vector3(8.5, 0.75, 0), Color("8c947c"))
	_box(stage, Vector3(0.3, 5, 16), Vector3(-5.5, 2.5, 0), Color("566b87"))
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(-1.0, 0.03, -2.0 if diagonal else 0.0)
	player.get_node("CreatureRuntimeVisual").runtime_visual_scale *= body_scale
	player.get_node("CreatureRuntimeVisual").apply_blueprint_stats = false
	# Keep the production collision profile; authored body sizes affect visuals.
	stage.add_child(player)
	player.move_speed = 3.0
	player.thirst_loss_per_second = 0.0
	player.hunger_loss_per_second = 0.0
	player.camera_pivot.rotation = Vector3(deg_to_rad(-15), deg_to_rad(-90 if not diagonal else -70), 0)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	var caption := CanvasLayer.new()
	caption.layer = 100
	root.add_child(caption)
	label = Label.new()
	label.position = Vector2(16, 76)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	caption.add_child(label)
	for tick in range(fps / 2): await _frame("settle")
	var initial: Vector3 = player.global_position
	Input.action_press("move_forward")
	for tick in range(fps * 4): await _frame("up + fall")
	Input.action_release("move_forward")
	_check(player.position.x > 10.0, "Did not cross the complete three-step staircase.")
	for tick in range(fps): await _frame("land + settle")
	_check(player.is_on_floor(), "Did not land after the plateau fall.")
	_check(absf(player.camera_pivot.position.y - 1.7) < 0.02, "Camera retained step oscillation after falling.")
	Input.action_press("jump")
	for tick in range(fps): await _frame("jump")
	Input.action_release("jump")
	for tick in range(fps / 2): await _frame("land")
	# Separate descent fixture: return to the plateau after testing its sheer fall.
	# The 1.5 m far wall is deliberately too high for normal step-up.
	var direction: Vector3 = (-player.camera_pivot.basis.z).slide(Vector3.UP).normalized()
	player.position = initial + direction * (9.6 / direction.x) + Vector3.UP * 1.53
	player.velocity = Vector3.ZERO
	player._reset_step_camera()
	for tick in range(fps / 2): await _frame("descent fixture settle")
	Input.action_press("move_back")
	for tick in range(int(fps * 3.2)): await _frame("down")
	Input.action_release("move_back")
	for tick in range(fps): await _frame("settle")
	_check(player.position.x < 1.0 and player.is_on_floor(), "Did not return grounded below the staircase.")
	_check(absf(player.camera_pivot.position.y - 1.7) < 0.02, "Camera did not settle after descent.")
	_check(player.position.distance_to(initial) < 1.0, "Descending the staircase retained a horizontal displacement.")
	var report := {"passed": failures.is_empty(), "failures": failures, "clock": "fixed simulation replay; wall_us records actual render cost",
		"fps": fps, "visual_body_scale": body_scale, "collision_profile": "unchanged production capsule", "diagonal": diagonal,
		"before": before, "voxel_height_m": 0.5, "rows": rows}
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("trace.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report))
	print("INT30_CAMERA_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "frames": rows.size(), "fps": fps, "size": body_scale, "diagonal": diagonal, "before": before}))
	stage.free()
	caption.free()
	if failures.is_empty(): print("INT30_CAMERA_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _frame(phase: String) -> void:
	var start: int = Time.get_ticks_usec()
	await process_frame
	# Counterfactual control reproduces the original pre-PT17-05 rigid pivot.
	# Physics, spring arm, input, terrain and body are identical on both sides.
	if before:
		player._camera_step_offset = 0.0
		player._apply_step_camera()
	label.text = "%s · %.2f× Körper · %d Hz Replay · %s\n%s · volle 0,5-m-Voxel" % ["VORHER: starrer Pivot" if before else "NACHHER: Produktionskamera", body_scale, fps, "schräg" if diagonal else "gerade", phase]
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame_index))
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	rows.append({"frame": frame_index, "phase": phase, "body": [player.position.x, player.position.y, player.position.z],
		"pivot_y": player.camera_pivot.global_position.y, "camera_y": camera.global_position.y,
		"floor": player.is_on_floor(), "offset": player._camera_step_offset, "spring_length": player.spring_arm.get_hit_length(),
		"vertical_velocity": player.velocity.y, "wall_us": Time.get_ticks_usec() - start})
	frame_index += 1

func _box(parent: Node3D, size: Vector3, point: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = point
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	body.add_child(visual)
	parent.add_child(body)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
