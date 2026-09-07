extends "res://world/generation/world_generator_adventure.gd"

const PlanetProfile = preload("res://world/generation/planet_profile_v9.gd")
const BiomeGrammar = preload("res://world/generation/biome_grammar_v9.gd")


func _configure_v6(seed_value: int) -> void:
	super._configure_v6(seed_value)
	_planet_profile = PlanetProfile.create(seed_value)
	_height_cache.clear()


func get_biome(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> int:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var sea_level: float = get_sea_level()
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var palette_field: float = _normalized_v6(_palette_noise, world_x, world_z)
	var ruggedness: float = float(
		get_region_profile(world_x, world_z).get("ruggedness", 0.0)
	)
	var recipe: Dictionary = _planet_profile.get("biome_recipe", {})
	var climate: Dictionary = _planet_profile.get("climate", {})
	var dryness_bias: float = float(recipe.get("dryness_bias", 0.0))
	var forest_threshold: float = float(recipe.get("forest_threshold", 0.56))
	var dense_threshold: float = float(
		recipe.get("dense_forest_threshold", 0.79)
	)
	var wetland_threshold: float = float(recipe.get("wetland_threshold", 0.58))
	var alpine_bias: float = float(recipe.get("alpine_bias", 0.0))
	var snow_start: float = float(
		_planet_profile.get("snow_start_altitude", 20.0)
	) + alpine_bias
	var temperature: float = float(climate.get("temperature_bias", 0.0))

	if terrain_height < sea_level - 0.45:
		return Biome.OCEAN
	if terrain_height < sea_level + 0.55:
		return Biome.COAST
	if lake > 0.68 and terrain_height < sea_level + 1.65:
		return Biome.LAKE
	if river > 0.70 and terrain_height < 8.0:
		return Biome.RIVER
	if terrain_height >= snow_start + 3.0:
		return Biome.SNOW
	if terrain_height >= snow_start - 4.0:
		return Biome.ALPINE
	if ruggedness > 0.60 and terrain_height > 5.0:
		return Biome.ROCKY_HIGHLANDS
	if (
		maxf(river, lake) > 0.64
		and ecology > wetland_threshold
		and terrain_height < 4.2
	):
		return Biome.WETLAND

	var dryness: float = clampf(
		palette_field + dryness_bias - ecology * 0.18,
		0.0,
		1.0
	)
	if dryness > 0.83 and ecology < 0.38:
		return Biome.DESERT
	if dryness > 0.68 and ecology < 0.56:
		return Biome.SAVANNA
	if ecology > dense_threshold:
		return Biome.DENSE_FOREST
	if ecology > forest_threshold:
		return Biome.FOREST
	if dryness > 0.57 + temperature * 0.04:
		return Biome.STEPPE
	return Biome.GRASSLAND


func get_biome_key(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> String:
	var biome: int = get_biome(world_x, world_z, terrain_height)
	match biome:
		Biome.OCEAN:
			return "ocean"
		Biome.COAST:
			return "coast"
		Biome.LAKE:
			return "lake"
		Biome.RIVER:
			return "river"
		Biome.WETLAND:
			return "wetland"
		Biome.GRASSLAND:
			return "grassland"
		Biome.STEPPE:
			return "steppe"
		Biome.SAVANNA:
			return "savanna"
		Biome.FOREST:
			return "forest"
		Biome.DENSE_FOREST:
			return "dense_forest"
		Biome.ROCKY_HIGHLANDS:
			return "rocky_highlands"
		Biome.ALPINE:
			return "alpine"
		Biome.SNOW:
			return "snow"
	return "grassland"


func get_biome_variant(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> String:
	return BiomeGrammar.choose_local_variant(
		get_biome_key(world_x, world_z, terrain_height),
		_planet_profile,
		world_x,
		world_z
	)


func get_biome_composition(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> Dictionary:
	return BiomeGrammar.get_biome_rules(
		get_biome_key(world_x, world_z, terrain_height),
		_planet_profile
	)


func get_biome_color(
	world_x: float,
	world_z: float,
	terrain_height: float = -9999.0
) -> Color:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var slots: Dictionary = _planet_profile.get("material_slots", {})
	var ground: Color = slots.get("ground_base", Color(0.30, 0.54, 0.28, 1.0))
	var ground_shadow: Color = slots.get("ground_shadow", ground.darkened(0.28))
	var dry: Color = slots.get("ground_dry", Color(0.64, 0.50, 0.24, 1.0))
	var coast: Color = slots.get("coast", Color(0.72, 0.61, 0.39, 1.0))
	var rock: Color = slots.get("rock_base", Color(0.37, 0.38, 0.39, 1.0))
	var rock_light: Color = slots.get("rock_light", rock.lightened(0.15))
	var foliage_shadow: Color = slots.get("foliage_shadow", Color(0.12, 0.36, 0.18, 1.0))
	var water_deep: Color = slots.get("water_deep", Color(0.04, 0.35, 0.44, 1.0))
	var water_shallow: Color = slots.get("water_shallow", water_deep.lightened(0.20))
	var snow: Color = _planet_profile.get("palette", {}).get(
		"snow",
		Color(0.86, 0.90, 0.91, 1.0)
	)
	var biome: int = get_biome(world_x, world_z, terrain_height)
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var palette_field: float = _normalized_v6(_palette_noise, world_x, world_z)
	var local_variation: float = clampf(
		(_micro_relief_noise.get_noise_2d(world_x * 1.7, world_z * 1.7) + 1.0) * 0.5,
		0.0,
		1.0
	)

	match biome:
		Biome.OCEAN:
			var depth: float = clampf(
				(get_sea_level() - terrain_height) / 9.0,
				0.0,
				1.0
			)
			return water_shallow.lerp(water_deep.darkened(0.22), depth)
		Biome.COAST:
			return coast.lerp(ground, ecology * 0.18)
		Biome.LAKE, Biome.RIVER:
			return water_shallow.lerp(water_deep, 0.36)
		Biome.WETLAND:
			return ground.lerp(foliage_shadow, 0.42).lightened(0.04)
		Biome.DESERT:
			return dry.lightened(0.06).lerp(rock_light, palette_field * 0.12)
		Biome.SAVANNA:
			return dry.lerp(ground, 0.28 + ecology * 0.22)
		Biome.STEPPE:
			return ground.lerp(dry, 0.46)
		Biome.FOREST:
			return ground.lerp(foliage_shadow, 0.32)
		Biome.DENSE_FOREST:
			return ground_shadow.lerp(foliage_shadow, 0.48)
		Biome.ROCKY_HIGHLANDS:
			return rock.lerp(ground_shadow, ecology * 0.16)
		Biome.ALPINE:
			return rock_light.lerp(ground, 0.22).lerp(snow, 0.18)
		Biome.SNOW:
			return snow.lerp(rock_light, 0.08 + local_variation * 0.08)
		_:
			return ground.lerp(
				ground.lightened(0.10),
				local_variation * 0.22
			)
