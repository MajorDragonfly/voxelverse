extends RefCounted
class_name BiomeGrammarV9

const BIOME_KEYS: Array[String] = [
	"ocean",
	"coast",
	"lake",
	"river",
	"wetland",
	"grassland",
	"steppe",
	"desert",
	"savanna",
	"forest",
	"dense_forest",
	"rocky_highlands",
	"alpine",
	"snow",
]


static func get_biome_rules(
	biome_key: String,
	planet_profile: Dictionary
) -> Dictionary:
	var recipe: Dictionary = planet_profile.get("biome_recipe", {})
	var morphology: Dictionary = planet_profile.get("flora_morphology", {})
	var exotic_factor: float = float(planet_profile.get("exotic_factor", 0.0))
	var base: Dictionary = _base_rules(biome_key)
	base["tree_density"] = clampf(
		float(base.get("tree_density", 0.0))
		* float(planet_profile.get("flora_scale", 1.0)),
		0.0,
		1.8
	)
	base["ground_density"] = clampf(
		float(base.get("ground_density", 0.0))
		* float(recipe.get("understory_density", 1.0)),
		0.0,
		2.0
	)
	base["hero_asset_chance"] = clampf(
		float(base.get("hero_asset_chance", 0.0))
		+ float(morphology.get("giant_flora_chance", 0.0)) * 0.35,
		0.0,
		0.20
	)
	base["exotic_variant_chance"] = clampf(
		0.08 + exotic_factor * 0.44,
		0.0,
		0.65
	)
	base["transition_width"] = float(recipe.get("transition_width", 0.14))
	base["preferred_architectures"] = _architectures_for_biome(
		biome_key,
		planet_profile
	)
	return base


static func get_asset_tags(
	biome_key: String,
	planet_profile: Dictionary
) -> Array[String]:
	var tags: Array[String] = ["biome:%s" % biome_key]
	var flora_family: String = str(
		planet_profile.get("flora_color_family", "verdant")
	)
	tags.append("palette:%s" % flora_family)
	var morphology: Dictionary = planet_profile.get("flora_morphology", {})
	var primary: String = str(morphology.get("primary_architecture", "broad_crown"))
	var secondary: String = str(morphology.get("secondary_architecture", "columnar"))
	tags.append("architecture:%s" % primary)
	tags.append("architecture:%s" % secondary)
	return tags


static func choose_local_variant(
	biome_key: String,
	planet_profile: Dictionary,
	world_x: float,
	world_z: float
) -> String:
	var seed_value: int = int(planet_profile.get("planet_seed", 0))
	var cell_x: int = floori(world_x / 96.0)
	var cell_z: int = floori(world_z / 96.0)
	var mixed_seed: int = (
		seed_value * 73_856_093
		+ cell_x * 19_349_663
		+ cell_z * 83_492_791
	)
	var random := RandomNumberGenerator.new()
	random.seed = mixed_seed
	var variants: Array[String] = _variants_for_biome(biome_key)
	if variants.is_empty():
		return biome_key
	return variants[random.randi_range(0, variants.size() - 1)]


