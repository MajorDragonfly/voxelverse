extends SceneTree

const Templates = preload("res://civilization/buildings/templates/building_templates.gd")
const Picker = preload("res://civilization/buildings/templates/building_template_picker.gd")
const Selection = preload("res://civilization/buildings/templates/building_template_selection.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const Parts = preload("res://civilization/buildings/building_part_library.gd")
const Assembly = preload("res://assembly/core/modular_assembly.gd")
const MeshBuilder = preload("res://assembly/runtime/modular_voxel_mesh_builder.gd")
const Visual = preload("res://civilization/buildings/building_runtime_visual.gd")
const TEST_DIR: String = "user://int30_building_templates"

var _failures: Array[String] = []
var _checks: int = 0
var _translations: Array[Translation] = []
var _capture: String = ""
var _report: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var capture_index: int = arguments.find("--capture")
	if capture_index >= 0 and arguments.size() > capture_index + 1:
		_capture = arguments[capture_index + 1]
	print("INT30_STAGE start")
	_install_translations()
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600, 1000)
	TranslationServer.set_locale("en")
	if arguments.has("--restart"):
		_test_restart()
	else:
		await _test_templates()
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	await process_frame
	print(JSON.stringify({"test": "int30_building_templates", "passed": _failures.is_empty(), "checks": _checks, "failures": _failures, "designs": _report, "restart": arguments.has("--restart")}))
	quit(0 if _failures.is_empty() else 1)


func _test_templates() -> void:
	var before: Dictionary = Blueprint.Store.capture()
	var entries: Array[Dictionary] = Templates.list_templates()
	_expect(entries.size() == 3, "Exactly three valid templates are required")
	_expect(Templates.load_template("missing").is_empty(), "Unknown template must fail closed")
	_expect(Templates.create_copy("../../outside").is_empty(), "Path input must not become a template")
	_expect(Blueprint.Store.capture() == before, "Browsing modified campaign designs")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var restart_manifest: Array[Dictionary] = []
	var source_ids: Dictionary = {}
	for entry in entries:
		print("INT30_STAGE template ", entry.id)
		var source_path: String = Templates.DIRECTORY + str(entry.path)
		var original_text: String = FileAccess.get_file_as_string(source_path)
		var raw: Dictionary = JSON.parse_string(original_text)
		var design: Dictionary = Templates.load_template(str(entry.id))
		_expect(not source_ids.has(design.design_id), "Template identities collided")
		source_ids[design.design_id] = true
		_expect(design == Templates.load_template(str(entry.id)), "Repeated loads are not deterministic")
		_expect(Blueprint.validate(raw).is_empty() and Blueprint.validate(design).is_empty(), "Raw and loaded template must validate")
		_expect(int(design.revision) == 1, "First template release must be revision 1")
		_expect(design.parts.size() <= 32, "Template exceeds bounded authoring budget")
		_check_geometry(raw, design)
		var stats: Dictionary = _independent_stats(design)
		_expect(stats == Blueprint.calculate_stats(design), "Stats are not exactly catalog-derived")
		_expect(not stats.has("storage"), "A storage capacity must not be invented")
		var scaled: Dictionary = design.duplicate(true)
		scaled.parts[0].scale *= 1.25
		_expect(Blueprint.calculate_stats(scaled) == stats, "Scale must not multiply catalog stats")
		var serialized: Dictionary = Assembly.serialize(design)
		var roundtrip: Dictionary = Assembly.deserialize(JSON.parse_string(JSON.stringify(serialized)))
		_expect(_same_data(Assembly.serialize(roundtrip), serialized), "Serialization changed template transforms or IDs")
		var a: Dictionary = Templates.create_copy(str(entry.id))
		var b: Dictionary = Templates.create_copy(str(entry.id))
		_expect(a.design_id != b.design_id and a.design_id != design.design_id, "Copies need independent identities")
		_expect(a.revision == 0 and a.metadata.source_template.revision == 1, "Copy revision/provenance is wrong")
		_expect(a.name != b.name, "Default editor filenames must differ for separate copies")
		for index in range(a.parts.size()):
			_expect(a.parts[index].uid != b.parts[index].uid and a.parts[index].uid != design.parts[index].uid, "Copy part identity leaked")
			for field in ["position", "rotation", "scale", "part_id"]:
				_expect(a.parts[index][field] == design.parts[index][field], "Copy changed " + field)
		a.metadata.source_template["revision"] = 99
		a.parts[0].position += Vector3.UP
		_expect(Templates.load_template(str(entry.id)) == design and b.parts[0].position == design.parts[0].position, "Copy mutation leaked into source or sibling")
		_expect(Templates.save_copy(design).error == ERR_INVALID_DATA, "Source template was accepted as an owned copy")
		var reserved: Dictionary = Templates.create_copy(str(entry.id))
		var reserved_path: String = Blueprint.DESIGN_DIR + "/" + str(reserved.design_id) + ".json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Blueprint.DESIGN_DIR))
		var protected := FileAccess.open(reserved_path, FileAccess.WRITE)
		protected.store_string('{"schema":999,"sentinel":"preserve"}')
		protected.close()
		_expect(Templates.save_copy(reserved).error == ERR_ALREADY_EXISTS, "Existing future-version original was not preserved")
		_expect(FileAccess.get_file_as_string(reserved_path).contains("sentinel"), "Protected original was overwritten")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(reserved_path))
		var state: Dictionary = await _test_editor(entry, design)
		if not state.is_empty():
			var reload_path: String = TEST_DIR + "/" + str(entry.id).get_slice(".", 2) + ".json"
			_expect(Blueprint.save_to_file(state, reload_path) == OK, "Restart fixture write failed")
			restart_manifest.append({"path": reload_path, "serialized_hash": _serialized_hash(state), "stats": Blueprint.calculate_stats(state)})
		if not _capture.is_empty():
			await _capture_views(entry, design)
		_expect(FileAccess.get_file_as_string(source_path) == original_text, "Built-in source file changed")
		_report.append({"id": entry.id, "design_id": design.design_id, "revision": design.revision, "parts": design.parts.size(), "stats": stats, "source_sha256": original_text.sha256_text()})
	var manifest_file := FileAccess.open(TEST_DIR + "/restart.json", FileAccess.WRITE)
	manifest_file.store_string(JSON.stringify(restart_manifest))
	manifest_file.close()
	_test_restart()


