extends SceneTree
## Real render acceptance and regressions for this presentation-only package.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
var failures: Array[String] = []
var output: String = ""
var scene: Node3D
var player: Node3D
var journal: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		output = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://visual_refresh.json"
	var state := root.get_node("GameState")
	state.start_world_with_seed(15838)
	var progression := root.get_node("ProgressionService")
	progression.reset_for_new_game()
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("a3bdce")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -28, 0)
	scene.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(30, 0.1, 30)
	floor_mesh.mesh = floor_box
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("526a4c")
	floor_mesh.material_override = material
	scene.add_child(floor_mesh)
	player = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 0.1, 5)
	scene.add_child(player)
	player.set_physics_process(false)
	await _frames(4)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var camera: Camera3D = player._gameplay_camera
	camera.global_position = Vector3(3, 2.3, 5)
	camera.look_at(Vector3(0, 0.5, 0))
	var bush_scene := load("res://world/resources/plants/berry_bush.tscn") as PackedScene
	var bushes: Array[Node3D] = []
	for i in range(3):
		var bush: Node3D = bush_scene.instantiate()
		bush.snap_to_terrain = false
		bush.position = Vector3(float(i - 1) * 2, 0, 0)
		scene.add_child(bush)
		bushes.append(bush)
	await _frames(5)
	var full_bounds: AABB = bushes[1].bush_mesh.mesh.get_aabb()
	var full_collision: Vector3 = bushes[1].bush_collision.shape.size
	bushes[1].is_depleted = true
	bushes[1]._generate_bush()
	_expect(bushes[1].bush_collision.shape.size == full_collision, "Harvest changed bush collision.")
	bushes[1].is_depleted = false
	bushes[1]._generate_bush()
	_expect(bushes[1].bush_mesh.mesh.get_aabb() == full_bounds, "Bush visual does not reproduce with same seed.")
	# Player survival continues to use controller-owned original bars.
	player.set_physics_process(true)
	player.fall_acceleration = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _frames(3)
	await _capture("hud_berries.png")
	var vitals: Control = player.find_child("CompactVitals", true, false)
	_expect(vitals != null and vitals.size.x < 340 and vitals.size.y < 140, "Survival HUD is not compact.")
	var context: Node = player.get_node("ContextActionHUD")
	var wildlife: Node3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
	wildlife.configure(2771337, 911227, Vector2i.ZERO, "forager")
	scene.add_child(wildlife)
	wildlife.set_physics_process(false)
	context._show_wildlife_context(wildlife)
	_expect(not context._label.visible, "Living species name is exposed outside scan mode.")
	wildlife.queue_free()
	journal = player.find_child("DiscoveryJournal", true, false)
	for role in ["grazer", "predator", "forager"]:
		var blueprint: Dictionary = Species.create_species(771337 + role.length(), Vector2i(1, -2), role)
		progression.register_species_discovery(771337 + role.length(), blueprint, 15838)
	var before: Dictionary = progression.export_state()
	journal.open_journal()
	await _frames(24)
	await _capture("journal_species.png")
	journal._tabs.current_tab = 1
	await _frames(80)
	await _capture("journal_parts.png")
	journal._status.select(2)
	journal._status.item_selected.emit(2)
	await _frames(40)
	await _capture("journal_locked.png")
	# Check every catalog part produces a real model, including terminal pieces.
	for category in Parts.get_categories():
		for part in Parts.get_parts_for_category(category["id"]):
			journal._preview.show_part(part["id"], false)
			_expect(_mesh_count(journal._preview._model) > 0, "Missing model: " + part["id"])
			_expect(_all_silhouette(journal._preview._model), "Locked part reveals colors: " + part["id"])
	journal._select_entry(0)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(800, 600)
	await _frames(8)
	await _capture("journal_800x600.png")
	print("LAYOUT: ", root.get_visible_rect(), " content ", journal._content.get_global_rect(), " detail ", journal._detail_scroll.get_global_rect())
	_expect(journal._detail_scroll.size.y >= 200, "Small landscape journal leaves too little space for details.")
	_expect(journal._detail_scroll.get_global_rect().end.y <= 600, "Small journal exceeds viewport.")
	_expect(progression.export_state() == before, "Presentation changes saved discoveries.")
	journal.close_journal()
	await _frames(4)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var skills: CanvasLayer = player.find_child("PlayerProgression", true, false)
	skills.open_panel()
	await _frames(6)
	await _capture("skills.png")
	skills._show_development()
	await _frames(6)
	await _capture("development.png")
	skills.close_panel()
	await _frames(4)
	scene.queue_free()
	await _frames(3)
	var editor: Node3D = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await _frames(5)
	editor._set_mode("parts")
	editor._on_category_button_pressed("mouth")
	await _frames(8)
	await _capture("editor_parts.png")
	var yaw_before: float = editor._preview_pivot.rotation.y
	editor._orbiting = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 0)
	editor.handle_canvas_input(motion)
	_expect(editor._preview_pivot.rotation.y > yaw_before, "Dragging right rotates editor the wrong way.")
	editor._orbiting = false
	editor.queue_free()
	await _frames(3)
	for failure in failures: push_error(failure)
	print("VISUAL_REFRESH_OK" if failures.is_empty() else "VISUAL_REFRESH_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _mesh_count(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child in node.get_children(): count += _mesh_count(child)
	return count

func _all_silhouette(node: Node) -> bool:
	if node is MeshInstance3D:
		if node.material_override.albedo_color != Color("080f18"): return false
	for child in node.get_children():
		if not _all_silhouette(child): return false
	return true

func _capture(filename: String) -> void:
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(filename))

func _frames(count: int) -> void:
	for i in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
