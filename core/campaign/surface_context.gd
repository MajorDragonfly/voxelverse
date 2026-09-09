extends RefCounted
## Versioned body geometry. Persistent positions use Cube addresses; scene
## Vector3 values are only local, after subtracting the body's floating origin.
const Cube = preload("res://world/space/cube_sphere.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const SCHEMA: int = 1
const LEGACY: String = "legacy_plane_v9"
const GENERATION: String = "living_planet_v1"
const DEFAULT_RADIUS: float = 6371000.0
const SCENE: String = "res://main/spherical_campaign.tscn"

static func descriptor(body: Dictionary) -> Dictionary:
	var context: Dictionary = body.surface_context
	var result: Dictionary = Profile.create(body.id, "planet", int(body.seed), float(context.radius))
	result.merge({"surface_generation": context.generation, "terrain_revision": context.terrain_revision,
		"gravity": context.gravity, "adaptive": true}, true)
	return result

static func create(body: Dictionary, radius: float = DEFAULT_RADIUS) -> Dictionary:
	if not number(radius, 50000.0, 1.0e10): return {}
	var result: Dictionary = body.duplicate(true)
	result.surface_mode = Cube.MODE
	result.surface_context = {"schema": SCHEMA, "mode": Cube.MODE, "generation": GENERATION,
		"terrain_revision": 3, "radius": radius, "gravity": 9.81, "spawn": {}}
	var surface: RefCounted = Factory.create(descriptor(result))
	# Bounded deterministic search over all six faces, independent of reference
	# lab IDs/seeds. The candidate and its entire landing footprint must be dry.
	for face in range(6):
		for y in range(9):
			for x in range(9):
				var address: Dictionary = Cube.address(str(body.id), face, (x - 4) * 0.22, (y - 4) * 0.22)
				if not landing_problem(surface, address).is_empty(): continue
				address.height = surface.sample(address).height + 1.1
				result.surface_context.spawn = address
				return result
	return {}

static func landing_problem(surface: RefCounted, address: Dictionary) -> String:
	if not Cube.valid(address, str(surface.body.id)): return "Zieladresse gehört nicht zum Planeten."
	var center: Array = Cube.cartesian(address, float(surface.body.radius))
	var frame: Basis = Cube.frame(Cube.vector(Cube.direction(address.face, address.u, address.v)))
	for offset in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3),
			Vector2(3, 3), Vector2(-3, 3), Vector2(3, -3), Vector2(-3, -3)]:
		var delta: Vector3 = frame.x * offset.x + frame.z * offset.y
		var p: Dictionary = Cube.from_cartesian(str(surface.body.id),
			[center[0] + delta.x, center[1] + delta.y, center[2] + delta.z], float(surface.body.radius))
		var sample: Dictionary = surface.sample(p)
		var up: Vector3 = Cube.vector(Cube.direction(p.face, p.u, p.v))
		if sample.water or sample.height < 3.0: return "Zielbereich liegt im Wasser oder zu nah am Ufer."
		if sample.blocked: return "Zielbereich ist gesperrt."
		if sample.normal.dot(up) < 0.97: return "Zielbereich ist zu steil."
	return ""

static func unsupported(body: Dictionary) -> bool:
	if body.get("surface_mode") not in [LEGACY, Cube.MODE]: return true
	var value: Variant = body.get("surface_context")
	return value is Dictionary and (value.get("schema") != SCHEMA or value.get("mode") != Cube.MODE or
		value.get("generation") != GENERATION or value.get("terrain_revision") != 3)

static func validate(body: Dictionary) -> String:
	if unsupported(body): return "Unbekannter Oberflächenvertrag; Spielstand bleibt geschützt."
	if body.surface_mode == LEGACY:
		return "Flachwelt mit widersprüchlichem Kugelkontext." if body.has("surface_context") else ""
	var value: Variant = body.get("surface_context")
	if not value is Dictionary: return "Kugelwelt ohne Oberflächenkontext."
	if not body.get("id") is String or body.id.is_empty() or not number(body.get("seed"), 1.0, 2147483647.0) or float(body.seed) != floor(float(body.seed)):
		return "Ungültige Körperidentität oder Seed."
	for field in ["home_group", "tribe", "tribal_neighbor", "domesticated_animals", "fauna_catalog"]:
		if body.has(field): return "Noch nicht angebundene Ortsdaten auf der Kugel: " + field
	if not number(value.get("radius"), 50000.0, 1.0e10) or not number(value.get("gravity"), 0.1, 100.0):
		return "Ungültiger Radius oder ungültige Schwerkraft."
	if not location(value.get("spawn"), str(body.get("id", ""))): return "Ungültiger Startort auf der Kugel."
	if body.has("legacy_exploration_atlas"):
		var old: Variant = body.legacy_exploration_atlas
		var problem: String = Atlas.validate(old, str(body.id))
		if not problem.is_empty(): return problem
		if old.mode != LEGACY: return "Das Kartenarchiv muss eine alte Flächenkarte enthalten."
	return ""

static func location(value: Variant, body_id: String) -> bool:
	return Cube.valid(value, body_id) and number(value.get("height"), -20000.0, 20000.0)

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func vector(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3: return false
	for n in value:
		if not number(n, -limit, limit): return false
	return true

static func player_problem(player: Dictionary, body: Dictionary) -> String:
	if not location(player.get("surface_address"), str(body.id)): return "Ungültiger körpergebundener Spielerort."
	if not vector(player.get("surface_forward"), 1.0) or Cube.vector(player.surface_forward).length() < 0.9:
		return "Ungültige radiale Blickrichtung."
	if not vector(player.get("surface_velocity"), 1000.0): return "Ungültige radiale Geschwindigkeit."
	if not number(player.get("surface_pitch"), -0.85, 0.5): return "Ungültige radiale Kameraneigung."
	return ""
