extends SceneTree
const Ship = preload("res://space/ships/ship_blueprint.gd")
const Yard = preload("res://space/ships/shipyard.tscn")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Draft = preload("res://tests/fixtures/expedition_contract_draft.gd")
const Placement = preload("res://space/ships/ship_placement.gd")
const LibraryPage = preload("res://space/ships/ship_library_page.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--shipyard-restart"):
		var loaded: Dictionary = Ship.load_design(Ship.DIRECTORY + "/restart.json")
		_expect(loaded.ok, "Restart loads the actual saved blueprint")
		if loaded.ok:
			_expect(loaded.blueprint.revision == 2, "Revision survives a fresh process")
			_expect(Ship.evaluate(loaded.blueprint).stats.cargo == 24, "Added capacity survives a fresh process")
			_expect(loaded.blueprint.name == "Neustartschiff", "Name survives restart")
		var protected_path: String = Ship.DIRECTORY + "/future.json"
		_expect(not Ship.load_design(protected_path).ok, "Fresh reader rejects future version without falling back")
		var copy_expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://shipyard_copy_expected.json"))
		var copy_loaded: Dictionary = Ship.load_design(str(copy_expected.get("path", "")))
		_expect(copy_loaded.ok, "Fresh process opens the separately saved copy")
		if copy_loaded.ok:
			_expect(copy_loaded.blueprint.design_id == copy_expected.design_id and copy_loaded.blueprint.revision == 1, "Copy identity and initial revision survive restart")
			var part_uids: Array = []
			for part: Dictionary in copy_loaded.blueprint.parts: part_uids.append(part.uid)
			_expect(part_uids == copy_expected.part_uids, "Every copied module retains its new identity across restart")
			_expect(Ship.evaluate(copy_loaded.blueprint).stats.cargo == 24, "Copy capabilities survive restart")
	else:
		_model_checks()
		_placement_checks()
		_storage_checks()
		_library_checks()
		await _editor_checks()
	print(JSON.stringify({"test": "shipyard", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _placement_checks() -> void:
	var data: Dictionary = Ship.template("lander")
	var source: Dictionary = data.duplicate(true)
	var pair: Dictionary = Placement.add_attached(data, 0, "cargo_s", 0, 0, true)
	_expect(pair.ok and pair.added.size() == 2, "Symmetric attachment creates both modules atomically")
	_expect(data == source, "Placement planning/commit leaves caller-owned source unchanged")
	_expect(Ship.evaluate(pair.blueprint).ok and Ship.evaluate(pair.blueprint).stats.cargo == 36, "Attached pair is structurally valid and contributes both capacities")
	_expect(pair.blueprint.parts[-1].uid != pair.blueprint.parts[-2].uid, "Pair has distinct persistent module identities")
	_expect(not Placement.add_attached(pair.blueprint, 0, "cargo_s", 0, 0, true).ok, "Occupied symmetric placement is rejected")
	var once: Dictionary = Placement.add_attached(data, 0, "cargo_s")
	var before: Dictionary = once.blueprint.duplicate(true)
	_expect(not Placement.add_attached(once.blueprint, 0, "cargo_s", 1, 0, true).ok and before == once.blueprint, "One blocked side cannot partially place the other side")
	_expect(not Placement.mirror(data, 0).ok, "Centreline mirror never produces an overlapping duplicate")
	var hull: Dictionary = data.duplicate(true)
	hull.parts.resize(1)
	for side in range(6):
		var placed: Dictionary = Placement.add_attached(hull, 0, "battery_s", side)
		_expect(placed.ok and not _has(placed.blueprint, "ship.disconnected") and not _has(placed.blueprint, "ship.overlap"), "All six attachment faces connect without overlap")
	var centre: Dictionary = Placement.add_attached(hull, 0, "battery_s", 2, 0, true)
	_expect(centre.ok and centre.added.size() == 1, "Symmetry on centreline adds exactly one module")
	var rotated: Dictionary = Placement.plan(hull, 0, "drive_s", 0, 90)
	_expect(rotated.ok and rotated.boxes[0].position.x == 2 and rotated.boxes[0].size == Vector3(2, 2, 4), "Attachment uses the rotated module extent")
	var stale: Dictionary = Placement.plan(data, 0, "cargo_s")
	_expect(not Placement.commit(once.blueprint, stale).ok, "Old green plan is revalidated against the current occupied space")
	var large: Dictionary = Ship.template("expedition")
	for i in range(119): _add(large, "battery_s", Vector3(30, 0, 0))
	_expect(large.parts.size() == 127 and Placement.add_attached(large, 0, "battery_s", 0, 0, true).code == "ship.module_limit", "Two-module operation enforces capacity as one transaction")
	_expect(Placement.plan(data, -1, "cargo_s").code == "ship.select_anchor", "No silent placement at the origin without selection")
	_expect(not Placement.plan(data, 0, "hangar").ok, "Placement respects role restrictions")

func _library_checks() -> void:
	var directory: String = "user://shipyard_library_probe"
	DirAccess.make_dir_recursive_absolute(directory)
	for i in range(29):
		var design: Dictionary = Ship.template("lander" if i % 2 == 0 else "expedition")
		design.name = "Probe %02d" % i
		Atomic.write(directory.path_join("%02d.json" % i), Ship.Assembly.serialize(design))
	var cursor := LibraryPage.new()
	var offset: int = 0
	var found: Dictionary = {}
	for page in range(4):
		cursor.start(directory, "Probe")
		if offset > 0: cursor.start(directory, "Probe", "", offset)
		for tick in range(100):
			cursor.advance()
			_expect(cursor.last_reads <= LibraryPage.READS_PER_TICK and cursor.last_scanned <= LibraryPage.ENTRIES_PER_TICK, "Directory and file reads respect per-tick caps")
			if cursor.done: break
		_expect(cursor.done and cursor.entries.size() <= LibraryPage.PAGE_SIZE, "Library retains only one bounded page")
		for entry: Dictionary in cursor.entries:
			_expect(not found.has(entry.path), "Pagination does not repeat a design")
			found[entry.path] = true
		if not cursor.may_have_more: break
		offset = cursor.next_offset
	_expect(found.size() == 29, "Every design remains reachable across pages")
	cursor.start(directory, "28", "lander")
	for tick in range(100):
		cursor.advance()
		if cursor.done: break
	_expect(cursor.entries.size() == 1 and cursor.entries[0].name == "Probe 28", "Search matches names and role across the full directory")
	cursor.start(directory)
	cursor.advance()
	cursor.cancel()
	cursor.start(directory, "does-not-exist")
	for tick in range(100):
		cursor.advance()
		if cursor.done: break
	_expect(cursor.done and cursor.entries.is_empty(), "Cancelled query cannot publish old entries into a new search")

func _model_checks() -> void:
	var host: Dictionary = Ship.template("expedition")
	var guest: Dictionary = Ship.template("lander")
	var original: Dictionary = guest.duplicate(true)
	_expect(Ship.evaluate(host).ok, "Expedition template has a connected, powered module assembly")
	_expect(Ship.evaluate(guest).ok, "Lander template is ready")
	_expect(Ship.evaluate(host).bounds.size.length() > Ship.evaluate(guest).bounds.size.length() * 3, "Expedition base is materially larger than lander")
	_expect(Ship.hangar_fit(host, guest).ok, "Template lander fits the real template bay")
	_expect(not Ship.hangar_fit(guest, host).ok, "Reversed roles cannot dock")
	_expect(Ship.hangar_fit(host, guest, "", 90).ok, "Quarter-turn docking accounts for exchanged axes")
	_expect(not Ship.hangar_fit(host, guest, "", 0, Vector3(5, 0, 0)).ok, "Offset cannot place lander through the bay wall")
	_expect(not Ship.hangar_fit(host, guest, "missing_bay").ok, "Unknown bay cannot silently choose another")
	_expect(not Ship.hangar_fit(host, guest, "", 45).ok, "Unsupported docking rotation rejected")
	var wide: Dictionary = guest.duplicate(true)
	_add(wide, "cargo_s", Vector3(4, -2, 0))
	_add(wide, "cargo_s", Vector3(8, -2, 0))
	_add(wide, "cargo_s", Vector3(12, -2, 0))
	_expect(Ship.evaluate(wide).ok and not Ship.hangar_fit(host, wide).ok, "Ready wide lander exceeds the unrotated bay width")
	_expect(Ship.find_hangar_fit(host, wide).ok and Ship.find_hangar_fit(host, wide).yaw == 90, "Automatic fit finds the rotated orientation")
	_expect(guest == original, "Inspection and fit never mutate source designs")
	var replacement: Dictionary = Ship.template("lander")
	_expect(guest.design_id != replacement.design_id and guest.parts[0].uid != replacement.parts[0].uid, "Templates create independent design/module identities")
	var changed: Dictionary = guest.duplicate(true)
	_add(changed, "cargo_s", Vector3(4, -2, 0))
	_expect(Ship.evaluate(changed).ok and Ship.evaluate(changed).stats.cargo == 24, "Connected expansion changes capacity")
	changed.stats = {"cargo": 99999, "energy": 99999}
	_expect(Ship.evaluate(changed).stats.cargo == 24, "Untrusted saved statistics do not grant capacity")
	changed.parts.back().position = Vector3(100, 0, 0)
	_expect(_has(changed, "ship.disconnected") and _has(changed, "ship.size_limit"), "Distant module fails connectivity and build dimensions")
	changed = guest.duplicate(true)
	changed.parts[1].position = Vector3.ZERO
	_expect(_has(changed, "ship.overlap"), "Overlap is diagnosed")
	changed = guest.duplicate(true)
	_add(changed, "battery_s", Vector3(3, 4, 2))
	_expect(_has(changed, "ship.disconnected"), "Edge/corner contact is not a structural attachment")
	changed = guest.duplicate(true)
	Ship.Assembly.remove_part(changed, 3)
	_expect(_has(changed, "ship.power_deficit"), "Removing reactor makes the electrical demand fail")
	changed = guest.duplicate(true)
	Ship.Assembly.remove_part(changed, 2)
	_expect(_has(changed, "ship.thrust_deficit"), "Removing drive fails thrust")
	changed = guest.duplicate(true)
	Ship.Assembly.remove_part(changed, 6)
	_expect(_has(changed, "ship.no_landing_gear"), "Landing capability comes from the installed gear")
	changed = host.duplicate(true)
	Ship.Assembly.remove_part(changed, 6)
	_expect(_has(changed, "ship.no_hangar"), "Removing the hangar removes docking capacity")
	changed = guest.duplicate(true)
	_add(changed, "bridge", Vector3(0, 8, 0))
	_expect(_has(changed, "ship.module_role"), "Role-bound modules cannot be used on the wrong ship")
	changed = host.duplicate(true)
	changed.parts[6].rotation = Vector3(0, 90, 0)
	_expect(Ship.module_box(changed.parts[6], Ship.Catalog.all().hangar).size == Vector3(20, 12, 16), "Yaw transforms the exact reserved module dimensions")
	for value in [null, true, "1", 0, 2, 1.5, [], {}]:
		changed = guest.duplicate(true)
		changed.ship.schema = value
		_expect(not Ship.inspect(changed).ok, "Ship schema rejects malformed/new discriminator %s" % str(value))
		changed = guest.duplicate(true)
		changed.ship.catalog_revision = value
		_expect(not Ship.inspect(changed).ok, "Catalog revision rejects malformed/new value %s" % str(value))
	for alteration: Array in [["scale", Vector3(2, 1, 1)], ["position", Vector3(0.5, 0, 0)],
		["rotation", Vector3(0, 45, 0)], ["rotation", Vector3(90, 0, 0)], ["position", Vector3(NAN, 0, 0)],
		["part_revision", 2], ["part_id", "downloaded_super_reactor"], ["uid", ""]]:
		changed = guest.duplicate(true)
		changed.parts[0][alteration[0]] = alteration[1]
		_expect(not Ship.inspect(changed).ok, "Reject unsupported or malformed module: " + alteration[0])
	changed = guest.duplicate(true)
	changed.parts[1].uid = changed.parts[0].uid
	_expect(not Ship.inspect(changed).ok, "Duplicate stable module identities are rejected")
	changed = guest.duplicate(true)
	changed.erase("parts")
	_expect(not Ship.inspect(changed).ok, "Missing part collection fails without a runtime error")
	changed = guest.duplicate(true)
	while changed.parts.size() <= Ship.MAX_MODULES: _add(changed, "battery_s", Vector3.ZERO)
	_expect(not Ship.inspect(changed).ok, "Technical module bound enforced before geometry work")
	var invalid: Dictionary = guest.duplicate(true)
	invalid.parts.clear()
	_expect(Ship.inspect(invalid).ok and not Ship.evaluate(invalid).ok, "Incomplete drafts can be stored without being expedition-ready")

func _storage_checks() -> void:
	var data: Dictionary = Ship.template("lander")
	data.name = "Neustartschiff"
	var path: String = Ship.DIRECTORY + "/restart.json"
	_expect(Ship.save_design(data, path).ok and data.revision == 1, "Existing atomically written store commits revision one")
	var initial: Dictionary = data.duplicate(true)
	_add(data, "cargo_s", Vector3(4, -2, 0))
	_expect(Ship.save_design(data, path).ok and data.revision == 2, "Expanded design commits the next revision")
	var frozen: Dictionary = Ship.pin_saved(path)
	_expect(frozen.ok and frozen.capabilities.cargo_space == 24 and frozen.blueprint.design_id == data.design_id, "Pin reads a saved, catalogue-derived snapshot")
	data.parts[0].position += Vector3(100, 0, 0)
	_expect(Ship.pin_saved(path) == frozen, "Unsaved editing does not alter a pinned stored revision")
	_expect(Ship.save_design(initial, path).ok and initial.revision == 3, "Undo cannot reuse an already committed revision")
	# Restore the expanded revision-two fixture for a genuine separate process.
	var restore: Dictionary = Ship.load_design(path + ".bak")
	_expect(restore.ok and restore.blueprint.revision == 2, "Existing writer keeps prior successful revision")
	Atomic.write(path, Ship.Assembly.serialize(restore.blueprint))
	var before: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	var candidate: Dictionary = restore.blueprint.duplicate(true)
	var candidate_before: Dictionary = candidate.duplicate(true)
	_expect(not Ship.save_design(candidate, path).ok, "Blocked atomic staging is reported")
	_expect(candidate == candidate_before, "Failed write preserves in-memory revision and contents")
	_expect(FileAccess.get_file_as_string(path) == before and FileAccess.get_file_as_string(path + ".bak") == backup, "Failed staging leaves both live and backup bytes intact")
	DirAccess.remove_absolute(path + ".tmp")
	var stranger: Dictionary = Ship.template("lander")
	_expect(not Ship.save_design(stranger, path).ok, "Other design cannot overwrite the same file")
	_expect(FileAccess.get_file_as_string(path) == before, "Rejected other design preserves original bytes")
	var protected_path: String = Ship.DIRECTORY + "/future.json"
	var future: Dictionary = Ship.Assembly.serialize(candidate)
	future.ship.schema = 2
	Atomic.write(protected_path, Ship.Assembly.serialize(candidate))
	Atomic.write(protected_path, future)
	var future_bytes: String = FileAccess.get_file_as_string(protected_path)
	var future_backup: String = FileAccess.get_file_as_string(protected_path + ".bak")
	_expect(not Ship.load_design(protected_path).ok, "Future ship format blocks fallback to a valid old backup")
	_expect(not Ship.save_design(candidate, protected_path).ok, "Future original cannot be overwritten")
	_expect(FileAccess.get_file_as_string(protected_path) == future_bytes and FileAccess.get_file_as_string(protected_path + ".bak") == future_backup, "Version rejection preserves original and backup bytes")
	var broken: String = Ship.DIRECTORY + "/broken.json"
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("not JSON")
	file.close()
	_expect(not Ship.save_design(candidate, broken).ok and FileAccess.get_file_as_string(broken) == "not JSON", "Corrupt original stays intact")
	var incomplete: Dictionary = Ship.template("lander")
	incomplete.parts.clear()
	var incomplete_save: Dictionary = Ship.save_design(incomplete)
	_expect(incomplete_save.ok and not Ship.pin_saved(incomplete_save.path).ok, "Draft saves do not become usable instance capabilities")
	var saved_copy: Dictionary = Ship.save_copy(candidate)
	_expect(saved_copy.ok and candidate == candidate_before and FileAccess.get_file_as_string(path) == before, "Saving a copy leaves source memory and original bytes unchanged")
	if saved_copy.ok:
		var old_uids: Array = []
		var new_uids: Array = []
		for part: Dictionary in candidate.parts: old_uids.append(part.uid)
		for part: Dictionary in saved_copy.blueprint.parts: new_uids.append(part.uid)
		_expect(saved_copy.blueprint.design_id != candidate.design_id and new_uids.all(func(uid: String) -> bool: return not old_uids.has(uid)), "Copy allocates a new design identity and all new module identities")
		_expect(Atomic.write("user://shipyard_copy_expected.json", {"path": saved_copy.path, "design_id": saved_copy.blueprint.design_id, "part_uids": new_uids}) == OK, "Copy restart expectations are written to isolated user data")
	_check_draft_adapter(candidate)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/shipyard_test.gd", "--", "--shipyard-restart"], output, true)
	_expect(code == 0 and not str(output).contains("SCRIPT ERROR") and not str(output).contains("ERROR:"), "Fresh process reload including protected originals")
	for line in output: print(line)

func _check_draft_adapter(guest: Dictionary) -> void:
	var host: Dictionary = Ship.template("expedition")
	var saved_host: Dictionary = Ship.save_design(host)
	var saved_guest: Dictionary = Ship.save_design(guest)
	var a: Dictionary = Ship.pin_saved(saved_host.path)
	var b: Dictionary = Ship.pin_saved(saved_guest.path)
	_expect(a.ok and b.ok, "Both real module designs produce pinnable capabilities")
	var fixture: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("res://tests/fixtures/expedition_contract_draft.json"))
	fixture.ships.ship_expedition.blueprint = a.blueprint
	fixture.ships.ship_expedition.capabilities = a.capabilities
	fixture.ships.ship_lander.blueprint = b.blueprint
	fixture.ships.ship_lander.capabilities = b.capabilities
	fixture.ships.ship_lander.place = {"kind": "dock", "host_ship_id": "ship_expedition", "bay_id": a.capabilities.bays.keys()[0], "offset": [0, 0, 0], "orientation": [0, 0, 0, 1]}
	var context: Dictionary = {"campaign_id": "campaign_fixture", "faction_id": "faction_fixture", "species_id": "species_fixture", "systems": ["system_home", "system_other"], "bodies": {"body_home": "system_home", "body_other": "system_other"}}
	_expect(Draft.validate(fixture, context).is_empty(), "Derived dimensions, capacities and stable bay ID satisfy the existing expedition contract")

func _editor_checks() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	var editor: Control = Yard.instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	_expect(Ship.evaluate(editor.blueprint).ok, "Actual scene opens a ready expedition template")
	editor.new_template("lander")
	var initial: Dictionary = editor.blueprint.duplicate(true)
	editor.select_part(5)
	editor.add_module("cargo_s")
	_expect(Ship.evaluate(editor.blueprint).stats.cargo == 24, "Editor add button path changes capacity")
	editor.undo()
	_expect(editor.blueprint == initial, "Shared undo restores original blueprint and identities")
	editor.redo()
	_expect(Ship.evaluate(editor.blueprint).stats.cargo == 24, "Shared redo restores the expansion")
	editor.select_part(7)
	var uid: String = editor.blueprint.parts[7].uid
	editor.rotate_part()
	_expect(editor.blueprint.parts[7].uid == uid and editor.blueprint.parts[7].rotation.y == 90, "Rotation preserves stable module ID")
	editor.mirror_part()
	_expect(editor.blueprint.parts.back().uid != uid, "Mirror copy creates a new stable module ID")
	editor.undo()
	editor.undo()
	editor.save_current()
	var path: String = editor.current_path
	_expect(not path.is_empty() and not editor.dirty, "Real editor saves through the existing store")
	editor.new_template("expedition")
	_expect(editor.load_path(path) and editor.blueprint.ship.role == "lander", "Real editor reopens a saved design with the matching catalogue")
	var edited_before: Dictionary = editor.blueprint.duplicate(true)
	_expect(not editor.load_path(Ship.DIRECTORY + "/future.json") and editor.blueprint == edited_before, "Failed editor load preserves the active draft")
	await _expanded_editor_checks(editor)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--capture"):
		await _capture_editor(editor, args[args.find("--capture") + 1])
	editor.queue_free()
	await process_frame

func _expanded_editor_checks(editor: Control) -> void:
	var original_path: String = editor.current_path
	var original_bytes: String = FileAccess.get_file_as_string(original_path)
	var original_id: String = editor.blueprint.design_id
	var old_part_id: String = editor.blueprint.parts[0].uid
	_expect(editor.save_as_copy(), "Editor can save a distinct design copy")
	_expect(editor.blueprint.design_id != original_id and editor.blueprint.parts[0].uid != old_part_id and editor.blueprint.revision == 1, "Copy starts its own design and module identities at revision one")
	_expect(FileAccess.get_file_as_string(original_path) == original_bytes and not editor.history.can_undo(), "Copy protects original bytes and does not undo across design identity")
	var copied: Dictionary = Ship.load_design(editor.current_path)
	_expect(copied.ok and copied.blueprint.design_id == editor.blueprint.design_id, "Copy can be reopened through the existing reader")
	var before: Dictionary = editor.blueprint.duplicate(true)
	editor._search.text = "Fracht"
	editor._search.text_changed.emit("Fracht")
	_expect(editor._module_ids.size() == 1 and editor._module_ids[0] == "cargo_s", "Module search filters the real role catalogue")
	editor._category.select(3)
	editor._fill_catalog()
	_expect(editor._module_ids.is_empty() and editor._add_button.disabled and editor.blueprint == before, "Empty search/category intersection cannot insert a wrong module")
	editor.new_template("expedition")
	for z in range(6):
		for x in range(8): _add(editor.blueprint, "battery_s", Vector3(23 + x * 2, 0, z * 2))
	editor._refresh()
	_expect(Ship.evaluate(editor.blueprint).ok, "Selection benchmark uses a connected 56-module expedition")
	var builds: int = editor.mesh_build_count
	var evaluations: int = editor.evaluation_count
	var mesh: Mesh = editor._assembler.get_node("PrimitiveAssembly").mesh
	var snapshot: Dictionary = editor.blueprint.duplicate(true)
	var start: int = Time.get_ticks_usec()
	for i in range(100): editor.select_part(i % editor.blueprint.parts.size())
	var elapsed: int = Time.get_ticks_usec() - start
	_expect(editor.mesh_build_count == builds and editor.evaluation_count == evaluations and mesh == editor._assembler.get_node("PrimitiveAssembly").mesh, "100 selections do not rebuild the ship mesh or recompute capabilities")
	_expect(snapshot == editor.blueprint, "Selection benchmark leaves the design unchanged")
	print(JSON.stringify({"probe": "shipyard_selection", "modules": editor.blueprint.parts.size(), "selections": 100, "microseconds": elapsed, "full_mesh_rebuilds": editor.mesh_build_count - builds, "capability_evaluations": editor.evaluation_count - evaluations, "scope": "CPU authoring; not target-PC FPS"}))
	editor.new_template("lander")
	editor._symmetry.set_pressed_no_signal(true)
	var source: Dictionary = editor.blueprint.duplicate(true)
	editor.add_module("cargo_s")
	_expect(editor.blueprint.parts.size() == 9, "Editor applies symmetric add as one operation")
	editor.undo()
	_expect(editor.blueprint == source, "One Undo removes both symmetric additions")
	editor.select_part(0)
	editor.mirror_part()
	_expect(editor.blueprint == source, "Rejected centreline mirror keeps the editor unchanged")
	# A name edit is one undo step, not one expensive geometry pass per letter.
	builds = editor.mesh_build_count
	editor._rename("A")
	editor._rename("Atlas")
	editor._rename("Atlas II")
	editor.undo()
	_expect(editor.blueprint.name == source.name, "One Undo restores the complete previous name")
	_expect(editor.mesh_build_count == builds + 1, "Typing a name does not rebuild geometry; only undo refreshes the model")
	# Save-and-continue must not discard the draft if the actual writer fails.
	editor.save_current()
	editor._rename("Behalten")
	var continued: Array[bool] = [false]
	editor._guard(func() -> void: continued[0] = true)
	DirAccess.make_dir_recursive_absolute(editor.current_path + ".tmp")
	editor._confirmation.custom_action.emit(&"save_continue")
	_expect(not continued[0] and editor._confirmation.visible and editor.dirty, "Write failure keeps save-before-switch modal and dirty draft")
	DirAccess.remove_absolute(editor.current_path + ".tmp")
	editor._confirmation.custom_action.emit(&"save_continue")
	_expect(continued[0] and not editor.dirty and not editor._confirmation.visible, "Successful save precedes the pending transition")
	await process_frame

func _capture_editor(editor: Control, directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	# DisplaySettings applies its startup defaults deferred. After it is ready,
	# test actual pixel-sized layouts rather than a scaled 1920px canvas.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	for dimensions: Vector2i in [Vector2i(960, 640), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for role: String in ["expedition", "lander"]:
			editor.new_template(role)
			for frame in range(5): await process_frame
			editor.frame_design()
			await process_frame
			await RenderingServer.frame_post_draw
			_expect(editor.get_rect().size.x <= dimensions.x + 1, "Editor fits window width")
			_expect(editor._viewport_container.size.x >= 220, "3D viewport stays usable")
			_expect(editor._status.get_global_rect().end.y <= dimensions.y + 1, "Save feedback remains inside the window")
			var capture_path: String = directory.path_join("shipyard-%s-%dx%d.png" % [role, dimensions.x, dimensions.y])
			_expect(root.get_texture().get_image().save_png(capture_path) == OK, "Native frame saved")
	await _idle_render_check(editor)
	# Exercise a real pointer click, then dirty-draft cancellation and the fit picker.
	root.size = Vector2i(1280, 720)
	editor.new_template("lander")
	await process_frame
	editor.select_part(5)
	var catalogue_index: int = editor._module_ids.find("cargo_s")
	editor._catalog.select(catalogue_index)
	editor._update_preview()
	var add_button: Button = _find_button(editor, "Modul hinzufügen")
	await _click(add_button)
	_expect(editor.blueprint.parts.size() == 8, "Pointer click on Add actually installs a module")
	var replace_button: Button = _find_button(editor, "Neue Expedition")
	await _click(replace_button)
	_expect(editor._confirmation.visible and editor.blueprint.ship.role == "lander", "Pointer replacement protects the dirty draft")
	editor._confirmation.get_cancel_button().pressed.emit()
	editor._confirmation.hide()
	_expect(editor.blueprint.ship.role == "lander", "Cancel keeps the edited lander")
	editor.save_current()
	var lander_path: String = editor.current_path
	editor.new_template("expedition")
	editor.save_current()
	editor._show_library(true)
	for frame in range(120):
		await process_frame
		if not editor._library_loading: break
	for index in range(editor._library_entries.size()):
		if editor._library_entries[index].path == lander_path:
			editor._activate_library(index)
			break
	_expect(editor._fit.text.contains("passt in"), "Library picker checks actual saved counterpart")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("shipyard-hangar-check.png"))
	# Preview and orthographic controls are rendered from the actual live editor.
	editor.new_template("lander")
	editor.select_part(0)
	editor._search.text = "Fracht"
	editor._search.text_changed.emit("Fracht")
	editor._preview_toggle.set_pressed_no_signal(true)
	editor._symmetry.set_pressed_no_signal(true)
	editor._update_preview()
	editor.set_view("Oben")
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(editor._ghost.visible and not editor._add_button.disabled, "Live symmetric ghost marks a free attachment")
	root.get_texture().get_image().save_png(directory.path_join("shipyard-symmetry-preview.png"))
	editor.add_selected_module()
	editor.select_part(0)
	editor._update_preview()
	_expect(editor._ghost.visible and editor._add_button.disabled, "Occupied placement becomes blocked before a second insertion")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join("shipyard-blocked-preview.png"))
	# Pick through the displayed viewport texture, then use a keyboard action.
	editor.new_template("lander")
	editor.set_view("Perspektive")
	for frame in range(3): await process_frame
	editor.select_part(-1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = editor._viewport_container.global_position + editor._camera.unproject_position(editor._target)
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	_expect(editor.selected >= 0, "Pointer ray selects a module through the retained viewport texture")
	var part_index: int = editor.selected
	if part_index >= 0:
		var old_rotation: Vector3 = editor.blueprint.parts[part_index].rotation
		var key := InputEventKey.new()
		key.keycode = KEY_R
		key.pressed = true
		root.push_input(key, true)
		await process_frame
		_expect(editor.blueprint.parts[part_index].rotation != old_rotation, "R shortcut rotates the selected module")
		old_rotation = editor.blueprint.parts[part_index].rotation
		editor._name_field.grab_focus()
		root.push_input(key, true)
		await process_frame
		_expect(editor.blueprint.parts[part_index].rotation == old_rotation, "Text focus prevents a rotation shortcut")

func _idle_render_check(editor: Control) -> void:
	# UPDATE_ONCE is the configured request, not a reliable renderer-frame
	# counter. Observe actual retained pixels and a subsequent explicit redraw.
	var environment: Environment
	for child: Node in editor._world.get_children():
		if child is WorldEnvironment: environment = child.environment
	_expect(environment != null, "Preview has its own environment")
	if environment == null: return
	await RenderingServer.frame_post_draw
	var before: PackedByteArray = editor._viewport.get_texture().get_image().get_data()
	var color: Color = environment.background_color
	environment.background_color = Color.RED
	for frame in range(3): await RenderingServer.frame_post_draw
	_expect(editor._viewport.get_texture().get_image().get_data() == before, "Idle preview retains its last frame despite an unrequested scene change")
	editor._request_render()
	await RenderingServer.frame_post_draw
	_expect(editor._viewport.get_texture().get_image().get_data() != before, "Explicit redraw publishes the new scene pixels")
	environment.background_color = color
	editor._request_render()
	await RenderingServer.frame_post_draw

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, label)
		if found != null: return found
	return null

func _click(button: Button) -> void:
	_expect(button != null, "Requested button exists")
	if button == null: return
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		root.push_input(event, true)
		await process_frame
	await process_frame

func _add(data: Dictionary, id: String, position: Vector3) -> void:
	var index: int = Ship.Assembly.add_part(data, id, position)
	data.parts[index].part_revision = 1

func _has(data: Dictionary, code: String) -> bool:
	for issue: Dictionary in Ship.evaluate(data).issues:
		if issue.code == code: return true
	return false

func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
