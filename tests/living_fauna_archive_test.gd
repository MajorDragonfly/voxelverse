extends SceneTree
## Exact legacy migration, >256 histories, real streamer nodes and fresh process.
const World = preload("res://world/planet_lab/living_planet.gd")
const Archive = preload("res://world/surface/living_fauna_archive.gd")
const Save = preload("res://world/surface/living_planet_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Compare = preload("res://tests/fixtures/domestic_native_comparison.gd")
const PATH: String = "user://lab-fauna-population.json"
const EXPECTED: String = "user://lab-fauna-expected.bin"
const HISTORY: int = 384
var failures: Array[String] = []
var world: Node3D
var design: Dictionary
var runtime_ids: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	world = World.new()
	world.store_path = PATH
	world.paused = true
	root.add_child(world)
	current_scene = world
	_quiet()
	if "--verify-only" in OS.get_cmdline_user_args():
		_verify_restart()
		await _finish()
		return
	design = Blueprint.create_default()
	design.body.shape = Vector3(1.1234567, 0.8912345, 2.2345678)
	design.appearance.base_color = Color(0.123456, 0.654321, 0.876543, 1.0)
	var legacy: Dictionary = world.snapshot()
	legacy.schema = 3
	var record: Dictionary = legacy.bodies[world.body_id]
	record.erase("fauna_archive")
	record.fauna = {}
	for i in range(256): record.fauna[_id(i)] = _state(i)
	_expect(Save.valid(legacy), "Legacy boundary fixture is invalid")
	_expect(Atomic.write(PATH, legacy, false) == OK, "Cannot create legacy source")
	var source: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	_expect(world.load_lab(), "Legacy lab failed actual load")
	_quiet()
	_expect(FileAccess.get_file_as_bytes(PATH) == source, "Opening the legacy source overwrote it")
	_expect(world.ecosystem.fauna.count == 256 and not world.records[world.body_id].has("fauna"), "Legacy history was not migrated")
	for i in range(256, HISTORY):
		_expect(world.ecosystem.fauna.put_state(_id(i), _state(i)), "History stopped at former record cap")
	_expect(not world.ecosystem.fauna.store.cache.has(_id(0)), "Early history never left the bounded cache")
	var first: Dictionary = world.ecosystem.fauna.get_state(_id(0))
	_expect(Compare.native_equal(first, _state(0)), "Eviction changed early pose or anatomy")
	first.traveled = 912.375
	first.returning = true
	_expect(world.ecosystem.fauna.put_state(_id(0), first), "Cannot update an evicted individual")
	_install_patches()
	_spawn_four()
	_expect(world.ecosystem.fauna.count == HISTORY + 4, "Real streamer did not create new identities beyond 256")
	# Capture after a checkpoint must mark the pinned record dirty again.
	_expect(world.save_lab(), "Paged lab checkpoint failed")
	var previous: Dictionary = Save.read(PATH).data.bodies[world.body_id].fauna_archive
	world.ecosystem.animals[runtime_ids[0]].traveled = 77.125
	_expect(world.save_lab(), "Pinned animal changed after save was not saved again")
	var old := Archive.new()
	_expect(old.open(world.body_id, {"fauna_archive": previous}), "Old generation is no longer readable")
	_expect(old.get_state(runtime_ids[0]).traveled != 77.125, "New save mutated an older immutable generation")
	var expected: Dictionary = {"states": {}, "design": design, "runtime_ids": runtime_ids}
	for i in range(HISTORY): expected.states[_id(i)] = world.ecosystem.fauna.get_state(_id(i)).duplicate(true)
	for id: String in runtime_ids: expected.states[id] = world.ecosystem.fauna.get_state(id).duplicate(true)
	var output := FileAccess.open(EXPECTED, FileAccess.WRITE)
	output.store_var(expected, false)
	output.close()
	_expect(world.ecosystem.fauna.store.peak_cache <= Archive.Store.CACHE_LIMIT and world.ecosystem.fauna.store.pages.size() <= Archive.Store.PAGE_LIMIT, "Archive exceeded resident budgets")
	var measured: Dictionary = {"history": HISTORY + 4, "active": world.ecosystem.animals.size(), "peak_cache": world.ecosystem.fauna.store.peak_cache, "pages": world.ecosystem.fauna.store.pages.size(), "save": ProjectSettings.globalize_path(PATH)}
	if "--create-only" not in OS.get_cmdline_user_args():
		var child: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--verify-only"], child, true)
		_expect(code == 0 and str(child).contains("LIVING_FAUNA_ARCHIVE_PASS") and not str(child).contains("ERROR:"), "Fresh process failed: " + str(child))
		_faults()
	print("LIVING_FAUNA_METRICS ", JSON.stringify(measured))
	await _finish()

func _quiet() -> void:
	world.set_paused(true)
	world.set_process(false)
	world.ecosystem.set_process(false)
	world.ecosystem.domestic.close(world.ecosystem)
	world.ecosystem.domestic = null

func _id(index: int) -> String:
	return world.body_id + ":land1:18:0:" + str(index) + ":0:animal"

func _state(index: int) -> Dictionary:
	var here: Dictionary = Cube.address(world.body_id, 0, -0.5 + index * 0.001, 0.1234567890123, 12.1234567890123)
	return {"location": here, "forward": [0.0, 0.0, -1.0], "velocity": [0.123456789, 0.0, 0.0], "traveled": index + 0.125,
		"home": here.duplicate(true), "goal": here.duplicate(true), "returning": false, "design": JSON.from_native(design)}

func _install_patches() -> void:
	runtime_ids.clear()
	var cells: Array = world.ecosystem.wanted.values()
	for i in range(4):
		var cell: Dictionary = cells[i]
		var id: String = cell.id + ":animal"
		runtime_ids.append(id)
		var node := Node3D.new()
		world.add_child(node)
		world.ecosystem.patches[cell.id] = {"node": node, "cell": cell, "instances": 0,
			"actor": {"id": id, "location": world.walker.location(), "species_seed": 120 + i, "role": "grazer"}}

func _spawn_four() -> void:
	world.ecosystem.paused = false
	for i in range(5):
		world.ecosystem._update_animals()
		_expect(world.ecosystem.animals.size() <= 4, "Physical animal limit exceeded")
		for animal: Node in world.ecosystem.animals.values(): animal.enabled = false
	world.ecosystem.paused = true
	_expect(world.ecosystem.animals.size() == 4, "Actual runtime creatures did not spawn beyond history cap")

func _verify_restart() -> void:
	var file := FileAccess.open(EXPECTED, FileAccess.READ)
	var expected: Dictionary = file.get_var(false)
	file.close()
	_expect(world.ecosystem.fauna.count == HISTORY + 4, "Restart lost identities")
	_expect(world.ecosystem.fauna.store.cache.is_empty(), "Restart eagerly loaded all history")
	for id: String in expected.states:
		var actual: Dictionary = world.ecosystem.fauna.get_state(id)
		_expect(Compare.native_equal(actual, expected.states[id]), "Restart changed individual state: " + id)
		if id.ends_with(":0:animal"):
			_expect(Compare.native_equal(JSON.to_native(actual.design, false), expected.design), "Native Vector3/Color anatomy changed")
	_install_patches()
	_expect(runtime_ids == expected.runtime_ids, "Body-fixed runtime identities changed")
	_spawn_four()
	for id: String in runtime_ids:
		_expect(Compare.native_equal(world.ecosystem.animals[id].design, JSON.to_native(expected.states[id].design, false)), "Restart regenerated runtime anatomy")
	_expect(world.ecosystem.animals[runtime_ids[0]].traveled == 77.125, "Restart lost post-checkpoint active changes")
	_expect(world.ecosystem.fauna.store.peak_cache <= 96 and world.ecosystem.fauna.store.pages.size() <= 128, "Restart cache is unbounded")

func _faults() -> void:
	var original: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(PATH + ".bak")
	var saved: Dictionary = Save.read(PATH).data
	var future: Dictionary = saved.duplicate(true)
	future.bodies[world.body_id].fauna_archive.schema = 99
	_expect(Atomic.write("user://lab-fauna-future.json", future, false) == OK, "Cannot create future manifest")
	_expect(Atomic.write("user://lab-fauna-future.json.bak", saved, false) == OK, "Cannot create old future backup")
	var protected: PackedByteArray = FileAccess.get_file_as_bytes("user://lab-fauna-future.json")
	_expect(Save.read("user://lab-fauna-future.json").error != OK and Save.write(saved, "user://lab-fauna-future.json") != OK, "Future archive was downgraded through backup")
	_expect(FileAccess.get_file_as_bytes("user://lab-fauna-future.json") == protected, "Future source bytes changed")
	# The root remains valid; the payload is discovered only on first lookup.
	var store: RefCounted = world.ecosystem.fauna.store
	var id: String = runtime_ids[0]
	var hash_value: String = store._lookup(store.root, id, id.sha256_text(), 0)
	var path: String = store._path(hash_value)
	var contents: String = FileAccess.get_file_as_string(path)
	Atomic._write_text(path, "corrupt")
	_expect(world.load_lab(), "Valid header should allow lazy archive open")
	_quiet()
	_install_patches()
	world.ecosystem.paused = false
	world.ecosystem._update_animals()
	_expect(world.ecosystem.animals.is_empty() and not world.ecosystem.fauna.problem().is_empty(), "Corrupt saved animal was regenerated")
	_expect(not world.save_lab() and world.read_only, "Archive read failure did not protect actual save")
	_expect(FileAccess.get_file_as_bytes(PATH) == original and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Read failure changed primary or backup")
	Atomic._write_text(path, contents)
	_expect(world.load_lab(), "Cannot reload after restoring damaged fixture")
	_quiet()
	var blocker: String = "user://lab-fauna-blocker"
	Atomic._write_text(blocker, "regular file blocks directory creation")
	_expect(world.ecosystem.fauna.put_state(_id(HISTORY + 1), _state(HISTORY + 1)), "Cannot stage write failure")
	world.ecosystem.fauna.store.directory = blocker + "/blobs"
	_expect(not world.save_lab() and world.read_only, "Blob write failure reported save success")
	_expect(FileAccess.get_file_as_bytes(PATH) == original and FileAccess.get_file_as_bytes(PATH + ".bak") == backup, "Failed checkpoint replaced primary or backup")
	# Well-hashed future payloads and malformed state must also fail closed.
	for kind: String in ["missing", "future", "invalid", "empty"]:
		var probe := Archive.new()
		var builder := Archive.Store.new()
		builder.directory = "user://lab-fault-" + kind
		var state: Dictionary = _state(0)
		if kind == "invalid": state.home.body_id = "foreign"
		if kind == "empty": state = {}
		var blob: String = builder._write({"schema": 99 if kind == "future" else 1, "key": _id(0), "value": state})
		var root_hash: String = builder._set_entry("", _id(0), _id(0).sha256_text(), blob, 0)
		if kind == "missing": DirAccess.remove_absolute(builder._path(blob))
		var manifest: Dictionary = {"schema": 1, "body_id": world.body_id, "count": 1, "storage": {"schema": 1, "format": Archive.Store.FORMAT, "root": root_hash}}
		_expect(probe.open(world.body_id, {"fauna_archive": manifest}, builder.directory), "Fault fixture root could not open")
		_expect(probe.get_state(_id(0)).is_empty() and not probe.problem().is_empty() and probe.checkpoint().is_empty(), kind + " payload was accepted")

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)

func _finish() -> void:
	world.queue_free()
	await process_frame
	for message: String in failures: push_error(message)
	print("LIVING_FAUNA_ARCHIVE_PASS" if failures.is_empty() else "LIVING_FAUNA_ARCHIVE_FAIL")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
