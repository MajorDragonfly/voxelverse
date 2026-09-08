extends "res://world/generation/world_generator_adventure.gd"

const ProfileV9 = preload("res://world/generation/planet_profile_v9.gd")
const BiomeGrammar = preload("res://world/generation/biome_grammar_v9.gd")
const Landmarks = preload("res://world/generation/landmark_grammar.gd")
const ScenicSpawn = preload("res://world/generation/adventure_spawn_selector.gd")
const Drainage = preload("res://world/generation/drainage_network.gd")
var _drainage_regions: Dictionary = {}
var _drainage_samples: Dictionary = {}
var _drained_heights: Dictionary = {}
var _landmark_cells: Dictionary = {}
var _spawn_cache: Dictionary = {}
var _canopy_noise := FastNoiseLite.new()


func _configure_v6(seed_value: int) -> void:
	super._configure_v6(seed_value)
	_planet_profile = ProfileV9.create(seed_value)
	_setup_adventure_noise(_canopy_noise, seed_value + 117_331, 0.008, FastNoiseLite.FRACTAL_FBM, 2, 8.0)
	_height_cache.clear()
	_landmark_cells.clear()
	_spawn_cache.clear()
	_drainage_regions.clear()
	_drainage_samples.clear()
	_drained_heights.clear()


func get_base_terrain_height(world_x: float, world_z: float) -> float:
	# Routing reads the uncarved landscape; querying final heights here would
	# recurse back into routing and make the result depend on chunk order.
	return super.get_terrain_height(world_x, world_z)


func get_drainage_region(cell: Vector2i) -> Dictionary:
	_ensure_v6_state()
	if not _drainage_regions.has(cell):
		if _drainage_regions.size() >= 64:
			_drainage_regions.clear()
		_drainage_regions[cell] = Drainage.create(self, cell)
	return _drainage_regions[cell]


func get_water_info(world_x: float, world_z: float) -> Dictionary:
	_ensure_v6_state()
	var key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if not _drainage_samples.has(key):
		if _drainage_samples.size() >= HEIGHT_CACHE_LIMIT:
			_drainage_samples.clear()
		var point: Vector2 = Vector2(key) / 100.0
		var cell := Vector2i(floori(point.x / Drainage.REGION_SIZE), floori(point.y / Drainage.REGION_SIZE))
		_drainage_samples[key] = Drainage.sample(get_drainage_region(cell), point)
	return _drainage_samples[key]


func get_terrain_height(world_x: float, world_z: float) -> float:
	_ensure_v6_state()
	var key := Vector2i(roundi(world_x * 100.0), roundi(world_z * 100.0))
	if not _drained_heights.has(key):
		if _drained_heights.size() >= HEIGHT_CACHE_LIMIT:
			_drained_heights.clear()
		var base: float = get_base_terrain_height(world_x, world_z)
		_drained_heights[key] = Drainage.carve(base, get_water_info(world_x, world_z))
	return float(_drained_heights[key])


func get_water_level(world_x: float, world_z: float) -> float:
	return Drainage.surface(get_water_info(world_x, world_z), get_sea_level())


func is_water_at(world_x: float, world_z: float) -> bool:
	return get_terrain_height(world_x, world_z) < get_water_level(world_x, world_z) - 0.08


func get_scenic_spawn(search_radius: float = 220.0) -> Vector3:
	_ensure_v6_state()
	if not _spawn_cache.has(search_radius):
		_spawn_cache[search_radius] = ScenicSpawn.find_spawn(self, Vector2.ZERO, search_radius)
	return _spawn_cache[search_radius]


func get_continentality(world_x: float, world_z: float) -> float:
	var base: float = super.get_continentality(world_x, world_z)
	var landscape: Dictionary = _planet_profile.get("landscape", {})
	var island_mix: float = float(landscape.get("island_mix", 0.0))
	var islands: float = _normalized_v6(_island_noise, world_x * 2.8, world_z * 2.8)
	return clampf(lerpf(base, islands, island_mix) + float(landscape.get("continental_bias", 0.0)), 0.0, 1.0)


