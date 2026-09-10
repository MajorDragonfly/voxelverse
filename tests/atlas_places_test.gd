extends SceneTree
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Store = preload("res://core/persistence/region_store.gd")
const COUNT: int = 3105
var failures: Array[String] = []
var state: Node
var saves: Node

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://atlas-places-save.json"
	if "--places-restart" in OS.get_cmdline_user_args():
		_restart()
		await _finish()
		return
	if "--places-ui" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Cannot load UI fixture.")
		await _ui(state.get_current_body_record().id)
		await _finish()
		return
	state.start_world_with_seed(15838)
	state.set_process(false)
	var body: Dictionary = state.get_current_body_record()
	var atlas := Atlas.new()
	atlas.bind(Atlas.create(body.id, "legacy_plane_v9"))
	atlas.reveal(Surface.plane_address(body.id, Vector3.ZERO))
	var old_record: Dictionary = {}
	for i in range(COUNT):
		_expect(atlas.remember(_place(body.id, i)), "Place rejected at %d: %s" % [i, atlas.last_error])
		if i == 120: old_record = atlas.data.duplicate(true)
	_expect(atlas.data.schema == Atlas.SCHEMA and atlas.places.count() == COUNT and not atlas.full, "Register retained its old total limit.")
	var updated: Dictionary = _place(body.id, 0)
	updated.name = "Verlegte Heimat"
	updated.address.position[0] = -448
	_expect(atlas.remember(updated) and not atlas.remember(updated), "Place update duplicated or lost its identity.")
	_expect(atlas.places.count() == COUNT and atlas.get_place(updated.id).name == updated.name, "Update changed the place count.")
	var copy: Dictionary = atlas.get_place(updated.id)
	copy.name = "Untracked external mutation"
	_expect(atlas.get_place(updated.id).name == updated.name, "Reader mutated authoritative place data.")
	var old := Atlas.new()
	_expect(old.bind(old_record) and old.get_place(updated.id).name == "Ort 00000" and old.get_place(_place(body.id, COUNT - 1).id).is_empty(), "Later changes mutated the old atlas root/overlay.")
	var before_read: String = JSON.stringify(atlas.data)
	var seen: Dictionary = {}
	for offset in range(0, COUNT, Atlas.Places.PAGE_SIZE):
		var page: Dictionary = atlas.place_page(offset, 999999)
		if page.is_empty(): _expect(false, atlas.last_error); break
		_expect(page.places.size() <= Atlas.Places.PAGE_SIZE and page.total == COUNT, "Page allocation exceeded its budget.")
		for place: Dictionary in page.places:
			_expect(not seen.has(place.id), "Paging repeated an identity.")
			seen[place.id] = true
	_expect(seen.size() == COUNT and JSON.stringify(atlas.data) == before_read, "Paging lost places or changed saved data.")
	_expect(atlas.data.places.size() <= 96 and atlas.places.store.cache.size() <= 96 and atlas.places.store.pages.size() <= 128, "Place cache grew with total exploration.")
	# Tile writes in a schema-3 atlas must never downgrade its place contract.
	atlas.reveal(Surface.plane_address(body.id, Vector3(8000, 0, 8000)))
	_expect(atlas.checkpoint() and atlas.data.schema == Atlas.SCHEMA, "Tile checkpoint downgraded a place-bearing atlas.")
	body.exploration_atlas = atlas.data
	_expect(saves.save_now(), "Place-bearing campaign cannot save: " + saves.last_error)
	_expect(not atlas.data.places.is_empty(), "Restart fixture has no unflushed place overlay.")
	var bytes: String = FileAccess.get_file_as_string(saves.save_path)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/atlas_places_test.gd", "--", "--places-restart"], output, true)
	_expect(code == 0 and str(output).contains("ATLAS_PLACES_PASS") and not str(output).contains("ERROR:"), "Fresh process lost place register: " + str(output).right(1200))
	await _ui(body.id)
	_migration()
	_sphere_and_switch()
	_friend_visibility(body.id)
	_failures(bytes)
	print("ATLAS_PLACES_METRICS count=%d pending=%d cache=%d pages=%d" % [COUNT, atlas.data.places.size(), atlas.places.store.cache.size(), atlas.places.store.pages.size()])
	await _finish()

