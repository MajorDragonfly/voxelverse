extends SceneTree
## ARCH-06: actual JSON, region paging and shared save/restart boundaries.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Store = preload("res://core/persistence/region_store.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const History = preload("res://core/persistence/slot_history.gd")
const Designs = preload("res://core/persistence/design_store.gd")
const Building = preload("res://civilization/buildings/building_blueprint.gd")
const PATH: String = "user://arch06_precision.json"
const INDEX: String = "user://arch06_restart.json"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.session_managed = true
	if OS.get_cmdline_user_args().has("--arch06-restart"):
		_restart(saves)
	else:
		_atomic_checks()
		var manifest: Dictionary = _region_checks()
		_campaign_checks(saves, manifest)
	for failure in failures: push_error(failure)
	print(JSON.stringify({"test": "coordinate_persistence", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _fixture() -> Dictionary:
	var addresses: Array = []
	for face in range(6):
		# Include near-edge and tiny face offsets; retain scalar doubles.
		addresses.append({"mode": Cube.MODE, "body_id": "precision_body", "face": face,
			"u": 0.9999999999999998, "v": -0.12345678901234567,
			"height": 123.12345678901235, "radius": 6371000.0})
	return {"schema": 1, "position": [1000000000010.125, -1000000000010.125, 149597870700.03125],
		"small": [0.12345678901234567, -0.9876543210987654, 1.2345678901234567e-12], "addresses": addresses}

func _same(actual: Variant, expected: Variant) -> bool:
	if expected is float:
		return (actual is float or actual is int) and var_to_bytes(float(actual)) == var_to_bytes(expected)
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size(): return false
		for key in expected:
			if not actual.has(key) or not _same(actual[key], expected[key]): return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size(): return false
		for i in range(expected.size()):
			if not _same(actual[i], expected[i]): return false
		return true
	return actual == expected

func _atomic_checks() -> void:
	var first: Dictionary = _fixture()
	_expect(not _same(Atomic.parse_dictionary(JSON.stringify(first)), first), "Fixture no longer detects the old lossy serializer.")
	_expect(Atomic.write(PATH, first, false) == OK, "Initial write failed.")
	_expect(_same(Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH)), first), "Atomic JSON changed coordinate bits.")
	var old_text: String = FileAccess.get_file_as_string(PATH)
	var second: Dictionary = first.duplicate(true)
	second.position[0] += 0.125
	_expect(Atomic.write(PATH, second) == OK, "Replacement write failed.")
	_expect(FileAccess.get_file_as_string(PATH + ".bak") == old_text, "Backup changed original bytes.")
	_expect(_same(Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH + ".bak")), first), "Backup changed coordinates.")
	var live_text: String = FileAccess.get_file_as_string(PATH)
	_expect(DirAccess.make_dir_absolute(PATH + ".tmp") == OK, "Write-failure fixture failed.")
	_expect(Atomic.write(PATH, first) != OK, "Blocked staging path unexpectedly succeeded.")
	_expect(FileAccess.get_file_as_string(PATH) == live_text and FileAccess.get_file_as_string(PATH + ".bak") == old_text, "Failed write changed live/backup.")
	DirAccess.remove_absolute(PATH + ".tmp")
	# A legacy source is backed up verbatim, without re-encoding or migration.
	var legacy: String = '{"schema":1,"position":[123.25,-71,0.125]}'
	_expect(Atomic._write_text(PATH, legacy) == OK and Atomic.write(PATH, first) == OK, "Legacy replacement failed.")
	_expect(FileAccess.get_file_as_string(PATH + ".bak") == legacy, "Legacy backup was re-encoded.")

func _region_checks() -> Dictionary:
	var store := Store.new()
	store.directory = "user://arch06_regions"
	# Build an existing v1 root with the historical compact serializer.
	var legacy: Dictionary = {"id": "old", "position": [123.25, -71.0, 0.125]}
	var blob: String = _old_blob(store, {"schema": 1, "key": "legacy", "value": legacy})
	var root_hash: String = _old_blob(store, {"schema": 1, "kind": "leaf", "entries": {"legacy": blob}})
	var old_manifest: Dictionary = {"schema": 1, "format": Store.FORMAT, "root": root_hash}
	_expect(store.open(old_manifest) and _same(store.get_value("legacy"), legacy), "Historical region root stopped loading.")
	_expect(store.put("precise", _fixture()), "Precise region rejected.")
	for i in range(Store.CACHE_LIMIT + 8):
		_expect(store.put("filler:" + str(i), {"id": i}), "Cache turnover failed.")
	_expect(not store.cache.has("precise"), "Precise region was not actually evicted.")
	var manifest: Dictionary = store.checkpoint()
	_expect(not manifest.is_empty(), "Precision checkpoint failed: " + store.last_error)
	_expect(_same(store.get_value("precise"), _fixture()), "Region eviction changed coordinates.")
	var before: String = store.root
	_expect(store.put("precise", _fixture()) and store.checkpoint().get("root") == before, "Unchanged precise region changed its content hash.")
	var earlier := Store.new()
	earlier.directory = store.directory
	_expect(earlier.open(old_manifest) and _same(earlier.get_value("legacy"), legacy) and earlier.get_value("precise").is_empty(), "New checkpoint changed historical root.")
	return manifest