func _check_geometry(raw: Dictionary, design: Dictionary) -> void:
	var boxes_by_part: Array[Array] = []
	var bounds := AABB()
	var first: bool = true
	for index in range(design.parts.size()):
		var placement: Dictionary = design.parts[index]
		for field in ["position", "rotation", "scale"]:
			var raw_vector: Array = raw.parts[index][field]
			_expect(placement[field].is_equal_approx(Vector3(raw_vector[0], raw_vector[1], raw_vector[2])), "Normalization changed stored " + field)
		var scale: Vector3 = placement.scale
		_expect(scale.x > 0 and scale.y > 0 and scale.z > 0, "Invalid geometric scale")
		var basis := Basis.from_euler(placement.rotation * PI / 180.0)
		var part_boxes: Array[AABB] = []
		for primitive in Parts.get_part(str(placement.part_id)).geometry:
			var size: Vector3 = primitive.size * scale
			var center: Vector3 = primitive.position * scale
			var box: AABB = Transform3D(basis, placement.position) * AABB(center - size / 2, size)
			part_boxes.append(box)
			bounds = box if first else bounds.merge(box)
			first = false
		boxes_by_part.append(part_boxes)
	_expect(bounds.position.y >= -0.001, "Geometry extends below ground")
	var mesh: ArrayMesh = MeshBuilder.build_mesh(design, Parts.get_all_parts())
	_expect(mesh.get_surface_count() == 1, "Template must use the existing merged mesh path")
	_expect(mesh.get_aabb().position.is_equal_approx(bounds.position) and mesh.get_aabb().size.is_equal_approx(bounds.size), "Rendered bounds disagree with transformed catalog geometry")
	var reached: Dictionary = {0: true}
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var parent: int = pending.pop_front()
		for candidate in range(boxes_by_part.size()):
			if reached.has(candidate):
				continue
			var touches: bool = false
			for a: AABB in boxes_by_part[parent]:
				for b: AABB in boxes_by_part[candidate]:
					if a.grow(0.001).intersects(b):
						touches = true
			if touches:
				reached[candidate] = true
				pending.append(candidate)
	_expect(reached.size() == design.parts.size(), "Floating/disconnected part in " + str(design.name))