func _restart() -> void:
	_expect(saves.load_now(), "Cannot restart campaign: " + saves.last_error)
	var atlas := Atlas.new()
	var record: Dictionary = state.get_current_body_record().get("exploration_atlas", {})
	if not atlas.bind(record): _expect(false, atlas.last_error); return
	_expect(atlas.places.store.reads == 1 and atlas.places.store.cache.is_empty(), "Loading a campaign materialized the place register.")
	_expect(atlas.places.count() == COUNT and atlas.get_place(_place(record.body_id, 0).id).name == "Verlegte Heimat", "Restart lost updated old place.")
	_expect(atlas.get_place(_place(record.body_id, COUNT - 1).id).name == "Ort 03104", "Restart lost unflushed latest place.")
	_expect(atlas.known(Surface.plane_address(record.body_id, Vector3(8000, 0, 8000))), "Place save lost tile exploration.")
	_expect(atlas.place_page(COUNT - 1).places.size() == 1 and atlas.place_page(COUNT).places.is_empty(), "Final page boundary is incorrect.")

func _ui(body_id: String) -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player: Node3D = load("res://creatures/player/player.tscn").instantiate()
	player.position = Vector3(0, 100, 0)
	player.fall_acceleration = 0
	scene.add_child(player)
	for i in range(5): await process_frame
	var map: CanvasLayer = get_first_node_in_group(&"world_map")
	if map == null: _expect(false, "Real player has no world map."); scene.queue_free(); return
	_expect(map.open_map(), "Cannot open map with paged places.")
	var before: String = JSON.stringify(map.tracker.atlas.data)
	_expect(map._places.size() == 64 and map._list.get_child_count() == 64 and map._place_pager.visible, "Map materialized the entire register.")
	map._place_next.pressed.emit()
	_expect(map._place_offset == 64 and map._places.size() == 64 and not map._place_previous.disabled, "Next-page button does not reach stored places.")
	var selected: String = _place(body_id, 70).id
	map.select_place(selected)
	_expect(map._selected == selected and map._canvas.places.size() <= 64, "Place on a later page cannot be selected.")
	map._place_previous.pressed.emit()
	_expect(map._place_offset == 0 and map._place_previous.disabled and JSON.stringify(map.tracker.atlas.data) == before, "Paging changed exploration or lost the first page.")
	root.size = Vector2i(800, 600)
	root.get_node("DisplaySettings").ui_scale = 1.5
	map._show_list = true
	map._layout()
	for i in range(5): await process_frame
	_expect(map._place_previous.is_visible_in_tree() and map._place_next.is_visible_in_tree(), "Compact place view hides paging actions.")
	_expect(map._scroll.size.y >= 44 * 1.5, "Compact place view cannot show a complete place button.")
	for button: Control in [map._place_previous, map._place_next]:
		var transform: Transform2D = button.get_global_transform_with_canvas()
		var factor: float = float(root.size.x) / root.get_visible_rect().size.x
		var physical := Rect2(transform.origin * factor, button.size * transform.get_scale() * factor)
		_expect(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(physical), "Paging action is outside the small viewport: " + str(physical))
	map.close_map()
	for i in range(2): await process_frame
	scene.queue_free()
	for i in range(3): await process_frame
	_expect(not paused, "Paged map leaked its pause.")

func _migration() -> void:
	for schema in [Atlas.INLINE_SCHEMA, Atlas.TILE_SCHEMA]:
		var legacy: Dictionary = Atlas.create("legacy", "legacy_plane_v9")
		if schema == Atlas.TILE_SCHEMA: legacy.merge({"schema": schema, "storage": Store.new().manifest(), "extent": []}, true)
		for i in range(Atlas.MAX_PLACES): legacy.places[_place("legacy", i).id] = _place("legacy", i)
		var original: String = JSON.stringify(legacy)
		var atlas := Atlas.new()
		_expect(atlas.bind(JSON.parse_string(original)), "Old inline markers cannot migrate: " + atlas.last_error)
		_expect(atlas.data.schema == Atlas.SCHEMA and atlas.places.count() == Atlas.MAX_PLACES and JSON.stringify(legacy) == original, "Migration changed the source or lost old identities.")
		_expect(atlas.get_place("place:00000").name == "Ort 00000" and atlas.get_place("place:02047").name == "Ort 02047", "Migration lost first or final legacy place.")
		_expect(atlas.remember(_place("legacy", Atlas.MAX_PLACES)), "Full old registry cannot add another place.")

func _sphere_and_switch() -> void:
	var atlas := Atlas.new()
	var record: Dictionary = Atlas.create("sphere", Cube.MODE, 6371000)
	atlas.bind(record)
	for i in range(180):
		var place: Dictionary = _place("sphere", i)
		place.address = Cube.address("sphere", i % 6, -0.9 + (i % 30) * 0.06, 0.2)
		atlas.remember(place)
	var polar: Dictionary = _place("sphere", 0)
	polar.address = Cube.address("sphere", 2, 0, 0)
	atlas.remember(polar)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(record))
	atlas.bind(Atlas.create("other", Cube.MODE, 6371000))
	_expect(atlas.get_place(polar.id).is_empty() and not atlas.remember(polar), "Body switch leaked foreign places.")
	_expect(atlas.bind(saved) and atlas.get_place(polar.id).address == saved.places[polar.id].address and atlas.places.count() == 180, "Rebinding a sphere lost its pending marker update.")

