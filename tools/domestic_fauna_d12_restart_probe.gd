extends SceneTree
const World = preload("res://world/planet_lab/living_planet.gd")
const Save = preload("res://world/surface/living_planet_store.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Contract = preload("res://world/fauna/domestication/domestic_surface_contract.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const NativeComparison = preload("res://tests/fixtures/domestic_native_comparison.gd")
const PATH: String = "user://d12-cold.json"
var failures: Array[String] = []
var cases: Array = []

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var old_campaign: String = JSON.stringify(root.get_node("GameState").campaign.export_state())
	var world := World.new()
	world.store_path = PATH
	root.add_child(world)
	current_scene = world
	world.set_paused(true)
	var mode: String = OS.get_environment("D1_RESTART_MODE")
	if mode == "write": await write_process(world)
	elif mode == "read": await read_process(world)
	else: failures.append("Missing explicit restart mode")
	expect(JSON.stringify(root.get_node("GameState").campaign.export_state()) == old_campaign, "Radial fauna wrote to the old campaign")
	world.queue_free()
	await process_frame
	await process_frame
	print(JSON.stringify({"probe": "d12", "process": mode, "cases": cases, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func write_process(world: Node) -> void:
	var native: Dictionary = {}
	for id in world.System.REAL_LANDABLE:
		world.open_body(id)
		await populate(world)
		world.set_paused(true)
		world._capture()
		for entry: Dictionary in world.ecosystem.domestic.catalog.species:
			native[entry.id] = Catalog.Contract.decode(entry.blueprint)
		cases.append({"body": id, "species": world.ecosystem.domestic.catalog.species.size(),
			"individuals": world.ecosystem.domestic.individuals.keys(), "plants": world.ecosystem.domestic.plants.size()})
	world.open_body("m1b:terra")
	await populate(world)
	world.set_paused(true)
	expect(world.save_lab(), "Write populated spherical checkpoint")
	var saved: Dictionary = Save.read(PATH).data
	expect(not saved.is_empty(), "Checkpoint is not readable immediately")
	if saved.is_empty(): return
	var file := FileAccess.open("user://d12-native.bin", FileAccess.WRITE)
	file.store_var(native, false)
	file.close()
	var old: Dictionary = saved.duplicate(true)
	old.schema = 1
	old.erase("map_atlases")
	for body: Dictionary in old.bodies.values():
		body.erase("fauna_catalog")
		body.erase("domestic_fauna")
	expect(Save.write(old, "user://d12-old.json") == OK, "Write valid pre-D1 spherical save")
	var pending: Dictionary = saved.duplicate(true)
	var record: Dictionary = pending.bodies["m1b:terra"]
	record.fauna_catalog = Catalog.create_surface(world.system.bodies[world.body_id], record.fauna_catalog.surface.anchor)
	record.domestic_fauna = {}
	var search := Planner.new()
	search.begin(world.terrain.surface, record.fauna_catalog)
	search.step(record.fauna_catalog, 7, 0)
	expect(record.fauna_catalog.surface_search.direction == 7 and record.fauna_catalog.habitat_status == "pending", "Search did not stop inside a node")
	expect(Save.write(pending, "user://d12-pending.json") == OK, "Persist interrupted spherical search")
	var completed: Dictionary = record.fauna_catalog.duplicate(true)
	var continuation := Planner.new()
	continuation.begin(world.terrain.surface, completed)
	while completed.habitat_status == "pending": continuation.step(completed, 512, 0)
	expect(Atomic.write("user://d12-reference.json", {"completed": completed, "old": old}) == OK, "Write cold continuation oracle")

func read_process(world: Node) -> void:
	var saved: Dictionary = Save.read(PATH).data
	var reference: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://d12-reference.json"))
	expect(not saved.is_empty() and not reference.is_empty(), "Read-process inputs missing")
	if saved.is_empty() or reference.is_empty(): return
	var native_file := FileAccess.open("user://d12-native.bin", FileAccess.READ)
	var native: Dictionary = native_file.get_var(false)
	native_file.close()
	for id in ["m1b:1000", "m1b:100", "m1b:terra"]:
		world.open_body(id, false)
		expect(world.records[id].fauna_catalog == saved.bodies[id].fauna_catalog, "Visit order changed frozen spherical catalog")
		expect(world.records[id].domestic_fauna == saved.bodies[id].domestic_fauna, "Cold load changed individual pose before simulation")
		await populate(world)
		world.set_paused(true)
		for animal: Node in world.ecosystem.animals.values():
			if animal.get("catalog_species") == null: continue
			expect(native.has(animal.catalog_species.id) and NativeComparison.native_equal(animal.design, native[animal.catalog_species.id]), "Cold runtime changed native body, skin or attachment types")
		cases.append({"cold_body": id, "individuals": world.ecosystem.domestic.individuals.keys()})
	# Resume the real persisted planner through the same scene entry.
	world.store_path = "user://d12-pending.json"
	expect(world.load_lab(), "Load persisted in-progress habitat search")
	var resumed: Dictionary = world.ecosystem.domestic.catalog
	while resumed.habitat_status == "pending": world.ecosystem.domestic.planner.step(resumed, 1, 1)
	expect(JSON.parse_string(JSON.stringify(resumed)) == reference.completed, "Cold search changed habitats, identities or cursor")
	# Pre-D1 spherical worlds acquire only the new optional data.
	world.store_path = "user://d12-old.json"
	expect(world.load_lab(), "Load original spherical schema 1")
	for id in ["m1b:terra", "m1b:100", "m1b:1000"]:
		world.open_body(id)
		expect(world.records[id].fauna == reference.old.bodies[id].fauna, "Old M1d animal IDs/designs changed")
		await populate(world)
		world.set_paused(true)
		expect(world.records[id].fauna_catalog.schema == Catalog.ROLE_SCHEMA \
			and world.records[id].fauna_catalog.role_policy == Catalog.ROLE_POLICY, "Old sphere did not receive current fauna role contract")
	expect(world.save_lab(), "Save upgraded spherical schema 1")
	expect(Save.read(world.store_path).data.get("schema") == Save.SCHEMA, "Old spherical header did not upgrade")
	for kind in ["save", "catalog", "surface", "search", "evidence", "individual", "food", "generation"]:
		var future: Dictionary = saved.duplicate(true)
		var body: Dictionary = future.bodies["m1b:terra"]
		match kind:
			"save": future.schema = 99
			"catalog": body.fauna_catalog.schema = 99
			"surface": body.fauna_catalog.surface.schema = 99
			"search": body.fauna_catalog.surface_search.schema = 99
			"evidence": body.fauna_catalog.species[0].body_evidence.schema = 99
			"individual": body.domestic_fauna.values()[0].schema = 99
			"food": body.fauna_catalog.habitats[0].food_state.schema = 99
			"generation": body.fauna_catalog.surface.generation = "future"
		var path: String = "user://d12-future-" + kind + ".json"
		Atomic.write(path, future, false)
		Atomic.write(path + ".bak", saved, false)
		var before: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var backup: PackedByteArray = FileAccess.get_file_as_bytes(path + ".bak")
		expect(Save.read(path).error == ERR_UNAVAILABLE, "Future " + kind + " silently downgraded to backup")
		expect(Save.write(saved, path) == ERR_UNAVAILABLE, "Future " + kind + " overwritten")
		expect(FileAccess.get_file_as_bytes(path) == before and FileAccess.get_file_as_bytes(path + ".bak") == backup, "Future primary/backup changed")
	cases.append({"future_versions_protected": 8, "legacy_sphere": true, "resumed_nodes": resumed.surface_search.nodes.size()})

func populate(world: Node) -> void:
	world.set_paused(false)
	world.walker.enabled = false
	for tick in range(1200):
		await physics_frame
		var count: int = 0
		for id: String in world.ecosystem.animals: count += int(world.ecosystem.domestic.owns(id))
		if count == 3 and world.ecosystem.domestic.plants.size() == 3: return
	failures.append("Cold process failed to populate " + str(world.body_id))

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
