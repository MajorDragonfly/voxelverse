extends "res://creatures/editor/creature_editor_v4.gd"

const AssemblyV7 = preload(
	"res://creatures/editor/creature_assembly_blueprint_v7.gd"
)
const BuilderHistoryV7 = preload(
	"res://creatures/editor/creature_builder_history_v7.gd"
)
const SurfaceSocketsV7 = preload(
	"res://creatures/editor/creature_surface_sockets_v7.gd"
)
const BaseBlueprintV7 = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const PartsV7 = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const AnatomyV7 = preload(
	"res://creatures/editor/creature_anatomy.gd"
)
const AttachmentNormalizerV7 = preload(
	"res://creatures/editor/creature_attachment_normalizer.gd"
)

const MAIN_SCENE_PATH: String = "res://main/main.tscn"
const LEGACY_SAVE_PATH: String = "user://creature_editor_blueprint.json"
const EDIT_COALESCE_MSEC: int = 320

var _history: RefCounted = BuilderHistoryV7.new()
var _builder_panel: PanelContainer
var _revision_label: Label
var _builder_status_label: Label
var _undo_button: Button
var _redo_button: Button
var _snap_button: Button
var _assembly_symmetry_button: Button
var _last_edit_label: String = ""
var _last_edit_msec: int = -10000
var _suppress_history: bool = false


func _ready() -> void:
	super._ready()
	blueprint = AssemblyV7.load_best_available()
	AssemblyV7.normalize(blueprint)
	AttachmentNormalizerV7.normalize(blueprint)
	AnatomyV7.ensure_anchors(blueprint, true)
	AnatomyV7.rebind_all_parts(blueprint)
	_symmetry_enabled = AssemblyV7.is_symmetry_enabled(blueprint)
	var assembly: Dictionary = blueprint.get("assembly", {})
	current_category = str(
		assembly.get("last_selected_category", PartsV7.CATEGORY_BODY)
	)
	selected_part_index = -1
	selected_body_segment = -1
	_build_builder_v7_toolbar()
	_reconfigure_legacy_buttons()
	if _title_label != null:
		_title_label.text = "VOXELVERSE CREATURE BUILDER"
	if _help_label != null:
		_help_label.text = (
			"SP0RE-STYLE ASSEMBLY\n"
			+ "Shape the spine and body directly. Add modular parts from the "
			+ "library, then move, rotate, scale or mirror them.\n\n"
			+ "Body: click cyan handles and drag.\n"
			+ "Parts: LMB drag = move, RMB drag = rotate, wheel = scale.\n"
			+ "Ctrl+Z / Ctrl+Y = undo / redo. F2 in the world returns here.\n\n"
			+ "There is no genetics or mutation system. The creature changes "
			+ "only when you rebuild it."
		)
	_history.clear()
	_refresh_all()
	_set_builder_status(
		"Assembly format V7 loaded. Genetics and mutation metadata removed."
	)
	_save_migrated_assembly_without_revision()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_last_edit_label = ""
	super._input(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		_last_edit_label = ""
	super._unhandled_input(event)


func _handle_key(event: InputEventKey) -> void:
	if event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			_undo_edit()
			return
		if event.keycode == KEY_Y:
			_redo_edit()
			return
	super._handle_key(event)


func _build_builder_v7_toolbar() -> void:
	if _ui_root == null:
		return
	_builder_panel = PanelContainer.new()
	_builder_panel.name = "CreatureBuilderV7Toolbar"
	_builder_panel.anchor_left = 0.0
	_builder_panel.anchor_top = 0.0
	_builder_panel.anchor_right = 1.0
	_builder_panel.anchor_bottom = 0.0
	_builder_panel.offset_left = 318.0
	_builder_panel.offset_top = 56.0
	_builder_panel.offset_right = -328.0
	_builder_panel.offset_bottom = 176.0
	_ui_root.add_child(_builder_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_builder_panel.add_child(content)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)
	_undo_button = _add_builder_button(actions, "Undo", _undo_edit)
	_redo_button = _add_builder_button(actions, "Redo", _redo_edit)
	_snap_button = _add_builder_button(actions, "Surface Snap", _toggle_surface_snap)
	_assembly_symmetry_button = _add_builder_button(
		actions,
		"Symmetry",
		_toggle_builder_symmetry
	)
	_add_builder_button(actions, "Attach", _attach_selected_to_surface)
	_add_builder_button(actions, "Duplicate", _duplicate_selected_part)
	_add_builder_button(actions, "Delete", _delete_selected_part)
	_add_builder_button(actions, "Save", _save_blueprint)
	_add_builder_button(actions, "Play", _play_test_placeholder)

	_revision_label = Label.new()
	_revision_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_revision_label)
	_builder_status_label = Label.new()
	_builder_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_builder_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_builder_status_label)
	_update_builder_toolbar()