func _failures(saved_bytes: String) -> void:
	var tracker := preload("res://ui/world_map/exploration_tracker.gd").new()
	root.add_child(tracker)
	tracker.set_process(false)
	tracker.atlas.bind(Atlas.create("failed", "legacy_plane_v9"))
	for i in range(96): tracker.atlas.remember(_place("failed", i))
	var before: String = JSON.stringify(tracker.atlas.data)
	# A real blob write succeeds before the ordinal-index validation fails.
	tracker.atlas.places.store.validate_value = func(key: String, _value: Dictionary) -> String: return "injected index failure" if key == "o:0" else ""
	_expect(not tracker.atlas.remember(_place("failed", 96)), "Interrupted migration did not fail.")
	_expect(tracker.atlas.places.store.writes > 0 and JSON.stringify(tracker.atlas.data) == before, "Partial migration discarded markers or published half an index.")
	_expect(not tracker.problem.is_empty() and saves._write_blocked and not saves.save_now(), "Place write failure did not activate existing save protection.")
	_expect(FileAccess.get_file_as_string(saves.save_path) == saved_bytes, "Place failure overwrote the last campaign.")
	tracker.queue_free()
	var corrupt := Atlas.new()
	corrupt.bind(Atlas.create("corrupt", "legacy_plane_v9"))
	for i in range(97): corrupt.remember(_place("corrupt", i))
	corrupt.checkpoint_places()
	var record: Dictionary = corrupt.data.duplicate(true)
	var writer := Store.new()
	writer.put("p:place:00000", {"schema": 2})
	writer.put("o:0", {"schema": 1, "body_id": "corrupt", "id": "place:00000"})
	record.place_storage = writer.checkpoint()
	corrupt.bind(record)
	_expect(corrupt.place_page().is_empty() and not corrupt.last_error.is_empty(), "Newer place payload was treated as an unknown location.")
	var future: Dictionary = record.duplicate(true)
	future.place_storage.root = writer._write({"schema": 2, "kind": "leaf", "entries": {}})
	_expect(Atlas.newer(future) and saves._has_unsupported_contract({"game_state": {"campaign": {"bodies": {"corrupt": {"exploration_atlas": future}}}}}), "Future place root could be replaced through backup fallback.")
	var missing: Dictionary = record.duplicate(true)
	missing.place_storage.root = "f".repeat(64)
	_expect(not Atlas.validate(missing, "corrupt").is_empty(), "Missing place root was accepted.")
	record.place_ordinals = {"nonexistent": 0}
	_expect(not Atlas.validate(record, "corrupt").is_empty(), "Invalid pending index was accepted.")

func _friend_visibility(body_id: String) -> void:
	var atlas := Atlas.new()
	atlas.bind(Atlas.create(body_id, "legacy_plane_v9"))
	for i in range(97): atlas.remember(_place(body_id, i))
	var progression := root.get_node("ProgressionService")
	var entry: Dictionary = progression._encounters.get_entry({"object_id": "paged-friend", "body_id": body_id, "species_id": "foreign-species", "region_id": "friend-region"}, "grazer", 144)
	entry.relation = "ally"
	entry.trust = 100.0
	_expect(progression._encounters.put(entry), "Friendship fixture is invalid.")
	var marker: Dictionary = _place(body_id, 97)
	marker.own = false
	marker.kind = "friend_habitat"
	marker.object_id = entry.object_id
	marker.species_id = entry.species_id
	atlas.remember(marker)
	atlas.checkpoint_places()
	var before: String = JSON.stringify(atlas.data)
	var source = preload("res://ui/world_map/world_map_source.gd")
	_expect(source.visible_place_page(atlas, self, 96).places.size() == 2, "Later page lost its living ally.")
	entry.dead = true
	entry.health_ratio = 0.0
	progression._encounters.put(entry)
	_expect(source.visible_place_page(atlas, self, 96).places.size() == 1 and JSON.stringify(atlas.data) == before, "Paging invented friendship or mutated remembered history after death.")

func _place(body_id: String, index: int) -> Dictionary:
	return {"id": "place:%05d" % index, "name": "Ort %05d" % index, "kind": "home", "species_id": "", "object_id": "", "own": true, "address": Surface.plane_address(body_id, Vector3(index * 32, 0, 8))}

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	for failure in failures: push_error(failure)
	print("ATLAS_PLACES_PASS" if failures.is_empty() else "ATLAS_PLACES_FAIL")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
