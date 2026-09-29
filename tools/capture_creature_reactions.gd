extends SceneTree
## Renderer evidence of the production motion/pose path with the AI intent contract.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
const INTENTS: Array[String] = ["rest", "social", "flee", "eat", "drink", "play_greet", "play_play", "play_rest"]
const LABELS: Array[String] = ["Ruhe", "Neugier", "Gefahr", "Fressen", "Trinken", "Begruessung", "Sozialspiel", "Ausruhen"]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("output path and baseline/candidate required")
		quit(1)
		return
	var output: String = args[0]
	var candidate: bool = args[1] == "candidate"
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(960, 540)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("102831")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7dce0")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.1
	stage.add_child(light)
	var plane := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	plane.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("345747")
	plane.material_override = floor_mat
	stage.add_child(plane)
	var actors: Array[Preview] = []
	var emotions: Array[RefCounted] = []
	for pairs in [1, 2, 3]:
		var design: Dictionary = Assembly.create_default()
		for index in range(pairs - 1): Assembly.BaseBlueprint.add_part(design, "legs_walker")
		for id: String in ["tail_balance", "eyes_stalks", "mouth_crocodile_snout"]:
			Assembly.BaseBlueprint.add_part(design, id)
		Anatomy.reset_all_anchors(design)
		design["appearance"] = {"base_color": ["89bfa0", "bdaf89", "8faac7"][pairs - 1], "accent_color": "30566c"}
		var mount := Node3D.new()
		mount.position.x = (pairs - 2) * 3.8
		stage.add_child(mount)
		var actor := Preview.new()
		mount.add_child(actor)
		actor.set_editor_state(design, -1, -1, false)
		actor.position.y = -float(actor.get_meta("ground_y"))
		actor.set_motion("idle")
		actor.set_process(false)
		actors.append(actor)
		var emotion := Emotion.new()
		emotion.configure(40 + pairs)
		emotions.append(emotion)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5.8, 3.9, 10.4)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	var title := Label.new()
	title.position = Vector2(20, 18)
	title.add_theme_font_size_override("font_size", 23)
	root.add_child(title)
	var times: Array[float] = []
	var draw_calls: Array[int] = []
	for frame in range(120):
		var phase: int = frame / 15
		var intent: String = INTENTS[phase]
		title.text = "Voxelverse · 2 / 4 / 6 Beine · " + LABELS[phase]
		var start: int = Time.get_ticks_usec()
		for index in range(actors.size()):
			var mode: String = "run" if intent == "flee" else "walk" if intent in ["social", "play_play"] else "idle"
			actors[index].set_motion(mode)
			actors[index].set_process(false)
			if candidate:
				actors[index].set_expression_pose(emotions[index].advance(1.0 / 30.0,
					{"intent": intent, "look_yaw": 0.22 if intent.begins_with("play_") else 0.0}))
			actors[index]._process(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
		draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if candidate:
			if root.get_texture().get_image().save_png(output.path_join("frame_%03d.png" % frame)) != OK:
				push_error("Animation capture failed")
				quit(1)
				return
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"candidate": candidate, "frame_ms": times, "draw_calls": draw_calls, "intents": INTENTS}))
	file.close()
	stage.free()
	title.free()
	print("CREATURE_REACTIONS_CAPTURE_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
