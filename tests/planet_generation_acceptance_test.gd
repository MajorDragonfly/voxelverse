extends SceneTree

const Generator = preload("res://world/generation/world_generator_planetary_v9.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
const Slots = preload("res://assets/catalog/planet_material_slots.gd")
const Grammar = preload("res://world/generation/biome_grammar_v9.gd")
const Flora = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")
const Spawn = preload("res://world/generation/adventure_spawn_selector.gd")
var _failures: Array[String] = []

# Same distant water, with an optional nearer ridge that should occlude it.
class ViewFixture extends Node:
	var occluded: bool = false
	func get_sea_level() -> float: return 0.0
	func get_terrain_height(x: float, z: float) -> float:
		var distance: float = Vector2(x, z).length()
		if occluded and distance >= 12.0 and distance <= 32.0:
			return 16.0
		return -1.0 if distance >= 55.0 else 2.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator := Generator.new()
	var comparison := Generator.new()
	generator.set_seed_override(7919)
	comparison.set_seed_override(7919)
	generator.get_terrain_height(100.001, -81.001)
	comparison.get_terrain_height(100.004, -81.004)
	_expect(generator.get_terrain_height(100.002, -81.002) == comparison.get_terrain_height(100.002, -81.002), "Height cache depends on previous query order.")
	comparison.free()
	var natural: int = 0
	var exotic: int = 0
	var landscape_kinds: Dictionary = {}
	var variants_seen: Dictionary = {}
	var min_tree_density: float = INF
	var max_tree_density: float = -INF
	for index in range(1, 97):
		var seed_value: int = index * 7919
		var profile: Dictionary = Profile.create(seed_value)
		_expect(profile == Profile.create(seed_value), "Complete profile is not deterministic: %s" % seed_value)
		_expect(Slots.validate(profile["material_slots"]).is_empty(), "Incomplete/invalid material slots: %s" % seed_value)
		var family: String = profile["flora_color_family"]
		natural += 1 if family in ["verdant", "autumn", "gold"] else 0
		exotic += 1 if family in ["violet", "cyan", "coral", "crimson", "pale", "indigo"] else 0
		if family == "violet":
			var palette: Dictionary = profile["material_slots"]
			_expect(absf((palette["shrub_base"] as Color).h - 0.49) < 0.02, "Violet flora lost curated turquoise companion shrubs.")
			_expect(absf((palette["rock_base"] as Color).h - 0.64) < 0.02, "Violet flora lost blue rock family.")
		var species: Dictionary = Flora.create_species_variant(profile, "forest", "ancient_oak_v2", 1)
		_expect(species == Flora.create_species_variant(profile, "forest", "ancient_oak_v2", 1), "Complete species recipe is not deterministic.")
		_expect(Flora.create_instance_variation(species, 17) == Flora.create_instance_variation(species, 17), "Individual variation is not deterministic.")
		_expect(species["palette"]["bark_base"] == profile["material_slots"]["bark_base"], "Species palette recolors planet bark independently.")
		generator.set_seed_override(seed_value)
		# Every tested planet must offer a dry, walkable scenic spawn, even when
		# the starting search disk lies in a sea. Probe the actual terrain there.
		var spawn: Vector3 = generator.get_scenic_spawn(90.0)
		_expect(spawn == generator.get_scenic_spawn(90.0), "Cached scenic spawn changed.")
		_expect(generator.get_terrain_height(spawn.x, spawn.z) >= generator.get_sea_level() + 0.70, "Spawn is over water: %s at %s" % [seed_value, spawn])
		_expect(generator.get_terrain_slope(spawn.x, spawn.z, 0.75) <= 0.45, "Spawn is not walkable: %s" % seed_value)
		var weights: Dictionary = generator.get_biome_weights(spawn.x, spawn.z)
		_check_weights(weights, "biome")
		var composition: Dictionary = generator.get_biome_composition(spawn.x, spawn.z)
		_check_weights(composition["variant_weights"], "variant")
		for weight: float in composition["families"].values():
			_expect(is_finite(weight) and weight >= 0.0, "Invalid family placement weight.")
		for landmark: Dictionary in generator.get_landmarks_near(spawn.x, spawn.z):
			landscape_kinds[landmark["kind"]] = true
		var forest: Dictionary = Grammar.blend_composition({"forest": 1.0}, profile, 0.0, 0.0)
		min_tree_density = minf(min_tree_density, forest["tree_density"])
		max_tree_density = maxf(max_tree_density, forest["tree_density"])
		for variant: String in forest["variant_weights"]:
			variants_seen[variant] = true
		# Test the unquantized grammar across positive/negative cell boundaries.
		for edge: float in [-256.0, -96.0, 0.0, 96.0, 256.0]:
			var a: Color = generator.get_biome_color(edge - 0.0005, 47.0, 4.0)
			var b: Color = generator.get_biome_color(edge + 0.0005, 47.0, 4.0)
			_expect(Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.005, "Hard biome color seam seed=%s edge=%s delta=%s" % [seed_value, edge, Vector3(a.r-b.r, a.g-b.g, a.b-b.b).length()])
			var fa: Dictionary = Grammar.blend_composition({"forest": 1.0}, profile, edge - 0.01, 47.0)
			var fb: Dictionary = Grammar.blend_composition({"forest": 1.0}, profile, edge + 0.01, 47.0)
			_expect(absf(float(fa["tree_density"]) - float(fb["tree_density"])) < 0.005, "Hard forest variant density seam.")
			_expect(absf(generator.get_landscape_height_offset(edge - 0.01, 47.0) - generator.get_landscape_height_offset(edge + 0.01, 47.0)) < 0.06, "Landmark cell seam.")
	var dry_open: int = 0
	var dry_forested: int = 0
	for seed_value in [7919, 15838, 23757, 31676, 39595, 47514]:
		generator.set_seed_override(seed_value)
		var spawn: Vector3 = generator.get_scenic_spawn()
		var low: float = INF
		var high: float = -INF
		for z in range(-8, 9):
			for x in range(-8, 9):
				var point := Vector2(spawn.x + x * 24.0, spawn.z + z * 24.0)
				var height: float = generator.get_terrain_height(point.x, point.y)
				low = minf(low, height)
				high = maxf(high, height)
				if height > generator.get_sea_level() + 0.5:
					var composition: Dictionary = generator.get_biome_composition(point.x, point.y, height)
					dry_open += int(float(composition["tree_density"]) < 0.18)
					dry_forested += int(float(composition["tree_density"]) > 0.65)
		_expect(high - low > 22.0, "Representative planet lacks walk-scale landscape relief: %d." % seed_value)
	_expect(dry_open > 200 and dry_forested > 50, "Planet surfaces lost their meadow/forest composition contrast.")
	generator.free()
	_expect(natural > 15 and exotic > 15, "Missing natural or exotic palette population.")
	_expect(landscape_kinds.size() >= 5, "Landscape grammar lost formation diversity.")
	_expect(variants_seen.size() >= 5 and max_tree_density - min_tree_density > 0.2, "Forest variants do not vary composition.")
	var view := ViewFixture.new()
	var open: Dictionary = Spawn.evaluate_view(view, Vector2.ZERO, 2.0)
	view.occluded = true
	var blocked: Dictionary = Spawn.evaluate_view(view, Vector2.ZERO, 2.0)
	_expect(open["water_samples"] > 0 and blocked["water_samples"] == 0, "Scenic viewshed rewards water hidden behind relief.")
	view.free()
	print("Planet acceptance: 96 seeds; natural=%s exotic=%s formations=%s forest_variants=%s" % [natural, exotic, landscape_kinds.size(), variants_seen.size()])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)

func _check_weights(weights: Dictionary, label: String) -> void:
	var total: float = 0.0
	for value: float in weights.values():
		_expect(is_finite(value) and value >= 0.0, "Invalid %s weight." % label)
		total += value
	_expect(absf(total - 1.0) < 0.0002, "Unnormalized %s weights: %s" % [label, total])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
