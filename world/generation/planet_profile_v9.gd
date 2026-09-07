extends RefCounted
class_name PlanetProfileV9

const BaseProfile = preload("res://world/generation/planet_profile_v8.gd")

const FLORA_FAMILIES: Array[Dictionary] = [
	{"id": "verdant", "hue": 0.30, "weight": 0.34},
	{"id": "autumn", "hue": 0.075, "weight": 0.11},
	{"id": "violet", "hue": 0.77, "weight": 0.13},
	{"id": "cyan", "hue": 0.50, "weight": 0.09},
	{"id": "coral", "hue": 0.98, "weight": 0.08},
	{"id": "gold", "hue": 0.13, "weight": 0.08},
	{"id": "crimson", "hue": 0.96, "weight": 0.07},
	{"id": "pale", "hue": 0.20, "weight": 0.05},
	{"id": "indigo", "hue": 0.66, "weight": 0.05},
]

const ARCHITECTURE_STYLES: Array[String] = [
	"broad_crown",
	"columnar",
	"conifer",
	"windswept",
	"ancient_massive",
	"wetland",
	"fungal",
	"spire",
	"fan_crown",
]


static func create(seed_value: int) -> Dictionary:
	var profile: Dictionary = BaseProfile.create(seed_value)
	var random := RandomNumberGenerator.new()
	random.seed = seed_value * 1_934_963 + 91_771_033

	var flora_family: Dictionary = _choose_weighted(random, FLORA_FAMILIES)
	var flora_id: String = str(flora_family.get("id", "verdant"))
	var flora_hue: float = wrapf(
		float(flora_family.get("hue", 0.30)) + random.randf_range(-0.045, 0.045),
		0.0,
		1.0
	)
	var exotic_factor: float = _exotic_factor_for_family(flora_id)
	var climate: Dictionary = _create_climate(random, profile)
	var morphology: Dictionary = _create_flora_morphology(random, exotic_factor)
	var material_slots: Dictionary = _create_material_slots(
		random,
		flora_hue,
		flora_id,
		exotic_factor
	)
	var atmosphere: Dictionary = _create_atmosphere(
		random,
		material_slots,
		exotic_factor
	)
	var biome_recipe: Dictionary = _create_biome_recipe(
		random,
		climate,
		morphology
	)
	var rare_traits: Array[String] = _create_rare_traits(
		random,
		flora_id,
		morphology,
		exotic_factor
	)

	var palette: Dictionary = profile.get("palette", {}).duplicate(true)
	palette["grass"] = material_slots.get("ground_base", palette.get("grass"))
	palette["forest"] = material_slots.get("foliage_shadow", palette.get("forest"))
	palette["dry"] = material_slots.get("ground_dry", palette.get("dry"))
	palette["rock"] = material_slots.get("rock_base", palette.get("rock"))
	palette["coast"] = material_slots.get("coast", palette.get("coast"))
	palette["water"] = material_slots.get("water_deep", palette.get("water"))
	profile["palette"] = palette

	profile["schema"] = 3
	profile["visual_generation_version"] = 9
	profile["flora_color_family"] = flora_id
	profile["exotic_factor"] = exotic_factor
	profile["climate"] = climate
	profile["flora_morphology"] = morphology
	profile["material_slots"] = material_slots
	profile["atmosphere"] = atmosphere
	profile["biome_recipe"] = biome_recipe
	profile["rare_traits"] = rare_traits
	profile["planet_signature"] = _create_signature(
		seed_value,
		flora_id,
		str(profile.get("terrain_archetype", "World")),
		rare_traits
	)
	return profile


static func _create_climate(
	random: RandomNumberGenerator,
	profile: Dictionary
) -> Dictionary:
	var terrain_style: int = int(profile.get("terrain_style", 0))
	var temperature: float = random.randf_range(-0.82, 0.88)
	var moisture: float = random.randf_range(-0.78, 0.92)
	if terrain_style == 3:
		moisture += 0.22
	elif terrain_style == 2:
		moisture -= 0.22
		temperature += 0.10
	elif terrain_style == 5:
		temperature -= 0.28
	return {
		"temperature_bias": clampf(temperature, -1.0, 1.0),
		"moisture_bias": clampf(moisture, -1.0, 1.0),
		"fertility": random.randf_range(0.42, 1.0),
		"seasonality": random.randf_range(0.08, 0.82),
		"storminess": random.randf_range(0.04, 0.76),
	}


