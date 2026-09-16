extends SceneTree
const Browser = preload("res://ui/frontend/save_browser.gd")
const Query = preload("res://ui/frontend/slot_browser_query.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []
var checks: int = 0
var saves: Node
var state: Node
var browser: Control
var original: String
var paths: Array[String] = []
var future: String
var damaged: String
var backup: String
var history_only: String
var back_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	saves.session_managed = true
	state.set_process(false)
	root.size = Vector2i(1280, 720)
	root.get_node("LocaleManager")._apply("de")
	_test_query()
	await _fixtures()
	var before := _file_hashes()
	var live_campaign := JSON.stringify(state.campaign.data)
	var live_slot: String = saves.save_path
	browser = Browser.new()
	root.add_child(browser)
	browser.back_requested.connect(func() -> void: back_count += 1)
	await _frames(4)
	_expect(browser._slots.size() == 31, "Browser lost real, damaged, backup-only or history-only slots")
	_expect(browser._list.get_child_count() == 12 and not browser._next.disabled, "Initial list built an unbounded number of previews")
	await _queries()
	await _layouts()
	_expect(_file_hashes() == before, "Searching, paging, language or layout changed save/history bytes")
	_expect(JSON.stringify(state.campaign.data) == live_campaign and saves.save_path == live_slot and not saves.session_active, "Browsing imported another campaign")
	await _actions()
	browser.queue_free()
	await _frames(3)
	for failure in failures: push_error(failure)
	print("SAVE_BROWSER_SEARCH: ", checks, " checks; failures=", failures.size())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _test_query() -> void:
	var slots: Array = []
	for index in range(1005):
		slots.append({"path": "slot_%04d" % index, "name": "Nadelöhr %d" % index, "seed": 7331, "phase": index % 2, "valid": true, "recovered": false, "saved_time": index, "seconds": 1005 - index})
	var before := JSON.stringify(slots)
	var result := Query.select(slots, " NADELÖHR 7331 ", 1, "ready", "name")
	_expect(result.size() == 502 and result[0].name == "Nadelöhr 1" and result[1].name == "Nadelöhr 3", "Combined case-insensitive search/seed/phase filtering or natural name order failed")
	var seen := {}
	for index in range(ceili(float(result.size()) / Query.PAGE_SIZE)):
		var page := Query.page(result, index)
		_expect(page.size() <= 12 and not page.is_empty(), "Result page exceeded its widget budget or became empty")
		for slot: Dictionary in page:
			_expect(not seen.has(slot.path), "Page repeated an identity")
			seen[slot.path] = true
	_expect(seen.size() == 502, "Paging skipped matching saves")
	_expect(Query.select(slots, "", -1, "all", "playtime")[0].path == "slot_0000", "Playtime sorting uses the wrong direction")
	_expect(Query.select(slots)[0].path == "slot_1004", "Recent sorting uses the wrong timestamp")
	_expect(Query.select(slots, "missing").is_empty(), "Empty query result retained stale rows")
	_expect(JSON.stringify(slots) == before, "Query sorted or rewrote its source array")
	var ties := [slots[2].duplicate(true), slots[1].duplicate(true)]
	ties[0].name = "Identisch"
	ties[1].name = "Identisch"
	_expect(Query.select(ties, "", -1, "all", "name")[0].path == "slot_0001", "Equal names are not ordered by stable path")

func _fixtures() -> void:
	original = saves.create_slot("Beenden {name}", 7331, "cube_sphere_m1_v1")
	_expect(not original.is_empty(), "Cannot create real save fixture")
	await process_frame
	for index in range(3):
		state.campaign.data.elapsed_seconds = 100.0 + index * 100
		_expect(saves.save_now(), "Cannot create real history fixture")
	saves.session_active = false
	for index in range(26):
		var path: String = saves.duplicate_slot(original, "Expedition %02d" % (index + 1))
		_expect(not path.is_empty(), "Cannot create independent save copy")
		paths.append(path)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		data.saved_unix_time = 10000 + index
		data.game_state.campaign.elapsed_seconds = 1000 - index
		_expect(Atomic.write(path, data, false) == OK, "Cannot set deterministic fixture metadata")
	future = saves.duplicate_slot(original, "Future {name}")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(future))
	data.schema = 999
	_expect(Atomic.write(future, data, false) == OK, "Cannot create future fixture")
	damaged = saves.duplicate_slot(original, "Damaged")
	_write(damaged, "{broken")
	backup = saves.duplicate_slot(original, "Backup only")
	_expect(DirAccess.rename_absolute(backup, backup + ".bak") == OK, "Cannot create backup-only fixture")
	history_only = saves.duplicate_slot(original, "History only")
	_expect(saves.rename_slot(history_only, "History renamed"), "Cannot capture history-only fixture")
	DirAccess.remove_absolute(history_only)
	DirAccess.remove_absolute(history_only + ".bak")

