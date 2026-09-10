extends SceneTree
## Native renderer comparison of the existing work animal and the additive egg body.
const Generator = preload("res://world/fauna/domestication/domestic_species_generator.gd")
const Traits = preload("res://world/fauna/domestication/domestication_contract.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = root.size
	root.content_scale_factor = 1.0
	root.get_node("SaveGameService").autosave_enabled = false
	var stage := Node3D.new()
	root.add_child(stage); current_scene = stage
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("18252b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6dce3")
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.position = Vector3(0, 3.5, 10)
	camera.look_at(Vector3(0, 0.6, 0)); camera.current = true
	for index in range(2):
		var entry: Dictionary = Generator.create({"id": "arch21-preview", "seed": 15838}, "work" if index == 0 else "eggs", 4000000015838 + index)
		var preview := Preview.new()
		stage.add_child(preview)
		preview.set_editor_state(Traits.decode(entry.blueprint), -1, -1, false)
		preview.set_motion("edit")
		preview.position = Vector3(-2.0 if index == 0 else 2.0, 0.15, 0)
		preview.rotation_degrees.y = -35
		var label := Label.new()
		label.text = "Bestehende Arbeitsart · 4 Beine" if index == 0 else "Neue Eierart · 2 Beine"
		label.add_theme_font_size_override("font_size", 26)
		label.position = Vector2(65 if index == 0 else 665, 575)
		root.add_child(label)
	var title := Label.new()
	title.text = "Voxelverse · ARCH-21"
	title.add_theme_font_size_override("font_size", 32)
	title.position = Vector2(48, 30)
	root.add_child(title)
	var note := Label.new()
	note.text = "Gemeinsamer Kreaturenrenderer · vorhandene Standfüße · keine neue Reitfähigkeit"
	note.add_theme_font_size_override("font_size", 18)
	note.position = Vector2(48, 650)
	root.add_child(note)
	for frame in range(12): await process_frame
	# DisplaySettings applies saved defaults on a deferred startup callback.
	# Fix this diagnostic capture's canvas after that callback has completed.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i(1200, 720)
	root.content_scale_factor = 1.0
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_cmdline_user_args()[0]
	root.get_texture().get_image().save_png(output)
	print("ARCH21_PREVIEW ", output)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
