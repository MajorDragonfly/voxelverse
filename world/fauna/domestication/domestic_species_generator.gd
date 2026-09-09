extends RefCounted
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Factory = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")

static func create(body: Dictionary, group: String, seed_value: int) -> Dictionary:
	var role: String = "forager" if group == "companion" else "grazer"
	var blueprint: Dictionary = Factory.create_species(seed_value, Vector2i.ZERO, role)
	Blueprint.clear_parts(blueprint)
	Blueprint.set_body_part(blueprint, "body_balanced_core" if group == "companion" else "body_long_grazer")
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	blueprint["appearance"] = SkinStyle.PALETTES[posmod(seed_value, SkinStyle.PALETTES.size())].duplicate(true)
	blueprint["appearance"]["skin_type"] = ["fur", "scales", "leather"][posmod(seed_value / 17, 3)]
	var variation: float = random.randf_range(0.9, 1.1)
	Blueprint.set_body_shape(blueprint, (Vector3(1.05, 0.8, 2.15) if group == "companion" else Vector3(1.55, 1.1, 2.8)) * variation)
	Blueprint.set_body_scale(blueprint, 1.0)
	blueprint["body"]["spine_length_scale"] = 1.0
	# A nearly level load-bearing back; no random dorsal spikes or plates.
	for segment: Dictionary in blueprint["body"]["spine"]:
		segment["y_offset"] = 0.0
		segment["height_scale"] = 1.0
		segment["width_scale"] = 1.0
	Blueprint.add_part(blueprint, "mouth_filter_snout" if group == "companion" else "mouth_grazer")
	Blueprint.add_part(blueprint, "eyes_beady" if posmod(seed_value, 2) == 0 else "eyes_wide")
	for pair in range(2):
		var index: int = Blueprint.add_part(blueprint, "legs_walker" if group == "companion" else "legs_hoof")
		var part: Dictionary = blueprint["parts"][index]
		part["mirrored"] = true
		part["rotation"] = Vector3.ZERO
		part["scale"] = 0.85 if group == "companion" else 1.05
		part["end_part_id"] = "feet_pads" if group == "companion" else "feet_hooves"
	Blueprint.add_part(blueprint, "tail_balance")
	Anatomy.reset_all_anchors(blueprint)
	var pair_index: int = 0
	for part: Dictionary in blueprint["parts"]:
		if part["category"] == "legs":
			part["anchor_t"] = 0.25 if pair_index == 0 else 0.75
			pair_index += 1
	Anatomy.rebind_all_parts(blueprint)
	Assembly.normalize(blueprint)
	var suitability: Dictionary = Contract.suitability(group)
	var label: String = {"milk": "Milchweider", "work": "Lastläufer", "companion": "Spürläufer"}[group]
	blueprint["name"] = str(blueprint["name"]).split(" · ")[0] + " · " + label
	blueprint["species"].merge({"display_name": blueprint["name"], "domestication": suitability.duplicate(true)}, true)
	var species_id: String = Ids.scoped("species", str(body["id"]), str(seed_value))
	blueprint["species"]["id"] = species_id
	blueprint["species"]["body_id"] = body["id"]
	return {"id": species_id, "body_id": body["id"], "species_seed": seed_value,
		"group": group, "role": role, "domestication": suitability,
		"visual_scale": 0.55 if group == "companion" else (0.88 if group == "work" else 0.74),
		"blueprint": Contract.encode(blueprint)}
