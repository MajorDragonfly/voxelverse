extends SceneTree
const Encounters = preload("res://core/progression/creature_encounters.gd")
const Store = preload("res://core/persistence/region_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const COUNT: int = 1200
const SAVE: String = "user://saves/slot_encounter_archive.json"
var failures: Array[String] = []
var state: Node
var progression: Node
var saves: Node
var host: Node
var peak_cache: int = 0
var peak_pages: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	DirAccess.make_dir_recursive_absolute(SAVE.get_base_dir())
	state.set_process(false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--archive-restart" in args or "--backup-verify" in args:
		_expect(saves.load_now(), "Fresh process cannot load encounter archive: " + saves.last_error)
		_expect(progression._encounters.store != null and progression._encounters.store.reads == 1 and progression._encounters.store.cache.is_empty(), "Loading eagerly decoded encounter records.")
		if state.get_current_body_record().has("surface_population"): _bind()
		_verify()
		_print_metrics()
		await _finish()
		return
	state.start_world_with_seed(15838, Cube.MODE)
	saves._pending_player_state = {"surface_address": state.get_current_body_record().surface_context.spawn.duplicate(true), "surface_forward": [0.0, 0.0, 1.0], "surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": -0.18, "health": 100.0, "hunger": 100.0, "thirst": 100.0}
	# A pre-archive spherical ledger: no migration may invent/reset its state.
	for i in range(12): _expect(progression._encounters.put(_expected(i)), "Cannot prepare legacy ledger.")
	_expect(progression._encounters.store == null, "Fixture is not an inline legacy ledger.")
	var legacy: Dictionary = progression._encounters.export_state()
	_expect(saves.save_now(), "Initial archive migration cannot save: " + saves.last_error)
	# Reopen an actual old inline snapshot and verify the shared writer keeps it
	# byte-for-byte as the previous generation when migrating to the archive.
	var inline: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE))
	inline.progression.creature_encounters = legacy
	_expect(Atomic.write(SAVE, inline, false) == OK and saves.load_now(), "Cannot reopen old inline campaign.")
	var inline_bytes: String = FileAccess.get_file_as_string(SAVE)
	_expect(progression._encounters.store == null and saves.save_now(), "Old campaign was not migrated through the normal save path.")
	_expect(FileAccess.get_file_as_string(SAVE + ".bak") == inline_bytes, "Migration changed its previous inline snapshot.")
	_expect(progression._encounters.entries.is_empty(), "Migration retained the full inline ledger.")
	var first: Dictionary = progression._encounters.export_state()
	_expect(JSON.stringify(first).length() < 256, "Archive snapshot copied encounter records.")
	for i in range(12, COUNT):
		_expect(progression.store_creature_encounter(_expected(i)).ok, "Encounter write failed at " + str(i))
		if not failures.is_empty(): break
	var copied: Dictionary = progression.get_saved_creature_encounter(_identity(1).object_id)
	copied.trust = 99.0
	_expect(progression.get_saved_creature_encounter(_identity(1).object_id).trust == 1.0, "Reader mutated the authoritative archive.")
	# Real discovery evidence and the behavior receipt share the same save.
	progression.register_species_scan(771, preload("res://creatures/wildlife/species_assembly_factory_v7.gd").create_species(771, Vector2i.ZERO, "grazer"))
	var reward: Dictionary = _expected(COUNT)
	reward.trust = 100.0
	reward.relation = "ally"
	_expect(progression.store_creature_encounter(reward, true, "befriended", {"target_relation": "wild"}).ok, "Cannot commit reward with archived relationship.")
	_expect(_earned() == 3, "Initial relationship reward changed.")
	_expect(progression.store_creature_encounter(reward, true, "befriended", {"target_relation": "wild"}).ok and _earned() == 3, "One encounter paid twice.")
	var old := Encounters.new()
	_expect(old.import_state(first) and old.saved(_identity(1).object_id) == legacy.entries[_identity(1).object_id], "Later archive writes changed the earlier root.")
	_body_roundtrip()
	_verify()
	if "--backup-create" in args:
		_print_metrics()
		await _finish()
		return
	# The already archived encounter moves into its regional owner once.
	_bind()
	var animal: Dictionary = _animal(3)
	_expect(host.storage.put(animal), "Regional owner cannot take an archived encounter.")
	_expect(host.storage.checkpoint(), "Regional adoption cannot checkpoint: " + host.storage.store.last_error)
	_expect(progression._encounters.saved(animal.id).is_empty(), "Adoption left a second global owner.")
	_expect(progression.get_saved_creature_encounter(animal.id) == _expected(3), "Adoption changed encounter evidence.")
	_expect(saves.save_now(), "Cannot save adopted encounter.")
	_verify()
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/encounter_archive_test.gd", "--", "--archive-restart"], output, true)
	_expect(code == 0 and str(output).contains("ENCOUNTER_ARCHIVE_PASSED") and not str(output).contains("ERROR:"), "Fresh process verification failed: " + str(output).right(2400))
	_rollback()
	_migration_failure()
	_corruption_and_future()
	_print_metrics()
	await _finish()

