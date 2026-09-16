extends SceneTree
const Browser = preload("res://ui/frontend/save_browser.gd")
var failures: Array[String] = []
var checks: int = 0
var saves: Node
var state: Node
var original: String
var other: String
var future: String
var damaged: String
var orphan: String
var backed: String
var browser: Control
var backs: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	saves.autosave_enabled = false
	saves.session_managed = true
	state.set_process(false)
	await _fixtures()
	var before := _hashes()
	var campaign := JSON.stringify(state.campaign.data)
	var active: String = saves.save_path
	_contracts()
	await _ui()
	_expect(_hashes() == before, "Scanning/canceling changed save or history bytes")
	_expect(JSON.stringify(state.campaign.data) == campaign and saves.save_path == active and not saves.session_active, "Scanning imported a campaign")
	# A summary is never write authority: change a previously valid slot after
	# inspection and verify the existing service rejects copy/load from disk.
	var bytes := FileAccess.get_file_as_string(other)
	var newer: Dictionary = JSON.parse_string(bytes)
	newer.schema = 999
	_write(other, JSON.stringify(newer))
	_expect(saves.duplicate_slot(other).is_empty() and not saves.select_slot(other), "Stale valid summary bypassed future-version protection")
	_expect(FileAccess.get_file_as_string(other) == JSON.stringify(newer), "Rejected action overwrote future save")
	_write(other, bytes)
	_expect(not saves.select_slot("user://saves/../outside.json"), "Direct selection accepted a non-slot path")
	for failure in failures: push_error(failure)
	print("SLOT_SCAN: ", checks, " checks; failures=", failures.size())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _fixtures() -> void:
	original = saves.create_slot("History owner", 15838, "cube_sphere_m1_v1")
	_expect(not original.is_empty(), "Cannot create source")
	await process_frame
	for index in range(8):
		state.campaign.data.elapsed_seconds = 10 + index
		_expect(saves.save_now(), "Cannot create history")
	saves.session_active = false
	other = saves.duplicate_slot(original, "Other owner")
	future = saves.duplicate_slot(original, "Future")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(future))
	# A valid backup must never hide a future primary.
	_write(future + ".bak", JSON.stringify(data))
	data.schema = 999
	_write(future, JSON.stringify(data))
	damaged = saves.duplicate_slot(original, "Damaged")
	_write(damaged, "{invalid")
	backed = saves.duplicate_slot(original, "Backup only")
	DirAccess.rename_absolute(backed, backed + ".bak")
	orphan = saves.duplicate_slot(original, "History only")
	_expect(saves.rename_slot(orphan, "History only renamed"), "Cannot create orphan history")
	DirAccess.remove_absolute(orphan)
	DirAccess.remove_absolute(orphan + ".bak")
	# Old default location is still discovered once even with backup/history.
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(other))
	previous.slot_name = "Old default location"
	_write(saves.DEFAULT_SAVE_PATH + ".bak", JSON.stringify(previous))
	DirAccess.make_dir_recursive_absolute(saves.History.directory(saves.DEFAULT_SAVE_PATH))
	# Retained snapshots can exceed eight after failed cleanup; don't hide them.
	var history: Array[String] = saves.History.paths(original)
	var duplicate: String = saves.History.directory(original).path_join("snapshot_9999999999999999_duplicate.json")
	_write(duplicate, FileAccess.get_file_as_string(history[0]))
	# Directory walking itself must yield, including irrelevant entries.
	for index in range(140): _write(saves.SLOT_DIRECTORY.path_join("ignored_%03d.txt" % index), "ignored")
	DirAccess.make_dir_recursive_absolute(saves.SLOT_DIRECTORY.path_join("slot_directory.json"))
	_write(saves.SLOT_DIRECTORY.path_join("slot_fake.json.history"), "not a directory")

func _contracts() -> void:
	var scan: RefCounted = saves.begin_slot_scan()
	_expect(scan.result.is_empty() and scan.inspected == 0, "Constructing a job synchronously validated saves")
	var slices := 0
	while scan.pending and slices < 1000:
		var previous: int = scan.inspected
		scan.advance()
		_expect(scan.last_entries <= 64 and scan.last_inspections <= 1 and scan.inspected - previous <= 1, "Scan exceeded per-call work limit")
		_expect(scan.last_entries == 0 or scan.last_inspections == 0, "One slice combined directory walking with validation")
		slices += 1
	_expect(not scan.pending and scan.result.size() == 7 and slices >= 9, "Scan skipped/doubled a slot or consumed unbounded discovery")
	_expect(scan.result == saves.list_slots(), "Cooperative listing changed synchronous compatibility")
	for slot: Dictionary in scan.result:
		_expect(slot == saves.inspect_slot(slot.path), "Scan bypassed authoritative slot inspection")
		if slot.path == future: _expect(not slot.valid and not slot.recovered and slot.problem.contains("neuere"), "Future primary fell back to old backup")
		if slot.path == backed: _expect(slot.valid and slot.recovered, "Backup-only slot disappeared")
		if slot.path == orphan or slot.path == damaged: _expect(not slot.valid, "Unreadable current slot became valid")
	var history: RefCounted = saves.begin_history_scan(original)
	while history.pending:
		history.advance()
		_expect(history.last_inspections <= 1 and history.last_entries <= 64, "History exceeded one-source budget")
	_expect(history.result == saves.list_slot_history(original) and history.result.size() == 8, "History order/deduplication changed")
	_expect(history.paths.size() == 10, "Failed-cleanup history or backup was silently truncated")
	var invalid: RefCounted = saves.begin_history_scan("")
	_expect(not invalid.pending and invalid.result.is_empty(), "Invalid history request enumerated campaigns")
	var canceled: RefCounted = saves.begin_slot_scan()
	canceled.advance()
	canceled.cancel()
	for index in range(3): canceled.advance()
	_expect(not canceled.pending and canceled.paths.is_empty() and canceled.result.is_empty() and canceled.last_inspections == 0, "Canceled job continued reading/publishing")

