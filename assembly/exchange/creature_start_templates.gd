extends RefCounted
## Authored starting forms use only the actual ProgressionService starter set.
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Progression = preload("res://autoload/progression_service.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Connections = preload("res://creatures/editor/creature_attachment_normalizer.gd")
const IDS: Array[String] = ["meadow", "dune", "moss"]


static func unlocked_parts() -> Array[String]:
	var progression := Progression.new()
	progression.reset_for_new_game()
	var result: Array[String] = progression.get_unlocked_part_ids()
	progression.free()
	return result


static func packages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in IDS:
		var blueprint: Dictionary = Creature.create_default()
		blueprint.design_id = "starter_" + id
		blueprint.name = {"meadow": "Wiesenläufer", "dune": "Dünenwanderer", "moss": "Mooskrabbler"}[id]
		blueprint.parts.clear()
		for category in ["eyes", "mouth", "legs", "tail"]:
			Creature.BaseBlueprint.add_part(blueprint, Creature.BaseBlueprint.PartLibrary.get_first_part_id_for_category(category))
		if id == "moss": Creature.BaseBlueprint.add_part(blueprint, "legs_stubby")
		blueprint.body.shape = {"meadow": Vector3(1.3, 1.0, 2.1), "dune": Vector3(1.1, 1.15, 2.6), "moss": Vector3(1.65, 0.75, 2.3)}[id]
		if id == "dune": blueprint.body.spine[1].y_offset = 0.35
		blueprint.appearance = {
			"base_color": {"meadow": "73b696", "dune": "cfa86a", "moss": "9eac42"}[id],
			"accent_color": {"meadow": "244e46", "dune": "704b39", "moss": "424956"}[id],
			"belly_color": "f1dbad", "eye_color": "448e9c", "horn_color": "eee1bd",
			"skin_type": "leather" if id == "dune" else "smooth", "skin_strength": 0.65, "skin_scale": 1.0,
		}
		Anatomy.reset_all_anchors(blueprint)
		Connections.normalize(blueprint)
		blueprint.assembly.revision = 1
		var exported: Dictionary = Package.export_blueprint(blueprint, {"author": "Voxelverse"})
		if exported.ok: result.append(exported.package)
	return result


static func prepare(package: Dictionary, current: Dictionary) -> Dictionary:
	var result: Dictionary = Package.prepare_import(package, current, 0, unlocked_parts())
	return for_editor(result)


static func for_editor(result: Dictionary) -> Dictionary:
	if not result.ok: return result
	mark_authored(result.blueprint)
	var candidate: Dictionary = result.blueprint.duplicate(true)
	Connections.normalize(candidate)
	var before: Dictionary = Package.Schema.project(Creature.serialize_snapshot(result.blueprint), Package.Schema.BLUEPRINT)
	var after: Dictionary = Package.Schema.project(Creature.serialize_snapshot(candidate), Package.Schema.BLUEPRINT)
	if before != after: return {"ok": false, "code": "editor_incompatible"}
	return result


## The transferred anchors already describe the authored current geometry.
## Runtime/editor legacy migrations must not reinterpret them as old placements.
static func mark_authored(blueprint: Dictionary) -> void:
	blueprint.assembly["attachment_schema_version"] = Connections.ATTACHMENT_SCHEMA_VERSION
	blueprint.assembly["sculpt_surface_bindings"] = 1
