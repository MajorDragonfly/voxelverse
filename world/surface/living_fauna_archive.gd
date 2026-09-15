extends RefCounted
## The independent living laboratory keeps exact wild individuals in immutable
## region-store blobs. Four live nodes pin their records; history is not a cap.
const Store = preload("res://core/persistence/region_store.gd")
const Pose = preload("res://world/surface/surface_lab_store.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const DIRECTORY: String = "user://living_fauna/blobs"
var store: RefCounted = Store.new()
var body_id: String = ""
var count: int = 0

static func manifest_valid(value: Variant, id: String) -> bool:
	return value is Dictionary and value.get("schema") == 1 and value.get("body_id") == id \
		and Pose.finite(value.get("count"), 9007199254740991.0) and value.count >= 0 \
		and value.count == floor(value.count) and Store.manifest_problem(value.get("storage")).is_empty() \
		and (value.count == 0) == value.storage.root.is_empty()

static func state_valid(key: Variant, state: Variant, id: String) -> bool:
	if not key is String or key.length() > 400 or not key.begins_with(id + ":land1:") or not key.ends_with(":animal"):
		return false
	if not Pose.pose_valid(state, id) or not state.get("returning") is bool:
		return false
	if not Cube.valid(state.get("home"), id) or not Cube.valid(state.get("goal"), id):
		return false
	if absf(state.home.height) > 20000.0 or absf(state.goal.height) > 20000.0:
		return false
	if not state.get("design") is Dictionary or state.design.get("type") != "Dictionary" or JSON.stringify(state.design).length() > 262144:
		return false
	var design: Variant = JSON.to_native(state.design, false)
	return design is Dictionary and design.get("version") == 7 and design.get("body") is Dictionary \
		and design.get("parts") is Array and design.get("design_id") is String

func open(id: String, record: Dictionary, directory: String = DIRECTORY) -> bool:
	body_id = id
	store.directory = directory
	store.validate_value = _problem.bind(id)
	if record.has("fauna_archive"):
		var manifest: Variant = record.fauna_archive
		if record.has("fauna") or not manifest_valid(manifest, id):
			return store._fail("Unbekanntes oder beschädigtes Labortierarchiv.")
		count = int(manifest.count)
		return store.open(manifest.storage)
	var legacy: Variant = record.get("fauna")
	if not legacy is Dictionary or legacy.size() > 256:
		return store._fail("Ungültiger alter Labortierbestand.")
	# Validate the complete bounded legacy source before writing any blobs.
	for key: Variant in legacy:
		if not state_valid(key, legacy[key], id): return store._fail("Ungültiger alter Labortierzustand.")
	count = 0
	if not store.open({"schema": 1, "format": Store.FORMAT, "root": ""}): return false
	for key: String in legacy:
		if not put_state(key, legacy[key]): return false
	return true

func get_state(id: String) -> Dictionary:
	var cached: bool = store.cache.has(id)
	var state: Dictionary = store.get_value(id)
	if not cached and store.cache.has(id) and not state_valid(id, state, body_id):
		store._fail("Ungültiger gespeicherter Labortierzustand: " + id)
		return {}
	return state

func put_state(id: String, state: Dictionary) -> bool:
	if not state_valid(id, state, body_id): return store._fail("Ungültiger Labortierzustand: " + id)
	var exists: bool = not get_state(id).is_empty()
	if not store.last_error.is_empty() or not store.put(id, state.duplicate(true)): return false
	if not exists: count += 1
	return true

func checkpoint() -> Dictionary:
	var storage: Dictionary = store.checkpoint()
	if storage.is_empty(): return {}
	return {"schema": 1, "body_id": body_id, "count": count, "storage": storage}

func problem() -> String:
	return store.last_error

static func _problem(id: String, state: Dictionary, owner: String) -> String:
	return "" if state_valid(id, state, owner) else "Ungültiger Labortierzustand: " + id
