extends SceneTree
## Native wall-clock frames, max_fps cap; physics remains production 60 Hz.
const Fixture = preload("res://tests/r32_03_step_fixture.gd")
var fixture: Node3D
var output: String
var cap: int
var body_scale: float
var diagonal: bool
var frames: Array[Dictionary] = []
var caption: Label
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args := OS.get_cmdline_user_args()
	cap = int(args[0])
	body_scale = float(args[1])
	diagonal = args[2] == "diagonal"
	output = args[3]
	DirAccess.make_dir_recursive_absolute(output)
	Engine.max_fps = cap
	root.size = Vector2i(640, 360)
	root.content_scale_size = Vector2i.ZERO
	root.get_viewport().set_disable_3d(false)
	fixture = Fixture.new()
	root.add_child(fixture)
	current_scene = fixture
	fixture.setup(body_scale, diagonal)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172c3b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dfecf2")
	environment.environment.ambient_light_energy = 0.7
	fixture.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -25, 0)
	fixture.add_child(light)
	var layer := CanvasLayer.new()
	layer.layer = 100
	fixture.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(10, 54)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(caption)
	await _phase("settle", 0.5)
	# Inspection HUDs obscure the short diagnostic viewport. Hide only fixture
	# overlays, retaining the actual player/camera/animation and separate caption.
	for hud: Node in fixture.player.find_children("*", "CanvasLayer", true, false): hud.visible = false
	Input.action_press("move_forward")
	await _phase("up + fall", 3.2)
	Input.action_release("move_forward")
	_check(fixture.point(fixture.player).x > 10.0, "Complete stairs not crossed")
	await _phase("land", 0.7)
	_check(fixture.player.is_on_floor(), "Fall did not land")
	Input.action_press("jump")
	await _phase("jump", 0.12)
	Input.action_release("jump")
	await _phase("jump + land", 1.0)
	fixture.put_on_plateau()
	await _phase("plateau settle", 0.5)
	Input.action_press("move_back")
	await _phase("down", 2.4)
	Input.action_release("move_back")
	await _phase("settle after down", 0.7)
	_check(fixture.point(fixture.player).x < 1 and fixture.player.is_on_floor(), "Descent not grounded below stairs")
	var before: Vector3 = fixture.point(fixture.player.camera)
	fixture.shift_origin()
	_check(fixture.point(fixture.player.camera).distance_to(before) < 0.0001, "Origin shift moved view")
	await _phase("rebase + settle", 0.7)
	_check(absf(fixture.player._camera_step_offset) < 0.002, "Residual camera offset")
	for index in range(1, fixture.rows.size()):
		var previous: Dictionary = fixture.rows[index - 1]
		var row: Dictionary = fixture.rows[index]
		if row.phase == "rebase + settle":
			_check(Vector3(row.camera[0], row.camera[1], row.camera[2]).distance_to(Vector3(previous.camera[0], previous.camera[1], previous.camera[2])) < 0.01, "Origin shift extended the collision camera on a following physics tick")
	var report := {"passed": failures.is_empty(), "failures": failures, "cap_fps": cap, "physics_hz": Engine.physics_ticks_per_second,
		"visual_body_scale": body_scale, "diagonal": diagonal, "fixture": "physical tangent-plane boxes; active spherical controller + radial adapter",
		"collision": "unchanged production capsule; only authored visual size varied", "seed": 15838, "move_speed_m_s": fixture.player.move_speed,
		"rows": fixture.rows, "render_frames": frames, "native_render_frames": fixture.render_rows}
	var file := FileAccess.open(output.path_join("trace.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	for message in failures: push_error(message)
	print("R32_03_CAMERA_RESULT ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "frames": frames.size(), "ticks": fixture.rows.size()}))
	fixture.close()
	await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _phase(name_value: String, seconds: float) -> void:
	fixture.phase = name_value
	var end: float = fixture.elapsed + seconds
	while fixture.elapsed < end:
		await process_frame
		root.content_scale_size = Vector2i.ZERO
		root.content_scale_factor = 1.0
		_hide_layers(fixture, caption.get_parent())
		caption.position = Vector2(10, 10)
		var body: Vector3 = fixture.point(fixture.player)
		var pivot: Vector3 = fixture.point(fixture.player.camera_pivot)
		caption.text = "%d FPS cap | %.2fx body | %s | %s\nBODY %.3f | TARGET %.3f | FLOOR %s | OFFSET %.3f" % [cap, body_scale, "diagonal" if diagonal else "straight", name_value, body.y, pivot.y, fixture.player.is_on_floor(), fixture.player._camera_step_offset]
		await RenderingServer.frame_post_draw
		var wall: int = Time.get_ticks_usec()
		root.get_texture().get_image().save_png(output.path_join("frame_%05d.png" % frames.size()))
		frames.append({"frame": frames.size(), "wall_us": wall, "physics_time_s": fixture.elapsed, "phase": name_value,
			"body": fixture._vec(fixture.point(fixture.player)), "pivot": fixture._vec(fixture.point(fixture.player.camera_pivot)),
			"camera": fixture._vec(fixture.point(fixture.player.camera)), "floor": fixture.player.is_on_floor(), "offset_m": fixture.player._camera_step_offset})

func _hide_layers(node: Node, kept: Node) -> void:
	if node is CanvasLayer and node != kept: node.hide()
	for child: Node in node.get_children(): _hide_layers(child, kept)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
