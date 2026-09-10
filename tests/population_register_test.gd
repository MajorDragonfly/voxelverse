extends SceneTree
const Model = preload("res://world/surface/campaign_population_state.gd")
const Regions = preload("res://world/surface/campaign_region_storage.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Foraging = preload("res://world/resources/plants/foraging_state.gd")
const Drinking = preload("res://creatures/ai/drinking_state.gd")
const COUNT: int = 384
var failures: Array[String] = []
var state: Node
var saves: Node
var progression: Node
var host: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	progression = root.get_node("ProgressionService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://population-register-save.json"
	state.set_process(false)
	if "--population-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process cannot load campaign: " + saves.last_error)
		_bind()
		_expect(host.storage.store.reads == 1 and host.storage.store.cache.is_empty(), "Opening a campaign eagerly loaded animal pages.")
		_verify()
		await _finish()
		return
	state.start_world_with_seed(15838, Cube.MODE)
	saves._pending_player_state = {"surface_address": state.get_current_body_record().surface_context.spawn.duplicate(true), "surface_forward": [0.0, 0.0, 1.0], "surface_velocity": [0.0, 0.0, 0.0], "surface_pitch": -0.18, "health": 100.0, "hunger": 100.0, "thirst": 100.0}
	_bind()
	for i in range(COUNT):
		var animal: Dictionary = _animal(i)
		_expect(host.storage.put(animal), "Animal registration failed: " + host.storage.store.last_error)
		_expect(host.storage.put({"id": _id(i) + ":plant", "food_key": _id(i) + ":food", "location": animal.location.duplicate(true)}, true), "Food registration failed.")
		var hunger: Dictionary = Foraging.animal(state, animal.identity.body_id, animal.id, 80.0)
		var thirst: Dictionary = Drinking.animal(state, animal.identity, 70.0)
		var food: Dictionary = Foraging.plant(state, animal.identity.body_id, animal.id + ":food", 20.0)
		if hunger.is_empty() or thirst.is_empty() or food.is_empty(): _expect(false, "Missing service port at " + str(i)); break
		hunger.satiety = 10.0 + i % 70
		thirst.hydration = 20.0 + i % 60
		food.remaining = i % 20
		food.regrow_at = 1000.0 + i
		var encounter: Dictionary = progression.get_creature_encounter(animal.identity, "grazer", i)
		encounter.trust = float(i % 99)
		encounter.health_ratio = 0.0 if i % 11 == 0 else 0.75
		encounter.dead = i % 11 == 0
		encounter.carcass_food = 0.0
		_expect(progression.store_creature_encounter(encounter).ok, "Encounter could not use regional storage.")
	_expect(progression._encounters.entries.is_empty(), "Regional encounters accumulated in the legacy ledger.")
	_expect(state.get_current_body_record().get("wildlife_foraging", {}).is_empty(), "Regional needs accumulated in the legacy ledger.")
	_expect(host.storage.put(_animal(COUNT)), "Lifetime exploration prevented another animal after 384 identities.")
	_expect(host.storage.checkpoint(), "Initial register checkpoint failed.")
	var first: Dictionary = host.body().surface_population.storage.duplicate(true)
	# AI holds mutable needs references between frames. No lookup occurs after
	# this checkpoint and before either the next save or releasing the region.
	var early: Dictionary = host.storage.record(_id(1))
	host.storage.pin([Model.cell(host.descriptor, early.location).id])
	var borrowed: Dictionary = host.needs(early.id, "foraging", 0)
	_expect(host.storage.checkpoint(), "Cannot checkpoint active needs.")
	borrowed.satiety = 6.25
	_expect(host.storage.checkpoint(), "Cannot save a changed borrowed reference.")
	var reader := Regions.Store.new()
	_expect(reader.open(host.body().surface_population.storage), "Cannot inspect active needs checkpoint.")
	var region_key: String = Model.cell(host.descriptor, early.location).id
	_expect(reader.get_value("r:" + region_key).objects[early.id].foraging.satiety == 6.25, "Save omitted needs changed through an active AI reference.")
	borrowed.satiety = 7.5
	host.storage.pin([])
	# More than 96 other pages evict the released region before we revisit it.
	for i in range(100, COUNT): host.storage.record(_id(i))
	_expect(host.storage.record(early.id).foraging.satiety == 7.5, "Unpin/eviction lost changes after the previous checkpoint.")
	# Same-cell moves must be dirty even immediately after a checkpoint.
	var moved: Dictionary = host.storage.record(_id(2))
	_expect(host.storage.checkpoint(), "Cannot checkpoint before movement.")
	var location: Dictionary = moved.location.duplicate(true)
	location.height = 12.0
	_expect(host.storage.move(moved, location), "Same-cell movement failed.")
	_expect(host.storage.checkpoint(), "Movement checkpoint failed.")
	for i in range(100, COUNT): host.storage.record(_id(i))
	_expect(host.storage.record(moved.id).location.height == 12.0, "Same-cell movement vanished after eviction.")
	# Transfer an early individual to a different face, retaining all fields.
	moved = host.storage.record(_id(3))
	var original_key: String = Model.cell(host.descriptor, moved.location).id
	location = _place(900)
	_expect(host.storage.move(moved, location), "Cross-region movement failed.")
	_expect(not host.storage.region(original_key, false).objects.has(moved.id), "Transfer left a duplicate animal in the source.")
	_expect(_same(host.storage.record(moved.id).location, location), "Individual index did not follow its region.")
	_expect(saves.save_now(), "Campaign cannot save registers: " + saves.last_error)
	_verify()
	var old := Regions.Store.new()
	_expect(old.open(first), "Earlier root cannot be reopened.")
	_expect(old.get_value("r:" + region_key).objects[early.id].foraging.satiety == 11.0, "Later needs changed immutable history.")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/population_register_test.gd", "--", "--population-restart"], output, true)
	_expect(code == 0 and str(output).contains("POPULATION_REGISTER_PASSED") and not str(output).contains("ERROR:"), "Fresh process verification failed: " + str(output).right(1800))
	_migration()
	_write_failure()
	await _finish()

func _bind() -> void:
	host = load("res://tests/fixtures/population_register_host.gd").new()
	host.descriptor = Surface.descriptor(state.get_current_body_record())
	root.add_child(host)
	_expect(host.storage_error.is_empty(), "Host cannot bind: " + host.storage_error)

func _id(i: int) -> String: return "arch14:animal:%04d" % i

func _place(i: int) -> Dictionary:
	var point: Dictionary = Cube.address(host.descriptor.id, i % 6, -0.8 + (i / 6 % 100) * 0.016, 0.1)
	point.radius = host.descriptor.radius
	point.height = 0.0
	return point

func _animal(i: int) -> Dictionary:
	var point: Dictionary = _place(i)
	var identity: Dictionary = {"object_id": _id(i), "species_id": "arch14:species", "body_id": host.descriptor.id,
		"region_id": "arch14:origin:%d" % i}
	return {"id": _id(i), "identity": identity, "location": point, "home": point.duplicate(true),
		"species_seed": 15838, "individual_seed": i, "role": "grazer", "blueprint": {"schema": 1, "seed": 15838}}

func _verify() -> void:
	for i in range(COUNT - 1, -1, -1):
		var record: Dictionary = host.storage.record(_id(i))
		if record.is_empty(): _expect(false, "Lost animal %d: %s" % [i, host.storage.store.last_error]); break
		_expect(_same(record.identity, _animal(i).identity) and _same(record.home, _place(i)), "Identity or home changed at " + str(i))
		_expect(record.foraging.satiety == (7.5 if i == 1 else 10.0 + i % 70), "Hunger changed at " + str(i))
		_expect(record.drinking.hydration == 20.0 + i % 60, "Thirst changed at " + str(i))
		var encounter: Dictionary = progression.get_saved_creature_encounter(_id(i))
		_expect(encounter.trust == float(i % 99) and encounter.dead == (i % 11 == 0) and encounter.carcass_food == 0.0, "Relationship/death delta changed at " + str(i))
		var food: Dictionary = Foraging.plant(state, host.descriptor.id, _id(i) + ":food", 20.0)
		_expect(food.remaining == i % 20 and food.regrow_at == 1000.0 + i, "Harvested food/regrowth changed at " + str(i))
		_expect(host.storage.store.cache.size() <= 96 and host.storage.store.pages.size() <= 128 and host.storage.checked.size() <= 96, "Resident register cache exceeded its budget.")
	_expect(host.storage.record(_id(2)).location.height == 12.0 and _same(host.storage.record(_id(3)).location, _place(900)), "Moved positions did not survive a fresh reader.")
	_expect(not host.storage.record(_id(COUNT)).is_empty(), "The next animal disappeared after the 384-entry register.")
	# Completely consumed dead animals must never be recreated by spawning.
	_expect(not host._spawn_animal(host.storage.record(_id(0))), "Consumed dead animal respawned.")
	_expect(host.animals.is_empty(), "Register inspection instantiated physical animals.")
	print("POPULATION_REGISTER_METRICS animals=%d food_sources=%d cache=%d pages=%d" % [COUNT, COUNT, host.storage.store.peak_cache, host.storage.store.pages.size()])

func _migration() -> void:
	# Exercise the existing schema-1 import and all three legacy ledgers.
	var original: Dictionary = host.body().surface_population
	var animal: Dictionary = _animal(999)
	var data: Dictionary = Model.create(host.descriptor.id)
	Model.put(data, host.descriptor, animal)
	Model.put(data, host.descriptor, {"id": "legacy-plant", "food_key": "legacy-food", "location": animal.location}, true)
	host.body().surface_population = data
	host.body().wildlife_foraging = {"schema": 1, "body_id": host.descriptor.id, "animals": {animal.id: {"satiety": 9.0, "seeking": true}}, "plants": {"legacy-food": {"remaining": 2.0, "regrow_at": 555.0}}}
	host.body().wildlife_drinking = {"schema": 1, "body_id": host.descriptor.id, "animals": {animal.id: {"hydration": 8.0, "seeking": true}}}
	var entry: Dictionary = progression._encounters.get_entry(animal.identity, "grazer", 999)
	entry.trust = 42.0
	progression._encounters.put(entry)
	var migrated := Regions.new()
	_expect(migrated.open(host, host.descriptor), "Legacy register migration failed.")
	_expect(migrated.record(animal.id).foraging.satiety == 9.0 and migrated.record(animal.id).drinking.hydration == 8.0 and migrated.record(animal.id).encounter.trust == 42.0, "Migration reset individual needs/relationship.")
	_expect(migrated.record("legacy-food", true).food.remaining == 2.0, "Migration reset harvested food.")
	_expect(host.body().wildlife_foraging.animals.is_empty() and host.body().wildlife_foraging.plants.is_empty() and host.body().wildlife_drinking.animals.is_empty() and not progression._encounters.entries.has(animal.id), "Migration retained duplicate legacy owners.")
	host.body().surface_population = original

func _write_failure() -> void:
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var manifest: Dictionary = host.body().surface_population.storage.duplicate(true)
	var record: Dictionary = host.storage.record(_id(5))
	record.foraging.satiety = 3.0
	# A real filesystem blocker stops the first content-addressed blob write.
	var blocker: String = "user://population-register-blocker"
	var file := FileAccess.open(blocker, FileAccess.WRITE)
	file.store_string("block directory creation")
	file.close()
	host.storage.store.directory = blocker.path_join("blobs")
	var report_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	_expect(not host.storage.checkpoint(), "Blocked regional write succeeded.")
	Engine.print_error_messages = report_errors
	_expect(host.body().surface_population.storage == manifest and record.foraging.satiety == 3.0 and not host.storage.store.dirty.is_empty(), "Write failure published a partial root or discarded dirty state.")
	# The real host's save_started handler blocks the shared writer.
	_expect(not saves.save_now() and saves._write_blocked, "Failed register did not block the shared save.")
	_expect(FileAccess.get_file_as_string(saves.save_path) == bytes, "Write failure replaced the last valid campaign.")

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _same(a: Dictionary, b: Dictionary) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _finish() -> void:
	if host != null: host.free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("POPULATION_REGISTER_PASSED: 384 animals/food sources, service ports, active references, moves, eviction, history, migration, write failure and fresh process.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
