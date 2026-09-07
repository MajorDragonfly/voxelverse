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
			return ["open_forest", "mixed_forest", "moss_forest", "fern_forest"]
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