func _test_editor(entry: Dictionary, source: Dictionary) -> Dictionary:
	var scene := load("res://civilization/buildings/building_builder.tscn") as PackedScene
	var builder: Node3D = scene.instantiate()
	root.add_child(builder)
	await process_frame
	# Same front-facing authoring camera for all three template captures.
	builder.set("_camera_yaw", deg_to_rad(-145.0))
	var original: Dictionary = builder.get("blueprint").duplicate(true)
	var picker := Picker.new()
	var parent: Node = (builder.get("_design_option") as OptionButton).get_parent()
	parent.add_child(picker)
	parent.move_child(picker, 0)
	picker.template_chosen.connect(func(copy: Dictionary): Selection.apply_to_editor(builder, copy))
	_expect(picker.select_template(str(entry.id)), "Template picker selection failed")
	await process_frame
	await process_frame
	_expect(picker.details.text.contains(str(entry.id)) and not picker.use_button.disabled, "Picker lacks source/revision details")
	_expect(builder.get("blueprint") == original, "Selection without use replaced editor design")
	print("INT30_STAGE use-copy")
	await _click(picker.use_button)
	var copy: Dictionary = builder.get("blueprint")
	_expect(copy.get("design_id") != source.design_id and copy.get("metadata", {}).has("source_template"), "Real use-copy click failed")
	_expect(copy.parts.size() == source.parts.size(), "Editor opening lost template parts")
	var copy_identity: String = str(copy.get("design_id", ""))
	builder.call("_undo")
	_expect(_same_data(Assembly.serialize(builder.get("blueprint")), Assembly.serialize(original)), "Undo template use did not restore the prior editor design")
	builder.call("_redo")
	copy = builder.get("blueprint")
	_expect(str(copy.get("design_id", "")) == copy_identity, "Redo template use changed the copy identity")
	if not _capture.is_empty():
		await _screenshot(str(entry.id).get_slice(".", 2) + "-editor-open")
	print("INT30_STAGE editing")
	builder.call("_select_part", 4)
	var placement: Dictionary = copy.parts[4].duplicate(true)
	root.gui_release_focus()
	await _key(KEY_RIGHT)
	await _key(KEY_E)
	await _key(KEY_BRACKETRIGHT)
	copy = builder.get("blueprint")
	_expect(copy.parts[4].position.is_equal_approx(placement.position + Vector3(.25, 0, 0)), "Real key edit did not move part")
	_expect(copy.parts[4].rotation.is_equal_approx(placement.rotation + Vector3(0, 15, 0)), "Real key edit did not rotate part")
	_expect(copy.parts[4].scale.is_equal_approx(placement.scale * 1.08), "Real key edit did not scale part")
	builder.call("_undo")
	_expect(builder.get("blueprint").parts[4].scale.is_equal_approx(placement.scale), "Undo failed after template use")
	builder.call("_redo")
	copy = builder.get("blueprint")
	print("INT30_STAGE save")
	var result: Dictionary = Templates.save_copy(copy)
	_expect(result.error == OK and int(copy.revision) == 1, "Saving owned copy did not create revision 1")
	if result.error == OK:
		print("INT30_STAGE reload")
		var expected: Dictionary = Assembly.serialize(copy)
		var loaded: Dictionary = Blueprint.load_from_file(str(result.path))
		_expect(_same_data(Assembly.serialize(loaded), expected), "Saved copy load lost transforms/provenance/IDs")
		var stored_text: String = Blueprint.Store.read_text(str(result.path))
		_expect(Templates.save_copy(copy).error == ERR_INVALID_DATA, "Repeated save-copy overwrote a revision")
		_expect(Blueprint.Store.read_text(str(result.path)) == stored_text, "Repeated save-copy modified saved original")
		builder.call("_new_building")
		var options: OptionButton = builder.get("_design_option")
		var found: bool = false
		for index in range(options.item_count):
			if str(options.get_item_metadata(index)) == str(result.path).get_file():
				options.select(index)
				found = true
		_expect(found, "Saved template copy missing from existing design picker")
		builder.call("_load_selected_design")
		_expect(_same_data(Assembly.serialize(builder.get("blueprint")), expected), "Existing editor reload failed")
		TranslationServer.set_locale("de")
		await process_frame
		_expect(picker.use_button.text == "Als eigene Kopie verwenden", "DE picker labels missing")
		_expect(picker.details.text.contains("Revision 1 ·"), "Language switch lost integer revision")
		var scroll: Control = parent.get_parent()
		_expect(picker.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1, "Template picker overflows the visible editor sidebar")
		if not _capture.is_empty():
			await _screenshot(str(entry.id).get_slice(".", 2) + "-editor-edited-reload-de")
		TranslationServer.set_locale("en")
		await process_frame
		copy = builder.get("blueprint").duplicate(true)
	builder.queue_free()
	await process_frame
	await process_frame
	return copy