static func _base_rules(biome_key: String) -> Dictionary:
	match biome_key:
		"coast":
			return {
				"tree_density": 0.28,
				"shrub_density": 0.44,
				"ground_density": 0.72,
				"rock_density": 0.34,
				"hero_asset_chance": 0.012,
			}
		"wetland":
			return {
				"tree_density": 0.56,
				"shrub_density": 0.82,
				"ground_density": 1.15,
				"rock_density": 0.12,
				"hero_asset_chance": 0.018,
			}
		"forest":
			return {
				"tree_density": 0.86,
				"shrub_density": 0.72,
				"ground_density": 0.94,
				"rock_density": 0.24,
				"hero_asset_chance": 0.022,
			}
		"dense_forest":
			return {
				"tree_density": 1.22,
				"shrub_density": 1.04,
				"ground_density": 1.28,
				"rock_density": 0.18,
				"hero_asset_chance": 0.032,
			}
		"rocky_highlands":
			return {
				"tree_density": 0.26,
				"shrub_density": 0.34,
				"ground_density": 0.42,
				"rock_density": 1.10,
				"hero_asset_chance": 0.024,
			}
		"alpine":
			return {
				"tree_density": 0.18,
				"shrub_density": 0.28,
				"ground_density": 0.36,
				"rock_density": 0.94,
				"hero_asset_chance": 0.016,
			}
		"savanna":
			return {
				"tree_density": 0.24,
				"shrub_density": 0.30,
				"ground_density": 0.78,
				"rock_density": 0.20,
				"hero_asset_chance": 0.018,
			}
		"steppe", "grassland":
			return {
				"tree_density": 0.12,
				"shrub_density": 0.26,
				"ground_density": 1.02,
				"rock_density": 0.18,
				"hero_asset_chance": 0.010,
			}
		_:
			return {
				"tree_density": 0.0,
				"shrub_density": 0.0,
				"ground_density": 0.08,
				"rock_density": 0.28,
				"hero_asset_chance": 0.004,
			}


static func _architectures_for_biome(
	biome_key: String,
	planet_profile: Dictionary
) -> Array[String]:
	var morphology: Dictionary = planet_profile.get("flora_morphology", {})
	var result: Array[String] = []
	var primary: String = str(morphology.get("primary_architecture", "broad_crown"))
	var secondary: String = str(morphology.get("secondary_architecture", "columnar"))
	if not primary.is_empty():
		result.append(primary)
	if not secondary.is_empty() and secondary != primary:
		result.append(secondary)
	match biome_key:
		"wetland":
			result.append("wetland")
		"rocky_highlands", "alpine":
			result.append("windswept")
			result.append("conifer")
		"dense_forest":
			result.append("ancient_massive")
		"savanna":
			result.append("broad_crown")
	return _unique_strings(result)


static func _variants_for_biome(biome_key: String) -> Array[String]:
	match biome_key:
		"forest":
			return ["sparse_woodland", "ancient_grove", "moss_forest", "fern_forest", "autumn_grove"]
		"dense_forest":
			return ["ancient_grove", "deep_forest", "giant_tree_field", "shadow_grove"]
		"grassland":
			return ["flower_meadow", "open_grass", "rolling_green", "shrub_meadow"]
		"steppe":
			return ["dry_steppe", "wind_steppe", "rock_steppe"]
		"savanna":
			return ["open_savanna", "tree_savanna", "dry_bloom"]
		"wetland":
			return ["reed_marsh", "swamp_grove", "shallow_bloom", "moss_wetland"]
		"coast":
			return ["dune_coast", "rocky_coast", "lush_shore", "tidal_flat"]
		"rocky_highlands":
			return ["broken_ridge", "rock_teeth", "highland_scrub", "wind_cliff"]
		"alpine":
			return ["alpine_meadow", "cold_scree", "high_pine", "snow_edge"]
	return [biome_key]


static func _unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result


static func variant_weights(biome_key: String, profile: Dictionary, world_x: float, world_z: float) -> Dictionary:
	# Bilinear interpolation of seeded patches gives continuous ecological
	# transitions at both positive and negative 96 m cell boundaries.
	var cell := Vector2(world_x, world_z) / 96.0
	var base := Vector2(floorf(cell.x), floorf(cell.y))
	var fraction: Vector2 = cell - base
	fraction = Vector2(smoothstep(0.0, 1.0, fraction.x), smoothstep(0.0, 1.0, fraction.y))
	var result: Dictionary = {}
	for z in range(2):
		for x in range(2):
			var weight: float = (fraction.x if x else 1.0 - fraction.x) * (fraction.y if z else 1.0 - fraction.y)
			var variant: String = choose_local_variant(biome_key, profile, (base.x + x) * 96.0, (base.y + z) * 96.0)
			result[variant] = float(result.get(variant, 0.0)) + weight
	return result


