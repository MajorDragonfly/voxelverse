extends SceneTree
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Base = preload("res://creatures/editor/creature_blueprint.gd")
const Revisions = preload("res://creatures/catalog/creature_part_revisions.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const Snapshot = preload("res://tests/creature_foot_snapshot.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const SAVE: String = "user://revision-supported.json"
const BLOCKED: String = "user://revision-future.json"
const EXPECTED: String = "user://revision-expected.json"
var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void: call_deferred("_run")


func _run() -> void:
	var saves: Node = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	if "--part-revision-restart" in OS.get_cmdline_user_args():
		_verify_restart(saves)
	else:
		_versions()
		_geometry()
		var design: Dictionary = await _editor()
		_files_and_library(design, saves)
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/creature_part_revisions_test.gd", "--", "--part-revision-restart"], output, true)
		check(code == 0 and str(output).contains("PART_REVISIONS_PASSED") and not str(output).contains("ERROR:"), "Fresh-process verification failed: " + str(output))
	for failure: String in failures: push_error(failure)
	print("PART_REVISIONS_PASSED " + JSON.stringify({"checks": checks, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _versions() -> void:
	var legacy: Dictionary = Base._serialize_blueprint(Creature.create_default())
	for part: Dictionary in legacy.parts:
		for field: String in Revisions.FIELDS: part.erase(field)
	var original: String = var_to_str(legacy)
	var migrated: Dictionary = Creature.migrate_snapshot(legacy, "revision-legacy")
	var encoded: Dictionary = Creature.serialize_snapshot(migrated)
	check(var_to_str(legacy) == original, "Migration mutated legacy source")
	check(encoded == Creature.serialize_snapshot(Creature.migrate_snapshot(encoded)), "Pinned migration is not idempotent")
	for section in [encoded.body, encoded.paint] + encoded.parts:
		check(section.part_revision == 1 and section.catalog_revision == 1, "Saved reference is not pinned")
	check(encoded.parts[2].end_part_revision == 1 and encoded.parts[2].end_catalog_revision == 1, "Implicit standard foot is not pinned")
	for field: String in Revisions.FIELDS:
		for location: String in ["root", "body", "paint", "part"]:
			for revision in [2, 3, 999999, 0, -1, 1.5, "1", true, null, INF, NAN]:
				var future: Dictionary = migrated.duplicate(true)
				var section: Dictionary = future if location == "root" else (future.parts[2] if location == "part" else future[location])
				section[field] = revision
				var before: String = var_to_str(future)
				check(not Creature.Contract.inspect(future, "creature").ok, "Invalid reference accepted: %s/%s/%s" % [location, field, revision])
				Creature.normalize(future)
				Base.set_body_scale(future, 1.5)
				check(Base.add_part(future, "eyes_wide") == -1, "Unsupported design accepted an edit")
				check(Creature.serialize_snapshot(future).is_empty() and Creature.migrate_snapshot(future).is_empty(), "Unsupported reference crossed a codec")
				check(var_to_str(future) == before, "Rejected reference mutated original")
	# Snapshot and legacy codecs retain all four reference fields.
	var restored: Dictionary = Base._deserialize_blueprint(Base._serialize_blueprint(Creature.migrate_snapshot(encoded)))
	check(restored.parts[2].end_part_revision == 1 and restored.body.part_revision == 1, "Legacy codec discarded explicit references")


func _geometry() -> void:
	var design: Dictionary = Creature.create_default()
	var ids: Array = Revisions.Mouths.LEGACY_IDS.duplicate()
	for entry: Dictionary in Revisions.Mouths.DEFINITIONS: ids.append(entry.id)
	for id: String in ids:
		var definition: Dictionary = Parts.get_part(id)
		var placement: Dictionary = {"part_id": id, "category": definition.category, "shape_scale": Vector3(0.8, 1.2, 1.1)}
		var old := Node3D.new()
		old.set_meta("creature_part_side", -1.0)
		Geometry.build(old, definition, placement, design)
		Revisions.pin_reference(placement)
		var pinned := Node3D.new()
		pinned.set_meta("creature_part_side", -1.0)
		Geometry.build(pinned, definition, placement, design)
		check(Snapshot.describe(old) == Snapshot.describe(pinned), "Pinned geometry changed: " + id)
		check(pinned.get_meta("geometry_id") == id and pinned.get_meta("geometry_revision") == 1, "Mouth resolver lost reference")
		placement.part_revision = Revisions.current_revision(id) + 1
		var rejected := Node3D.new()
		Geometry.build(rejected, definition, placement, design)
		check(rejected.get_child_count() == 0, "Future mouth rendered current geometry")
		old.free()
		pinned.free()
		rejected.free()
	for definition: Dictionary in Parts.get_terminal_parts():
		var category: String = "legs" if definition.category == "feet" else "arms"
		var id: String = "legs_walker" if category == "legs" else "arms_grasping"
		var placement: Dictionary = {"part_id": id, "category": category, "end_part_id": definition.id,
			"part_revision": 1, "end_part_revision": 1, "end_catalog_revision": 1}
		var node := Node3D.new()
		Geometry.build(node, Parts.get_part(id), placement, design)
		var terminal: Node = node.find_child("LimbEnd", true, false)
		check(terminal != null and terminal.get_meta("geometry_id") == definition.id and terminal.get_meta("geometry_revision") == 1, "Terminal resolver lost reference: " + definition.id)
		check(terminal != null and terminal.get_child_count() > 0, "Pinned terminal has no geometry")
		node.free()
		placement.end_part_revision = 2
		node = Node3D.new()
		Geometry.build(node, Parts.get_part(id), placement, design)
		check(node.get_child_count() == 0, "Future terminal silently reverted to a default")
		node.free()
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var first_child: Node = preview.get_child(0)
	var future: Dictionary = design.duplicate(true)
	future.body.part_revision = 2
	preview.set_editor_state(future, 0, 0, true)
	check(preview.blueprint == design and preview.get_child(0) == first_child, "Runtime replaced valid model with future body")
	check(not preview.BodyContract.resolve(future).errors.is_empty(), "Body sockets used an unsupported model")
	preview.free()


func _editor() -> Dictionary:
	var design: Dictionary = Creature.create_default()
	for part: Dictionary in design.parts: part.part_revision = 1
	preload("res://creatures/editor/creature_anatomy.gd").reset_all_anchors(design)
	design = Creature.migrate_snapshot(Creature.serialize_snapshot(design))
	design.name = "Pinned creature"
	design.assembly.revision = 7
	root.get_node("GameState").set_world_seed(24824)
	var progress: Node = root.get_node("ProgressionService")
	progress.reset_for_new_game()
	progress.merge_unlocked_parts(["feet_bear_paws", "mouth_feline_snout"])
	var editor: Node = load("res://creatures/editor/creature_editor.tscn").instantiate()
	root.add_child(editor)
	for frame in range(12): await process_frame
	editor.set("blueprint", design)
	editor.call("_refresh_all")
	editor.call("_select_part_by_index", 2)
	editor.call("_set_terminal", "feet_bear_paws")
	check(editor.blueprint.parts[2].end_part_id == "feet_bear_paws" and editor.blueprint.parts[2].end_part_revision == 1, "Editor lost terminal reference")
	editor.call("_undo_edit")
	check(str(editor.blueprint.parts[2].get("end_part_id", "")).is_empty(), "Terminal undo failed")
	editor.call("_redo_edit")
	check(editor.blueprint.parts[2].end_part_id == "feet_bear_paws" and editor.blueprint.parts[2].end_part_revision == 1, "Terminal redo lost revision")
	design = editor.blueprint.duplicate(true)
	var future: Dictionary = design.duplicate(true)
	future.parts[2].end_part_revision = 2
	var original: String = var_to_str(future)
	editor.set("blueprint", future)
	editor.call("_save_blueprint")
	check(not editor._last_save_ok and var_to_str(editor.blueprint) == original, "Editor normalized or saved future design")
	editor.free()
	await process_frame
	return design


func _files_and_library(design: Dictionary, saves: Node) -> void:
	check(Creature.save_to_file(design, SAVE) == OK, "Supported design save failed")
	var before: String = FileAccess.get_file_as_string(SAVE)
	var memory: String = var_to_str(design)
	DirAccess.make_dir_absolute(SAVE + ".tmp")
	check(Creature.save_to_file(design, SAVE) != OK, "Failed atomic write reported success")
	check(FileAccess.get_file_as_string(SAVE) == before and var_to_str(design) == memory, "Failed write changed file or live design")
	DirAccess.remove_absolute(SAVE + ".tmp")
	var exported: Dictionary = Package.export_blueprint(design)
	check(exported.ok, "Pinned export failed: " + str(exported))
	if not exported.ok: return
	var legacy: Dictionary = exported.package.duplicate(true)
	for section in [legacy.blueprint.body, legacy.blueprint.paint] + legacy.blueprint.parts:
		for field: String in Revisions.FIELDS: section.erase(field)
	check(Package.inspect(legacy).ok, "Legacy package no longer imports")
	check(Library.add(legacy).ok and Package.write_file("user://legacy-package.json", legacy).ok, "Legacy library fixture failed")
	var library_bytes: String = FileAccess.get_file_as_string(Library.PATH)
	var package_bytes: String = FileAccess.get_file_as_string("user://legacy-package.json")
	check(Library.add(exported.package).code == "already_present", "Pinning created a false immutable revision conflict")
	check(Package.write_file("user://legacy-package.json", exported.package).ok, "Equivalent pinned export conflicted with original")
	check(FileAccess.get_file_as_string(Library.PATH) == library_bytes and FileAccess.get_file_as_string("user://legacy-package.json") == package_bytes, "Equivalent import rewrote originals")
	var modified: Dictionary = exported.package.duplicate(true)
	modified.blueprint.parts[2].end_part_revision = 2
	check(not Library.add(modified).ok and not Package.prepare_import(modified, design, 0, modified.required_parts).ok, "Future terminal entered library/editor")
	check(FileAccess.get_file_as_string(Library.PATH) == library_bytes, "Rejected package changed library")
	check(Atomic.write("user://future-library.json", {"schema": 1, "packages": [modified]}, false) == OK, "Future library fixture failed")
	var future_library: String = FileAccess.get_file_as_string("user://future-library.json")
	check(not Library.add(exported.package, "user://future-library.json").ok and not Library.remove(Library.key_of(modified), "user://future-library.json").ok, "Future library accepted writes")
	check(FileAccess.get_file_as_string("user://future-library.json") == future_library, "Future library original changed")
	var pinned: Dictionary = Creature.serialize_snapshot(design)
	var future: Dictionary = pinned.duplicate(true)
	future.parts[2].end_part_revision = 2
	check(Atomic.write(BLOCKED, pinned, false) == OK and Atomic.write(BLOCKED, future) == OK, "Future file/backup fixture failed")
	var future_bytes: String = FileAccess.get_file_as_string(BLOCKED)
	var backup_bytes: String = FileAccess.get_file_as_string(BLOCKED + ".bak")
	check(Creature.load_from_file(BLOCKED).is_empty() and Creature.save_to_file(design, BLOCKED) != OK, "Future loose file was replaced")
	check(FileAccess.get_file_as_string(BLOCKED) == future_bytes and FileAccess.get_file_as_string(BLOCKED + ".bak") == backup_bytes, "Blocked write changed loose file or backup")
	var campaign: String = saves.create_slot("Revision protection", 24824)
	check(not campaign.is_empty(), "Campaign fixture failed")
	if campaign.is_empty(): return
	check(Creature.save_to_file(design) == OK and saves.save_now(), "Campaign design save failed")
	var state: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(campaign))
	state.design_files[Creature.SAVE_PATH] = Atomic.stringify(future)
	check(Atomic.write(campaign, state) == OK, "Future campaign fixture failed")
	var campaign_bytes: String = FileAccess.get_file_as_string(campaign)
	var campaign_backup: String = FileAccess.get_file_as_string(campaign + ".bak")
	check(not saves.load_now() and not saves.save_now(), "Campaign fell back to a backup or overwrote future revision")
	check(FileAccess.get_file_as_string(campaign) == campaign_bytes and FileAccess.get_file_as_string(campaign + ".bak") == campaign_backup, "Blocked campaign write changed original/backup")
	check(Atomic.write(EXPECTED, {"design": pinned, "campaign": campaign, "campaign_bytes": campaign_bytes,
		"campaign_backup": campaign_backup, "future_bytes": future_bytes, "backup_bytes": backup_bytes,
		"library": library_bytes, "package": exported.package}, false) == OK, "Restart oracle could not be written")


func _verify_restart(saves: Node) -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(EXPECTED))
	check(not expected.is_empty(), "Restart oracle missing")
	if expected.is_empty(): return
	var design: Dictionary = Creature.load_from_file(SAVE)
	check(not design.is_empty(), "Restart rejected supported revisions")
	check(JSON.parse_string(Atomic.stringify(Creature.serialize_snapshot(design))) == expected.design, "Restart changed revisions, identity, geometry or transforms")
	check(Library.add(expected.package).code == "already_present" and FileAccess.get_file_as_string(Library.PATH) == expected.library, "Restart changed legacy library")
	check(Creature.load_from_file(BLOCKED).is_empty() and Creature.save_to_file(design, BLOCKED) != OK, "Restart overwrote future file")
	check(FileAccess.get_file_as_string(BLOCKED) == expected.future_bytes and FileAccess.get_file_as_string(BLOCKED + ".bak") == expected.backup_bytes, "Restart changed future original/backup")
	saves.save_path = expected.campaign
	check(not saves.load_now() and not saves.save_now(), "Fresh process downgraded future campaign")
	check(FileAccess.get_file_as_string(expected.campaign) == expected.campaign_bytes and FileAccess.get_file_as_string(expected.campaign + ".bak") == expected.campaign_backup, "Fresh process rewrote campaign/backup")
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	var terminals: Array[Node] = preview.find_children("LimbEnd", "Node3D", true, false)
	check(terminals.size() == 2, "Restart lost mirrored supporting feet")
	for terminal: Node in terminals:
		check(terminal.get_meta("geometry_id") == "feet_bear_paws" and terminal.get_meta("geometry_revision") == 1, "Restart drew different saved terminal")
	preview.free()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
