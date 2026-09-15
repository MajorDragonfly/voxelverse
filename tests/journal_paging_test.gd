extends SceneTree
## Large read-only discovery collections, real book paging and a fresh-process save.
const Catalog = preload("res://core/discovery/journal_catalog.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Journal = preload("res://ui/discovery/discovery_journal.gd")
const SAVE := "user://journal_paging.json"
const COUNT := 1205
var failures: Array[String] = []
var measurements: Dictionary = {}
var progression: Node
var journal: CanvasLayer
var fixture: Node3D

class Source extends Node:
	var discovery_points := 7
	var discovered_species: Dictionary = {}
	var discovered_regions: Dictionary = {}
	var unlocked_parts: Dictionary = {}
	var exports := 0
	func get_research_settings() -> Dictionary: return {"version": 1, "pinned": "", "wished_parts": []}
	func export_state() -> Dictionary:
		exports += 1
		return {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	progression = root.get_node("ProgressionService")
	await process_frame
	if "--paging-child" in OS.get_cmdline_user_args():
		check(saves.load_now(SAVE), "Fresh process loads the large collection")
		check(progression.discovered_species.size() == COUNT and progression.discovered_regions.size() == COUNT, "No discovery is lost across restart")
		_create_book()
		journal.open_journal()
		journal._page = 12
		journal._apply_filters()
		check(journal._list.item_count == 5 and journal._title.text == "Art 1201", "Fresh process reaches the last page")
		check(journal._preview._model != null, "Saved last-page anatomy builds a real preview")
		journal.close_journal()
		await _finish()
		return
	_test_catalog()
	root.get_node("GameState").start_world_with_seed(15838)
	progression.reset_for_new_game()
	_seed_campaign()
	check(saves.save_now(SAVE), "Large species and region collection saves")
	var saved_before: String = FileAccess.get_file_as_string(SAVE)
	var before: String = JSON.stringify(progression.export_state())
	_create_book()
	await _test_book()
	check(JSON.stringify(progression.export_state()) == before, "Book operations leave all saved progression unchanged")
	check(FileAccess.get_file_as_string(SAVE) == saved_before, "Browsing does not rewrite the save")
	await _test_refresh(saves)
	var output: Array = []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/journal_paging_test.gd", "--", "--paging-child"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	check(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Independent restart: " + str(output))
	await _finish()

func _test_catalog() -> void:
	var source := Source.new()
	var observation: Dictionary = Records.observation({"body": {"payload": "x".repeat(32768)}, "parts": [],
		"species": {"domestication": D1.suitability("milk")}}, "Welt 15838")
	for index in 10005:
		var key: String = "species:%d" % index
		source.discovered_species[key] = {"name": "Art %d" % index, "world_seed": 15838,
			"role": "grazer" if index % 2 == 0 else "predator", "journal": observation,
			"scan": {"version": 1, "complete": index % 2 == 0}}
		source.discovered_regions[key] = {"world_seed": 15838, "x": index, "z": -1}
	var catalog := Catalog.new()
	var started: int = Time.get_ticks_usec()
	catalog.bind(source, Suitability.read.bind(D1))
	measurements.index_10005_species_and_regions_ms = (Time.get_ticks_usec() - started) / 1000.0
	check(source.exports == 0 and catalog.detail_reads == 0, "Index never exports progression or reads a full observation")
	var metadata: String = JSON.stringify(catalog.state)
	check(not metadata.contains("payload") and not metadata.contains("visual"), "Index retains no body/attachment payloads")
	var first: Dictionary = catalog.page("species", "", "", 0, Suitability.ROLES)
	check(first.total == 10005 and first.rows.size() == 100, "Visible metadata is bounded to 100 without capping the collection")
	check(first.rows[2].name == "Art 2" and first.rows[99].name == "Art 99", "Natural numeric sorting is retained")
	var queries: int = catalog.queries
	var seen: Dictionary = {}
	for number in 101:
		var page: Dictionary = catalog.page("species", "", "", number, Suitability.ROLES)
		for row: Dictionary in page.rows:
			check(not seen.has(row.key), "Pages never repeat an identity")
			seen[row.key] = true
	check(seen.size() == 10005 and catalog.queries == queries, "All identities are reachable without re-filtering/re-sorting on each page")
	check(catalog.detail_reads == 0, "Paging metadata never loads anatomy")
	check(catalog.page("species", "", "", 999).rows.size() == 5, "Overlarge page clamps to the final partial page")
	check(catalog.page("species", "  ART 10004  ", "", 0).total == 1, "Normalized search reaches an entry beyond the first hundred pages")
	check(catalog.page("species", "", "predator", 0).total == 5002, "Ecological roles filter the complete collection")
	check(catalog.page("species", "", "domestic:milk", 0).total == 5003, "Only completed scans with valid D1 data match animal roles")
	check(catalog.page("species", "milchtier", "", 0, Suitability.ROLES).total == 5003, "Animal role labels remain searchable")
	check(catalog.page("species", "milchtier", "", 0, {"milk": "Milk animal"}).total == 0, "Changed role labels invalidate the search cache")
	check(catalog.page("species", "not present", "", 99).rows.is_empty(), "Empty search returns no rows")
	var expected: Array[Dictionary] = Records.region_rows({"discovered_regions": source.discovered_regions})
	var last: Dictionary = catalog.page("regions", "", "", 100)
	check(last.total == 10005 and last.rows[-1].key == expected[-1].key, "Region pages retain established location/coordinate order")
	first.rows[0].journal.location = "changed copy"
	check(catalog.state.discovered_species["species:0"].location == "Welt 15838", "Returned rows cannot mutate indexed metadata")
	var detail: Dictionary = catalog.species_detail("species:10004")
	detail.journal.visual.body.payload = "changed copy"
	check(source.discovered_species["species:10004"].journal.visual.body.payload.length() == 32768, "Detail copies cannot mutate the saved anatomy")
	check(catalog.detail_reads == 1 and catalog.species_detail("missing").is_empty(), "Only explicitly requested details are materialized")
	# Old discoveries and unsupported D1 revisions stay visible without inventing roles.
	source.discovered_species = {"old": {"name": "Old"}, "future": detail}
	detail.journal.visual.species.domestication.schema = 999
	catalog.bind(source, Suitability.read.bind(D1))
	check(catalog.page("species", "", "", 0).total == 2 and catalog.page("species", "", "domestic:milk", 0).total == 0, "Legacy/unsupported records remain reachable without guessed suitability")
	source.free()
	check(catalog.species_detail("old").is_empty(), "Disposed campaign owner cannot leak old details")
	catalog.clear()
	check(catalog.state.is_empty() and catalog.page_for("old") == -1, "Closing releases the metadata index")

func _seed_campaign() -> void:
	var blueprint: Dictionary = Species.create_species(771337, Vector2i(1, -2), "grazer")
	var receipt: Dictionary = progression.register_species_discovery(771337, blueprint, 15838)
	var species: Dictionary = progression.discovered_species[receipt.species_key]
	progression.register_region_discovery(Vector2i(1, -2), 15838)
	var region: Dictionary = progression.discovered_regions.values()[0]
	progression.discovered_species.clear()
	progression.discovered_regions.clear()
	var campaign = root.get_node("GameState").campaign
	for number in range(1, COUNT + 1):
		var entry: Dictionary = species.duplicate()
		entry.name = "Art %d" % number
		entry.species_seed = 800000 + number
		entry.id = campaign.species_id(entry.body_id, entry.species_seed)
		progression.discovered_species[entry.id] = entry
		entry = region.duplicate()
		entry.x = number
		entry.id = campaign.region_id(entry.body_id, Vector2i(number, -2))
		progression.discovered_regions[entry.id] = entry

func _create_book() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	journal = Journal.new()
	fixture.add_child(journal)

func _test_book() -> void:
	journal.open_journal()
	check(journal._rows.size() == 100 and journal._row_total == COUNT, "Real book stores one page and the uncapped total")
	check(not journal._state.has("creature_encounters") and not journal._rows[0].journal.has("visual"), "Book snapshot excludes unrelated campaign history and body records")
	var queries: int = journal._catalog.queries
	journal._next_page.pressed.emit()
	check(journal._title.text == "Art 101" and journal._page == 1, "Next button selects a local page index")
	journal._page = 12
	journal._apply_filters()
	journal._list.item_selected.emit(4)
	check(journal._title.text == "Art 1205" and journal._preview._model != null, "Final item renders its own saved anatomy")
	check(journal._next_page.disabled and not journal._previous_page.disabled, "Last-page navigation boundaries are correct")
	check(journal._catalog.queries == queries, "Book page changes reuse the index")
	await _capture("last_species_page")
	journal._search.text = "Art 1205"
	journal._search.text_changed.emit(journal._search.text)
	check(journal._list.item_count == 1 and journal._page == 0, "Search finds the final identity and resets paging")
	journal._tabs.current_tab = 2
	journal._page = 12
	journal._apply_filters()
	check(journal._list.item_count == 5 and journal._row_total == COUNT and not journal._preview.visible, "Regions use the same bounded page view")
	await _capture("last_region_page")
	journal._tabs.current_tab = 3
	check(journal._thumbnail_queue.is_empty(), "Guide retires prior thumbnail work")
	journal.close_journal()
	check(journal._state.is_empty() and journal._rows.is_empty() and journal._thumbnail_cache.is_empty(), "Closed book releases temporary collections and textures")
	await process_frame
	await process_frame

func _test_refresh(saves: Node) -> void:
	journal._tabs.current_tab = 0
	journal.open_journal()
	journal._list.item_selected.emit(99)
	var selected: String = journal._selected_key
	var entry: Dictionary = progression.discovered_species.values()[0].duplicate()
	entry.name = "Art 0"
	entry.species_seed = 900000
	entry.id = root.get_node("GameState").campaign.species_id(entry.body_id, entry.species_seed)
	progression.discovered_species[entry.id] = entry
	journal.refresh()
	check(journal._page == 1 and journal._selected_key == selected and journal._title.text == "Art 100", "New discovery preserves selection when sorting moves it across a page boundary")
	progression.reset_for_new_game()
	await process_frame
	check(journal._list.item_count == 0 and journal._row_total == 0, "Campaign reset invalidates the open book")
	check(saves.load_now(SAVE), "Saved collection reloads while the book is open")
	await process_frame
	check(journal._row_total == COUNT and journal._list.item_count == 100, "Load rebuilds metadata from the restored owner")
	journal._page = 12
	journal._apply_filters()
	check(journal._title.text == "Art 1201" and journal._preview._model != null, "Reloaded page details belong to the restored campaign")
	journal.close_journal()
	await process_frame

func _capture(label: String) -> void:
	if not "--paging-capture" in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://art/review/journal_paging"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Capture " + label)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _finish() -> void:
	if fixture != null: fixture.queue_free()
	current_scene = null
	await process_frame
	for failure in failures: push_error(failure)
	print("JOURNAL_PAGING_TEST ", JSON.stringify({"passed": failures.is_empty(), "failures": failures, "measurements": measurements}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