func _identity(i: int) -> Dictionary:
	var body_id: String = state.get_current_body_record().id
	var region: String = state.campaign.region_id(body_id, Vector2i(i, 0))
	return {"object_id": state.campaign.object_id(region, "arch14:" + str(i)), "species_id": state.campaign.species_id(body_id, 771), "body_id": body_id, "region_id": region, "habitat_cell": "%d:0" % i, "species_seed": 771}

func _expected(i: int) -> Dictionary:
	var data: Dictionary = Encounters.new().get_entry(_identity(i), "grazer", i)
	data.trust = float(i % 99)
	data.health_ratio = 0.0 if i % 17 == 0 else 0.625
	data.dead = i % 17 == 0
	data.carcass_food = 0.0 if i % 17 == 0 else 7.0
	data.player_harmed = i % 5 == 0
	data.need_origin = "player" if data.player_harmed else "environment"
	data.conflict_reason = "unprovoked" if data.player_harmed else ""
	data.conflict_relation = "wild" if data.player_harmed else ""
	return data

func _earned() -> int: return int(progression.get_behavior_wallet(0).earned.social)

func _verify() -> void:
	for i in range(COUNT - 1, -1, -1):
		var data: Dictionary = progression.get_saved_creature_encounter(_identity(i).object_id)
		_expect(data == _expected(i), "Encounter identity/health/trust/evidence changed at " + str(i))
		if data.is_empty(): break
		peak_cache = maxi(peak_cache, progression._encounters.store.peak_cache)
		peak_pages = maxi(peak_pages, progression._encounters.store.pages.size())
		_expect(progression._encounters.entries.is_empty() and progression._encounters.store.cache.size() <= Store.CACHE_LIMIT and progression._encounters.store.pages.size() <= Store.PAGE_LIMIT, "Encounter residency exceeded cache budgets.")
	_expect(progression.get_saved_creature_encounter(_identity(COUNT).object_id).get("relation") == "ally" and _earned() == 3, "Restart lost relationship or reward receipt.")
	_expect(progression.get_discovered_species_count() == 1, "Discovery scan was lost.")
	for body: Dictionary in state.campaign.data.bodies.values():
		if body.id == state.active_body_id: continue
		var key: String = state.campaign.object_id(state.campaign.region_id(body.id, Vector2i(1, 0)), "arch14:1")
		var other: Dictionary = progression.get_saved_creature_encounter(key)
		_expect(other.get("body_id") == body.id and other.get("trust") == 64.0, "Cold load lost the other body's independent encounter.")
	_expect(progression.store_creature_encounter(progression.get_saved_creature_encounter(_identity(COUNT).object_id), true, "befriended", {"target_relation": "wild"}).ok and _earned() == 3, "Revisit/eviction paid the same encounter again.")

func _body_roundtrip() -> void:
	var source: String = state.active_body_id
	var original: Dictionary = _expected(1)
	var destination: Dictionary = state.campaign.ensure_body(15838, 23757)
	_expect(not destination.is_empty() and destination.id != source, "Same-seed planets shared an identity.")
	_expect(state.activate_body(destination.id, 23757, 0, false), "Cannot select second archive body.")
	var other: Dictionary = _expected(1)
	other.trust = 64.0
	_expect(other.object_id != original.object_id and progression.store_creature_encounter(other).ok, "Body B replaced body A's encounter.")
	_expect(progression.get_saved_creature_encounter(original.object_id) == original, "Inactive body lost its encounter.")
	_expect(state.activate_body(source, 15838, 0, false), "Cannot return to original archive body.")
	_expect(progression.get_saved_creature_encounter(other.object_id) == other, "A-B-A discarded the other body's encounter.")
	_expect(saves.save_now(), "Cannot save independent body encounters.")

func _bind() -> void:
	host = load("res://tests/fixtures/population_register_host.gd").new()
	host.descriptor = Surface.descriptor(state.get_current_body_record())
	root.add_child(host)
	_expect(host.storage_error.is_empty(), "Regional host failed: " + host.storage_error)

func _animal(i: int) -> Dictionary:
	var identity: Dictionary = _identity(i)
	var place: Dictionary = state.get_current_body_record().surface_context.spawn.duplicate(true)
	place.radius = state.get_current_body_record().surface_context.radius
	return {"id": identity.object_id, "identity": identity, "location": place, "home": place.duplicate(true), "species_seed": 771, "individual_seed": i, "role": "grazer", "blueprint": {"schema": 1, "seed": 771}}

