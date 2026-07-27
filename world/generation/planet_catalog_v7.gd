extends RefCounted
class_name PlanetCatalogV7

const PlanetProfile = preload(
	"res://world/generation/planet_profile_v6.gd"
)

const PLANET_CLASSES: Array[String] = [
	"temperate",
	"oceanic",
	"arid",
	"alpine",
	"verdant",
	"rugged",
]

const STAR_PREFIXES: Array[String] = [
	"Aster",
	"Cygna",
	"Helion",
	"Novera",
	"Orialis",
	"Vesper",
]


static func create_system(system_seed: int) -> Dictionary:
	var safe_seed: int = maxi(absi(system_seed), 1)
	var random := RandomNumberGenerator.new()
	random.seed = safe_seed * 1_000_003 + 7_919
	var planet_count: int = random.randi_range(3, 6)
	var planets: Array = []
	for planet_index in range(planet_count):
		var planet_seed: int = safe_seed
		if planet_index > 0:
			planet_seed = absi(
				safe_seed
				+ (planet_index + 1) * 83_492_791
				+ random.randi_range(1, 2_000_000_000)
			)
		planet_seed = maxi(planet_seed, 1)
		var profile: Dictionary = PlanetProfile.create(planet_seed)
		var planet_class: String = PLANET_CLASSES[
			posmod(planet_seed + planet_index, PLANET_CLASSES.size())
		]
		planets.append({
			"index": planet_index,
			"planet_seed": planet_seed,
			"name": _planet_name(safe_seed, planet_index),
			"planet_class": planet_class,
			"orbit_radius": 0.72 + float(planet_index) * random.randf_range(0.42, 0.78),
			"orbit_speed": random.randf_range(0.16, 0.72) / float(planet_index + 1),
			"axial_tilt": random.randf_range(-28.0, 28.0),
			"surface_gravity": random.randf_range(0.72, 1.28),
			"profile": profile,
		})
	return {
		"schema": 1,
		"system_seed": safe_seed,
		"system_name": "%s-%04d" % [
			STAR_PREFIXES[posmod(safe_seed, STAR_PREFIXES.size())],
			posmod(safe_seed, 10_000),
		],
		"star_temperature": random.randf_range(3800.0, 7800.0),
		"star_energy": random.randf_range(0.78, 1.28),
		"planets": planets,
	}


static func get_planet(
	system: Dictionary,
	planet_index: int
) -> Dictionary:
	var planets: Array = system.get("planets", [])
	if planets.is_empty():
		return {}
	var safe_index: int = posmod(planet_index, planets.size())
	if planets[safe_index] is Dictionary:
		return planets[safe_index].duplicate(true)
	return {}


static func get_planet_count(system: Dictionary) -> int:
	var planets: Array = system.get("planets", [])
	return planets.size()


static func _planet_name(system_seed: int, planet_index: int) -> String:
	var syllables_a: Array[String] = [
		"Ae",
		"Cor",
		"Ily",
		"Nex",
		"Oro",
		"Tera",
		"Vey",
		"Zan",
	]
	var syllables_b: Array[String] = [
		"bora",
		"dune",
		"lia",
		"mera",
		"nox",
		"ria",
		"vora",
		"xis",
	]
	var divided_seed: int = floori(float(system_seed) / 19.0)
	return "%s%s %s" % [
		syllables_a[posmod(system_seed + planet_index * 11, syllables_a.size())],
		syllables_b[posmod(divided_seed + planet_index * 7, syllables_b.size())],
		_roman_numeral(planet_index + 1),
	]


static func _roman_numeral(value: int) -> String:
	match value:
		1: return "I"
		2: return "II"
		3: return "III"
		4: return "IV"
		5: return "V"
		6: return "VI"
		_: return str(value)
