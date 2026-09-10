extends SceneTree
## Capture only on main bb2f83b before the ARCH-24 mouth addition.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Snapshot = preload("res://tests/creature_foot_snapshot.gd")
const Blueprint = preload("res://creatures/editor/creature_blueprint.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")


func _initialize() -> void:
	var result: Dictionary = {"mouths": {}, "species": {}}
	for id: String in ["mouth_grazer", "mouth_broad_beak", "mouth_predator_jaws", "mouth_filter_snout"]:
		for shape: Vector3 in [Vector3.ONE, Vector3(0.8, 1.1, 1.4), Vector3(1.7, 0.6, 0.9)]:
			for side: float in [-1.0, 1.0]:
				var node := Node3D.new()
				node.set_meta("creature_part_side", side)
				Geometry.build(node, Parts.get_part(id), {"category": "mouth", "shape_scale": shape}, Blueprint.create_default())
				result.mouths["%s:%s:%d" % [id, shape, int(side)]] = Snapshot.describe(node)
				node.free()
	for seed_value: int in [1, 17, 42, 977, 8192]:
		for role: String in Species.ECOLOGICAL_ROLES:
			var design: Dictionary = Species.create_species(seed_value, Vector2i(13, -7), role)
			result.species["%d:%s" % [seed_value, role]] = JSON.stringify(Blueprint._serialize_blueprint(design)).sha256_text()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	file.close()
	print("MOUTH_BASELINE_CAPTURED")
	quit()