static func _create_flora_morphology(
	random: RandomNumberGenerator,
	exotic_factor: float
) -> Dictionary:
	var primary_style: String = ARCHITECTURE_STYLES[
		random.randi_range(0, ARCHITECTURE_STYLES.size() - 1)
	]
	var secondary_style: String = ARCHITECTURE_STYLES[
		random.randi_range(0, ARCHITECTURE_STYLES.size() - 1)
	]
	if secondary_style == primary_style:
		secondary_style = ARCHITECTURE_STYLES[
			(posmod(ARCHITECTURE_STYLES.find(primary_style) + 3, ARCHITECTURE_STYLES.size()))
		]
	return {
		"primary_architecture": primary_style,
		"secondary_architecture": secondary_style,
		"height_scale": random.randf_range(0.72, 1.62 + exotic_factor * 0.42),
		"width_scale": random.randf_range(0.72, 1.48 + exotic_factor * 0.30),
		"crown_density": random.randf_range(0.48, 1.0),
		"branch_density": random.randf_range(0.42, 1.0),
		"trunk_taper": random.randf_range(0.42, 0.92),
		"trunk_twist": random.randf_range(0.0, 0.28 + exotic_factor * 0.42),
		"asymmetry": random.randf_range(0.06, 0.38 + exotic_factor * 0.28),
		"canopy_layer_min": random.randi_range(2, 4),
		"canopy_layer_max": random.randi_range(5, 9),
		"giant_flora_chance": random.randf_range(0.015, 0.08 + exotic_factor * 0.08),
		"deadwood_chance": random.randf_range(0.025, 0.14),
		"ground_cover_scale": random.randf_range(0.60, 1.55),
	}


static func _create_material_slots(
	random: RandomNumberGenerator,
	flora_hue: float,
	flora_id: String,
	exotic_factor: float
) -> Dictionary:
	var saturation: float = random.randf_range(0.48, 0.82)
	if flora_id == "pale":
		saturation *= 0.34
	var foliage_base := Color.from_hsv(
		flora_hue,
		clampf(saturation + exotic_factor * 0.08, 0.18, 0.92),
		random.randf_range(0.50, 0.76),
		1.0
	)
	var foliage_highlight := Color.from_hsv(
		wrapf(flora_hue + random.randf_range(-0.018, 0.018), 0.0, 1.0),
		clampf(saturation * 0.84, 0.15, 0.88),
		clampf(foliage_base.v + 0.17, 0.0, 1.0),
		1.0
	)
	var foliage_shadow: Color = foliage_base.darkened(0.34)
	var foliage_deep: Color = foliage_base.darkened(0.56)

	var bark_hue: float = wrapf(flora_hue + random.randf_range(0.08, 0.28), 0.0, 1.0)
	if exotic_factor < 0.25:
		bark_hue = random.randf_range(0.045, 0.105)
	var bark_base := Color.from_hsv(
		bark_hue,
		random.randf_range(0.22, 0.52),
		random.randf_range(0.30, 0.52),
		1.0
	)
	var ground_base: Color = foliage_base.lerp(
		Color.from_hsv(wrapf(flora_hue + 0.045, 0.0, 1.0), 0.48, 0.48, 1.0),
		0.56
	)
	var dry_hue: float = wrapf(flora_hue - 0.17 + random.randf_range(-0.04, 0.04), 0.0, 1.0)
	var ground_dry := Color.from_hsv(
		dry_hue,
		random.randf_range(0.34, 0.64),
		random.randf_range(0.56, 0.76),
		1.0
	)
	var rock_hue: float = wrapf(flora_hue + random.randf_range(0.20, 0.46), 0.0, 1.0)
	var rock_base := Color.from_hsv(
		rock_hue,
		random.randf_range(0.06, 0.26 + exotic_factor * 0.12),
		random.randf_range(0.34, 0.58),
		1.0
	)
	var water_hue: float = wrapf(flora_hue + random.randf_range(0.18, 0.43), 0.0, 1.0)
	var water_deep := Color.from_hsv(
		water_hue,
		random.randf_range(0.60, 0.90),
		random.randf_range(0.34, 0.58),
		1.0
	)
	var flower_hue: float = wrapf(flora_hue + random.randf_range(0.22, 0.56), 0.0, 1.0)
	return {
		"foliage_highlight": foliage_highlight,
		"foliage_base": foliage_base,
		"foliage_shadow": foliage_shadow,
		"foliage_deep": foliage_deep,
		"bark_highlight": bark_base.lightened(0.18),
		"bark_base": bark_base,
		"bark_shadow": bark_base.darkened(0.38),
		"ground_base": ground_base,
		"ground_shadow": ground_base.darkened(0.30),
		"ground_dry": ground_dry,
		"flower_primary": Color.from_hsv(flower_hue, 0.72, 0.90, 1.0),
		"flower_accent": Color.from_hsv(wrapf(flower_hue + 0.10, 0.0, 1.0), 0.64, 0.96, 1.0),
		"rock_light": rock_base.lightened(0.18),
		"rock_base": rock_base,
		"rock_dark": rock_base.darkened(0.32),
		"coast": ground_dry.lerp(Color(0.84, 0.74, 0.54, 1.0), 0.46),
		"water_shallow": water_deep.lightened(0.23),
		"water_deep": water_deep,
	}


