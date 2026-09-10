extends RefCounted
class_name CreatureAssemblyAdapter

const Assembly = preload("res://assembly/core/modular_assembly.gd")
const Contract = preload("res://assembly/core/blueprint_contract.gd")
const CreatureBlueprint = preload("res://creatures/editor/creature_blueprint.gd")
const BodyAttachments = preload("res://assembly/core/creature_body_attachments.gd")


static func to_modular_blueprint(creature: Dictionary) -> Dictionary:
	if not Contract.inspect(creature, "creature").ok: return {}
	var modular: Dictionary = Assembly.create(
		"creature",
		str(creature.get("name", "Creature"))
	)
	var creature_assembly: Dictionary = creature.get("assembly", {})
	modular["design_id"] = str(creature.get("design_id", ""))
	modular["revision"] = maxi(int(creature_assembly.get("revision", 0)), 0)
	modular["grid_snap"] = false
	modular["metadata"] = {
		"source_schema": int(creature_assembly.get("schema", 0)),
		"body_part_id": CreatureBlueprint.get_body_part_id(creature),
		"paint_part_id": CreatureBlueprint.get_paint_part_id(creature),
		"adapter_only": true,
		"body_attachments": BodyAttachments.read(creature),
	}
	var parts: Array = creature.get("parts", [])
	for placement_value in parts:
		if not (placement_value is Dictionary):
			continue
		var placement: Dictionary = placement_value
		var index: int = Assembly.add_part(
			modular,
			str(placement.get("part_id", "")),
			CreatureBlueprint._as_vector3(placement.get("position", Vector3.ZERO)),
			CreatureBlueprint._as_vector3(placement.get("rotation", Vector3.ZERO)),
			Vector3.ONE * maxf(float(placement.get("scale", 1.0)), 0.05),
			str(placement.get("socket_type", "surface"))
		)
		if index < 0:
			continue
		var part: Dictionary = Assembly.get_part(modular, index)
		part["uid"] = str(placement.get("uid", part.get("uid", "")))
		part["mirror_group"] = str(placement.get("paired_uid", ""))
		part["tags"] = [str(placement.get("category", "part"))]
		Assembly.set_part(modular, index, part)
	Assembly.normalize(modular, "creature")
	return modular


static func get_migration_summary(creature: Dictionary) -> Dictionary:
	var modular: Dictionary = to_modular_blueprint(creature)
	if modular.is_empty(): return {"ready_for_shared_transform_history": false, "error": "unsupported_blueprint"}
	return {
		"name": str(modular.get("name", "Creature")),
		"revision": int(modular.get("revision", 0)),
		"part_count": modular.get("parts", []).size(),
		"body_part_id": str(modular.get("metadata", {}).get("body_part_id", "")),
		"paint_part_id": str(modular.get("metadata", {}).get("paint_part_id", "")),
		"ready_for_shared_transform_history": true,
	}
