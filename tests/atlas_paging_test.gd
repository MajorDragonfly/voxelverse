extends SceneTree
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Store = preload("res://core/persistence/region_store.gd")
const COUNT: int = 8205
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://atlas-paging-save.json"
	if "--atlas-restart" in OS.get_cmdline_user_args():
		_restart()
		await _finish()
		return
	state.start_world_with_seed(15838)
	state.set_process(false)
	var atlas := Atlas.new()
	var body: Dictionary = state.get_current_body_record()
	_expect(atlas.bind(Atlas.create(body.id, "legacy_plane_v9")), "Cannot bind initial atlas.")
	_expect(atlas.reveal(_address(body.id, 0), 0), "Initial visit failed.")
	_expect(atlas.checkpoint(), "First checkpoint failed: " + atlas.last_error)
	var history: Dictionary = atlas.data.duplicate(true)
	for i in range(1, COUNT):
		if not atlas.reveal(_address(body.id, i), 0):
			_expect(false, "Exploration stopped at tile %d: %s" % [i, atlas.last_error])
			break
	_expect(atlas.data.schema == Atlas.SCHEMA and not atlas.full, "Old exploration ceiling is still a gameplay limit.")
	_expect(atlas.data.tiles.size() <= Atlas.PENDING_LIMIT and atlas.store.cache.size() <= Store.CACHE_LIMIT and atlas.store.pages.size() <= Store.PAGE_LIMIT, "Atlas exceeded resident tile/page budgets.")
	_expect(atlas.known(_address(body.id, 0)) and atlas.known(_address(body.id, COUNT - 1)), "Eviction forgot early or latest ground.")
	var reads: int = atlas.store.reads
	var extent: Array = atlas.explored_extent()
	_expect(extent.size() == 4 and extent[0] == 8 and extent[2] == (COUNT - 1) * 512 + 8 and atlas.store.reads == reads, "Fit explored lost evicted ground or scanned disk.")
	# Revisiting a committed tile modifies a copy in the save-safe overlay.
	var extra: Dictionary = Surface.plane_address(body.id, Vector3(24, 0, 8))
	_expect(atlas.reveal(extra, 0) and atlas.known(extra), "Committed tile did not accept new bits.")
	var before_view: String = JSON.stringify(atlas.data)
	for i in range(COUNT - 1, -1, -97): atlas.known(_address(body.id, i))
	_expect(JSON.stringify(atlas.data) == before_view, "Reading the map changed its persistent state.")
	var old := Atlas.new()
	_expect(old.bind(history) and old.known(_address(body.id, 0)) and not old.known(extra) and not old.known(_address(body.id, 1)), "New exploration mutated an old root.")
	body.exploration_atlas = atlas.data
	_expect(saves.save_now(), "Campaign cannot save paged atlas: " + saves.last_error)
	_expect(not atlas.data.tiles.is_empty(), "Save fixture does not exercise an unflushed overlay.")
	var saved_bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/atlas_paging_test.gd", "--", "--atlas-restart"], output, true)
	_expect(code == 0 and str(output).contains("ATLAS_PAGING_PASS") and not str(output).contains("ERROR:"), "Fresh process lost atlas: " + str(output).right(1200))
	_migration()
	_sphere()
	_corruption()
	_write_failure(saved_bytes)
	print("ATLAS_PAGING_METRICS tiles=%d pending=%d cache=%d pages=%d reads=%d writes=%d" % [COUNT, atlas.data.tiles.size(), atlas.store.cache.size(), atlas.store.pages.size(), atlas.store.reads, atlas.store.writes])
	await _finish()

func _restart() -> void:
	_expect(saves.load_now(), "Restart cannot load campaign: " + saves.last_error)
	var record: Dictionary = state.get_current_body_record().get("exploration_atlas", {})
	var atlas := Atlas.new()
	if not atlas.bind(record): _expect(false, atlas.last_error); return
	_expect(atlas.store.reads == 1 and atlas.store.cache.is_empty(), "Loading materialized explored tiles.")
	for i in [0, 1, 4096, COUNT - 1]:
		_expect(atlas.known(_address(record.body_id, i)), "Restart lost tile " + str(i))
	_expect(atlas.known(Surface.plane_address(record.body_id, Vector3(24, 0, 8))), "Restart lost unflushed changes to an older tile.")
	_expect(not atlas.known(_address(record.body_id, COUNT + 10)), "Restart revealed unvisited ground.")
	_expect(atlas.store.cache.size() <= Store.CACHE_LIMIT, "Restart violated cache limit.")

func _migration() -> void:
	var legacy: Dictionary = Atlas.create("legacy", "legacy_plane_v9")
	for i in range(Atlas.MAX_TILES):
		var rows: Array = []
		rows.resize(32); rows.fill(0)
		rows[31] = 4294967295 # Every bit, including bit 31, survives JSON/migration.
		legacy.tiles["-1:%d:-1" % -i] = rows
	legacy.places["home"] = {"id": "home", "name": "Heimat", "kind": "home", "species_id": "", "object_id": "", "own": true, "address": Surface.plane_address("legacy", Vector3.ZERO)}
	var source: Dictionary = JSON.parse_string(JSON.stringify(legacy))
	var atlas := Atlas.new()
	_expect(atlas.bind(source), "Full legacy atlas cannot migrate: " + atlas.last_error)
	_expect(legacy.schema == 1 and legacy.tiles.size() == Atlas.MAX_TILES, "Migration mutated its source copy.")
	_expect(source.schema == Atlas.SCHEMA and source.tiles.is_empty() and JSON.stringify(source.places) == JSON.stringify(legacy.places), "Migration lost inline data or places.")
	for i in [0, 4096, Atlas.MAX_TILES - 1]:
		for column in [0, 31]:
			_expect(atlas.known(Surface.plane_address("legacy", Vector3((-i * 32 + column + 0.5) * 16, 0, -8))), "Migration lost signed coordinates or high bits.")
	_expect(atlas.reveal(Surface.plane_address("legacy", Vector3(520, 0, 8)), 0), "Full old atlas cannot explore new ground.")