func _rollback() -> void:
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	var before: Dictionary = progression.get_saved_creature_encounter(_identity(7).object_id)
	var update: Dictionary = before.duplicate(true)
	update.trust = 100.0
	update.relation = "ally"
	var wallet: Dictionary = progression.get_behavior_wallet(0)
	var campaign: Dictionary = state.campaign.export_state()
	saves.save_path = "user://missing-archive-directory/save.json"
	_expect(not progression.store_creature_encounter(update, true, "befriended", {"target_relation": "wild"}).ok, "Failed campaign write was reported as successful.")
	_expect(progression.get_saved_creature_encounter(update.object_id) == before and progression.get_behavior_wallet(0) == wallet and state.campaign.export_state() == campaign, "Failed save kept trust, reward or event cursor.")
	_expect(FileAccess.get_file_as_string(SAVE) == bytes, "Failed transaction replaced the valid campaign.")
	saves.save_path = SAVE
	_expect(saves.save_now(), "Rollback cannot be saved.")
	# Real blob failure after the action changed RAM: restore even while blocked.
	var blocker: String = "user://encounter-write-blocker"
	_write(blocker, "not a directory")
	var directory: String = progression._encounters.store.directory
	progression._encounters.store.directory = blocker.path_join("blobs")
	var reports: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var blocked: Dictionary = progression.store_creature_encounter(update, true, "befriended", {"target_relation": "wild"})
	Engine.print_error_messages = reports
	_expect(not blocked.ok, "Failed blob publication granted success.")
	_expect(progression._encounters.store.cache[update.object_id].entry == before and progression.get_behavior_wallet(0) == wallet, "Failed blob write kept new encounter/reward.")
	_expect(saves._write_blocked, "Unreadable archive did not protect shared writer.")
	progression._encounters.store.directory = directory
	_expect(saves.load_now(), "Loading a compatible snapshot did not clear archive failure.")

func _migration_failure() -> void:
	var archive := Encounters.new()
	_expect(archive.put(_expected(44)), "Cannot prepare migration failure fixture.")
	var original: Dictionary = archive.export_state()
	var directory: String = ProjectSettings.globalize_path(Store.DIRECTORY)
	var moved: String = directory + "-held"
	_expect(DirAccess.rename_absolute(directory, moved) == OK, "Cannot isolate migration filesystem failure.")
	_write(directory, "not a directory")
	var reports: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var migrated: bool = archive.enable_paging()
	Engine.print_error_messages = reports
	_expect(not migrated and archive.store == null and archive.export_state() == original, "Failed migration discarded the inline original.")
	DirAccess.remove_absolute(directory)
	_expect(DirAccess.rename_absolute(moved, directory) == OK, "Cannot restore synthetic archive directory.")

func _corruption_and_future() -> void:
	var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(SAVE))
	var bytes: String = FileAccess.get_file_as_string(SAVE)
	var future: Dictionary = snapshot.duplicate(true)
	future.progression.creature_encounters.schema = 3
	var path: String = "user://future-encounters.json"
	Atomic.write(path, future, false)
	Atomic.write(path + ".bak", snapshot, false)
	_expect(not saves.load_now(path) and not saves.save_now(path), "Future encounter envelope fell back to old backup.")
	_expect(saves.load_now(SAVE), "Compatible source cannot reload after future envelope.")
	future = snapshot.duplicate(true)
	future.progression.creature_encounters.next_storage = future.progression.creature_encounters.storage
	Atomic.write(path, future, false)
	_expect(not saves.load_now(path), "Unknown archive pointer was discarded through an older backup.")
	_expect(saves.load_now(SAVE), "Compatible source cannot reload after future pointer.")
	future = snapshot.duplicate(true)
	future.progression.creature_encounters.storage.root = Store.new()._write({"schema": 2, "kind": "leaf", "entries": {}})
	Atomic.write(path, future, false)
	_expect(not saves.load_now(path), "Future archive root fell back to old backup.")
	_expect(saves.load_now(SAVE), "Compatible source cannot reload after future root.")
	var key: String = _identity(4).object_id
	var reader := Store.new()
	_expect(reader.open(snapshot.progression.creature_encounters.storage), "Cannot inspect archive for deep corruption.")
	var digest: String = reader._lookup(reader.root, key, key.sha256_text(), 0)
	var file: String = reader._path(digest)
	var original: String = FileAccess.get_file_as_string(file)
	_write(file, "corrupt")
	_expect(progression.get_creature_encounter(_identity(4), "grazer", 4).is_empty() and saves._write_blocked, "Corrupt archived encounter became a fresh healthy animal.")
	_expect(not saves.save_now() and FileAccess.get_file_as_string(SAVE) == bytes, "Corruption overwrote the last valid snapshot.")
	_write(file, original)
	_expect(saves.load_now(SAVE), "Restored source cannot reload.")
	progression.reset_for_new_game()
	_expect(progression._encounters.store == null and progression._encounters.entries.is_empty(), "New game inherited another campaign archive.")
	_expect(saves.load_now(SAVE), "Cannot restore test campaign after reset.")

func _write(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Cannot write filesystem fixture: " + path)
	if file != null:
		file.store_string(contents)
		file.close()

func _print_metrics() -> void:
	print("ENCOUNTER_ARCHIVE_METRICS " + JSON.stringify({"encounters": COUNT + 2, "slot": ProjectSettings.globalize_path(SAVE), "regions": ProjectSettings.globalize_path(Store.DIRECTORY), "peak_cache": peak_cache, "pages": peak_pages, "campaign_id": state.campaign.data.id}))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	if host != null: host.free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("ENCOUNTER_ARCHIVE_PASSED: migration, 1202 encounters, bounded residency, regional adoption, rewards, rollback, corruption, future protection and cold reload.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