func _add_builder_button(
	parent: Control,
	button_text: String,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(82.0, 32.0)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _reconfigure_legacy_buttons() -> void:
	var randomize_button: Button = _find_button_by_text(_bottom_panel, "Randomize")
	if randomize_button != null:
		randomize_button.visible = false
	var play_button: Button = _find_button_by_text(
		_bottom_panel,
		"Play Test Later"
	)
	if play_button != null:
		play_button.text = "Play Creature"
	var title := _find_label_by_text(_left_panel, "PART LIBRARY")
	if title != null:
		title.text = "MODULAR PARTS"
	var stats_title := _find_label_by_text(_right_panel, "CREATURE STATS")
	if stats_title != null:
		stats_title.text = "ASSEMBLY / ABILITIES"


func _find_button_by_text(root: Node, text_value: String) -> Button:
	if root == null:
		return null
	if root is Button and root.text == text_value:
		return root as Button
	for child in root.get_children():
		var result: Button = _find_button_by_text(child, text_value)
		if result != null:
			return result
	return null


func _find_label_by_text(root: Node, text_value: String) -> Label:
	if root == null:
		return null
	if root is Label and root.text == text_value:
		return root as Label
	for child in root.get_children():
		var result: Label = _find_label_by_text(child, text_value)
		if result != null:
			return result
	return null


func _on_category_button_pressed(category_id: String) -> void:
	super._on_category_button_pressed(category_id)
	var assembly: Dictionary = blueprint.get("assembly", {})
	assembly["last_selected_category"] = category_id
	assembly["edit_mode"] = (
		"body"
		if category_id == PartsV7.CATEGORY_BODY
		else "paint"
		if category_id == PartsV7.CATEGORY_PAINT
		else "parts"
	)
	blueprint["assembly"] = assembly
	_update_builder_toolbar()


func _on_part_button_pressed(part_id: String) -> void:
	_record_before_edit("Place %s" % part_id)
	var part_count_before: int = BaseBlueprintV7.get_part_count(blueprint)
	super._on_part_button_pressed(part_id)
	AssemblyV7.normalize(blueprint)
	if current_category == PartsV7.CATEGORY_BODY:
		AnatomyV7.rebind_all_parts(blueprint)
	elif current_category != PartsV7.CATEGORY_PAINT:
		var part_count_after: int = BaseBlueprintV7.get_part_count(blueprint)
		if part_count_after > part_count_before and selected_part_index >= 0:
			AnatomyV7.ensure_anchors(blueprint, false)
			AnatomyV7.reset_part_anchor(blueprint, selected_part_index)
			SurfaceSocketsV7.apply_symmetry(
				blueprint,
				selected_part_index,
				AssemblyV7.is_symmetry_enabled(blueprint)
			)
			if AssemblyV7.is_snap_to_surface(blueprint):
				SurfaceSocketsV7.snap_part_to_surface(
					blueprint,
					selected_part_index
				)
	AttachmentNormalizerV7.normalize(blueprint)
	_refresh_all()
	_set_builder_status("Part placed. Drag it directly on the creature surface.")


func _apply_spine_delta(
	width_delta: float,
	height_delta: float,
	curve_delta: float,
	length_delta: float
) -> void:
	_record_before_edit("Shape body")
	super._apply_spine_delta(
		width_delta,
		height_delta,
		curve_delta,
		length_delta
	)
	AnatomyV7.rebind_all_parts(blueprint)


func _apply_body_delta(
	position_delta: Vector3,
	scale_delta: float
) -> void:
	_record_before_edit("Shape body")
	super._apply_body_delta(position_delta, scale_delta)
	AnatomyV7.rebind_all_parts(blueprint)


func _apply_transform_delta(
	position_delta: Vector3,
	scale_delta: float,
	rotation_y_delta: float
) -> void:
	_record_before_edit("Transform part")
	super._apply_transform_delta(
		position_delta,
		scale_delta,
		rotation_y_delta
	)
	_apply_selected_socket_policy(position_delta != Vector3.ZERO)


func _drag_selected_part_from_mouse(event: InputEventMouseMotion) -> void:
	_record_before_edit("Move part")
	super._drag_selected_part_from_mouse(event)
	_apply_selected_socket_policy(true)


func _rotate_selected_part_from_mouse(event: InputEventMouseMotion) -> void:
	_record_before_edit("Rotate part")
	super._rotate_selected_part_from_mouse(event)


func _scale_selected_part_from_mouse(scale_delta: float) -> void:
	_record_before_edit("Scale part")
	super._scale_selected_part_from_mouse(scale_delta)


func _apply_selected_socket_policy(position_changed: bool) -> void:
	if selected_part_index < 0:
		return
	if position_changed and AssemblyV7.is_snap_to_surface(blueprint):
		SurfaceSocketsV7.snap_part_to_surface(blueprint, selected_part_index)
	else:
		AnatomyV7.capture_manual_offset(blueprint, selected_part_index)
	_refresh_preview()
	_refresh_stats_panel()


func _toggle_surface_snap() -> void:
	_record_before_edit("Toggle surface snap", true)
	var enabled: bool = not AssemblyV7.is_snap_to_surface(blueprint)
	AssemblyV7.set_snap_to_surface(blueprint, enabled)
	if enabled:
		_attach_selected_to_surface(false)
	_update_builder_toolbar()
	_set_builder_status("Surface snap: %s" % ("ON" if enabled else "OFF"))


func _toggle_builder_symmetry() -> void:
	_record_before_edit("Toggle symmetry", true)
	_symmetry_enabled = not AssemblyV7.is_symmetry_enabled(blueprint)
	AssemblyV7.set_symmetry_enabled(blueprint, _symmetry_enabled)
	if selected_part_index >= 0:
		SurfaceSocketsV7.apply_symmetry(
			blueprint,
			selected_part_index,
			_symmetry_enabled
		)
	_refresh_all()
	_set_builder_status(
		"Part symmetry: %s" % ("ON" if _symmetry_enabled else "OFF")
	)


func _toggle_global_symmetry() -> void:
	_toggle_builder_symmetry()


func _toggle_selected_mirror() -> void:
	_record_before_edit("Mirror selected part", true)
	super._toggle_selected_mirror()
	_refresh_all()


func _attach_selected_to_surface(show_status: bool = true) -> void:
	if selected_part_index < 0:
		if show_status:
			_set_builder_status("Select a modular part first.")
		return
	_record_before_edit("Attach part to surface", true)
	if SurfaceSocketsV7.snap_part_to_surface(blueprint, selected_part_index):
		AttachmentNormalizerV7.normalize(blueprint)
		_refresh_all()
		if show_status:
			_set_builder_status("Selected part attached to the body surface.")


func _duplicate_selected_part() -> void:
	if selected_part_index < 0:
		return
	_record_before_edit("Duplicate part", true)
	super._duplicate_selected_part()
	if selected_part_index >= 0:
		SurfaceSocketsV7.apply_symmetry(
			blueprint,
			selected_part_index,
			AssemblyV7.is_symmetry_enabled(blueprint)
		)
		if AssemblyV7.is_snap_to_surface(blueprint):
			SurfaceSocketsV7.snap_part_to_surface(
				blueprint,
				selected_part_index
			)
	_refresh_all()


func _delete_selected_part() -> void:
	if selected_part_index < 0:
		return
	_record_before_edit("Delete part", true)
	super._delete_selected_part()
	_refresh_all()


func _clear_all_parts() -> void:
	_record_before_edit("Clear modular parts", true)
	super._clear_all_parts()
	_refresh_all()


func _reset_selected_transform() -> void:
	_record_before_edit("Reset selected transform", true)
	super._reset_selected_transform()
	if selected_part_index >= 0:
		AnatomyV7.reset_part_anchor(blueprint, selected_part_index)
	_refresh_all()


func _reset_blueprint() -> void:
	_record_before_edit("New creature", true)
	blueprint = AssemblyV7.create_default()
	AttachmentNormalizerV7.normalize(blueprint, true)
	AnatomyV7.ensure_anchors(blueprint, true)
	AnatomyV7.rebind_all_parts(blueprint)
	_symmetry_enabled = AssemblyV7.is_symmetry_enabled(blueprint)
	selected_part_index = -1
	selected_body_segment = -1
	current_category = PartsV7.CATEGORY_BODY
	_refresh_all()
	_set_builder_status("New creature assembly created.")


func _randomize_blueprint() -> void:
	_set_builder_status(
		"Random mutation is disabled. Rebuild the creature manually with parts."
	)


func _save_blueprint() -> void:
	if _creature_name_edit != null:
		var creature_name: String = _creature_name_edit.text.strip_edges()
		if creature_name.is_empty():
			creature_name = "New Creature"
		blueprint["name"] = creature_name
		_creature_name_edit.text = creature_name
	AssemblyV7.normalize(blueprint)
	AttachmentNormalizerV7.normalize(blueprint)
	AnatomyV7.rebind_all_parts(blueprint)
	var revision: int = AssemblyV7.increment_revision(blueprint)
	var save_error: Error = AssemblyV7.save_to_file(blueprint)
	if save_error != OK:
		push_error("Creature assembly save failed: %s" % save_error)
		_set_builder_status("Save failed: %s" % save_error)
		return
	var legacy_error: Error = BaseBlueprintV7.save_to_file(
		blueprint,
		LEGACY_SAVE_PATH
	)
	if legacy_error != OK:
		push_warning("Legacy compatibility save failed: %s" % legacy_error)
	_history.clear()
	_refresh_all()
	_set_builder_status("Creature assembly saved as revision %d." % revision)


func _save_migrated_assembly_without_revision() -> void:
	AssemblyV7.normalize(blueprint)
	var save_error: Error = AssemblyV7.save_to_file(blueprint)
	if save_error != OK:
		push_warning("Could not save migrated V7 assembly: %s" % save_error)


func _load_blueprint() -> void:
	_record_before_edit("Load creature", true)
	blueprint = AssemblyV7.load_best_available()
	AssemblyV7.normalize(blueprint)
	AttachmentNormalizerV7.normalize(blueprint)
	AnatomyV7.ensure_anchors(blueprint, true)
	AnatomyV7.rebind_all_parts(blueprint)
	_symmetry_enabled = AssemblyV7.is_symmetry_enabled(blueprint)
	selected_part_index = -1
	selected_body_segment = -1
	var assembly: Dictionary = blueprint.get("assembly", {})
	current_category = str(
		assembly.get("last_selected_category", PartsV7.CATEGORY_BODY)
	)
	_refresh_all()
	_set_builder_status(
		"Loaded creature assembly revision %d."
		% AssemblyV7.get_revision(blueprint)
	)


func _play_test_placeholder() -> void:
	_save_blueprint()
	var change_error: Error = get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if change_error != OK:
		push_error("Could not open main scene: %s" % change_error)
		_set_builder_status("Could not open the world: %s" % change_error)


func _undo_edit() -> void:
	var restored: Dictionary = _history.call("undo", blueprint)
	if restored.is_empty():
		_set_builder_status("Nothing to undo.")
		return
	_apply_restored_blueprint(restored, "Undo applied.")


func _redo_edit() -> void:
	var restored: Dictionary = _history.call("redo", blueprint)
	if restored.is_empty():
		_set_builder_status("Nothing to redo.")
		return
	_apply_restored_blueprint(restored, "Redo applied.")


func _apply_restored_blueprint(
	restored: Dictionary,
	status_text: String
) -> void:
	_suppress_history = true
	blueprint = restored
	AssemblyV7.normalize(blueprint)
	AttachmentNormalizerV7.normalize(blueprint)
	AnatomyV7.ensure_anchors(blueprint, true)
	AnatomyV7.rebind_all_parts(blueprint)
	_symmetry_enabled = AssemblyV7.is_symmetry_enabled(blueprint)
	selected_part_index = -1
	selected_body_segment = -1
	_suppress_history = false
	_refresh_all()
	_set_builder_status(status_text)


func _record_before_edit(
	label: String,
	force_new_entry: bool = false
) -> void:
	if _suppress_history:
		return
	var now_msec: int = Time.get_ticks_msec()
	var should_push: bool = (
		force_new_entry
		or label != _last_edit_label
		or now_msec - _last_edit_msec > EDIT_COALESCE_MSEC
	)
	if should_push:
		_history.call("push_state", blueprint, label)
	_last_edit_label = label
	_last_edit_msec = now_msec
	_update_builder_toolbar()


func _refresh_stats_panel() -> void:
	super._refresh_stats_panel()
	if _stats_label != null:
		_stats_label.text = (
			"Revision: %d\n" % AssemblyV7.get_revision(blueprint)
			+ _stats_label.text
		)
	if _selection_label != null and selected_part_index >= 0:
		var placement: Dictionary = BaseBlueprintV7.get_part_placement(
			blueprint,
			selected_part_index
		)
		if not placement.is_empty():
			_selection_label.text += (
				"\nSocket: %s\nSurface locked: %s"
				% [
					str(placement.get("socket_type", "surface")),
					str(bool(placement.get("anchor_locked", true))),
				]
			)
	_update_builder_toolbar()


func _update_builder_toolbar() -> void:
	if _revision_label != null:
		_revision_label.text = (
			"Revision %d · %d modular parts · Complexity %d/%d · "
			+ "development by rebuilding only"
		) % [
			AssemblyV7.get_revision(blueprint),
			BaseBlueprintV7.get_part_count(blueprint),
			BaseBlueprintV7.calculate_complexity(blueprint),
			BaseBlueprintV7.COMPLEXITY_LIMIT,
		]
	if _undo_button != null:
		_undo_button.disabled = not bool(_history.call("can_undo"))
	if _redo_button != null:
		_redo_button.disabled = not bool(_history.call("can_redo"))
	if _snap_button != null:
		_snap_button.text = "Snap: %s" % (
			"ON" if AssemblyV7.is_snap_to_surface(blueprint) else "OFF"
		)
	if _assembly_symmetry_button != null:
		_assembly_symmetry_button.text = "Symmetry: %s" % (
			"ON" if AssemblyV7.is_symmetry_enabled(blueprint) else "OFF"
		)


func _set_builder_status(status_text: String) -> void:
	if _builder_status_label != null:
		_builder_status_label.text = status_text