static func _create_atmosphere(
	random: RandomNumberGenerator,
	materials: Dictionary,
	exotic_factor: float
) -> Dictionary:
	var water: Color = materials.get("water_deep", Color(0.08, 0.36, 0.50, 1.0))
	var foliage: Color = materials.get("foliage_base", Color(0.24, 0.52, 0.26, 1.0))
	var horizon: Color = water.lerp(foliage, 0.18 + exotic_factor * 0.18).lightened(0.28)
	var sky_top: Color = horizon.darkened(random.randf_range(0.10, 0.28))
	return {
		"sky_top": sky_top,
		"sky_horizon": horizon,
		"fog_color": horizon.lerp(Color(0.72, 0.76, 0.82, 1.0), 0.28),
		"fog_density_scale": random.randf_range(0.68, 1.42),
		"sun_energy_scale": random.randf_range(0.82, 1.22),
		"ambient_scale": random.randf_range(0.82, 1.18),
		"cloud_density": random.randf_range(0.20, 0.74),
	}


static func _create_biome_recipe(
	random: RandomNumberGenerator,
	climate: Dictionary,
	morphology: Dictionary
) -> Dictionary:
	var moisture: float = float(climate.get("moisture_bias", 0.0))
	var temperature: float = float(climate.get("temperature_bias", 0.0))
	return {
		"forest_threshold": clampf(0.56 - moisture * 0.10, 0.42, 0.68),
		"dense_forest_threshold": clampf(0.79 - moisture * 0.08, 0.65, 0.88),
		"wetland_threshold": clampf(0.58 - moisture * 0.10, 0.44, 0.72),
		"dryness_bias": clampf(-moisture * 0.18 + temperature * 0.10, -0.22, 0.28),
		"alpine_bias": clampf(-temperature * 2.2, -2.8, 2.8),
		"understory_density": clampf(
			float(morphology.get("ground_cover_scale", 1.0)) * (1.0 + moisture * 0.20),
			0.45,
			1.80
		),
		"transition_width": random.randf_range(0.08, 0.22),
	}


static func _create_rare_traits(
	random: RandomNumberGenerator,
	flora_id: String,
	morphology: Dictionary,
	exotic_factor: float
) -> Array[String]:
	var traits: Array[String] = []
	if flora_id in ["violet", "cyan", "coral", "crimson", "indigo"]:
		traits.append("exotic_foliage")
	if float(morphology.get("giant_flora_chance", 0.0)) > 0.10:
		traits.append("giant_flora")
	if float(morphology.get("asymmetry", 0.0)) > 0.46:
		traits.append("twisted_growth")
	if random.randf() < 0.12 + exotic_factor * 0.14:
		traits.append("hero_flora_fields")
	if random.randf() < 0.10:
		traits.append("monolith_rocks")
	if random.randf() < 0.08 + exotic_factor * 0.10:
		traits.append("unusual_water_palette")
	return traits


static func _create_signature(
	seed_value: int,
	flora_id: String,
	terrain_archetype: String,
	rare_traits: Array[String]
) -> String:
	var trait: String = "PRIME"
	if not rare_traits.is_empty():
		trait = rare_traits[0].to_upper()
	var terrain: String = terrain_archetype.to_upper().replace(" ", "_")
	return "%s-%s-%s-%04X" % [
		flora_id.to_upper(),
		terrain,
		trait,
		absi(seed_value) & 0xFFFF,
	]


static func _exotic_factor_for_family(flora_id: String) -> float:
	match flora_id:
		"verdant":
			return 0.08
		"autumn", "gold":
			return 0.18
		"pale":
			return 0.42
		"violet", "cyan", "coral", "crimson", "indigo":
			return 0.78
	return 0.25


static func _choose_weighted(
	random: RandomNumberGenerator,
	entries: Array[Dictionary]
) -> Dictionary:
	var total: float = 0.0
	for entry in entries:
		total += maxf(float(entry.get("weight", 0.0)), 0.0)
	if total <= 0.0:
		return entries[0] if not entries.is_empty() else {}
	var roll: float = random.randf_range(0.0, total)
	var cursor: float = 0.0
	for entry in entries:
		cursor += maxf(float(entry.get("weight", 0.0)), 0.0)
		if roll <= cursor:
			return entry.duplicate(true)
	return entries.back().duplicate(true)
