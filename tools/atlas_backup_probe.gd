extends SceneTree
## Native acceptance against the pinned, published ARCH-14 Atlas implementation.
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Store = preload("res://core/persistence/region_store.gd")
const History = preload("res://core/persistence/slot_history.gd")
const COUNT: int = 1200
const LEGACY_COUNT: int = 130
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	state.set_process(false)
	_expect(Atlas.SCHEMA == 2, "Native acceptance requires the published ARCH-14 schema-2 Atlas")
	var result: Dictionary = _create() if "create" in OS.get_cmdline_user_args() else _restore()
	for message in failures: push_error(message)
	result["passed"] = failures.is_empty()
	print("ATLAS_BACKUP_PROBE ", JSON.stringify(result))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _create() -> Dictionary:
	var slot: String = saves.create_slot("Atlas 1", 15838)
	_expect(not slot.is_empty(), saves.last_error)
	var body: Dictionary = state.get_current_body_record()
	var atlas: RefCounted = Atlas.new()
	_expect(atlas.bind(Atlas.create(body.id, Cube.MODE, body.surface_context.radius)), atlas.last_error)
	for i in range(COUNT):
		_expect(atlas.reveal(atlas.address_for(_cell(i)), 0), "Cannot reveal sphere tile " + str(i))
	_expect(atlas.checkpoint(), atlas.last_error)
	var legacy: RefCounted = Atlas.new()
	_expect(legacy.bind(Atlas.create(body.id, "legacy_plane_v9")), legacy.last_error)
	for i in range(LEGACY_COUNT):
		_expect(legacy.reveal(legacy.address_for(Vector3i(-1, -i * 32 - 1, -1)), 0), "Cannot reveal legacy tile")
	_expect(legacy.checkpoint(), legacy.last_error)
	var marker: Dictionary = {"id": "arch13:home", "name": "Heimat", "kind": "home",
		"species_id": "", "object_id": "", "own": true, "address": atlas.address_for(_cell(0))}
	_expect(atlas.remember(marker), "Cannot record home marker")
	body.exploration_atlas = atlas.data
	body.legacy_exploration_atlas = legacy.data
	_expect(saves.save_now(), "First atlas save failed: " + saves.last_error)
	# A new committed generation and an unflushed override of that generation.
	_expect(atlas.reveal(atlas.address_for(_extra(30)), 0), "Cannot extend committed tile")
	_expect(atlas.checkpoint(), atlas.last_error)
	_expect(atlas.reveal(atlas.address_for(_extra(29)), 0), "Cannot keep changed tile in overlay")
	_expect(atlas.reveal(atlas.address_for(_cell(COUNT)), 0), "Cannot explore new tile")
	_expect(atlas.reveal(Cube.address(body.id, 0, 0.999999, 0.2)), "Cannot explore face seam")
	_expect(atlas.reveal(Cube.address(body.id, 2, 0, 0)), "Cannot explore pole")
	_expect(not atlas.data.tiles.is_empty() and atlas.data.tiles.size() <= 96, "Missing bounded save-safe overlay")
	saves.slot_name = "Atlas 2"
	_expect(saves.save_now(), "Second atlas save failed: " + saves.last_error)
	return {"slot": ProjectSettings.globalize_path(slot), "regions": ProjectSettings.globalize_path(Store.DIRECTORY),
		"campaign_id": state.campaign.data.id, "body_id": body.id, "pending": atlas.data.tiles.size(),
		"tiles_per_generation": COUNT, "legacy_tiles_per_generation": LEGACY_COUNT}

func _restore() -> Dictionary:
	var slot: String = ""
	for filename in DirAccess.get_files_at("user://saves"):
		if filename.ends_with(".json"): slot = "user://saves/" + filename
	_expect(not slot.is_empty(), "Restored slot missing")
	var paths: Array[String] = [slot, slot + ".bak"]
	paths.append_array(History.paths(slot))
	var checked: int = 0
	var legacy_checked: int = 0
	var peak_cache: int = 0
	var peak_pages: int = 0
	var snapshots: int = 0
	for path in paths:
		_expect(saves.load_now(path), "Restored atlas save cannot load: " + path + " " + saves.last_error)
		var body: Dictionary = state.get_current_body_record()
		if not body.has("legacy_exploration_atlas"): continue # Empty initial slot.
		snapshots += 1
		var atlas: RefCounted = Atlas.new()
		var legacy: RefCounted = Atlas.new()
		_expect(atlas.bind(body.exploration_atlas), atlas.last_error)
		_expect(legacy.bind(body.legacy_exploration_atlas), legacy.last_error)
		_expect(atlas.store.reads == 1 and atlas.store.cache.is_empty(), "Opening atlas eagerly loaded tiles")
		for i in range(COUNT - 1, -1, -1):
			_expect(atlas.known(atlas.address_for(_cell(i))), "Restored sphere lost tile " + str(i))
			checked += 1
		for i in range(LEGACY_COUNT - 1, -1, -1):
			_expect(legacy.known(legacy.address_for(Vector3i(-1, -i * 32 - 1, -1))), "Restored archive lost signed/high-bit tile")
			legacy_checked += 1
		var current: bool = saves.slot_name == "Atlas 2"
		for column in [29, 30]:
			_expect(atlas.known(atlas.address_for(_extra(column))) == current, "Old/new generation or pending override lost")
		_expect(atlas.known(atlas.address_for(_cell(COUNT))) == current, "Pending new tile lost or revealed in history")
		_expect(not atlas.known(atlas.address_for(_cell(COUNT + 10))), "Backup revealed unvisited ground")
		_expect(not atlas.known(Cube.address("other-body", 0, 0, 0)), "Atlas crossed body identity")
		_expect(atlas.data.places.get("arch13:home", {}).get("name") == "Heimat", "Home marker lost")
		if current:
			_expect(atlas.known(Cube.address(body.id, 0, 0.999999, 0.2)), "Seam knowledge lost")
			_expect(atlas.known(Cube.address(body.id, 2, 0, 0)), "Pole knowledge lost")
		peak_cache = maxi(peak_cache, maxi(atlas.store.peak_cache, legacy.store.peak_cache))
		peak_pages = maxi(peak_pages, maxi(atlas.store.pages.size(), legacy.store.pages.size()))
		_expect(atlas.last_error.is_empty() and legacy.last_error.is_empty(), "Restored tile read failed")
	_expect(saves.load_now(slot), saves.last_error)
	return {"checked_sphere_tiles": checked, "checked_legacy_tiles": legacy_checked, "atlas_snapshots": snapshots,
		"peak_cache": peak_cache, "peak_pages": peak_pages, "campaign_id": state.campaign.data.id,
		"body_id": state.get_current_body_record().id}

func _cell(index: int) -> Vector3i:
	return Vector3i(index % 6, (index / 6 % 50) * 32 + 31, (index / 300) * 32 + 31)

func _extra(column: int) -> Vector3i:
	var cell: Vector3i = _cell(0)
	cell.y = column
	return cell

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