func _sphere() -> void:
	var atlas := Atlas.new()
	atlas.bind(Atlas.create("sphere", Cube.MODE, 6371000))
	var seam: Dictionary = Cube.address("sphere", 0, 0.999999, 0.2)
	var local := Surface.new()
	local.configure(seam, 6371000)
	atlas.reveal(seam)
	for face in range(6):
		for i in range(40): atlas.reveal(Cube.address("sphere", face, -0.9 + i * 0.04, 0.3), 0)
	var pole: Dictionary = Cube.address("sphere", 2, 0, 0)
	atlas.reveal(pole)
	_expect(atlas.checkpoint(), "Sphere checkpoint failed.")
	var restored := Atlas.new()
	_expect(restored.bind(JSON.parse_string(JSON.stringify(atlas.data))), "Sphere atlas cannot reopen.")
	_expect(restored.known(pole) and restored.known(seam) and restored.known(local.address_at(Vector2(12, 0))), "Paging broke poles or cube-face seams.")
	_expect(not restored.known(Cube.address("another", 2, 0, 0)), "Atlas leaked knowledge between bodies.")

func _corruption() -> void:
	var writer := Store.new()
	writer.put("-1:0:0", {"schema": 1, "body_id": "wrong-body", "mode": "legacy_plane_v9", "divisions": 0, "rows": []})
	var record: Dictionary = Atlas.create("corrupt", "legacy_plane_v9")
	record.merge({"schema": Atlas.SCHEMA, "storage": writer.checkpoint(), "extent": [8, 8, 8, 8]}, true)
	var atlas := Atlas.new()
	_expect(atlas.bind(record), "Tile validation was not lazy.")
	_expect(not atlas.known(_address("corrupt", 0)) and not atlas.last_error.is_empty() and not atlas.checkpoint(), "Malformed tile was silently treated as unexplored.")
	var missing: Dictionary = record.duplicate(true)
	missing.storage.root = "f".repeat(64)
	_expect(not Atlas.validate(missing, "corrupt").is_empty(), "Missing root was accepted.")
	var future: Dictionary = record.duplicate(true)
	future.storage.root = writer._write({"schema": 2, "kind": "leaf", "entries": {}})
	_expect(Atlas.newer(future), "Future root could be replaced by a backup.")
	var saved := {"game_state": {"campaign": {"bodies": {"corrupt": {"exploration_atlas": future}}}}}
	_expect(saves._has_unsupported_contract(saved), "Save service did not protect a future atlas root.")
	# Even a valid hash must not permit a future/malformed tile payload.
	writer = Store.new()
	writer.put("-1:0:0", {})
	record.storage = writer.checkpoint()
	atlas = Atlas.new()
	atlas.bind(record)
	_expect(not atlas.known(_address("corrupt", 0)) and not atlas.last_error.is_empty(), "Empty committed tile passed validation.")

func _write_failure(saved_bytes: String) -> void:
	var path: String = "user://atlas-blocked-directory"
	var blocker := FileAccess.open(path, FileAccess.WRITE)
	blocker.store_string("file, not directory"); blocker.close()
	var tracker := preload("res://ui/world_map/exploration_tracker.gd").new()
	root.add_child(tracker)
	tracker.set_process(false)
	tracker.atlas.bind(Atlas.create("blocked", "legacy_plane_v9"), path)
	for i in range(Atlas.PENDING_LIMIT): tracker.atlas.reveal(_address("blocked", i), 0)
	var pending: String = JSON.stringify(tracker.atlas.data)
	# The engine logs the deliberately denied mkdir; assertions below own this
	# expected error so the suite still reports unexpected engine errors normally.
	var report_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var revealed: bool = tracker.atlas.reveal(_address("blocked", Atlas.PENDING_LIMIT), 0)
	Engine.print_error_messages = report_errors
	_expect(not revealed, "Unwritable directory did not fail.")
	_expect(JSON.stringify(tracker.atlas.data) == pending, "Failed checkpoint discarded pending bits or changed its root.")
	_expect(not tracker.problem.is_empty() and saves._write_blocked and not saves.save_now(), "Atlas storage failure did not block slot overwrite.")
	_expect(FileAccess.get_file_as_string(saves.save_path) == saved_bytes, "Failed map write changed saved campaign bytes.")
	tracker.queue_free()
	# Fail after one tile has flushed; publication must still be all-or-nothing.
	var partial := Atlas.new()
	partial.bind(Atlas.create("partial", "legacy_plane_v9"))
	partial.reveal(_address("partial", 0), 0)
	partial.reveal(_address("partial", 1), 0)
	partial.store.validate_value = func(key: String, _value: Dictionary) -> String: return "injected second-tile failure" if key == "-1:1:0" else ""
	pending = JSON.stringify(partial.data)
	_expect(not partial.checkpoint() and partial.store.writes > 0 and JSON.stringify(partial.data) == pending, "Partial checkpoint published an incomplete root.")
	var recovered := Atlas.new()
	_expect(recovered.bind(partial.data.duplicate(true)) and recovered.known(_address("partial", 0)) and recovered.known(_address("partial", 1)), "Pending overlay cannot recover after interrupted paging.")

func _address(body_id: String, tile: int) -> Dictionary:
	return Surface.plane_address(body_id, Vector3(tile * 512 + 8, 0, 8))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	print("ATLAS_PAGING_PASS" if failures.is_empty() else "ATLAS_PAGING_FAIL")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