func _ui() -> void:
	root.size = Vector2i(800, 600)
	root.content_scale_size = root.size
	root.content_scale_factor = 1.5
	browser = Browser.new()
	root.add_child(browser)
	browser.back_requested.connect(func() -> void: backs += 1)
	_expect(browser.is_loading() and browser._slots.is_empty() and browser.selected_path.is_empty(), "Browser opened synchronously or exposed stale actions")
	var initial: RefCounted = browser._scan
	await process_frame
	_expect(initial.inspected <= 1, "First UI frame validated all saves")
	root.get_node("LocaleManager")._apply("en")
	_expect(browser._scan_label.text.begins_with("Finding") or browser._scan_label.text.begins_with("Checking"), "Loading text did not switch language")
	await _key(KEY_F, true)
	_expect(browser._search.has_focus(), "Search cannot focus while loading")
	browser._search.text = "Other owner"
	browser._search.text_changed.emit(browser._search.text)
	await _idle()
	_expect(browser._filtered.size() == 1 and browser.selected_path == other, "Input during loading was discarded")
	browser._reset_filters()
	browser.select_slot(original)
	await _idle()
	browser._name_input.text = "Unwritten draft"
	browser._history.select(browser._entries.size() - 1)
	var remembered: String = browser._entries[browser._history.selected].source
	browser.refresh(original)
	var old: RefCounted = browser._scan
	await process_frame
	browser.refresh(original)
	_expect(not old.pending and old.result.is_empty(), "Refresh kept the superseded job")
	await _idle()
	_expect(browser.selected_path == original and browser._name_input.text == "Unwritten draft", "Refresh lost identity or name draft")
	_expect(browser._entries[browser._history.selected].source == remembered, "Refresh lost selected historical source")
	# Switching selection while history is being read cannot publish old owner.
	browser.select_slot(original)
	var old_history: RefCounted = browser._history_scan
	await process_frame
	browser.select_slot(other)
	_expect(not old_history.pending, "Selection did not cancel old history")
	await _idle()
	_expect(browser.selected_path == other and browser._entries.is_empty(), "Old history appeared under another owner")
	browser.select_slot(original)
	var hidden: RefCounted = browser._history_scan
	browser.hide()
	await _frames(3)
	_expect(not browser.is_loading() and not hidden.pending, "Hidden view continued scanning")
	browser.show()
	await _idle()
	_expect(browser.selected_path == original, "Showing view lost selected identity")
	# Native key routing: first Esc releases search, second leaves and cancels.
	browser.refresh()
	var leaving: RefCounted = browser._scan
	await _key(KEY_F, true)
	await _key(KEY_ESCAPE)
	_expect(backs == 0, "First Escape left search instead of releasing focus")
	await _key(KEY_ESCAPE)
	_expect(backs == 1 and not leaving.pending and not browser.is_loading(), "Back did not cancel current scan")
	browser.refresh()
	var detached: RefCounted = browser._scan
	browser.queue_free()
	await _frames(3)
	_expect(not detached.pending and detached.result.is_empty(), "Freed browser retained an active scan")
	root.content_scale_factor = 1.0

func _idle() -> void:
	for index in range(2000):
		if not browser.is_loading(): break
		await process_frame
	_expect(not browser.is_loading(), "Browser scan timed out")
	await _frames(3)

func _key(code: Key, control: bool = false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = control
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func _hashes() -> Dictionary:
	var result := {}
	_hash_directory(saves.SLOT_DIRECTORY, result)
	result[saves.DEFAULT_SAVE_PATH + ".bak"] = FileAccess.get_sha256(saves.DEFAULT_SAVE_PATH + ".bak")
	return result

func _hash_directory(path: String, result: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(path):
		var full := path.path_join(file)
		result[full] = FileAccess.get_sha256(full)
	for directory: String in DirAccess.get_directories_at(path): _hash_directory(path.path_join(directory), result)

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _frames(count: int) -> void:
	for index in range(count): await process_frame

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
