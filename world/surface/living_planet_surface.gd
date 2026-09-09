extends "res://world/space/planet_surface.gd"

## A new, explicitly versioned spherical landscape. Reuses the campaign's V9
## planet profile, biome grammar and material slots. The field is continuous in
## body-fixed 3D, including cube edges/poles; legacy X/Z terrain is never bent.
const GENERATION: String = "living_planet_v1"
const Grammar = preload("res://world/generation/biome_grammar_v9.gd")


func height_precise(d: Array) -> float:
	var p: Array = [d[0] * body.radius, d[1] * body.radius, d[2] * body.radius]
	var land: float = ValueField.sample(d, 0.38, body.seed) * 100.0
	var region: float = ValueField.sample(p, 1800.0, body.seed + 733)
	var ridge: float = 1.0 - absf(ValueField.sample(p, 520.0, body.seed + 937))
	var hills: float = ValueField.sample(p, 160.0, body.seed + 1973) * 9.0
	var mountains: float = smoothstep(0.1, 0.8, region) * ridge * ridge * 150.0
	return land + region * 38.0 + mountains + hills \
		+ ValueField.sample(p, 32.0, body.seed + 2777) * 1.1


func fields(d: Array, height: float) -> Dictionary:
	var p: Array = [d[0] * body.radius, d[1] * body.radius, d[2] * body.radius]
	var climate: Dictionary = terrain.climate
	var wet: float = clampf(0.5 + ValueField.sample(p, 900.0, body.seed + 3119) * 0.5 + climate.moisture_bias * 0.12, 0.0, 1.0)
	var canopy: float = 0.5 + ValueField.sample(p, 125.0, body.seed + 4111) * 0.5
	var temperature: float = clampf(1.0 - absf(d[1]) * 0.85 - maxf(height, 0.0) / 260.0 + climate.temperature_bias * 0.12, 0.0, 1.0)
	var forest: float = smoothstep(0.3, 0.65, wet) * smoothstep(0.3, 0.7, canopy)
	var weights: Dictionary = {"grassland": 1.0}
	_blend(weights, "savanna", smoothstep(0.5, 0.85, 1.0 - wet))
	_blend(weights, "desert", smoothstep(0.75, 0.95, 1.0 - wet))
	_blend(weights, "forest", forest)
	_blend(weights, "dense_forest", smoothstep(0.6, 0.95, forest))
	_blend(weights, "rocky_highlands", smoothstep(52.0, 98.0, height))
	_blend(weights, "alpine", smoothstep(100.0, 135.0, height))
	_blend(weights, "snow", maxf(smoothstep(130.0, 165.0, height), 1.0 - smoothstep(0.08, 0.22, temperature)))
	_blend(weights, "coast", 1.0 - smoothstep(0.6, 3.5, height))
	_blend(weights, "ocean", 1.0 - smoothstep(-1.5, -0.2, height))
	var biome: String = "grassland"
	var largest: float = -1.0
	for key: String in weights:
		if weights[key] > largest:
			largest = weights[key]
			biome = key
	return {"weights": weights, "biome": biome, "moisture": wet, "temperature": temperature, "canopy": forest}


func _blend(weights: Dictionary, key: String, amount: float) -> void:
	for old: String in weights:
		weights[old] *= 1.0 - amount
	weights[key] = amount


func _sample(d: Array) -> Dictionary:
	var height: float = height_precise(d)
	var field: Dictionary = fields(d, height)
	return {"height": height, "water_level": 0.0, "water": height < -0.08,
		"normal": normal_precise(d), "biome": field.biome, "temperature": field.temperature,
		"moisture": field.moisture, "biome_weights": field.weights, "canopy": field.canopy, "blocked": false}


func composition(address: Dictionary) -> Dictionary:
	var d: Array = Cube.direction(address.face, address.u, address.v)
	var field: Dictionary = fields(d, height_precise(d))
	return Grammar.blend_composition(field.weights, terrain, d[0] * body.radius, d[2] * body.radius)


func color_at(d: Vector3, height: float) -> Color:
	var weights: Dictionary = fields([d.x, d.y, d.z], height).weights
	var slots: Dictionary = terrain.material_slots
	var ground: Color = slots.ground_base
	var rock: Color = slots.rock_base
	var pigments: Dictionary = {"grassland": ground, "savanna": ground.lerp(slots.ground_dry, 0.68),
		"desert": slots.ground_dry, "forest": ground.lerp(slots.foliage_shadow, 0.30),
		"dense_forest": ground.lerp(slots.foliage_shadow, 0.46), "rocky_highlands": rock,
		"alpine": rock.lightened(0.15), "snow": terrain.palette.snow,
		"coast": slots.coast, "ocean": slots.coast.darkened(0.2)}
	var result := Color(0, 0, 0, 0)
	for key: String in weights:
		result += pigments[key] * weights[key]
	return result