func _test_restart() -> void:
	var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR + "/restart.json"))
	_expect(records is Array and records.size() == 3, "Restart fixture must contain three designs")
	if not records is Array:
		return
	for record in records:
		var loaded: Dictionary = Blueprint.load_from_file(str(record.path))
		_expect(not loaded.is_empty(), "Restart could not load owned design")
		_expect(_serialized_hash(loaded) == record.serialized_hash, "Restart changed serialized transforms or identities")
		_expect(Blueprint.calculate_stats(loaded) == record.stats, "Restart changed catalog stats")


func _independent_stats(design: Dictionary) -> Dictionary:
	var result: Dictionary = {"cost": 0.0, "housing": 0.0, "commerce": 0.0, "industry": 0.0, "defense": 0.0, "prestige": 0.0, "energy": 0.0, "pollution": 0.0}
	for placement in design.parts:
		for key in Parts.get_part(str(placement.part_id)).stats:
			result[key] += float(Parts.get_part(str(placement.part_id)).stats[key])
	return result


func _capture_views(entry: Dictionary, design: Dictionary) -> void:
	var world := Node3D.new()
	root.add_child(world)
	var visual := Visual.new()
	visual.set_blueprint(design)
	world.add_child(visual)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(.08, .10, .13)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.78, .82, .9)
	settings.ambient_light_energy = .65
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.18, .23, .22)
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var camera := Camera3D.new()
	camera.fov = 45
	camera.current = true
	world.add_child(camera)
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var label := Label.new()
	label.position = Vector2(28, 22)
	label.add_theme_font_size_override("font_size", 24)
	layer.add_child(label)
	var directions: Array[Vector3] = [Vector3(-10, 8, -13), Vector3(10, 8, 13), Vector3(0, 18, .1)]
	var view_names: Array[String] = ["front", "rear", "top"]
	for index in range(directions.size()):
		camera.position = directions[index] + Vector3(0, 1.5, 0)
		camera.look_at(Vector3(0, 1.5, 0))
		label.text = str(design.name) + " · " + str(entry.id) + " · r1 · " + view_names[index]
		await _screenshot(str(entry.id).get_slice(".", 2) + "-" + view_names[index])
	world.queue_free()
	await process_frame
	await process_frame


func _screenshot(name_value: String) -> void:
	print("INT30_STAGE capture ", name_value)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(_capture.path_join(name_value + ".png")) == OK, "Capture failed: " + name_value)
	# Return to the next frame before editing scene meshes after readback.
	await process_frame


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _install_translations() -> void:
	# Exact proposed append, without altering the shared localization catalog.
	var append: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/int30-building-templates/integration/localization.append.json"))
	for locale in ["de", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		for key in append:
			translation.add_message(key, str(append[key][locale]))
		TranslationServer.add_translation(translation)
		_translations.append(translation)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _same_data(a: Dictionary, b: Dictionary) -> bool:
	# JSON numbers have no int/float distinction; compare in the persisted domain.
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func _serialized_hash(design: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(Assembly.serialize(design)))).sha256_text()
