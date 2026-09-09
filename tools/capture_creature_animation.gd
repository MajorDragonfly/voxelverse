extends SceneTree
## Deterministic real-renderer review of the live (not random-access) animator.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
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
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("345747")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var actors: Array[Preview] = []
	var mounts: Array[Node3D] = []
	for pairs in [1, 2, 3]:
		var design: Dictionary = Assembly.create_default()
		for index in range(pairs - 1):
			Assembly.BaseBlueprint.add_part(design, "legs_walker")
		Assembly.BaseBlueprint.add_part(design, "tail_balance")
		Anatomy.reset_all_anchors(design)
		design["appearance"] = {"base_color": ["89bfa0", "bdaf89", "8faac7"][pairs - 1], "accent_color": "30566c"}
		var mount := Node3D.new()
		mount.position.x = (pairs - 2) * 4.2
		stage.add_child(mount)
		var actor := Preview.new()
		mount.add_child(actor)
		actor.set_editor_state(design, -1, -1, false)
		actor.position.y = -float(actor.get_meta("ground_y"))
		actor.set_motion("idle")
		actor.set_process(false)
		actors.append(actor)
		mounts.append(mount)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5.8, 4.2, 11)
	camera.look_at(Vector3(0, 0.9, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	var label := Label.new()
	label.position = Vector2(26, 24)
	label.add_theme_font_size_override("font_size", 26)
	root.add_child(label)
	for frame in range(210):
		var mode: String = "idle" if frame < 20 or frame >= 150 else "walk" if frame < 80 else "run"
		label.text = "Voxelverse · 2 / 4 / 6 Beine · " + {"idle": "Stehen", "walk": "Gehen", "run": "Rennen"}[mode]
		for index in range(actors.size()):
			actors[index].set_motion(mode)
			actors[index].set_process(false)
			actors[index]._process(1.0 / 30.0)
			var target: float = 0.7 if frame >= 90 and frame < 150 else -0.4
			mounts[index].rotation.y = lerp_angle(mounts[index].rotation.y, target, 1.0 - exp(-4.5 / 30.0))
		await process_frame
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		if capture.save_png(output.path_join("frame_%03d.png" % frame)) != OK:
			push_error("Animation capture failed")
			quit(1)
			return
	stage.free()
	label.free()
	print("CREATURE_ANIMATION_RENDER_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