func _old_blob(store: RefCounted, value: Dictionary) -> String:
	var text: String = JSON.stringify(value, "", true)
	var digest: String = text.sha256_text()
	var path: String = store._path(digest)
	_expect(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK and Atomic._write_text(path, text) == OK, "Historical region fixture failed.")
	return digest

func _player(body_id: String) -> Dictionary:
	var address: Dictionary = _fixture().addresses[0].duplicate(true)
	address.body_id = body_id
	address.erase("radius")
	return {"surface_address": address, "surface_forward": [0.0, 0.0, -1.0],
		"surface_velocity": [0.12345678901234567, 0.0, -0.9876543210987654], "surface_pitch": -0.12345678901234567}

func _same_player(actual: Dictionary, expected: Dictionary) -> bool:
	# SaveGameService adds campaign identity/design references to runtime state.
	for field in expected:
		if not actual.has(field) or not _same(actual[field], expected[field]): return false
	return true

func _campaign_checks(saves: Node, regions: Dictionary) -> void:
	var path: String = saves.create_slot("ARCH-06 Präzision", 15838)
	_expect(not path.is_empty(), "Shared sphere slot could not be created.")
	if path.is_empty(): return
	# The managed design mirror must contain exactly the loose file's bytes;
	# otherwise embedding it into a slot could undo the writer correction.
	var design_path: String = Building.DESIGN_DIR + "/arch06_precision.json"
	var design: Dictionary = Building.Assembly.serialize(Building.create_default())
	_expect(DirAccess.make_dir_recursive_absolute(Building.DESIGN_DIR) == OK and Designs.write(design_path, design) == OK, "Managed design write failed.")
	_expect(Designs.read_text(design_path) == FileAccess.get_file_as_string(design_path), "Managed design mirror differs from saved bytes.")
	var state: Node = root.get_node("GameState")
	var player: Dictionary = _player(state.get_current_body().id)
	saves._pending_player_state = player.duplicate(true)
	saves._last_player_state = player.duplicate(true)
	_expect(saves.save_now(), "Shared save rejected precise player.")
	var saved: Dictionary = saves._read_save(path)
	_expect(_same_player(saved.player, player), "Shared save changed surface coordinates or motion.")
	_expect(saves.save_now(), "Shared repeat save failed.")
	_expect(_same_player(saves._read_save(path + ".bak").player, player), "Shared backup changed precise player.")
	var paths: Array[String] = History.paths(path)
	_expect(not paths.is_empty() and _same_player(saves._read_save(paths[0]).player, player), "History changed precise player.")
	_expect(Atomic.write(INDEX, {"slot": path, "regions": regions}, false) == OK, "Restart index failed.")
	_child()
	# Public slot operations still use the same writer and retain precision.
	saves.session_active = false
	var copied: String = saves.duplicate_slot(path, "Präzise Kopie")
	_expect(not copied.is_empty() and _same_player(saves._read_save(copied).player, player), "Slot copy changed coordinates.")
	var source_text: String = FileAccess.get_file_as_string(path)
	var future: Dictionary = saved.duplicate(true)
	future.schema = 999
	_expect(Atomic.write(path, future, false) == OK, "Future-version fixture failed.")
	var future_text: String = FileAccess.get_file_as_string(path)
	_expect(not saves.select_slot(path), "Future save fell back to its compatible backup.")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(path) == future_text, "Blocked future save was overwritten.")
	_expect(Atomic._write_text(path, source_text) == OK, "Fixture restore failed.")

func _restart(saves: Node) -> void:
	var index: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(INDEX))
	_expect(not index.is_empty(), "Restart index missing.")
	if index.is_empty(): return
	_expect(saves.select_slot(index.slot), "Fresh process rejected shared sphere slot.")
	var body: Dictionary = root.get_node("GameState").get_current_body()
	var player: Dictionary = _player(body.id)
	_expect(_same_player(saves._export_player_state(), player), "Fresh process changed precise player.")
	_expect(Surface.player_problem(player, body).is_empty(), "Player address invalid after restart.")
	var foreign: Dictionary = player.duplicate(true)
	foreign.surface_address.body_id = "foreign_body"
	_expect(not Surface.player_problem(foreign, body).is_empty(), "Foreign body address accepted.")
	foreign = player.duplicate(true)
	foreign.surface_address.mode = "unknown_surface"
	_expect(not Surface.player_problem(foreign, body).is_empty(), "Unknown address accepted.")
	var store := Store.new()
	store.directory = "user://arch06_regions"
	_expect(store.open(index.regions), "Fresh process rejected region manifest.")
	_expect(_same(store.get_value("precise"), _fixture()), "Fresh process changed precise region.")
	_expect(saves.save_now() and _same_player(saves._read_save(index.slot).player, player), "Fresh process resave changed coordinates.")

func _child() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/coordinate_persistence_test.gd", "--", "--arch06-restart"], output, true)
	for line in output: print(str(line))
	_expect(code == 0, "Fresh-process precision check failed.")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
