extends SceneTree

const Address = preload("res://world/space/galaxy_address.gd")
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Journal = preload("res://world/space/galaxy_journal.gd")
const CatalogPanel = preload("res://world/planet_lab/galaxy_catalog_panel.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const SEED: String = "9007199254740993"
const DIRECTORY: String = "user://galaxy_contract_test"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--reopen" in OS.get_cmdline_user_args():
		_reopen()
		return
	_addresses()
	var catalog := Catalog.new(SEED)
	var reference: Dictionary = {}
	var ids: Array[String] = []
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for index in range(96):
		var coordinates: Array = [index * 17 - 700, 0, index * 7 - 280]
		if index == 0:
			coordinates = [0, 0, 0]
		var sector: Dictionary = catalog.sector_at(coordinates)
		reference[sector.id] = JSON.stringify(sector)
		for entry: Dictionary in sector.systems:
			var system: Dictionary = catalog.system(entry.id)
			ids.append(entry.id)
			_body_contract(system)
			_expect(catalog.stats().systems <= Catalog.SYSTEM_CACHE_LIMIT, "Unbounded system cache.")
		_expect(catalog.stats().sectors <= Catalog.SECTOR_CACHE_LIMIT, "Unbounded sector cache.")
	_expect(ids.size() > 32, "Fixture did not evict system metadata.")
	_expect(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == node_count, "Catalog queries created scene nodes.")
	var reverse: Array = reference.keys()
	reverse.reverse()
	for id: String in reverse:
		_expect(JSON.stringify(catalog.sector(id)) == reference[id], "Sector changes after eviction or reverse visits.")
	for coordinates: Array in [[1000, 0, -700], [-2400, 0, 800], [-3100, 0, 0], [1000000000, 0, -1000000000]]:
		var value: Dictionary = catalog.sector_at(coordinates)
		_expect(value == Catalog.new(SEED).sector_at(coordinates), "Far sector depends on query history.")
	_expect(catalog.sector_at([1000000000, 0, -1000000000]).systems.is_empty(), "Stars generated beyond the reference galaxy.")
	_expect(catalog.sector_at([0, 0, 0]) != Catalog.new("9007199254740992").sector_at([0, 0, 0]), "Universe seed lost its 64-bit integer identity.")
	var first: String = ids[0]
	var original: Dictionary = catalog.system(first)
	var mutable: Dictionary = catalog.system(first)
	mutable.bodies.clear()
	_expect(catalog.system(first) == original, "Caller mutation corrupts the cached catalog.")
	_journal(catalog, ids)
	await _panel(catalog)
	var expected: Dictionary = {"system_id": first, "system_json": JSON.stringify(original)}
	_expect(Atomic.write(DIRECTORY.path_join("reopen.json"), expected) == OK, "Could not stage the cross-process fixture.")
	var output: Array = []
	var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", get_script().resource_path, "--", "--reopen"]
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	_expect(exit_code == 0 and "GALAXY_REOPEN_PASSED" in str(output), "Fresh process did not recover the same system and changes: " + str(output))
	print("Galaxy catalog metrics ", JSON.stringify({"systems_queried": ids.size(), "sectors_queried": reference.size(), "cache": catalog.stats(), "restart_exit": exit_code, "sample": first, "fingerprint": JSON.stringify(original).sha256_text()}))
	_finish()

func _addresses() -> void:
	var id: String = Address.sector_id(SEED, 0, [-1000000000, 2, 1000000000])
	_expect(Address.parse(id).sector == ["-1000000000", "2", "1000000000"], "Sector integers did not round-trip.")
	_expect(Address.galaxy_id("9223372036854775807") != "", "Signed 64-bit seed boundary rejected.")
	for value in ["vx2/u1/g0", "vx1/u01/g0", "vx1/u1/g0/s-0,0,0", "vx1/u1/g0/s0,0,0/t8", "vx1/u1/g0/s0,0,0/t0/b64", "vx1/u1/g0/s0,0,0/t0/../../save", "vx1/u9223372036854775808/g0", "vx1/u1/g0/s1000000001,0,0"]:
		_expect(Address.parse(value).is_empty(), "Noncanonical or unsupported address accepted: " + value)
	var normalized: Dictionary = Address.normalize_position([999999999, 0, -999999999], [16.25, -0.25, 0.000001])
	_expect(normalized.sector == ["1000000000", "-1", "-999999999"] and normalized.offset_ly[0] == 0.25 and normalized.offset_ly[1] == 15.75, "Negative/positive sector carry failed.")
	var delta: Array = Address.relative_ly(normalized, {"sector": ["999999999", "0", "-999999999"], "offset_ly": [16.25, -0.25, 0.0]})
	_expect(delta.size() == 3 and absf(delta[0]) < 1e-12 and absf(delta[1]) < 1e-12 and absf(delta[2] - 0.000001) < 1e-12, "Sub-sector offset was rounded through a global float vector.")
	_expect(Address.normalize_position([1000000000, 0, 0], [16.0, 0, 0]).is_empty(), "Out-of-range sector carry wrapped.")

func _body_contract(system: Dictionary) -> void:
	_expect(system.bodies.size() >= 3 and system.bodies.size() <= 34, "Invalid body budget.")
	var stars: int = 0
	for body: Dictionary in system.bodies.values():
		stars += int(body.kind == "star")
		_expect(Address.parse(body.id).system_id == system.id and body.radius > 0 and is_finite(body.radius) and body.gravity > 0 and is_finite(body.gravity), "Body has an invalid identity or physical size.")
		_expect(body.seed > 0 and body.seed < 2147483647 and body.terrain_revision == 3, "Terrain generator contract changed.")
		if not str(body.parent_id).is_empty():
			_expect(system.bodies.has(body.parent_id), "Orbit references a missing parent.")
			_expect(body.orbit_radius > body.radius + system.bodies[body.parent_id].radius, "Orbit intersects the parent body.")
		if body.kind in ["star", "gas_giant"]:
			_expect(not body.landable, "A gas body was declared walkable terrain.")
	_expect(stars == system.star_count, "Binary system star count disagrees with its sector entry.")

func _journal(catalog: RefCounted, ids: Array[String]) -> void:
	var journal := Journal.new(catalog, DIRECTORY)
	_expect(journal.open() == OK, "Could not initialize galaxy storage.")
	var id: String = ids[0]
	var record: Dictionary = journal.read(id).get("record", {})
	if record.is_empty():
		_expect(false, "Initial system record is unavailable.")
		return
	record.name = "Mein erstes System"
	record.note = "Bleibt nach Cachewechsel und Neustart erhalten."
	record.discovered = true
	var body_id: String = catalog.system(id).bodies.keys()[-1]
	record.bodies[body_id] = {"discovered": true, "name": "Beobachteter Mond", "note": "Körperbezogene Änderung"}
	_expect(journal.write(record) == OK, "Could not persist system/body changes.")
	_expect(journal.write(record) == ERR_BUSY, "Stale revision overwrote a newer saved record.")
	for system_id: String in ids:
		_expect(journal.read(system_id).error == OK and journal.stats().loaded_records <= Journal.CACHE_LIMIT, "Journal cache is unbounded or cannot read a generated system.")
	_expect(DirAccess.get_files_at(DIRECTORY.path_join("systems")).size() == 1, "Read-only catalog browsing wrote empty per-system files.")
	record = journal.read(id).record
	_expect(record.name == "Mein erstes System" and record.bodies.has(body_id), "Cache eviction discarded stored changes.")
	record.note = "Zweite Fassung"
	_expect(journal.write(record) == OK, "Second revision failed.")
	var path: String = journal.record_path(id)
	_write_text(path, "{broken")
	journal.clear_cache()
	var recovered: Dictionary = journal.read(id)
	_expect(recovered.error == OK and recovered.recovered and recovered.record.revision == 1, "Corrupted primary did not recover the valid backup.")
	_expect(journal.write(recovered.record) == OK, "Recovered data could not replace the damaged primary safely.")
	var bytes: String = FileAccess.get_file_as_string(path)
	var future: String = '{"schema":999,"catalog_version":"galaxy_catalog_v999"}'
	_write_text(path, future)
	journal.clear_cache()
	_expect(journal.read(id).error == ERR_UNAVAILABLE and journal.write(recovered.record) == ERR_UNAVAILABLE and FileAccess.get_file_as_string(path) == future, "Future system format was downgraded through a backup or write.")
	_write_text(path, bytes)
	journal.clear_cache()
	var manifest: String = DIRECTORY.path_join("manifest.json")
	bytes = FileAccess.get_file_as_string(manifest)
	_write_text(manifest, future)
	_expect(journal.write(journal.read(id).record) == ERR_UNAVAILABLE, "New manifest was bypassed by a cached record.")
	_write_text(manifest, bytes)
	_expect(Journal.new(Catalog.new("1"), DIRECTORY).open() == ERR_INVALID_DATA and FileAccess.get_file_as_string(manifest) == bytes, "Another universe reused or overwrote this journal.")

func _panel(catalog: RefCounted) -> void:
	root.size = Vector2i(1152, 648)
	var panel := CatalogPanel.new()
	panel.catalog = catalog
	panel.journal_directory = DIRECTORY
	root.add_child(panel)
	await process_frame
	_expect(panel.system_list.item_count > 0 and not panel.record.is_empty(), "Catalog UI has no selectable saved systems.")
	panel.note.text = "Notiz aus der Katalogansicht"
	_expect(panel.save_changes(), "Catalog UI could not save its edit.")
	var id: String = panel.selected_id
	panel.show_sector([1000, 0, -700])
	panel.show_sector([0, 0, 0])
	_expect(panel.selected_id == id and panel.note.text == "Notiz aus der Katalogansicht", "UI revisits lost the saved note.")
	panel.close()
	await process_frame

func _reopen() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(DIRECTORY.path_join("reopen.json")))
	var catalog := Catalog.new(SEED)
	var journal := Journal.new(catalog, DIRECTORY)
	_expect(journal.open() == OK, "Fresh process did not open the same galaxy manifest.")
	_expect(JSON.stringify(catalog.system(expected.get("system_id", ""))) == expected.get("system_json"), "Fresh process regenerated a different system.")
	var loaded: Dictionary = journal.read(expected.get("system_id", ""))
	_expect(loaded.get("record", {}).get("name") == "Mein erstes System" and loaded.get("record", {}).get("note") == "Notiz aus der Katalogansicht" and loaded.get("record", {}).get("bodies", {}).size() == 1, "Fresh process lost system/body observations.")
	if failures.is_empty():
		print("GALAXY_REOPEN_PASSED")
	_finish()

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
