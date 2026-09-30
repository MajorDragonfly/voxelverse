extends RefCounted
## Frozen review specimens, never a population/spawn or mesh-cache owner.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const SIZES: Array[float] = [0.65, 1.0, 1.45]
const SHAPES: Array[Vector3] = [Vector3(0.8, 0.7, 1.5), Vector3(1.3, 1.0, 2.8), Vector3(1.8, 0.9, 3.8)]

static func design(index: int, role: String = "grazer") -> Dictionary:
	var data: Dictionary = Assembly.create_default()
	data.parts = []
	Assembly.BaseBlueprint.set_body_shape(data, SHAPES[index])
	for pair in range(index + 1): Assembly.BaseBlueprint.add_part(data, "legs_walker")
	for id: String in ["tail_balance", "eyes_stalks", "mouth_crocodile_snout", "arms_claws"]:
		Assembly.BaseBlueprint.add_part(data, id)
	Anatomy.reset_all_anchors(data)
	data["appearance"] = {"base_color": ["89bfa0", "bdaf89", "8faac7"][index], "accent_color": "30566c"}
	data["species"] = {"ecological_role": role, "display_name": "INT30 specimen %d" % index}
	Assembly.Ids.ensure_design(data, "int30-review:%d:%s" % [index, role])
	return data