func _queries() -> void:
	browser._sort.select(1)
	browser._sort.item_selected.emit(1)
	browser.select_slot(original)
	await _frames(3)
	await _click(browser._next)
	_expect(browser._page == 1 and browser._list.get_child_count() == 12, "Real Next click did not advance the result page")
	await _click(browser._next)
	_expect(browser._page == 2 and browser._next.disabled and browser._list.get_child_count() == 7, "Last result page is wrong")
	await _click(browser._previous)
	_expect(browser._page == 1, "Real Previous click did not return a page")
	await _search("  eXpEdItIoN 15 7331 ")
	_expect(browser._filtered.size() == 1 and browser.selected_path == paths[14], "Name/seed search selected the wrong save")
	var button: Button = browser._list.get_child(0)
	await _click(button)
	_expect(browser.selected_path == paths[14], "Real result click changed identity")
	browser._name_input.text = "Noch ungespeichert {seed}"
	await _search("nothing-matches")
	_expect(browser.selected_path.is_empty() and browser._name_input == null and browser._previous.disabled and browser._next.disabled, "No-result view retained active save commands")
	await _search("Expedition 15")
	_expect(browser._name_input.text == "Noch ungespeichert {seed}", "Filtering away and back discarded the rename draft")
	_expect(saves.inspect_slot(paths[14]).name == "Expedition 15", "Search accidentally saved a rename draft")
	browser._name_input.text = "Expedition 15"
	browser._phase_filter.select(2)
	browser._phase_filter.item_selected.emit(2)
	_expect(browser._filtered.is_empty(), "Era filter retained creature-phase saves")
	browser._reset_filters()
	browser._state_filter.select(2)
	browser._state_filter.item_selected.emit(2)
	_expect(browser._filtered.size() == 4 and browser._filtered.any(func(slot: Dictionary) -> bool: return slot.path == future), "Attention filter hid future/corrupt/history-only or backup records")
	browser.select_slot(future)
	_expect(browser.find_child("LoadAdventure", true, false).disabled and browser.find_child("CopySlot", true, false).disabled, "Future save became loadable through filtering")
	browser.select_slot(backup)
	_expect(saves.inspect_slot(backup).recovered and not browser.find_child("LoadAdventure", true, false).disabled, "Backup-only save was not reachable")
	browser._state_filter.select(1)
	browser._state_filter.item_selected.emit(1)
	_expect(browser._filtered.size() == 27, "Intact filter retained backups or unreadable slots")
	browser.select_slot(original)
	var history_index: int = browser._entries.size() - 1
	browser._history.select(history_index)
	browser._history.item_selected.emit(history_index)
	var history_source: String = browser._entries[history_index].source
	browser._name_input.text = "Entwurf {key}"
	browser._name_input.grab_focus()
	browser._name_input.caret_column = 4
	root.get_node("LocaleManager")._apply("en")
	await _frames(3)
	_expect(browser.selected_path == original and browser._name_input.text == "Entwurf {key}" and browser._name_input.has_focus() and browser._name_input.caret_column == 4, "Language switch lost identity, literal draft or text focus")
	_expect(browser._entries[browser._history.selected].source == history_source and browser._state_filter.selected == 1, "Language switch changed history selection or filters")
	browser._reset_filters()
	await _key(KEY_F, 0, true)
	_expect(browser._search.has_focus(), "Ctrl+F did not focus search")
	browser._search.select_all()
	await _key(KEY_M, 109)
	_expect(browser._search.text == "m", "Real typed search input was lost")
	await _key(KEY_ESCAPE)
	_expect(back_count == 0 and not browser._search.has_focus(), "Escape exited before releasing search focus")
	await _key(KEY_ESCAPE)
	_expect(back_count == 1, "Second Escape did not return to the title menu")
	browser._reset_filters()
	await _frames(3)

