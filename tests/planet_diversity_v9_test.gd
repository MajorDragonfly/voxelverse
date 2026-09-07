extends SceneTree

const PlanetProfile = preload("res://world/generation/planet_profile_v9.gd")
const BiomeGrammar = preload("res://world/generation/biome_grammar_v9.gd")
const FloraFactory = preload("res://world/visuals/scenery/flora_species_factory_v9.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_test_profile_determinism()
	_test_planet_population_diversity()
	_test_biome_grammar()
	_test_flora_species_variation()
	_finish()


func _test_profile_determinism() -> void:
	var a: Dictionary = PlanetProfile.create(483_927)
	var b: Dictionary = PlanetProfile.create(483_927)
	_expect(
		str(a.get("planet_signature", "")) == str(b.get("planet_signature", "")),
		"Planet signature is not deterministic."
	)
	_expect(
		str(a.get("flora_color_family", "")) == str(b.get("flora_color_family", "")),
		"Flora color family is not deterministic."
	)
	var a_slots: Dictionary = a.get("material_slots", {})
	var b_slots: Dictionary = b.get("material_slots", {})
	_expect(
		a_slots.get("foliage_base") == b_slots.get("foliage_base"),
		"Planet material palette is not deterministic."
	)


func _test_planet_population_diversity() -> void:
	var families: Dictionary = {}
	var terrain_archetypes: Dictionary = {}
	var hue_buckets: Dictionary = {}
	var exotic_count: int = 0
	var trait_count: int = 0
	for seed_value in range(1, 97):
		var profile: Dictionary = PlanetProfile.create(seed_value * 7_919)
		var family: String = str(profile.get("flora_color_family", ""))
		families[family] = true
		terrain_archetypes[str(profile.get("terrain_archetype", ""))] = true
		if float(profile.get("exotic_factor", 0.0)) >= 0.70:
			exotic_count += 1
		trait_count += profile.get("rare_traits", []).size()
		var slots: Dictionary = profile.get("material_slots", {})
		var foliage: Color = slots.get("foliage_base", Color.WHITE)
		var hue_bucket: int = floori(foliage.h * 12.0)
		hue_buckets[hue_bucket] = true
		_expect(
			profile.has("biome_recipe") and profile.has("flora_morphology"),
			"Planet V9 profile is missing scalable generation metadata."
		)
		_expect(
			foliage.r >= 0.0 and foliage.r <= 1.0
			and foliage.g >= 0.0 and foliage.g <= 1.0
			and foliage.b >= 0.0 and foliage.b <= 1.0,
			"Generated foliage color is outside display range."
		)
	_expect(families.size() >= 6, "V9 generated too few flora color families.")
	_expect(hue_buckets.size() >= 5, "V9 foliage palettes occupy too few hue regions.")
	_expect(terrain_archetypes.size() >= 5, "V9 lost terrain archetype diversity.")
	_expect(exotic_count >= 10, "Exotic planet palettes are too rare in the V9 population.")
	_expect(trait_count >= 8, "Rare visual world traits are not appearing often enough.")


func _test_biome_grammar() -> void:
	var profile: Dictionary = PlanetProfile.create(91_177)
	var forest: Dictionary = BiomeGrammar.get_biome_rules("dense_forest", profile)
	var alpine: Dictionary = BiomeGrammar.get_biome_rules("alpine", profile)
	_expect(
		float(forest.get("tree_density", 0.0)) > float(alpine.get("tree_density", 0.0)),
		"Biome grammar does not distinguish forest and alpine tree density."
	)
	var variant_a: String = BiomeGrammar.choose_local_variant(
		"forest",
		profile,
		192.0,
		-384.0
	)
	var variant_b: String = BiomeGrammar.choose_local_variant(
		"forest",
		profile,
		192.0,
		-384.0
	)
	_expect(variant_a == variant_b, "Local biome variants are not deterministic.")
	_expect(variant_a != "", "Biome grammar returned an empty local variant.")


func _test_flora_species_variation() -> void:
	var profile: Dictionary = PlanetProfile.create(771_221)
	var species_a: Dictionary = FloraFactory.create_species_variant(
		profile,
		"forest",
		"oak_broad",
		0
	)
	var species_b: Dictionary = FloraFactory.create_species_variant(
		profile,
		"forest",
		"oak_broad",
		1
	)
	var species_repeat: Dictionary = FloraFactory.create_species_variant(
		profile,
		"forest",
		"oak_broad",
		0
	)
	_expect(
		str(species_a.get("species_id", "")) == str(species_repeat.get("species_id", "")),
		"Flora species recipe is not deterministic."
	)
	_expect(
		float(species_a.get("height_scale", 1.0))
		!= float(species_b.get("height_scale", 1.0))
		or float(species_a.get("width_scale", 1.0))
		!= float(species_b.get("width_scale", 1.0)),
		"Two species variants collapsed to identical morphology."
	)
	var instance_a: Dictionary = FloraFactory.create_instance_variation(species_a, 100)
	var instance_b: Dictionary = FloraFactory.create_instance_variation(species_a, 101)
	_expect(
		float(instance_a.get("rotation_y", 0.0))
		!= float(instance_b.get("rotation_y", 0.0)),
		"Flora instances are not receiving visible per-instance variation."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Planet Diversity V9 test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
