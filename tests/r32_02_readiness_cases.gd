extends RefCounted
const Readiness = preload("res://tools/review_r32_02_readiness.gd")

class CacheStore:
	extends RefCounted
	var cache: Dictionary = {}

class CachedStorage:
	extends RefCounted
	var store := CacheStore.new()
	# Deliberately no region() method: observations must not load/write pages.

class Observer:
	extends CharacterBody3D
	func location() -> Dictionary:
		return Readiness.Model.Cube.address("readiness-fixture", 0, 0.0, 0.0)

class Animal:
	extends Node3D
	var _decision_timer: float = 1.0
	var is_dead: bool = false

class PopulationFixture:
	extends Node3D
	const ACTIVE_DISTANCE: float = 82.0
	var descriptor: Dictionary = {"id": "readiness-fixture", "radius": 8192.0}
	var player: CharacterBody3D
	var storage := CachedStorage.new()
	var animals: Dictionary = {}
	var plants: Dictionary = {}
	var nests: Dictionary = {}

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var fixture := Node3D.new()
	var mesh := MeshInstance3D.new()
	fixture.add_child(mesh)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	body.add_child(collider)
	fixture.add_child(body)
	mesh.mesh = BoxMesh.new()
	collider.shape = BoxShape3D.new()
	if Readiness.published_components(fixture) != {"mesh": false, "collider": false}:
		failures.append("Unpublished staged components were reported ready")
	tree.root.add_child(fixture)
	if Readiness.published_components(fixture) != {"mesh": true, "collider": true}:
		failures.append("Published mesh/collider were not observed")
	collider.disabled = true
	mesh.mesh = null
	if Readiness.published_components(fixture) != {"mesh": false, "collider": false}:
		failures.append("Deferred bush mesh or disabled collider was reported ready")
	# Observation must never fill missing resources or enable collision.
	if mesh.mesh != null or not collider.disabled:
		failures.append("Readiness inspection changed physical publication")
	fixture.free()
	# Load the population scene dependencies after campaign autoloads exist.
	var population: Node = load("res://world/surface/campaign_population.gd").new()
	var recorder := Readiness.new()
	population._record_spawn_stage("position", Time.get_ticks_usec())
	if not recorder.data.work.is_empty(): failures.append("Default gameplay emitted diagnostic work")
	population.work_probe = recorder.record_work
	population._record_spawn_stage("actor_ready", Time.get_ticks_usec())
	population._record_tick_stage("generation", Time.get_ticks_usec())
	if recorder.data.work.size() != 2:
		failures.append("Population did not report both measured stage types")
	elif recorder.data.work[0].kind != "spawn" or recorder.data.work[1].kind != "tick":
		failures.append("Nested spawn and whole tick costs cannot be distinguished")
	population.work_probe = Callable()
	population._record_tick_stage("nests", Time.get_ticks_usec())
	if recorder.data.work.size() != 2: failures.append("Detached diagnostic callback retained work")
	population.free()
	var cached := PopulationFixture.new()
	cached.player = Observer.new()
	cached.add_child(cached.player)
	var animal := Animal.new()
	cached.add_child(animal)
	cached.animals["animal"] = animal
	var cell: Dictionary = Readiness.Model.cell(cached.descriptor, cached.player.location())
	cached.storage.store.cache["r:" + str(cell.id)] = {"objects": {"animal": {"id": "animal", "location": [0.0, 0.0, 0.0]}}, "plants": {}}
	var original: String = JSON.stringify(cached.storage.store.cache)
	tree.root.add_child(cached)
	var observer := Readiness.new()
	observer.sample(cached, 1000000, "walk_outward")
	animal._decision_timer = 0.98
	observer.sample(cached, 1016667, "walk_outward")
	var components: Array = observer.data.events.map(func(event: Dictionary) -> String: return event.component)
	if "record" not in components or "terrain_ready_observed" not in components or "first_ai_step_observed" not in components:
		failures.append("Cached records or first observed AI progress were lost")
	if components.count("first_ai_step_observed") != 1:
		failures.append("First observed AI progress was counted repeatedly")
	if JSON.stringify(cached.storage.store.cache) != original:
		failures.append("Readiness observation rewrote canonical records")
	cached.free()
	print("R32_02_READINESS_CASES ", JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	return failures
