extends RefCounted
class_name FloraSpeciesFactoryV9

const BiomeGrammar = preload("res://world/generation/biome_grammar_v9.gd")


static func create_species_variant(
	planet_profile: Dictionary,
	biome_key: String,
	family_id: String,
	species_index: int
) -> Dictionary:
	var planet_seed: int = int(planet_profile.get("planet_seed", 0))
	var random := RandomNumberGenerator.new()
	random.seed = (
		planet_seed * 1_000_003
		+ species_index * 97_409
		+ _stable_string_hash(family_id) * 193
		+ _stable_string_hash(biome_key) * 389
	)
	var morphology: Dictionary = planet_profile.get("flora_morphology", {})
	var materials: Dictionary = planet_profile.get("material_slots", {})
	var biome_rules: Dictionary = BiomeGrammar.get_biome_rules(
		biome_key,
		planet_profile
	)
	var architecture_options: Array = biome_rules.get(
		"preferred_architectures",
		[]
	)
	var architecture: String = str(
		morphology.get("primary_architecture", "broad_crown")
	)
	if not architecture_options.is_empty():
		architecture = str(
			architecture_options[
				random.randi_range(0, architecture_options.size() - 1)
			]
		)
	if "pine" in family_id:
		architecture = "conifer"
	elif "oak" in family_id:
		architecture = "ancient_massive"
	var height_base: float = float(morphology.get("height_scale", 1.0))
	var width_base: float = float(morphology.get("width_scale", 1.0))
	var asymmetry: float = float(morphology.get("asymmetry", 0.2))
	var palette_shift: float = random.randf_range(-0.035, 0.035)
	return {
		"species_id": "%d_%s_%s_%02d" % [planet_seed, family_id, biome_key, species_index],
		"species_seed": random.seed,
		"geometry_variant": posmod(species_index, 3),
		"age": random.randf_range(0.35, 1.0),
		"family_id": family_id,
		"biome_key": biome_key,
		"architecture": architecture,
		"height_scale": height_base * random.randf_range(0.82, 1.24),
		"width_scale": width_base * random.randf_range(0.82, 1.22),
		"crown_density": clampf(
			float(morphology.get("crown_density", 0.75))
			* random.randf_range(0.82, 1.18),
			0.30,
			1.20
		),
		"branch_density": clampf(
			float(morphology.get("branch_density", 0.72))
			* random.randf_range(0.82, 1.18),
			0.28,
			1.18
		),
		"trunk_taper": clampf(
			float(morphology.get("trunk_taper", 0.62))
			* random.randf_range(0.88, 1.12),
			0.30,
			1.0
		),
		"trunk_twist": clampf(
			float(morphology.get("trunk_twist", 0.1))
			+ random.randf_range(-0.05, 0.08),
			0.0,
			0.72
		),
		"asymmetry": clampf(
			asymmetry + random.randf_range(-0.08, 0.12),
			0.0,
			0.78
		),
		"canopy_layers": random.randi_range(
			int(morphology.get("canopy_layer_min", 2)),
			int(morphology.get("canopy_layer_max", 7))
		),
		"hero_scale_chance": float(biome_rules.get("hero_asset_chance", 0.01)),
		"palette": _shift_material_palette(materials, palette_shift),
		"placement": {
			"tree_density": float(biome_rules.get("tree_density", 0.0)),
			"shrub_density": float(biome_rules.get("shrub_density", 0.0)),
			"ground_density": float(biome_rules.get("ground_density", 0.0)),
			"rock_density": float(biome_rules.get("rock_density", 0.0)),
		},
	}


static func create_species_set(
	planet_profile: Dictionary,
	biome_key: String,
	family_ids: Array[String],
	variants_per_family: int = 3
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for family_id in family_ids:
		var species_index: int = 0
		for _variant in range(maxi(variants_per_family, 1)):
			result.append(
				create_species_variant(
					planet_profile,
					biome_key,
					family_id,
					species_index
				)
			)
			species_index += 1
	return result


static func create_instance_variation(
	species: Dictionary,
	instance_seed: int
) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = instance_seed * 104_729 + _stable_string_hash(
		str(species.get("species_id", "species"))
	)
	var hero_roll: float = random.randf()
	var hero_chance: float = float(species.get("hero_scale_chance", 0.0))
	var hero_scale: float = (
		random.randf_range(1.35, 2.05)
		if hero_roll < hero_chance
		else 1.0
	)
	return {
		"uniform_scale": random.randf_range(0.92, 1.08) * hero_scale,
		"height_multiplier": random.randf_range(0.96, 1.04),
		"width_multiplier": random.randf_range(0.96, 1.04),
		"rotation_y": random.randf_range(0.0, 360.0),
		"lean_degrees": random.randf_range(-4.0, 4.0)
		* (1.0 + float(species.get("asymmetry", 0.0))),
		"crown_density_multiplier": random.randf_range(0.88, 1.12),
		"is_hero": hero_scale > 1.0,
		"health": random.randf_range(0.82, 1.0),
		"age": random.randf_range(0.3, 1.0),
	}


static func _shift_material_palette(
	materials: Dictionary,
	hue_shift: float
) -> Dictionary:
	var result: Dictionary = {}
	for key in materials.keys():
		var value: Variant = materials[key]
		if value is Color and (str(key).begins_with("foliage_") or str(key).begins_with("shrub_") or str(key).begins_with("flower_")):
			var color: Color = value
			result[key] = Color.from_hsv(
				wrapf(color.h + hue_shift, 0.0, 1.0),
				color.s,
				color.v,
				color.a
			)
		else:
			result[key] = value
	return result


static func _stable_string_hash(value: String) -> int:
	var result: int = 2_166_136_261
	for character in value.to_utf8_buffer():
		result = int((result ^ int(character)) * 16_777_619) & 0x7FFFFFFF
	return result
