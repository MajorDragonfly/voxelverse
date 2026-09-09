extends SceneTree

const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")

func _initialize() -> void:
	var samples: Array[Dictionary] = []
	var wanted: Array[String] = ["verdant", "autumn", "violet"]
	for family: String in wanted:
		for index in range(1, 97):
			var profile: Dictionary = Profile.create(index * 7919)
			if profile["flora_color_family"] != family:
				continue
			var palette: Dictionary = {}
			for slot_index in range(Slots.NAMES.size()):
				var color: Color = profile["material_slots"][Slots.NAMES[slot_index]]
				palette[str(slot_index)] = [color.r, color.g, color.b, color.a]
			var generator := Generator.new()
			generator.set_seed_override(index * 7919)
			var spawn: Vector3 = generator.get_scenic_spawn()
			samples.append({"seed": index * 7919, "family": family, "palette": palette,
				"signature": profile["planet_signature"], "spawn": [spawn.x, spawn.y, spawn.z],
				"terrain_archetype": profile["terrain_archetype"],
				"composition_at_spawn": generator.get_biome_composition(spawn.x, spawn.z)})
			generator.free()
			break
	var path: String = "res://art/review/benchmark_v2/planet_samples.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t") + "\n")
	file.close()
	print("Exported deterministic review profiles: ", path)
	await preload("res://core/runtime_shutdown.gd").finish(self)
