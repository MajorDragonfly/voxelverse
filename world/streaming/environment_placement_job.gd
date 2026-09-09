extends RefCounted

# CPU data only. This job owns a detached generator and never touches scene-tree
# nodes, resource loading, rendering or physics. The owner joins it on unload.
const FloraFactory = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
var generator_script: Script
var world_seed: int
var chunk_origin: Vector2
var width: float
var depth: float
var cell_size: float
var heights := PackedFloat32Array()
var height_width: int
var height_depth: int
var spawn_clear_center: Vector2
var recipes: Array[Dictionary] = []
var result: Dictionary = {}
var elapsed_usec: int = 0
var _generator: Node
var _batches: Dictionary = {}
var _tree_points: Array[Vector2] = []
var placement_attempt_count: int = 0
var instance_count: int = 0

static func tree_recipe(attempts: int = 16, density: float = 1.55) -> Dictionary:
	return {"group": "tree", "attempts": roundi(attempts * density), "families": ["ancient_oak_v2", "tall_pine_v2"], "chance": 0.70, "slope": 0.52}

func run(reusable_generator: Node = null) -> void:
	var started: int = Time.get_ticks_usec()
	_generator = reusable_generator
	if _generator == null:
		_generator = generator_script.new()
		_generator.set_seed_override(world_seed)
	var profile: Dictionary = _generator.get_planet_profile()
	var random := RandomNumberGenerator.new()
	random.seed = world_seed + roundi(chunk_origin.x / width) * 73_856_093 + roundi(chunk_origin.y / depth) * 19_349_663 + 2_104_729_311
	for recipe: Dictionary in recipes:
		for attempt in range(int(recipe["attempts"])):
			_place_attempt(random, profile, recipe, attempt)
	result = {"batches": _batches, "attempts": placement_attempt_count, "instances": instance_count}
	if reusable_generator == null:
		_generator.free()
	_generator = null
	elapsed_usec = Time.get_ticks_usec() - started

func _surface_height(x: float, z: float) -> float:
	var ix: int = clampi(floori((x + width * 0.5) / cell_size), 0, height_width - 3)
	var iz: int = clampi(floori((z + depth * 0.5) / cell_size), 0, height_depth - 3)
	if heights.is_empty():
		# The distant tree preview samples the same cell centres without making
		# collision chunks or a complete height grid for every forest tile.
		var point: Vector2 = chunk_origin + Vector2((ix + 0.5) * cell_size - width * 0.5, (iz + 0.5) * cell_size - depth * 0.5)
		return _generator.get_visual_terrain_height(point.x, point.y)
	return heights[(iz + 1) * height_width + ix + 1]

func _sample_point(random: RandomNumberGenerator, maximum_slope: float) -> Dictionary:
	var margin: float = minf(1.5, width * 0.18)
	var x: float = random.randf_range(-width * 0.5 + margin, width * 0.5 - margin)
	var z: float = random.randf_range(-depth * 0.5 + margin, depth * 0.5 - margin)
	var wx: float = chunk_origin.x + x
	var wz: float = chunk_origin.y + z
	var logical: float = _generator.get_terrain_height(wx, wz)
	if logical <= _generator.get_water_level(wx, wz) + 0.25:
		return {}
	var surface: float = _surface_height(x, z)
	var slope: float = maxf(absf(_surface_height(x + 0.75, z) - surface), absf(_surface_height(x, z + 0.75) - surface)) / 0.75
	if slope > maximum_slope:
		return {}
	return {"local_x": x, "local_z": z, "world_x": wx, "world_z": wz, "logical_height": logical, "surface_height": surface}

func _choose_species(composition: Dictionary, family: String, random: RandomNumberGenerator) -> int:
	var weights: Dictionary = composition.get("biome_weights", {})
	var open: float = float(composition.get("openness", 0.0))
	var alpine: float = float(weights.get("alpine", 0.0)) + float(weights.get("rocky_highlands", 0.0))
	var roll: float = random.randf()
	if "oak" in family:
		return 1 if roll < 0.15 + open * 0.65 else (2 if roll > 0.70 else 0)
	if "pine" in family:
		return 2 if roll < alpine * 0.7 else (1 if roll > 0.62 else 0)
	return random.randi_range(0, 2)

func _place_attempt(random: RandomNumberGenerator, profile: Dictionary, recipe: Dictionary, attempt: int) -> void:
	placement_attempt_count += 1
	var point: Dictionary = _sample_point(random, float(recipe["slope"]))
	if point.is_empty():
		return
	var wx: float = float(point["world_x"])
	var wz: float = float(point["world_z"])
	var tree: bool = recipe["group"] == "tree"
	if recipe["group"] in ["tree", "shrub", "rock"] and Vector2(wx, wz).distance_to(spawn_clear_center) < (9.0 if tree else 3.5):
		return
	var composition: Dictionary = _generator.get_biome_composition(wx, wz, point["logical_height"])
	var families: Dictionary = composition.get("families", {})
	var options: Array = recipe["families"]
	var total: float = 0.0
	for family: String in options:
		total += float(families.get(family, 0.0))
	if random.randf() >= minf(total * float(recipe["chance"]), 0.98):
		return
	if tree:
		for existing: Vector2 in _tree_points:
			if existing.distance_squared_to(Vector2(wx, wz)) < 36.0:
				return
	var roll: float = random.randf() * total
	var selected: String = str(options[0])
	for family: String in options:
		selected = family
		roll -= float(families.get(family, 0.0))
		if roll <= 0.0:
			break
	var species_index: int = _choose_species(composition, selected, random)
	var key: String = "%s_%d" % [selected, species_index]
	if not _batches.has(key):
		var species: Dictionary = FloraFactory.create_species_variant(profile, ("forest" if species_index == 0 else ("savanna" if species_index == 1 else "alpine")) if tree else "grassland", selected, species_index)
		_batches[key] = {"asset_id": selected, "species": species, "transforms": [], "custom": [], "tree": tree, "node": null}
	var batch: Dictionary = _batches[key]
	var species: Dictionary = batch["species"]
	var individual: Dictionary = FloraFactory.create_instance_variation(species, random.randi() + attempt)
	var scale_value: float = float(individual["uniform_scale"])
	var height: float = clampf(float(species["height_scale"]), 0.72, 1.26) * float(individual["height_multiplier"])
	var breadth: float = clampf(float(species["width_scale"]), 0.76, 1.18) * float(individual["width_multiplier"])
	if not tree:
		height = lerpf(1.0, height, 0.35)
		breadth = lerpf(1.0, breadth, 0.35)
		scale_value = clampf(scale_value, 0.82, 1.18)
	var basis := Basis(Vector3.UP, deg_to_rad(float(individual["rotation_y"])))
	basis = basis.rotated(basis.z.normalized(), deg_to_rad(float(individual["lean_degrees"])) * (0.55 if tree else 1.0))
	basis = basis.scaled(Vector3(breadth, height, breadth) * scale_value)
	var transform := Transform3D(basis, Vector3(point["local_x"], float(point["surface_height"]) - 0.035, point["local_z"]))
	batch["transforms"].append(transform)
	batch["custom"].append(Color(lerpf(0.95, 1.03, float(individual["health"])), random.randf(), float(individual["age"]), 1.0))
	if tree:
		_tree_points.append(Vector2(wx, wz))
	instance_count += 1

