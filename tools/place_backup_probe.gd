extends SceneTree
## Real ARCH-14 place writer/reader; run against the published PR #65 checkout.
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Store = preload("res://core/persistence/region_store.gd")
const History = preload("res://core/persistence/slot_history.gd")
const COUNT: int = 3105
const LEGACY_COUNT: int = 130
var failures: Array[String] = []
var saves: Node
var state: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	state.set_process(false)
	_expect(Atlas.SCHEMA == 3, "Acceptance requires the published schema-3 Atlas")
	var result: Dictionary = _create() if "create" in OS.get_cmdline_user_args() else _restore()
	for message in failures: push_error(message)
	result.passed = failures.is_empty()
	print("PLACE_BACKUP_PROBE ", JSON.stringify(result))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _create() -> Dictionary:
	var slot: String = saves.create_slot("Places 1", 15838)
	_expect(not slot.is_empty(), saves.last_error)
	var body: Dictionary = state.get_current_body_record()
	var atlas: RefCounted = Atlas.new()
	var legacy: RefCounted = Atlas.new()
	_expect(atlas.bind(Atlas.create(body.id, Cube.MODE, body.surface_context.radius)), atlas.last_error)
	_expect(legacy.bind(Atlas.create(body.id, "legacy_plane_v9")), legacy.last_error)
	for i in range(COUNT): _expect(atlas.remember(_place(i, body.id, Cube.MODE)), "Cannot remember place " + str(i))
	for i in range(LEGACY_COUNT): _expect(legacy.remember(_place(i, body.id, "legacy_plane_v9")), "Cannot remember archived place")
	_expect(atlas.checkpoint_places() and legacy.checkpoint_places(), "Cannot checkpoint place roots")
	_expect(atlas.reveal(Cube.address(body.id, 2, 0, 0)), "Cannot explore pole")
	_expect(atlas.checkpoint(), "Cannot checkpoint tile root beside place root")
	_expect(atlas.data.schema == 3 and atlas.data.place_count == COUNT, "Tile checkpoint changed place contract")
	body.exploration_atlas = atlas.data
	body.legacy_exploration_atlas = legacy.data
	_expect(saves.save_now(), "First place snapshot failed: " + saves.last_error)
	# Commit one moved place, then leave another move and a new place pending.
	_expect(atlas.remember(_place(7, body.id, Cube.MODE, true)), "Cannot move committed place")
	_expect(atlas.checkpoint_places(), "Cannot publish moved place")
	_expect(atlas.remember(_place(13, body.id, Cube.MODE, true)), "Cannot move pending place")
	_expect(atlas.remember(_place(COUNT, body.id, Cube.MODE)), "Cannot add pending place")
	saves.slot_name = "Places 2"
	_expect(saves.save_now(), "Second place snapshot failed: " + saves.last_error)
	return {"slot": ProjectSettings.globalize_path(slot), "regions": ProjectSettings.globalize_path(Store.DIRECTORY),
		"campaign_id": state.campaign.data.id, "body_id": body.id, "pending": atlas.data.places.size(),
		"place_count": atlas.data.place_count}

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
	var peak_page_size: int = 0
	var snapshots: int = 0
	for path in paths:
		_expect(saves.load_now(path), "Cannot load restored places: " + path + " " + saves.last_error)
		var body: Dictionary = state.get_current_body_record()
		if not body.has("legacy_exploration_atlas"): continue
		snapshots += 1
		var current: bool = saves.slot_name == "Places 2"
		for field: String in ["exploration_atlas", "legacy_exploration_atlas"]:
			var atlas: RefCounted = Atlas.new()
			_expect(atlas.bind(body[field]), "Cannot bind restored place root")
			_expect(atlas.places.store.reads == 1 and atlas.places.store.cache.is_empty(), "Bind materialized all places")
			var sphere: bool = field == "exploration_atlas"
			var expected: int = (COUNT + (1 if current else 0)) if sphere else LEGACY_COUNT
			var offset: int = 0
			while offset < expected:
				var page: Dictionary = atlas.place_page(offset, 10000)
				if page.is_empty(): _expect(false, "Restored place page is missing"); break
				_expect(page.total == expected and page.next > offset and page.places.size() <= 64, "Invalid bounded page")
				if page.next <= offset: break
				peak_page_size = maxi(peak_page_size, page.places.size())
				for i in range(page.places.size()):
					var ordinal: int = offset + i
					var moved: bool = sphere and current and ordinal in [7, 13]
					var wanted: Dictionary = _place(ordinal, body.id, atlas.data.mode, moved)
					_expect(page.places[i] == wanted, "Place identity, order, name or address changed at " + str(ordinal))
					if sphere: checked += 1
					else: legacy_checked += 1
				offset = int(page.next)
			var direct: Dictionary = atlas.get_place("place:13")
			_expect(direct == _place(13, body.id, atlas.data.mode, sphere and current), "Direct lookup differs from page")
			direct.name = "Reader mutation"
			_expect(atlas.get_place("place:13").name != direct.name, "Reader mutated retained place")
			_expect(atlas.get_place("unvisited").is_empty(), "Backup invented an unknown place")
			if sphere: _expect(atlas.known(Cube.address(body.id, 2, 0, 0)), "Place export lost tile root")
			peak_cache = maxi(peak_cache, atlas.places.store.peak_cache)
			peak_pages = maxi(peak_pages, atlas.places.store.pages.size())
			_expect(atlas.last_error.is_empty(), "Restored place lookup failed")
	_expect(saves.load_now(slot), saves.last_error)
	return {"checked_places": checked, "checked_legacy_places": legacy_checked, "place_snapshots": snapshots,
		"peak_cache": peak_cache, "peak_pages": peak_pages, "peak_page_size": peak_page_size,
		"campaign_id": state.campaign.data.id, "body_id": state.get_current_body_record().id}

func _place(index: int, body_id: String, mode: String, moved: bool = false) -> Dictionary:
	var address: Dictionary = Cube.address(body_id, index % 6, -0.8 + float(index % 17) * 0.1, 0.2)
	if moved: address = Cube.address(body_id, 2, 0, 0)
	if mode == "legacy_plane_v9": address = {"body_id": body_id, "mode": mode, "position": [-index * 16, 0, -16]}
	return JSON.parse_string(JSON.stringify({"id": "place:" + str(index), "name": ("Moved " if moved else "Original ") + str(index),
		"kind": ["nest", "home", "friend_habitat", "friend_nest"][index % 4], "own": index % 2 == 0,
		"species_id": "kept-species", "object_id": "kept-object:" + str(index), "address": address}))

func _expect(ok: bool, message: String) -> void:
	if not ok and message not in failures: failures.append(message)
