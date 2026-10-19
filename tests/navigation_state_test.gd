extends SceneTree
const Navigation = preload("res://core/map/navigation_state.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Participants = preload("res://core/persistence/save_participants.gd")
const Owned = preload("res://ui/minimap/owned_animal_markers.gd")
var failures: Array[String] = []
var checks: int = 0
class OwnedRuntime extends Node:
	var registry: Dictionary = {}
	var animals: Dictionary = {}
	func is_active() -> bool: return true
	func current_registry() -> Dictionary: return registry

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for sphere in [false, true]:
		var body: Dictionary = {"id": "body-test", "surface_mode": Cube.MODE if sphere else "legacy_plane_v9"}
		var address: Dictionary = Cube.address(body.id, 0, 0.999999, 0.2) if sphere else Surface.plane_address(body.id, Vector3(-15, 0, 32))
		var atlas := Atlas.new()
		_expect(atlas.bind(Atlas.create(body.id, body.surface_mode, 6371000 if sphere else 0)), "Cannot bind navigation atlas")
		var before: Dictionary = body.duplicate(true)
		_expect(Navigation.add(body, address, "Unknown", atlas).is_empty() and body == before, "Unknown ground acquired a pin or navigation state")
		atlas.reveal(address)
		var fog: Dictionary = atlas.data.duplicate(true)
		var id: String = Navigation.add(body, address, "  River\n crossing  ", atlas)
		_expect(not id.is_empty() and Navigation.validate(body).is_empty(), "Explored waypoint rejected")
		_expect(Navigation.view(body).waypoints[id].name == "River crossing", "Name controls were not normalized")
		_expect(Navigation.target(body, atlas).id == id, "New waypoint is not the active target")
		_expect(Navigation.rename(body, id, "M · {name} — 🏕"), "Unicode/literal name was rejected")
		_expect(Navigation.target(body, atlas).name == "M · {name} — 🏕", "Name was interpreted or target retained stale title")
		var stable: Dictionary = body.duplicate(true)
		var reused: Dictionary = body.duplicate(true)
		reused.map_navigation.next_id = 1
		var before_reuse: Dictionary = reused.duplicate(true)
		_expect(Navigation.add(reused, address, "Collision", atlas).is_empty() and reused == before_reuse, "Reused sequence silently replaced a saved waypoint")
		_expect(not Navigation.rename(body, id, "\t\n") and body == stable, "Blank rename changed the record")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(body))
		_expect(Navigation.validate(restored).is_empty() and Navigation.target(restored, atlas).id == id, "JSON restart changed the waypoint contract")
		var foreign: Dictionary = address.duplicate(true)
		foreign.body_id = "foreign"
		_expect(Navigation.add(body, foreign, "Wrong body", atlas).is_empty() and body == stable, "Foreign marker mutated the current body")
		for index in range(1, Navigation.CAPACITY):
			_expect(not Navigation.add(body, address, "Point %d" % index, atlas).is_empty(), "Waypoint capacity was reduced")
		var full: Dictionary = body.duplicate(true)
		_expect(Navigation.add(body, address, "Overflow", atlas).is_empty() and body == full, "Overflow discarded or replaced a waypoint")
		_expect(Navigation.track(body, id, "waypoint", atlas), "Existing waypoint cannot become target")
		_expect(Navigation.remove(body, id) and Navigation.view(body).target.is_empty(), "Deleting target retained a dangling reference")
		var replacement: String = Navigation.add(body, address, "Replacement", atlas)
		_expect(not replacement.is_empty() and replacement != id, "Deleted stable ID was reused")
		_expect(Navigation.clear_target(body) and Navigation.target(body, atlas).is_empty(), "Stop tracking did not retain pins and clear target")
		var place := {"id": "home-id", "name": "Home", "kind": "home", "species_id": "player", "object_id": "", "own": true, "address": address}
		atlas.remember(place)
		_expect(Navigation.track(body, place.id, "place", atlas) and Navigation.target(body, atlas) == place, "Known-place target does not resolve canonical atlas record")
		var other_atlas := Atlas.new()
		other_atlas.bind(Atlas.create("foreign", body.surface_mode, 6371000 if sphere else 0))
		_expect(Navigation.target(body, other_atlas).is_empty(), "Atlas target leaked across bodies")
		# Target selection and pins never write explored bits or place records.
		atlas.data.places.erase(place.id)
		_expect(Navigation.target(body, atlas).is_empty(), "Missing known place was fabricated from target metadata")
		_expect(atlas.data == fog, "Navigation generated exploration or saved place duplicates")
		var broken: Dictionary = body.duplicate(true)
		broken.map_navigation.next_id = INF
		_expect(not Navigation.validate(broken).is_empty(), "Nonfinite sequence accepted")
		broken = body.duplicate(true)
		broken.map_navigation.waypoints[replacement].address.body_id = "foreign"
		_expect(not Navigation.validate(broken).is_empty(), "Cross-body saved waypoint accepted")
		broken = body.duplicate(true)
		broken.map_navigation.target = {"kind": "waypoint", "id": "missing"}
		_expect(not Navigation.validate(broken).is_empty(), "Dangling saved waypoint target accepted")
		broken.map_navigation.schema = Navigation.SCHEMA + 1
		var future: Dictionary = broken.duplicate(true)
		_expect(Navigation.unsupported(broken) and Participants.unsupported_body(broken), "Future navigation was not protected by central save participant")
		_expect(Navigation.add(broken, address, "Downgrade", atlas).is_empty() and broken == future, "Mutation downgraded future navigation")
	_test_owned_animals()
	for failure in failures: push_error(failure)
	print("NAVIGATION_STATE_PASSED checks=%d" % checks if failures.is_empty() else "NAVIGATION_STATE_FAILED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _test_owned_animals() -> void:
	var body := {"id": "animals", "surface_mode": "legacy_plane_v9", "domesticated_animals": {"schema": 1,
		"registry": {"body_id": "animals", "animals": {}}, "sources": {}}}
	for index in range(6):
		var id: String = "animal-%d" % index
		body.domesticated_animals.registry.animals[id] = {"object_id": id, "body_id": "animals", "status": "tamed", "health": 100.0,
			"owner_faction_id": "player", "position": [index * 4.0, 0.0, 0.0]}
		body.domesticated_animals.sources[id] = {"name": "Named animal %d" % index}
	body.domesticated_animals.registry.animals["animal-1"].status = "dead"
	body.domesticated_animals.registry.animals["animal-1"].health = 0.0
	body.domesticated_animals.registry.animals["animal-2"].owner_faction_id = "other"
	body.domesticated_animals.registry.animals["animal-3"].status = "taming"
	body.domesticated_animals.registry.animals["animal-4"].body_id = "other-body"
	var before: Dictionary = body.duplicate(true)
	var markers: Array[Dictionary] = Owned.collect(body, "player", self)
	_expect(markers.size() == 2 and markers[0].id == "animal-0" and markers[1].id == "animal-5", "Owned markers included dead, claimed, foreign or other-body animals")
	_expect(markers[0].address.body_id == body.id and body == before, "Animal map reader mutated simulation or lost body identity")
	_expect(Owned.collect(body, "", self).is_empty(), "An empty player identity exposed animals")
	var foreign: Dictionary = body.duplicate(true)
	foreign.domesticated_animals.registry.body_id = "foreign"
	_expect(Owned.collect(foreign, "player", self).is_empty(), "Foreign ownership ledger exposed animals")
	var sphere: Dictionary = body.duplicate(true)
	sphere.surface_mode = Cube.MODE
	for animal: Dictionary in sphere.domesticated_animals.registry.animals.values(): animal.position = Cube.address("animals", 2, 0.0, 0.0)
	_expect(Owned.collect(sphere, "player", self).size() == 2, "Sphere-owned animal addresses were lost")
	var runtime := OwnedRuntime.new()
	runtime.registry = body.domesticated_animals.registry.duplicate(true)
	root.add_child(runtime)
	runtime.add_to_group(&"domestication_runtime")
	var actor := Node3D.new()
	root.add_child(actor)
	actor.position = Vector3(28.0, 4.0, -7.0)
	runtime.animals["animal-0"] = actor
	var actual: Array[Dictionary] = Owned.collect(body, "player", self)
	_expect(actual.size() == 2 and actual[0].address.position == [28.0, 4.0, -7.0], "Loaded owned animal used stale saved coordinates")
	runtime.registry.animals["animal-0"].status = "dead"
	runtime.registry.animals["animal-0"].health = 0.0
	_expect(Owned.collect(body, "player", self).size() == 1, "Live death waited for save flush before hiding marker")
	_expect(body == before, "Live animal projection rewrote saved position or health")
	root.remove_child(runtime)
	runtime.free()
	root.remove_child(actor)
	actor.free()

func _expect(okay: bool, message: String) -> void:
	checks += 1
	if not okay: failures.append(message)
