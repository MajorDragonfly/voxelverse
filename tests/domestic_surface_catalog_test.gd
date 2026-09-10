extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Living = preload("res://world/surface/living_planet_surface.gd")
const System = preload("res://world/space/celestial_system.gd")
var failures: Array[String] = []
var reports: Array = []

class FlatSphere extends RefCounted:
	var body: Dictionary
	var submerged: bool = false
	func _init(descriptor: Dictionary) -> void: body = descriptor
	func sample(point: Dictionary) -> Dictionary:
		return {"height": -2.0 if submerged else 20.0, "water": submerged, "water_level": 0.0,
			"normal": Cube.vector(Cube.direction(point.face, point.u, point.v)), "blocked": false}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	for radius in [50000.0, 500000.0, 6371000.0]:
		for face in range(6):
			var body: Dictionary = descriptor("test:%s:%s" % [radius, face], 15838 + face, radius)
			var surface := FlatSphere.new(body)
			# Alternating exact poles and just inside all six cube-face edges.
			var anchor: Dictionary = Cube.address(body.id, face, 1.0 - 1.0 / radius if face % 2 == 0 else 0.0, 0.0, 20.0)
			var result: Dictionary = exercise(surface, anchor)
			expect(result.habitat_status == "ready", "Flat spherical fixture lacks roles")
			if face % 2 == 0:
				var crossed: bool = false
				for node: Dictionary in result.surface_search.nodes: crossed = crossed or node.location.face != anchor.face
				expect(crossed, "Search failed cube-edge crossing")
			var unsupported: Dictionary = result.duplicate(true)
			unsupported.surface.schema = 99
			expect(Catalog.has_unsupported(unsupported), "Future surface accepted")
			unsupported = result.duplicate(true)
			unsupported.surface_search.algorithm = "future"
			expect(Catalog.has_unsupported(unsupported), "Future search accepted")
			unsupported = result.duplicate(true)
			unsupported.surface_search.nodes[1].parent = 1
			expect(not Catalog.validate(unsupported, body).is_empty(), "Cyclic search graph accepted")
			unsupported = result.duplicate(true)
			unsupported.habitats[0].path[1].body_id = "other"
			expect(not Catalog.validate(unsupported, body).is_empty(), "Cross-body path accepted")
	var system := System.new(false, true)
	for id in System.REAL_LANDABLE:
		var body: Dictionary = system.bodies[id].duplicate(true)
		body.merge({"surface_mode": Cube.MODE, "surface_generation": Contract.GENERATION, "inhabited": true}, true)
		var surface := Living.new(body)
		var anchor: Dictionary = landing(surface)
		expect(not anchor.is_empty(), "Reference body has no dry landing")
		if anchor.is_empty(): continue
		var result: Dictionary = exercise(surface, anchor)
		expect(result.habitat_status == "ready", "Real reference body lacks reachable roles: " + id)
		for habitat: Dictionary in result.habitats:
			for index in range(1, habitat.path.size()):
				expect(not Planner.path(surface, habitat.path[index - 1], habitat.path[index]).is_empty(), "Saved route cannot be walked")
	var body: Dictionary = descriptor("water", 42, 6371000.0)
	var water := FlatSphere.new(body)
	water.submerged = true
	var anchor: Dictionary = Cube.address(body.id, 2, 0.0, 0.0, -2.0)
	var blocked: Dictionary = Catalog.create_surface(body, anchor)
	var search := Planner.new()
	search.begin(water, blocked)
	search.step(blocked, 100, 0)
	expect(blocked.habitat_status == "unavailable" and blocked.habitats.is_empty(), "Ocean became a reachable land habitat")
	body.inhabited = false
	expect(Catalog.create_surface(body, anchor).is_empty(), "Lifeless body received mandatory fauna")
	for kind in ["star", "gas_giant", "asteroid"]:
		body.kind = kind
		body.inhabited = true
		expect(Catalog.create_surface(body, anchor).is_empty(), "Non-playable body received mandatory fauna")
	print(JSON.stringify({"test": "domestic_surface_catalog", "cases": reports, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func exercise(surface: RefCounted, anchor: Dictionary) -> Dictionary:
	var catalog: Dictionary = Catalog.create_surface(surface.body, anchor)
	var original: Dictionary = Catalog.create(surface.body)
	expect(catalog.species.slice(0, 3) == original.species, "Surface extension changed existing species or bodies")
	var frozen: String = JSON.stringify(catalog.species)
	var resumed: Dictionary = catalog.duplicate(true)
	var one := Planner.new()
	one.begin(surface, catalog)
	while catalog.habitat_status == "pending": one.step(catalog, 4096, 0)
	var interrupted := Planner.new()
	interrupted.begin(surface, resumed)
	interrupted.step(resumed, 7, 0)
	resumed = JSON.parse_string(JSON.stringify(resumed))
	var two := Planner.new()
	two.begin(surface, resumed)
	while resumed.habitat_status == "pending": two.step(resumed, 1, 1)
	expect(JSON.parse_string(JSON.stringify(catalog)) == JSON.parse_string(JSON.stringify(resumed)), "Restart/frame budget changed spherical search")
	expect(JSON.stringify(catalog.species) == frozen, "Search mutated saved species")
	expect(Catalog.validate(resumed, surface.body).is_empty(), "Catalog rejected: " + Catalog.validate(resumed, surface.body))
	var ids: Array = []
	for habitat: Dictionary in catalog.habitats:
		ids.append(Contract.object_id(habitat))
		expect(habitat.water_supply == "requires_transport", "Ocean claimed as freshwater")
	reports.append({"body": surface.body.id, "radius": surface.body.radius, "nodes": catalog.surface_search.nodes.size(), "habitats": catalog.habitats.size(), "ids": ids})
	return catalog

static func descriptor(id: String, seed_value: int, radius: float) -> Dictionary:
	return {"id": id, "seed": seed_value, "radius": radius, "terrain_revision": 3, "kind": "planet", "inhabited": true,
		"surface_mode": Cube.MODE, "surface_generation": Contract.GENERATION}

static func landing(surface: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	var score: float = INF
	for face in range(6):
		for index in range(-12, 13):
			var point: Dictionary = Cube.address(surface.body.id, face, 1.0 - 96.0 / float(surface.body.radius), index / 14.0)
			var sample: Dictionary = surface.sample(point)
			if sample.height < 3.0 or sample.height > 50.0 or sample.normal.dot(Cube.vector(Cube.direction(point.face, point.u, point.v))) < 0.97: continue
			var cost: float = absf(sample.height - 12.0) + absf(sample.canopy - 0.55) * 25.0
			if cost < score:
				score = cost
				best = point
				best.height = sample.height
	return best

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
