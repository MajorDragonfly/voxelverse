extends SceneTree
## Cross-process consumers of the complete, byte-preserving user-data archive.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const D2 = preload("res://world/domestication/lab/lab_store.gd")
const Fixture = preload("res://world/domestication/lab/lab_fixture.gd")
const Planet = preload("res://world/planet_lab/planet_lab_save.gd")
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Catalog = preload("res://world/space/galaxy_catalog.gd")
const Journal = preload("res://world/space/galaxy_journal.gd")
const D3_PATH: String = "user://d3-village-lab/campaign.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var create: bool = "create" in OS.get_cmdline_user_args()
	var d2 := D2.new()
	var catalog := Catalog.new("9007199254740993")
	var system_id: String = catalog.sector_at([0, 0, 0]).systems[0].id
	var journal := Journal.new(catalog)
	_expect(journal.open() == OK, "Galaxy journal cannot open")
	if create:
		var snapshot: Dictionary = Fixture.create()
		_expect(d2.write_snapshot(snapshot), "D2 initial write failed")
		snapshot.stock.roots = 8
		snapshot.friendship = true
		_expect(d2.write_snapshot(snapshot), "D2 second write failed")
		var future: Dictionary = snapshot.duplicate(true)
		future.schema = 99
		_expect(Atomic.write("user://d2_lab/future.json", future, false) == OK, "Future original fixture failed")
		_expect(Atomic.write("user://d2_lab/future.json.bak", snapshot, false) == OK, "Future backup fixture failed")
		var atlas := Atlas.new()
		_expect(atlas.bind(Atlas.create("m1b:terra", Cube.MODE, 6371000.0)), "Lab atlas bind failed")
		for i in range(130): atlas.reveal(_address(i), 0.0)
		_expect(atlas.checkpoint() and atlas.data.schema >= 2, "Lab atlas did not flush to shared blobs")
		var planet: Dictionary = {"schema": 3, "surface_version": Cube.MODE, "terrain_revision": 3,
			"scale_mode": "real", "binary": false, "body_id": "m1b:terra", "location": _address(129),
			"forward": [0.0, 0.0, -1.0], "elapsed": 117.25, "map_atlases": {"m1b:terra": atlas.data}}
		_expect(Planet.write(planet) == OK, "Planet lab write failed")
		_expect(Library.save_variant(Creature.create_default(), "Archivkreatur").ok, "Local template write failed")
		_expect(Creature.save_to_file(Creature.create_default()) == OK, "Loose creature design write failed")
		var record: Dictionary = journal.read(system_id).record
		record.name = "Erhaltenes System"
		record.discovered = true
		_expect(journal.write(record) == OK, "Journal discovery write failed")
		var slot: String = ""
		for filename in DirAccess.get_files_at("user://saves"):
			if filename.ends_with(".json") and not filename.contains(".json."):
				slot = "user://saves/" + filename
		_expect(saves.load_now(slot), "Source campaign cannot load")
		_expect(DirAccess.make_dir_recursive_absolute(D3_PATH.get_base_dir()) == OK, "D3 directory failed")
		_expect(saves.save_now(D3_PATH), "D3 SaveGameService snapshot failed")
		var original: String = FileAccess.get_file_as_string(slot)
		_expect(Atomic.write(slot + ".schema9.backup.json", {"legacy_save_text": original,
			"design_files": {"user://creature_editor_blueprint.json": "protected original"}}, false) == OK, "Migration original write failed")
	else:
		var snapshot: Dictionary = d2.load_snapshot()
		_expect(not snapshot.is_empty() and snapshot.stock.roots == 8 and snapshot.friendship, "D2 restore lost stock or friendship")
		var old := D2.new()
		old.path += ".bak"
		_expect(old.load_snapshot().get("stock", {}).get("roots") == 12, "D2 previous generation missing")
		var future := D2.new()
		future.path = "user://d2_lab/future.json"
		var original: String = FileAccess.get_file_as_string(future.path)
		_expect(future.load_snapshot().is_empty() and future.blocked and not future.write_snapshot(Fixture.create()), "Restored future version lost its protection")
		_expect(FileAccess.get_file_as_string(future.path) == original, "Future original was overwritten")
		var planet: Dictionary = Planet.read()
		_expect(planet.get("elapsed") == 117.25, "Planet lab clock missing")
		var atlas := Atlas.new()
		_expect(atlas.bind(planet.get("map_atlases", {}).get("m1b:terra", {})), "Lab atlas blobs missing")
		for i in range(130): _expect(atlas.known(_address(i)), "Lab atlas lost a visited tile")
		_expect(Library.read().ok and Library.read().packages.size() == 1, "Local template library missing")
		_expect(FileAccess.file_exists(Creature.SAVE_PATH), "Loose creature design missing")
		_expect(journal.read(system_id).record.name == "Erhaltenes System", "Galaxy journal discovery missing")
		_expect(saves.load_now(D3_PATH), "D3 lab campaign cannot load after restart")
	for failure in failures: push_error(failure)
	print("USERDATA_BACKUP_PROBE ", JSON.stringify({"passed": failures.is_empty(), "lab_tiles": 130,
		"d2_roots": 8, "template_count": 1, "galaxy_system": system_id}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _address(index: int) -> Dictionary:
	return Cube.address("m1b:terra", 0, -0.7 + index * 0.01, 0.2)

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
