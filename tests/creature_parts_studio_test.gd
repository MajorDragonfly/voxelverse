extends SceneTree
## Behavioral acceptance: authored transforms, true pairs, shared soles,
## per-foot terrain contact, cosmetic surfaces and the actual editor controls.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Blueprint = Assembly.BaseBlueprint
const Library = Blueprint.PartLibrary
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Sockets = preload("res://creatures/editor/creature_surface_sockets_v7.gd")
const Spine = preload("res://creatures/editor/creature_spine_profile.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_catalog_and_pairs()
	_check_skin_and_storage()
	for count: int in [1, 2, 3]:
		_check_stance(count)
	await _check_terrain()
	await _check_wildlife()
	await _check_editor()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("Creature parts studio passed: 29 part recipes, 7 end pieces, XYZ controls, undo, mirrored spikes, center sockets, 2/4/6-leg soles, terrain IK, wildlife floor alignment, cosmetic skins and save roundtrip.")
	quit(0 if failures.is_empty() else 1)


func _make_preview(blueprint: Dictionary) -> Preview:
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(blueprint, -1, -1, false)
	return preview


func _part_roots(preview: Node3D, index: int) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in preview.get_children():
		if child is Node3D and int(child.get_meta("creature_part_index", -1)) == index:
			result.append(child)
	return result


func _check_catalog_and_pairs() -> void:
	var count: int = 0
	for category in ["mouth", "eyes", "legs", "arms", "tail", "horns", "plates", "spikes", "decor"]:
		for definition: Dictionary in Library.get_parts_for_category(category):
			var blueprint: Dictionary = Assembly.create_default()
			blueprint["parts"] = []
			Blueprint.add_part(blueprint, definition["id"])
			Anatomy.reset_all_anchors(blueprint)
			var preview := _make_preview(blueprint)
			var parts: Array[Node3D] = _part_roots(preview, 0)
			_expect(not parts.is_empty(), "Catalog part missing: " + str(definition["id"]))
			for part in parts:
				_expect(not part.find_children("*", "MeshInstance3D", true, false).is_empty(), "Empty geometry recipe: " + str(definition["id"]))
				for mesh: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
					_expect(mesh.mesh is ArrayMesh, "Non-voxel detail in " + str(definition["id"]))
			preview.free()
			count += 1
	_expect(count == 29 and Library.get_terminal_parts().size() == 7, "Part or end-piece catalog incomplete.")
	var blueprint: Dictionary = Assembly.create_default()
	var index: int = Blueprint.add_part(blueprint, "spikes_side")
	Anatomy.reset_all_anchors(blueprint)
	Sockets.apply_symmetry(blueprint, index, true)
	blueprint["parts"][index]["rotation"] = Vector3(18, 32, -24)
	var preview := _make_preview(blueprint)
	var pair: Array[Node3D] = _part_roots(preview, index)
	_expect(pair.size() == 2 and pair[0].position.x > 0.05, "Spikes do not form two separate sides.")
	if pair.size() == 2:
		var a: MeshInstance3D = pair[0].get_node("Spike1")
		var b: MeshInstance3D = pair[1].get_node("Spike1")
		for endpoint: float in [-0.5, 0.5]:
			var point: Vector3 = a.to_global(Vector3.UP * endpoint * a.mesh.get_aabb().size.y)
			var reflected: Vector3 = b.to_global(Vector3.UP * endpoint * b.mesh.get_aabb().size.y)
			_expect((point * Vector3(-1, 1, 1)).distance_to(reflected) < 0.0001, "Rotated spike pair is not a geometric reflection.")
	preview.free()
	var part: Dictionary = blueprint["parts"][index]
	part["center_locked"] = true
	part["manual_offset"] = Vector3(0.2, 0, 0)
	Assembly.normalize(blueprint)
	Anatomy.rebind_part(blueprint, index)
	Spine.set_segment(blueprint, 3, {"width_scale": 1.7, "y_offset": 0.5})
	preview = _make_preview(blueprint)
	var centered: Array[Node3D] = _part_roots(preview, index)
	_expect(centered.size() == 1 and is_zero_approx(centered[0].position.x), "Middle-axis attachment drifted or duplicated after shaping.")
	preview.free()


func _leg_design(pairs: int) -> Dictionary:
	var blueprint: Dictionary = Assembly.create_default()
	blueprint["parts"] = []
	for index in range(pairs):
		Blueprint.add_part(blueprint, ["legs_walker", "legs_stubby", "legs_spider"][index])
	Anatomy.reset_all_anchors(blueprint)
	Spine.set_segment(blueprint, 2, {"y_offset": 0.5, "height_scale": 0.7})
	for index in range(pairs):
		var part: Dictionary = blueprint["parts"][index]
		part["anchor_t"] = 0.25 + float(index) * 0.23
		part["anchor_vertical"] = -0.15 - float(index) * 0.25
		part["scale"] = 0.7 + float(index) * 0.3
		part["rotation"] = Vector3(10.0 * index, 12.0 * index, -8.0 * index)
		part["end_part_id"] = ["feet_pads", "feet_hooves", "feet_claws"][index]
	Anatomy.rebind_all_parts(blueprint)
	return blueprint


func _check_stance(pairs: int) -> void:
	var blueprint: Dictionary = _leg_design(pairs)
	var preview := _make_preview(blueprint)
	var ground: float = preview.get_meta("ground_y")
	var contacts: Array[Node] = preview.find_children("RuntimeFootContact", "Marker3D", true, false)
	_expect(contacts.size() == pairs * 2, "A limb end lost its foot contact.")
	for foot: Node3D in contacts:
		_expect(absf(foot.global_position.y - ground) < 0.0001, "Unequal leg heights left a sole above the floor.")
	var before: String = JSON.stringify(blueprint)
	for mode: String in ["idle", "walk", "run"]:
		preview.set_motion(mode)
		preview.set_process(false)
		for time: float in [0.0, 0.19, 0.47, 0.81]:
			preview._motion.sample(mode, time)
			var planted: int = 0
			for foot: Node3D in contacts:
				_expect(foot.global_position.is_finite() and foot.global_position.y >= ground - 0.0001, "Animated foot penetrated the floor.")
				if absf(foot.global_position.y - ground) < 0.0001:
					planted += 1
			_expect(planted >= (pairs * 2 if mode == "idle" else pairs), "Breathing or walking lifted the supporting feet.")
	preview.set_motion("edit")
	_expect(before == JSON.stringify(blueprint), "Posing rewrote the user's limb dimensions.")
	preview.free()


func _check_skin_and_storage() -> void:
	var first: ImageTexture = SkinStyle.texture("scales", 0.5)
	var second: ImageTexture = SkinStyle.texture("scales", 0.5)
	_expect(first == second, "Identical skin tiles were uploaded twice.")
	var reference: WeakRef = weakref(first)
	first = null
	second = null
	_expect(reference.get_ref() == null, "Unused skin texture remained resident after its owners were freed.")
	var blueprint: Dictionary = Assembly.create_default()
	var vertices: PackedVector3Array = Surface.build_skin(blueprint).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	var hashes: Array[int] = []
	for kind: String in SkinStyle.TYPES:
		blueprint["appearance"]["skin_type"] = kind
		var material: StandardMaterial3D = Surface.material(Color.WHITE, true, blueprint)
		_expect(Surface.build_skin(blueprint).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == vertices, "SkinStyle style added geometry.")
		_expect(Blueprint.calculate_stats(blueprint) == stats, "Cosmetic skin changed stats.")
		if kind != "smooth":
			_expect(material.albedo_texture != null and material.uv1_triplanar, "SkinStyle texture absent: " + kind)
			if material.albedo_texture != null:
				hashes.append(hash(material.albedo_texture.get_image().get_data()))
	var unique: Dictionary = {}
	for value: int in hashes:
		unique[value] = true
	_expect(hashes.size() == 4 and unique.size() == 4, "SkinStyle types share identical textures.")
	for end: Dictionary in Library.get_terminal_parts():
		var index: int = Blueprint.add_part(blueprint, "legs_walker" if end["category"] == "feet" else "arms_grasping")
		var part: Dictionary = blueprint["parts"][index]
		part["end_part_id"] = end["id"]
		part["rotation"] = Vector3(12, 35, -17)
		part["shape_scale"] = Vector3(1.4, 0.8, 1.2)
		part["end_rotation"] = Vector3(0, -23, 10)
		part["end_shape_scale"] = Vector3(0.8, 1.1, 1.4)
		part["end_scale"] = 1.35
	blueprint["appearance"].merge(SkinStyle.PALETTES[2], true)
	_expect(Assembly.save_to_file(blueprint, "user://parts_studio.json") == OK, "New fields could not be saved.")
	var loaded: Dictionary = Assembly.load_from_file("user://parts_studio.json")
	for index in range(4, blueprint["parts"].size()):
		for key: String in ["uid", "end_part_id", "rotation", "shape_scale", "end_rotation", "end_shape_scale", "end_scale"]:
			_expect(loaded["parts"][index][key] == blueprint["parts"][index][key], "Saved part setting was lost: " + key)
	_expect(loaded["appearance"] == blueprint["appearance"], "SkinStyle / color choices lost on reload.")
	loaded["parts"][0]["end_part_id"] = "feet_unknown"
	Assembly.normalize(loaded)
	_expect(str(loaded["parts"][0]["end_part_id"]).is_empty(), "Invalid terminal attached to an eye.")


func _check_terrain() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	collision.shape = box
	floor.position.y = -0.1
	floor.add_child(collision)
	root.add_child(floor)
	var player := CharacterBody3D.new()
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.1
	capsule.height = 0.4
	player_shape.shape = capsule
	player.add_child(player_shape)
	player.position.y = 0.21
	root.add_child(player)
	var preview := _make_preview(_leg_design(2))
	preview.position.y = -float(preview.get_meta("ground_y")) + 0.18
	for object: CollisionObject3D in preview.find_children("*", "CollisionObject3D", true, false):
		object.collision_layer = 0
	var animator := Animator.new()
	root.add_child(animator)
	animator._player = player
	animator._preview = preview
	for part in preview.get_children():
		if part is Node3D and part.has_meta("sculpt_limb_rig"):
			animator._leg_records.append(part.get_meta("sculpt_limb_rig"))
	for frame in range(4):
		await physics_frame
		player.velocity = Vector3.DOWN
		player.move_and_slide()
	_expect(player.is_on_floor(), "Terrain fixture did not reach the floor.")
	animator._solve_ground_contact(1.0 / 60.0)
	for record: Dictionary in animator._leg_records:
		_expect(absf(record["foot"].global_position.y) < 0.0002, "Terrain solver failed to ground an individual sole.")
	animator.free()
	preview.free()
	player.free()
	floor.free()


func _check_wildlife() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.2, 20)
	collision.shape = box
	floor.position.y = -0.1
	floor.add_child(collision)
	root.add_child(floor)
	for index in range(2):
		var wildlife: CharacterBody3D = load("res://creatures/wildlife/procedural_wildlife_v7.tscn").instantiate()
		wildlife.call("configure", 7 + index * 22, 91, Vector2i.ZERO, "grazer" if index == 0 else "predator")
		wildlife.set("visual_scale_min", 0.42 if index == 0 else 0.72)
		wildlife.set("visual_scale_max", wildlife.get("visual_scale_min"))
		wildlife.position = Vector3(2, 0.018, -3)
		wildlife.rotation.y = deg_to_rad(37)
		root.add_child(wildlife)
		wildlife.set_physics_process(false)
		var preview: Node3D = wildlife.get("_preview")
		preview.set_process(false)
		for frame in range(4):
			await physics_frame
			wildlife.velocity = Vector3.DOWN
			wildlife.move_and_slide()
		_expect(wildlife.is_on_floor(), "Wildlife fixture did not reach the physical floor.")
		# Arm end markers are not supporting feet. Generated species may
		# have hands as well as the required leg pair.
		var contacts: Array[Node3D] = []
		for part in preview.get_children():
			if part is Node3D and str(part.get_meta("creature_part_category", "")) == "legs" and part.has_meta("sculpt_limb_rig"):
				contacts.append(part.get_meta("sculpt_limb_rig")["foot"])
		_expect(contacts.size() >= 2, "Wildlife lost its generated leg pair.")
		var motion: RefCounted = preview.get("_motion")
		for time: float in [0.0, 0.47]:
			motion.call("sample", "idle", time)
			for foot: Node3D in contacts:
				_expect(foot.global_position.y >= -0.0002 and foot.global_position.y < 0.017, "Wildlife sole is %.5f above the physical floor (species %d)." % [foot.global_position.y, wildlife.get("species_seed")])
		wildlife.free()
	floor.free()