func get_landmarks_near(world_x: float, world_z: float) -> Array[Dictionary]:
	_ensure_v6_state()
	var cell := Vector2i(floori(world_x / Landmarks.CELL_SIZE), floori(world_z / Landmarks.CELL_SIZE))
	var result: Array[Dictionary] = []
	for z in range(-1, 2):
		for x in range(-1, 2):
			var key := cell + Vector2i(x, z)
			if not _landmark_cells.has(key):
				if _landmark_cells.size() >= 256:
					_landmark_cells.clear()
				_landmark_cells[key] = Landmarks.create_cell(int(_planet_profile["planet_seed"]), key, _planet_profile)
			var landmark: Dictionary = _landmark_cells[key]
			if not landmark.is_empty():
				result.append(landmark)
	return result


func get_landscape_height_offset(world_x: float, world_z: float) -> float:
	var total: float = 0.0
	for landmark: Dictionary in get_landmarks_near(world_x, world_z):
		total += Landmarks.height_offset(landmark, Vector2(world_x, world_z))
	return total


func get_ecology_density(world_x: float, world_z: float, terrain_height: float = -9999.0) -> float:
	var base: float = super.get_ecology_density(world_x, world_z, terrain_height)
	# Walk-scale canopy patches complement continental climate. A meadow retains
	# abundant ground cover; only the woody canopy recedes through soft edges.
	var cover: float = smoothstep(0.34, 0.65, _normalized_v6(_canopy_noise, world_x, world_z))
	return clampf(lerpf(base * 0.12, base * 1.20, cover), 0.0, 1.0)


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

	var water: Dictionary = get_water_info(world_x, world_z)
	if not water.is_empty() and float(water["distance"]) < 1.5 and float(water["level"]) > sea_level + 0.5:
		return Biome.LAKE if water["kind"] == "lake" else Biome.RIVER
	if terrain_height < sea_level - 0.45:
		return Biome.OCEAN
	if terrain_height < sea_level + 0.55:
		return Biome.COAST
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
		Biome.DESERT:
			return "desert"
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


func get_biome_composition(world_x: float, world_z: float, terrain_height: float = -9999.0) -> Dictionary:
	var weights: Dictionary = get_biome_weights(world_x, world_z, terrain_height)
	return BiomeGrammar.blend_composition(weights, _planet_profile, world_x, world_z)


func get_temperature(world_x: float, world_z: float, terrain_height: float = -9999.0) -> float:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	return clampf(_normalized_v6(_temperature_noise, world_x, world_z) + float(_planet_profile.get("climate", {}).get("temperature_bias", 0.0)) * 0.34 - maxf(terrain_height - 3.0, 0.0) * 0.014, 0.0, 1.0)


func get_moisture(world_x: float, world_z: float, _terrain_height: float = -9999.0) -> float:
	_ensure_v6_state()
	return clampf(_normalized_v6(_moisture_noise, world_x, world_z) + float(_planet_profile.get("climate", {}).get("moisture_bias", 0.0)) * 0.34, 0.0, 1.0)


