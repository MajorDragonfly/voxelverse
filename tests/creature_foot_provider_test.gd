extends SceneTree
const Feet = preload("res://creatures/catalog/creature_foot_catalog.gd")
const Library = preload("res://creatures/editor/creature_part_library.gd")
const Geometry = preload("res://creatures/editor/creature_foot_geometry.gd")
const Snapshot = preload("res://tests/creature_foot_snapshot.gd")
const Journal = preload("res://ui/discovery/journal_preview.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Body = preload("res://creatures/runtime/creature_body_contract.gd")
var failures: Array[String] = []


func _initialize() -> void: call_deferred("run")


func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	_check_catalog()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_feet_v1.json"))
	# JSON reads counts as floats; put both sides through the same decoding.
	var actual: Dictionary = JSON.parse_string(JSON.stringify(Snapshot.capture()))
	check(actual == expected, "Revision 1 changed shipped meshes, colors, bounds or mirrored/nonuniform transforms")
	_check_profiles()
	_check_d1()
	for id: String in Snapshot.FootIds:
		_check_preview(id)
		_check_radial_contact(id)
	for problem: String in failures: push_error(problem)
	print(JSON.stringify({"test": "creature_foot_provider", "catalog_entries": 46,
		"legacy_geometry_cases": expected.size(), "preview_and_radial_families": 4, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _check_catalog() -> void:
	var fixture: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/creature_part_catalog_v1.json"))
	var current_ids: Array = []
	for category: Dictionary in Library.get_categories():
		for part: Dictionary in Library.get_parts_for_category(category.id): current_ids.append(part.id)
	for part: Dictionary in Library.get_terminal_parts(): current_ids.append(part.id)
	var expected_ids: Array = []
	for entry: Dictionary in fixture:
		var original: Dictionary = str_to_var(entry.definition)
		expected_ids.append(original.id)
		var current: Dictionary = Library.get_part(original.id)
		for key: String in original:
			check(current.get(key) == original[key], "Changed old definition %s.%s" % [original.id, key])
	var additions: Array = ["feet_feline_paws", "feet_bear_paws", "feet_horse_hooves", "hands_crab_claws"]
	check(current_ids.filter(func(id: String) -> bool: return id not in additions) == expected_ids, "Legacy catalog IDs/order changed (including terminal and default parts)")
	check(current_ids.size() == expected_ids.size() + additions.size(), "Unexpected catalog additions")


func _check_profiles() -> void:
	var changed: Dictionary = Feet.get_profile("feet_pads")
	changed.capabilities.clear()
	changed.contact.method = "arbitrary_height"
	check(Feet.supports("feet_pads", "domestic_support"), "Caller mutated authoritative foot traits")
	check(Feet.get_profile("feet_pads").contact.method == "rendered_bounds", "Caller mutated contact definition")
	for id: String in Snapshot.FootIds:
		check(Feet.supports(id, "ground_contact"), "Missing foot contact: " + id)
		for action: String in ["swim", "fly", "climb"]:
			check(action not in Feet.get_profile(id).supported_limb_actions, "Shape granted unsupported action: " + action)
	check(Feet.get_profile("feet_future").is_empty() and Feet.get_profile("feet_pads", 2).is_empty(), "Unknown identity/revision silently replaced")
	check(Geometry.recipe("feet_future", Color.WHITE, Color.WHITE).is_empty(), "Unknown foot rendered as pads")
	check(Geometry.recipe("feet_pads", Color.WHITE, Color.WHITE, 2).is_empty(), "Future geometry revision overwritten")
	check(not Feet.supports("feet_pads", "domestic_support", 2), "Future foot traits granted old capability")


func _check_d1() -> void:
	var body: Dictionary = {"id": "arch24-body", "seed": 42, "surface_mode": "legacy_plane_v9"}
	var original: Dictionary = Catalog.create(body)
	var encoded: String = JSON.stringify(original)
	check(Catalog.validate(original, body).is_empty(), "Existing deterministic D1 catalog rejected")
	check(JSON.stringify(original) == encoded, "D1 read changed frozen species")
	for id: String in ["feet_pads", "feet_hooves", "feet_claws", "feet_webbed", "feet_unknown", "hands_grasp"]:
		var copy: Dictionary = original.duplicate(true)
		for entry: Dictionary in copy.species:
			for part: Dictionary in entry.blueprint.parts:
				if part.category == "legs": part.end_part_id = id
		var accepted: bool = Catalog.validate(copy, body).is_empty()
		check(accepted == (id in ["feet_pads", "feet_hooves"]), "D1 support policy changed: " + id)
	check(Catalog.validate(JSON.parse_string(encoded), body).is_empty(), "Serialized D1 catalog lost support")


func _check_preview(id: String) -> void:
	var journal := Journal.new()
	root.add_child(journal)
	journal.show_part(id, true)
	var visible_shape: Array = Snapshot.describe(journal._model)
	journal.show_part(id, false)
	var silhouette: Array = Snapshot.describe(journal._model)
	check(visible_shape.size() == silhouette.size() and not silhouette.is_empty(), "Missing shared preview: " + id)
	for index in range(mini(visible_shape.size(), silhouette.size())):
		check(silhouette[index].color == "080f18ff", "Locked part exposed material color")
		visible_shape[index].erase("color")
		silhouette[index].erase("color")
		check(visible_shape[index] == silhouette[index], "Silhouette changed actual model geometry")
	journal.free()


func _check_radial_contact(id: String) -> void:
	var design: Dictionary = Assembly.create_default()
	design.parts = []
	for limb: String in ["legs_walker", "legs_stubby", "legs_spider"]:
		Assembly.BaseBlueprint.add_part(design, limb)
	Anatomy.reset_all_anchors(design)
	for index in range(design.parts.size()):
		var part: Dictionary = design.parts[index]
		part.end_part_id = id
		part.anchor_t = 0.25 + 0.23 * index
		part.end_shape_scale = Vector3(0.8, 1.1, 1.4)
		part.end_rotation = Vector3(12, -23, 10)
	Anatomy.rebind_all_parts(design)
	var parent := Node3D.new()
	root.add_child(parent)
	parent.transform = Transform3D(Basis.from_euler(Vector3(1.1, -0.7, 0.35)), Vector3(1500, -700, 2300))
	var preview := Preview.new()
	parent.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var report: Dictionary = Body.inspect_rest(preview)
	check(report.leg_count == 6 and report.all_feet_on_plane, "Six-leg radial rest lost sole: " + id)
	var original: String = var_to_str(design)
	preview.set_motion("walk")
	preview.set_process(false)
	for index in range(12):
		preview._motion.sample("walk", 0.13 * index)
		var grounded: int = 0
		for rig: Dictionary in preview._motion._legs:
			var point: Vector3 = parent.to_local(rig.foot.global_position)
			var gap: float = point.y - float(preview.get_meta("ground_y"))
			check(gap >= -0.002, "Rotated sole penetrated radial plane: " + id)
			if absf(gap) < 0.002: grounded += 1
		check(grounded >= 3, "Six-legged creature lost its support feet: " + id)
	check(var_to_str(design) == original, "Posing rewrote saved foot placement")
	parent.free()


func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
