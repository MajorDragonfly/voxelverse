extends RefCounted
const Population = preload("res://world/surface/campaign_population.gd")
const Model = preload("res://world/surface/campaign_population_state.gd")
const Cube = preload("res://world/space/cube_sphere.gd")

class StorageFixture:
	extends "res://world/surface/campaign_region_storage.gd"
	var regions: Dictionary = {}
	func region(key: String, _create: bool = true) -> Dictionary:
		return regions.get(key, {})

class Observer:
	extends CharacterBody3D

class Resident:
	extends Node3D
	var catalog_species: Dictionary = {}
	var colony_id: String = ""
	func get_campaign_identity() -> Dictionary: return {}

var failures: Array[String] = []

func run(tree: SceneTree) -> Array[String]:
	var population := Population.new()
	population.player = Observer.new()
	tree.root.add_child(population.player)
	population.descriptor = {"id":"stream-test", "radius":8192.0}
	var storage := StorageFixture.new()
	population.storage = storage
	var observer: Dictionary = Cube.address("stream-test", 0, 0.01, 0.01)
	var wanted: Dictionary = Model.Cells.nearby(population.descriptor, observer)
	var central: Dictionary = Model.cell(population.descriptor, observer)
	_expect(population._generation_cell(wanted, observer).id == central.id, "Observer cell lost first-generation priority")
	storage.regions[central.id] = {"generated":true}
	var pending: Array[Dictionary] = []
	for cell: Dictionary in wanted.values():
		if cell.id != central.id: pending.append(cell)
	var nearest: Dictionary = Model.nearest_cell(population.descriptor, observer, pending)
	_expect(population._generation_cell(wanted, observer).id == nearest.id, "Distant ring corner preceded the nearest missing cell")
	_expect(nearest.id != wanted.keys()[0], "Fixture did not distinguish nearest-first from old ring order")
	storage.regions[nearest.id] = {"generated":true}
	_expect(population._generation_cell(wanted, observer).id != nearest.id, "Already generated cell stole a pending cell's update")
	for id: String in wanted: storage.regions[id] = {"generated":true}
	var visited: Dictionary = {}
	for index in wanted.size(): visited[population._generation_cell(wanted, observer).id] = true
	_expect(visited.size() == wanted.size(), "Maintenance no longer visits old generated regions for colony upgrades")
	# Across cube-face seams the metric must be physical, not an x/y index.
	for face in range(6):
		var edge: Dictionary = Cube.address("stream-test", face, 0.999, -0.999)
		var candidates: Array[Dictionary] = []
		candidates.assign(Model.Cells.nearby(population.descriptor, edge).values())
		var result: Dictionary = Model.nearest_cell(population.descriptor, edge, candidates)
		var origin: Array = Cube.cartesian(edge, population.descriptor.radius)
		var selected_distance: float = _distance(result, origin, population.descriptor)
		for cell: Dictionary in candidates:
			_expect(selected_distance <= _distance(cell, origin, population.descriptor) + 0.001, "Cube seam chose a farther cell")
	var represented := Resident.new()
	represented.catalog_species = {"id":"role-present"}
	population.animals["catalog"] = represented
	for index in range(2):
		var resident := Resident.new()
		resident.colony_id = "visible-family"
		population.animals["resident"+str(index)] = resident
	var candidates: Array[Dictionary] = [
		{"id":"new-family", "colony_id":"other-family", "location":[1.0,0.0,0.0]},
		{"id":"sibling", "colony_id":"visible-family", "location":[20.0,0.0,0.0]},
		{"id":"missing-role", "catalog_species_id":"role-missing", "location":[30.0,0.0,0.0]},
		{"id":"duplicate-role", "catalog_species_id":"role-present", "location":[0.0,0.0,0.0]}]
	var original: Array = candidates.duplicate(true)
	population._prioritize_catalog(candidates)
	_expect(candidates.map(func(record: Dictionary) -> String: return record.id) == ["missing-role","sibling","new-family","duplicate-role"], "Cached ordering broke missing-role priority or three-resident completion")
	for record: Dictionary in original:
		_expect(candidates.has(record), "Ordering changed a canonical record")
	# Cached distances are per-tick input; a new location/rebase must reorder.
	var ordinary: Array[Dictionary] = [original[0], {"id":"other", "colony_id":"other-family", "location":[2.0,0.0,0.0]}]
	population._prioritize_catalog(ordinary, {"new-family":100.0, "other":1.0})
	_expect(ordinary[0].id == "other", "Provided distances were ignored")
	population._prioritize_catalog(ordinary, {"new-family":0.1, "other":100.0})
	_expect(ordinary[0].id == "new-family", "Ordering reused distances from an earlier tick")
	for node: Node in population.animals.values(): node.free()
	population.animals.clear()
	population.player.free()
	population.free()
	print(JSON.stringify({"test":"campaign_population_streaming", "passed":failures.is_empty(), "failures":failures}))
	return failures

func _distance(cell: Dictionary, origin: Array, body: Dictionary) -> float:
	var center: Dictionary = Cube.address(body.id, cell.face, -1.0+(cell.x+0.5)*cell.step, -1.0+(cell.y+0.5)*cell.step)
	return Cube.local_position(Cube.cartesian(center, body.radius), origin).length_squared()

func _expect(value: bool, message: String) -> void:
	if not value: failures.append(message)