func get_biome_weights(world_x: float, world_z: float, terrain_height: float = -9999.0) -> Dictionary:
	_ensure_v6_state()
	if terrain_height < -9000.0:
		terrain_height = get_terrain_height(world_x, world_z)
	var sea: float = get_sea_level()
	var recipe: Dictionary = _planet_profile.get("biome_recipe", {})
	var width: float = float(recipe.get("transition_width", 0.14))
	var ecology: float = get_ecology_density(world_x, world_z, terrain_height)
	var dry: float = clampf(_normalized_v6(_palette_noise, world_x, world_z) + float(recipe.get("dryness_bias", 0.0)) - ecology * 0.18, 0.0, 1.0)
	var forest: float = float(recipe.get("forest_threshold", 0.56))
	var dense: float = float(recipe.get("dense_forest_threshold", 0.79))
	var snow: float = float(_planet_profile.get("snow_start_altitude", 20.0)) + float(recipe.get("alpine_bias", 0.0))
	var weights: Dictionary = {"grassland": 1.0}
	_blend_weight(weights, "steppe", smoothstep(0.57 - width, 0.57 + width, dry))
	_blend_weight(weights, "savanna", smoothstep(0.68 - width, 0.68 + width, dry) * (1.0 - smoothstep(0.45, 0.65, ecology)))
	_blend_weight(weights, "desert", smoothstep(0.83 - width, 0.83 + width, dry) * (1.0 - smoothstep(0.28, 0.48, ecology)))
	_blend_weight(weights, "forest", smoothstep(forest - width, forest + width, ecology))
	_blend_weight(weights, "dense_forest", smoothstep(dense - width, dense + width, ecology))
	var river: float = get_river_strength(world_x, world_z)
	var lake: float = get_lake_strength(world_x, world_z)
	var wet: float = smoothstep(0.48, 0.78, maxf(river, lake)) * (1.0 - smoothstep(2.0, 5.0, terrain_height))
	_blend_weight(weights, "wetland", wet * smoothstep(0.3, 0.65, ecology))
	var rugged: float = float(get_region_profile(world_x, world_z).get("ruggedness", 0.0))
	_blend_weight(weights, "rocky_highlands", smoothstep(0.45, 0.78, rugged) * smoothstep(4.0, 10.0, terrain_height))
	_blend_weight(weights, "alpine", smoothstep(snow - 6.0, snow - 1.0, terrain_height))
	_blend_weight(weights, "snow", smoothstep(snow, snow + 4.0, terrain_height))
	_blend_weight(weights, "coast", 1.0 - smoothstep(sea + 0.25, sea + 1.5, terrain_height))
	_blend_weight(weights, "ocean", 1.0 - smoothstep(sea - 0.85, sea - 0.15, terrain_height))
	var water: Dictionary = get_water_info(world_x, world_z)
	if not water.is_empty() and float(water["level"]) > sea + 0.5:
		var shore: float = 1.0 - smoothstep(0.0, Drainage.BANK_WIDTH, float(water["distance"]))
		_blend_weight(weights, "wetland", shore * 0.5)
		_blend_weight(weights, str(water["kind"]), 1.0 - smoothstep(-1.0, 3.0, float(water["distance"])))
	return weights


func _blend_weight(weights: Dictionary, key: String, amount: float) -> void:
	for old_key in weights:
		weights[old_key] = float(weights[old_key]) * (1.0 - amount)
	weights[key] = float(weights.get(key, 0.0)) + amount


func sample_world(world_x: float, world_z: float) -> Dictionary:
	var result: Dictionary = super.sample_world(world_x, world_z)
	result["temperature"] = get_temperature(world_x, world_z, result["height"])
	result["moisture"] = get_moisture(world_x, world_z, result["height"])
	result["water_level"] = get_water_level(world_x, world_z)
	result["water_depth"] = maxf(0.0, float(result["water_level"]) - float(result["height"]))
	result["water_body"] = str(get_water_info(world_x, world_z).get("kind", "ocean" if float(result["water_depth"]) > 0.0 else "none"))
	return result


func get_biome_color(world_x: float, world_z: float, terrain_height: float = -9999.0) -> Color:
	# A continuous palette field is shared by terrain and ecological composition.
	# Never switch terrain colors using the categorical inspection biome ID.
	var weights: Dictionary = get_biome_weights(world_x, world_z, terrain_height)
	var slots: Dictionary = _planet_profile["material_slots"]
	var ground: Color = slots["ground_base"]
	var dry: Color = slots["ground_dry"]
	var rock: Color = slots["rock_base"]
	var colors: Dictionary = {
		"grassland": ground, "steppe": ground.lerp(dry, 0.46),
		"savanna": ground.lerp(dry, 0.68), "desert": dry,
		"forest": ground.lerp(slots["foliage_shadow"], 0.30),
		"dense_forest": ground.lerp(slots["foliage_shadow"], 0.46),
		"wetland": ground.darkened(0.12), "rocky_highlands": rock,
		"alpine": rock.lightened(0.15), "snow": _planet_profile["palette"]["snow"],
		"river": ground.lerp(slots["coast"], 0.35).darkened(0.10), "lake": slots["coast"],
		"coast": slots["coast"], "ocean": slots["water_deep"],
	}
	var color := Color(0.0, 0.0, 0.0, 0.0)
	for key in weights:
		color += (colors[key] as Color) * float(weights[key])
	color.a = 1.0
	return color