func _check_editor() -> void:
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(16):
		await process_frame
	editor.call("_set_mode", "parts")
	editor.call("_select_part_by_index", 2)
	for frame in range(3):
		await process_frame
	var rotate: Control = editor.find_child("PartRotateRight", true, false)
	var scroll: ScrollContainer = editor.get("_inspector").get_parent()
	scroll.ensure_control_visible(rotate)
	await process_frame
	await _click(rotate.get_global_rect().get_center())
	_expect(is_equal_approx(Blueprint._as_vector3(editor.get("blueprint")["parts"][2]["rotation"]).y, 15), "Native rotate button did not change the selected part.")
	var spin: SpinBox = editor.find_child("Part_rotation_2", true, false)
	spin.value = 27
	var visual: Node3D = editor.get("_preview")
	_expect(is_equal_approx(_part_roots(visual, 2)[0].rotation_degrees.z, 27), "Z rotation field did not reach rendered geometry.")
	editor.call("_on_category_button_pressed", "feet")
	editor.call("_on_part_button_pressed", "feet_claws")
	_expect(str(editor.get("blueprint")["parts"][2].get("end_part_id", "")) == "feet_claws", "Runtime editor blocked an available foot.")
	var old_parent: Vector3 = editor.get("blueprint")["parts"][2]["rotation"]
	editor.call("_change_part_field", 38.0, "rotation", 1)
	_expect(editor.get("blueprint")["parts"][2]["rotation"] == old_parent, "Foot rotation changed the entire leg.")
	_expect(is_equal_approx(editor.get("blueprint")["parts"][2]["end_rotation"].y, 38), "End-piece rotation was ignored.")
	editor.call("_undo_edit")
	_expect(is_zero_approx(editor.get("blueprint")["parts"][2].get("end_rotation", Vector3.ZERO).y), "End-piece rotation cannot be undone.")
	editor.call("_redo_edit")
	_expect(is_equal_approx(editor.get("blueprint")["parts"][2]["end_rotation"].y, 38), "End-piece rotation cannot be redone.")
	editor.call("_choose_transform_target", 0)
	editor.call("_set_placement_mode", "center")
	_expect(visual.get_node_or_null("BodyV4/CenterAxis/CenterSocket3") != null, "Editor middle-axis sockets are missing.")
	_expect(_part_roots(visual, 2).size() == 1 and is_zero_approx(_part_roots(visual, 2)[0].position.x), "Middle attachment mode did not center the part.")
	editor.call("_set_mode", "paint")
	editor.call("_choose_skin_type", 1)
	editor.call("_apply_color_palette", 2)
	_expect(str(editor.get("blueprint")["appearance"]["skin_type"]) == "scales", "SkinStyle selector did not apply scales.")
	_expect(editor.find_child("Swatch_f3ead6", true, false) != null, "Expanded color swatches are absent.")
	# Rebuild repeatedly before deferred frees run, just as fast mode changes
	# do. The former pose must never touch detached limb roots.
	editor.call("_set_mode", "test")
	editor.call("_choose_motion", "walk")
	editor.call("_set_mode", "parts")
	editor.call("_select_part_by_index", 2)
	editor.call("_change_part_field", 19.0, "rotation", 0)
	editor.call("_refresh_preview")
	_expect(is_equal_approx(_part_roots(visual, 2)[0].rotation_degrees.x, 19), "Returning from motion lost the editable limb pose.")
	editor.free()
	await process_frame


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(click, true)
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