static func blend_composition(weights: Dictionary, profile: Dictionary, world_x: float, world_z: float) -> Dictionary:
	var result: Dictionary = {"tree_density": 0.0, "shrub_density": 0.0, "ground_density": 0.0, "rock_density": 0.0, "hero_asset_chance": 0.0,
		"biome_weights": weights.duplicate(), "variant_weights": {},
		"families": {}, "fauna_weights": {"grazer": 0.0, "forager": 0.0, "predator": 0.0},
		"water_style": {"still": 0.0, "flowing": 0.0, "coastal": 0.0},
		"atmosphere": {"mist": 0.0}, "landmarks": {"ancient_grove": 0.0, "rock_spire": 0.0},
		"surface_slots": {"ground_base": 1.0}}
	for biome_key: String in weights:
		var weight: float = float(weights[biome_key])
		if weight <= 0.00001:
			continue
		var rules: Dictionary = get_biome_rules(biome_key, profile)
		var patches: Dictionary = variant_weights(biome_key, profile, world_x, world_z)
		var forest: bool = biome_key in ["forest", "dense_forest", "wetland"]
		var alpine: bool = biome_key in ["alpine", "rocky_highlands"]
		var aquatic: bool = biome_key in ["ocean", "river", "lake"]
		var fern_bias: float = 0.0
		var tree_scale: float = 1.0
		for variant: String in patches:
			var patch_weight: float = float(patches[variant])
			result["variant_weights"][variant] = float(result["variant_weights"].get(variant, 0.0)) + weight * patch_weight
			if variant in ["fern_forest", "moss_forest", "moss_wetland"]:
				fern_bias += patch_weight * 0.55
			if variant == "sparse_woodland":
				tree_scale -= patch_weight * 0.42
			if variant in ["ancient_grove", "giant_tree_field"]:
				tree_scale += patch_weight * 0.15
		for density: String in ["tree_density", "shrub_density", "ground_density", "rock_density", "hero_asset_chance"]:
			var value: float = float(rules.get(density, 0.0))
			if density == "tree_density":
				value *= tree_scale
			result[density] += value * weight
		var tree_density: float = float(rules["tree_density"]) * tree_scale
		var pine_share: float = 0.88 if alpine else (0.24 if forest else 0.38)
		_add_family(result, "ancient_oak_v2", weight * tree_density * (1.0 - pine_share))
		_add_family(result, "tall_pine_v2", weight * tree_density * pine_share)
		_add_family(result, "dense_bush_v2", weight * float(rules["shrub_density"]))
		_add_family(result, "fern_cluster_v2", weight * float(rules["ground_density"]) * ((0.65 + fern_bias) if forest else 0.08))
		_add_family(result, "flower_cluster_v2", weight * float(rules["ground_density"]) * (0.12 if forest else 0.45))
		_add_family(result, "grass_tuft_v2", weight * float(rules["ground_density"]) * (0.45 if forest else 0.85))
		_add_family(result, "layered_rock_v2", weight * float(rules["rock_density"]))
		result["fauna_weights"]["grazer"] += weight * (0.0 if aquatic else (0.28 if forest else 0.65))
		result["fauna_weights"]["forager"] += weight * (0.0 if aquatic else (0.54 if forest else 0.25))
		result["fauna_weights"]["predator"] += weight * (0.0 if aquatic else (0.18 if forest else 0.10))
		result["water_style"]["flowing"] += weight if biome_key == "river" else 0.0
		result["water_style"]["still"] += weight if biome_key in ["lake", "wetland"] else 0.0
		result["water_style"]["coastal"] += weight if biome_key in ["coast", "ocean"] else 0.0
		result["atmosphere"]["mist"] += weight * (0.8 if biome_key == "wetland" else (0.4 if forest else 0.1))
		result["landmarks"]["ancient_grove"] += weight * (0.7 if forest else 0.05)
		result["landmarks"]["rock_spire"] += weight * (0.8 if alpine else 0.12)
	result["openness"] = 1.0 - smoothstep(0.12, 0.75, float(result["tree_density"]))
	return result


static func _add_family(result: Dictionary, family: String, weight: float) -> void:
	result["families"][family] = float(result["families"].get(family, 0.0)) + weight
