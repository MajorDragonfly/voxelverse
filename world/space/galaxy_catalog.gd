extends RefCounted

const Address = preload("res://world/space/galaxy_address.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
const VERSION: String = "galaxy_catalog_v1"
const SECTOR_CACHE_LIMIT: int = 16
const SYSTEM_CACHE_LIMIT: int = 32
const RADIUS_LY: float = 50_000.0
const AU_M: float = 149_597_870_700.0
const G: float = 6.67430e-11
const SOLAR_MASS_KG: float = 1.98847e30
var universe_seed: String
var galaxy_index: int
var _sectors: Dictionary = {}
var _systems: Dictionary = {}
var _sector_generations: int = 0
var _system_generations: int = 0

func _init(seed_value: String = "15838", galaxy: int = 0) -> void:
	universe_seed = seed_value
	galaxy_index = galaxy

func identity() -> Dictionary:
	return {"catalog_version": VERSION, "address_version": Address.VERSION, "universe_seed": universe_seed, "galaxy_index": galaxy_index, "galaxy_id": Address.galaxy_id(universe_seed, galaxy_index), "radius_ly": RADIUS_LY, "sector_size_ly": Address.SECTOR_SIZE_LY}

func owns(id: String, kind: String) -> bool:
	var address: Dictionary = Address.parse(id)
	return address.get("kind") == kind and address.get("universe_seed") == universe_seed and address.get("galaxy_index") == galaxy_index

func sector_at(coordinates: Array) -> Dictionary:
	return sector(Address.sector_id(universe_seed, galaxy_index, coordinates))

func sector(id: String) -> Dictionary:
	if not owns(id, "sector"):
		return {}
	if _sectors.has(id):
		return _touch(_sectors, id)
	_sector_generations += 1
	var address: Dictionary = Address.parse(id)
	var entries: Array[Dictionary] = []
	for slot in range(Address.MAX_SYSTEMS):
		var system_identity: String = Address.system_id(id, slot)
		var offset: Array[float] = []
		var position: Array[float] = []
		for axis in range(3):
			offset.append(_unit(system_identity, "offset%d" % axis) * Address.SECTOR_SIZE_LY)
			position.append(int(address.sector[axis]) * Address.SECTOR_SIZE_LY + offset[axis])
		var radius: float = sqrt(position[0] * position[0] + position[2] * position[2])
		var density: float = exp(-radius / 22000.0) * exp(-absf(position[1]) / 250.0)
		density += 0.65 * exp(-radius / 4500.0) * exp(-absf(position[1]) / 1300.0)
		if radius >= RADIUS_LY or absf(position[1]) > 6000.0 or _unit(system_identity, "present") >= minf(density, 0.94):
			continue
		entries.append({"id": system_identity, "name": _name(system_identity), "position": {"sector": address.sector.duplicate(), "offset_ly": offset}, "star_count": 2 if _unit(system_identity, "binary") < 0.28 else 1})
	var value: Dictionary = {"id": id, "catalog_version": VERSION, "coordinates": address.sector.duplicate(), "systems": entries}
	_cache(_sectors, id, value, SECTOR_CACHE_LIMIT)
	return value.duplicate(true)

func system(id: String) -> Dictionary:
	if not owns(id, "system"):
		return {}
	if _systems.has(id):
		return _touch(_systems, id)
	var address: Dictionary = Address.parse(id)
	var entry: Dictionary = {}
	for candidate: Dictionary in sector(address.sector_id).systems:
		if candidate.id == id:
			entry = candidate.duplicate(true)
			break
	if entry.is_empty():
		return {}
	_system_generations += 1
	entry["catalog_version"] = VERSION
	entry["bodies"] = _bodies(entry)
	_cache(_systems, id, entry, SYSTEM_CACHE_LIMIT)
	return entry.duplicate(true)

func body(id: String) -> Dictionary:
	if not owns(id, "body"):
		return {}
	return system(Address.parse(id).system_id).get("bodies", {}).get(id, {}).duplicate(true)

func clear_cache() -> void:
	_sectors.clear()
	_systems.clear()

func stats() -> Dictionary:
	return {"sectors": _sectors.size(), "systems": _systems.size(), "sector_limit": SECTOR_CACHE_LIMIT, "system_limit": SYSTEM_CACHE_LIMIT, "sector_generations": _sector_generations, "system_generations": _system_generations, "terrain_meshes": 0}

func _bodies(entry: Dictionary) -> Dictionary:
	var bodies: Dictionary = {}
	var stars: Array[Dictionary] = []
	var total_mass: float = 0.0
	for index in range(int(entry.star_count)):
		var id: String = Address.body_id(entry.id, index)
		var types: Array[String] = ["M", "K", "G", "F", "A"]
		var roll: float = _unit(id, "class")
		var kind: int = 0 if roll < 0.5 else (1 if roll < 0.75 else (2 if roll < 0.9 else (3 if roll < 0.98 else 4)))
		var masses: Array[float] = [0.3, 0.7, 1.0, 1.35, 2.1]
		var mass: float = masses[kind] * lerpf(0.86, 1.14, _unit(id, "mass")) * SOLAR_MASS_KG
		var radius: float = 696340000.0 * pow(mass / SOLAR_MASS_KG, 0.8)
		var star: Dictionary = _body(id, entry.name + (" A" if index == 0 else " B"), "star", radius, mass, "", 0.0, 1.0)
		star["spectral_class"] = types[kind]
		star["surface_mode"] = "stellar"
		stars.append(star)
		total_mass += mass
	var separation: float = 0.0
	if stars.size() == 2:
		separation = maxf(0.08 * AU_M + _unit(entry.id, "binary_distance") * 0.25 * AU_M, (stars[0].radius + stars[1].radius) * 5.0)
		for index in range(2):
			stars[index].orbit_radius = separation * stars[1 - index].mass_kg / total_mass
			stars[index].orbit_period = _period(separation, total_mass)
			stars[index].orbit_phase = PI * index
	for star in stars:
		bodies[star.id] = star
	var orbit: float = maxf(0.15 * AU_M, maxf(separation * 4.0, stars[0].radius * 8.0))
	var planets: int = 2 + int(_hash(entry.id, "planet_count") % 7)
	var romans: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
	for index in range(planets):
		var slot: int = 2 + index * 4
		var id: String = Address.body_id(entry.id, slot)
		orbit *= lerpf(1.55, 1.95, _unit(id, "spacing"))
		var gas: bool = index > 1 and _unit(id, "gas") < 0.42
		var radius: float = lerpf(30000000.0, 85000000.0, _unit(id, "radius")) if gas else lerpf(1000000.0, 11000000.0, _unit(id, "radius"))
		var density: float = lerpf(650.0, 1900.0, _unit(id, "density")) if gas else lerpf(3000.0, 6500.0, _unit(id, "density"))
		var mass: float = 4.0 / 3.0 * PI * pow(radius, 3) * density
		var parent: String = stars[0].id if stars.size() == 1 else ""
		var planet: Dictionary = _body(id, entry.name + " " + romans[index], "gas_giant" if gas else "planet", radius, mass, parent, orbit, _period(orbit, total_mass))
		bodies[id] = planet
		var moon_count: int = int(_hash(id, "moon_count") % 3)
		var hill: float = orbit * pow(mass / (3.0 * total_mass), 1.0 / 3.0)
		var moon_orbit: float = radius * 5.0
		for moon_index in range(moon_count):
			var moon_id: String = Address.body_id(entry.id, slot + moon_index + 1)
			var moon_radius: float = lerpf(50000.0, minf(radius * 0.24, 2500000.0), _unit(moon_id, "radius"))
			moon_orbit *= 2.0
			if moon_orbit + moon_radius > hill * 0.35:
				break
			var moon_mass: float = 4.0 / 3.0 * PI * pow(moon_radius, 3) * 3000.0
			bodies[moon_id] = _body(moon_id, planet.name + (" a" if moon_index == 0 else " b"), "moon", moon_radius, moon_mass, id, moon_orbit, _period(moon_orbit, mass))
	return bodies

func _body(id: String, label: String, kind: String, radius: float, mass: float, parent: String, orbit: float, period: float) -> Dictionary:
	var value: Dictionary = Profile.create(id, kind, 1 + int(_hash(id, "terrain") % 2147483646), radius, parent)
	value.merge({"name": label, "catalog_version": VERSION, "mass_kg": mass, "gravity": G * mass / (radius * radius), "orbit_radius": orbit, "orbit_period": period, "orbit_phase": _unit(id, "phase") * TAU, "rotation_period": lerpf(7200.0, 172800.0, _unit(id, "rotation")), "terrain_revision": 3, "adaptive_tiles": kind in ["planet", "moon"], "landable": kind in ["planet", "moon"]}, true)
	if kind == "gas_giant":
		value["surface_mode"] = "gas_atmosphere"
	return value

static func _period(radius: float, mass: float) -> float:
	return TAU * sqrt(pow(radius, 3.0) / (G * mass))

static func _hash(id: String, field: String) -> int:
	# Each field has its own SHA-256 domain; RNG state, dictionary order and
	# engine RNG implementation never choose the next system or body.
	return (VERSION + "|" + id + "|" + field).sha256_text().substr(0, 13).hex_to_int()

static func _unit(id: String, field: String) -> float:
	return float(_hash(id, field)) / 4503599627370496.0

static func _name(id: String) -> String:
	var names: Array[String] = ["Velara", "Orian", "Nareth", "Solven", "Ivara", "Talora", "Arven", "Nerion", "Kelara", "Darian", "Ravena", "Elion"]
	return names[int(_hash(id, "name") % names.size())] + "-%04d" % int(_hash(id, "suffix") % 10000)

static func _cache(cache: Dictionary, id: String, value: Dictionary, limit: int) -> void:
	cache[id] = value
	while cache.size() > limit:
		cache.erase(cache.keys()[0])

static func _touch(cache: Dictionary, id: String) -> Dictionary:
	var value: Dictionary = cache[id]
	cache.erase(id)
	cache[id] = value
	return value.duplicate(true)