func _layouts() -> void:
	for size: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		for scale: float in [1.0, 1.5]:
			root.size = size
			root.content_scale_size = size
			root.content_scale_factor = scale
			for locale: String in ["de", "en"]:
				root.get_node("LocaleManager")._apply(locale)
				browser._show_details = false
				browser._layout()
				await _frames(5)
				var screen := root.get_visible_rect()
				for node: Control in [browser._margin, browser._search, browser._phase_filter, browser._state_filter, browser._sort, browser._previous, browser._next]:
					_expect(screen.grow(1).encloses(node.get_global_rect()), "Save list control escaped viewport: %s %s/%s/%s rect=%s screen=%s" % [node.name, size, scale, locale, node.get_global_rect(), screen])
				_expect(browser._slot_scroll.size.y >= 120, "Save list has no complete result row at %s/%s/%s: height=%s" % [size, scale, locale, browser._slot_scroll.size.y])
				if browser._compact:
					await _click(browser._list.get_child(0))
					_expect(browser._right.visible and not browser._left.visible, "Small screen result click did not show details")
					var load: Button = browser.find_child("LoadAdventure", true, false)
					browser._right.ensure_control_visible(load)
					await _frames(3)
					_expect(screen.grow(1).encloses(load.get_global_rect()), "Load action is unreachable in compact details")
					await _click(browser._details_toggle)
					_expect(browser._left.visible and not browser._right.visible, "Compact Results action did not restore list")
	root.content_scale_factor = 1.0
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1280, 720)
	root.get_node("LocaleManager")._apply("de")
	await _frames(4)

func _actions() -> void:
	await _search("Expedition 15")
	var untouched: String = FileAccess.get_file_as_string(paths[13])
	var original_bytes: String = FileAccess.get_file_as_string(original)
	browser._name_input.text = "Neu benannt {name}"
	await _detail_click("RenameSlot")
	_expect(browser.selected_path == paths[14] and browser._search.text.is_empty() and saves.inspect_slot(paths[14]).name == "Neu benannt {name}", "Rename affected a hidden slot or did not reveal the renamed result")
	_expect(FileAccess.get_file_as_string(paths[13]) == untouched, "Rename changed a neighboring result")
	await _search("Neu benannt")
	await _detail_click("CopySlot")
	var copy: String = browser.selected_path
	_expect(copy != paths[14] and not copy.is_empty() and Query.page_for(browser._filtered, copy) == browser._page, "Copy did not select its independent visible result")
	var copied: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(copy))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths[14]))
	_expect(copied.game_state.campaign.id != source.game_state.campaign.id, "Browser copy reused the source campaign identity")
	browser.select_slot(original)
	browser._history.select(browser._entries.size() - 1)
	browser._history.item_selected.emit(browser._history.selected)
	var historical: String = browser._entries[browser._history.selected].source
	var historical_bytes: String = FileAccess.get_file_as_string(historical)
	await _detail_click("RestoreSlot")
	var restored: String = browser.selected_path
	_expect(restored not in [original, copy, paths[14]] and Query.page_for(browser._filtered, restored) == browser._page, "History recovery did not select its new result")
	var recovery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(restored))
	_expect(recovery.game_state.campaign.elapsed_seconds == JSON.parse_string(historical_bytes).game_state.campaign.elapsed_seconds, "Recovery used the wrong history after filtering")
	_expect(FileAccess.get_file_as_string(original) == original_bytes and FileAccess.get_file_as_string(historical) == historical_bytes, "Recovery changed current/source bytes")
	# A blocked history target rejects rename and retains the pending draft.
	var blocked: String = saves.duplicate_slot(original, "Blocked")
	_write(blocked + ".history", "not a directory")
	browser.refresh(blocked)
	var protected_bytes: String = FileAccess.get_file_as_string(blocked)
	browser._name_input.text = "Cannot save"
	await _detail_click("RenameSlot")
	_expect(FileAccess.get_file_as_string(blocked) == protected_bytes and browser._name_input.text == "Cannot save" and browser.selected_path == blocked, "Failed rename changed bytes/selection or discarded the draft")

func _search(term: String) -> void:
	browser._show_details = false
	browser._layout()
	browser._search.text = term
	browser._search.text_changed.emit(term)
	for frame in range(1000):
		if not browser._query_pending: break
		await process_frame
	_expect(not browser._query_pending, "Debounced search did not finish")
	await _frames(3)

func _detail_click(id: String) -> void:
	browser._show_details = true
	browser._layout()
	var button: Button = browser.find_child(id, true, false)
	browser._right.ensure_control_visible(button)
	await _frames(3)
	await _click(button)
	await _frames(3)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _key(code: int, unicode_value: int = 0, ctrl: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = unicode_value
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _file_hashes() -> Dictionary:
	var result := {}
	_hash_directory("user://saves", result)
	return result

func _hash_directory(path: String, result: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(path): result[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
	for folder: String in DirAccess.get_directories_at(path): _hash_directory(path.path_join(folder), result)

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
