extends "res://creatures/editor/creature_editor_v7.gd"
## Active creature workshop. V7 remains the persistence/history contract.

const StudioPreview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Voxels = preload("res://creatures/editor/creature_voxel_mesh.gd")
const PartCard = preload("res://creatures/editor/creature_part_card.gd")
const Canvas = preload("res://creatures/editor/creature_editor_canvas.gd")
const CATEGORY_NAMES: Dictionary = {"body": "Körper", "mouth": "Mäuler", "eyes": "Augen", "legs": "Beine", "arms": "Arme", "tail": "Schwänze", "horns": "Hörner", "plates": "Panzer", "spikes": "Stacheln", "decor": "Details", "paint": "Muster"}
const MINT := Color("a6ebcc")
const INK := Color("0d202b")

var _studio_mode: String = "body"
var _canvas: Control
var _header: PanelContainer
var _inspector: VBoxContainer
var _palette_title: Label
var _stage_caption: Label
var _mode_buttons: Dictionary = {}
var _sliders: Dictionary = {}
var _part_list: ItemList
var _base_picker: ColorPickerButton
var _accent_picker: ColorPickerButton
var _syncing_ui: bool = false
var _gesture: bool = false
var _gesture_recorded: bool = false
var _last_save_ok: bool = false
var _saved_fingerprint: String = ""
var _saved_revisions: Dictionary = {}
var _orbiting: bool = false
var _drag_spine: int = -1
var _drag_part: bool = false
var _drag_side: float = 1.0
var _motion_choice: String = "idle"
var _last_mode_category: String = "eyes"


func _ready() -> void:
	super._ready()
	_title_label.text = "VOXELVERSE  /  KREATUREN"
	_help_label.text = "Ziehe an den Körperpunkten. Das Mausrad macht die gewählte Stelle dicker oder dünner."
	_studio_mode = "body"
	current_category = "body"
	_preview_pivot.rotation_degrees.y = 145.0
	_saved_fingerprint = _fingerprint()
	_saved_revisions[str(blueprint.get("design_id", ""))] = AssemblyV7.get_revision(blueprint)
	_set_mode("body")
	_set_builder_status("Deine Kreatur. Deine Form.")
	call_deferred("_frame_creature")


func _build_editor_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("112c37")
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c0d8df")
	environment.ambient_light_energy = 0.24
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color("fff1da")
	key.light_energy = 0.48
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 2, 3)
	fill.light_color = Color("a3e8dd")
	fill.light_energy = 0.08
	fill.omni_range = 9
	add_child(fill)
	var rim := OmniLight3D.new()
	rim.position = Vector3(2, 3, -3)
	rim.light_color = Color("f3ddb7")
	rim.light_energy = 0.12
	rim.omni_range = 9
	add_child(rim)
	var platform := MeshInstance3D.new()
	platform.name = "SculptingPlinth"
	platform.mesh = Voxels.plinth()
	platform.position.y = -1.22
	platform.material_override = Surface.material(Color.WHITE, true)
	add_child(platform)
	var outline := Node3D.new()
	outline.name = "PlinthRim"
	for index in range(4):
		var edge := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.2, 0.025, 0.025)
		edge.mesh = box
		edge.position = Vector3(0, 0, 2.49) if index == 0 else (Vector3(0, 0, -2.49) if index == 1 else Vector3(2.49 if index == 2 else -2.49, 0, 0))
		if index >= 2:
			edge.rotation.y = PI * 0.5
		edge.material_override = Surface.material(Color("80c9b3"))
		outline.add_child(edge)
	outline.position.y = -1.215
	add_child(outline)
	_camera_pivot = Node3D.new()
	add_child(_camera_pivot)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 38
	_camera.position = Vector3(0, 1.5, 7.3)
	_camera_pivot.add_child(_camera)
	_camera.look_at(Vector3(0, -0.05, 0))
	_preview_pivot = Node3D.new()
	_preview_pivot.name = "CreatureTurntable"
	add_child(_preview_pivot)
	_replace_preview_with_v4()


func _replace_preview_with_v4() -> void:
	if is_instance_valid(_preview):
		_preview_pivot.remove_child(_preview)
		_preview.queue_free()
	_preview = StudioPreview.new()
	_preview.name = "CreaturePreview"
	_preview_pivot.add_child(_preview)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EditorUI"
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.theme = _studio_theme()
	layer.add_child(_ui_root)
	_canvas = Canvas.new()
	_canvas.name = "CreatureCanvas"
	_canvas.set("editor", self)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(_canvas)
	_build_header()
	_build_palette()
	_build_inspector()
	_build_footer()
	_stage_caption = Label.new()
	_stage_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_stage_caption.offset_left = 328
	_stage_caption.offset_right = -316
	_stage_caption.offset_top = 104
	_stage_caption.offset_bottom = 136
	_stage_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_caption.add_theme_font_size_override("font_size", 17)
	_stage_caption.modulate = Color("93b7bd")
	_ui_root.add_child(_stage_caption)


func _studio_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for type in ["Label", "Button", "LineEdit", "CheckButton", "ItemList"]:
		theme.set_color("font_color", type, Color("e3f0e9"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1d3a44") if state == "normal" else Color("315b5d")
		if state == "pressed":
			style.bg_color = Color("41776b")
		if state == "disabled":
			style.bg_color = Color("142d37")
		style.set_corner_radius_all(3)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = MINT
		theme.set_stylebox(state, "Button", style)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102933")
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(18)
	panel.border_color = Color("2b454b")
	panel.set_border_width_all(1)
	theme.set_stylebox("panel", "PanelContainer", panel)
	return theme


func _panel(node_name: String, anchor_left_value: float, anchor_top_value: float, anchor_right_value: float, anchor_bottom_value: float, offsets: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = anchor_left_value
	panel.anchor_top = anchor_top_value
	panel.anchor_right = anchor_right_value
	panel.anchor_bottom = anchor_bottom_value
	panel.offset_left = offsets.x
	panel.offset_top = offsets.y
	panel.offset_right = offsets.z
	panel.offset_bottom = offsets.w
	_ui_root.add_child(panel)
	return panel


func _label(parent: Node, value: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _build_header() -> void:
	_header = _panel("WorkshopHeader", 0, 0, 1, 0, Vector4(16, 14, -16, 88))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_header.add_child(row)
	_title_label = _label(row, "VOXELVERSE  /  KREATUREN", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for entry in [["body", "01  Formen"], ["parts", "02  Teile"], ["paint", "03  Farbe"], ["test", "04  Testen"]]:
		var button := _button(row, entry[1], _set_mode.bind(entry[0]))
		button.toggle_mode = true
		_mode_buttons[entry[0]] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_button(row, "In die Welt  →", _play_test_placeholder).name = "PlayCreature"


func _build_palette() -> void:
	_left_panel = _panel("LeftPartPalette", 0, 0, 0, 1, Vector4(16, 104, 312, -126))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_left_panel.add_child(column)
	_palette_title = _label(column, "KÖRPER FORMEN", 20)
	_help_label = _label(column, "", 14)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_category_grid = GridContainer.new()
	_category_grid.columns = 3
	column.add_child(_category_grid)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_part_grid = GridContainer.new()
	_part_grid.name = "PartGrid"
	_part_grid.columns = 2
	_part_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_part_grid.add_theme_constant_override("h_separation", 8)
	_part_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_part_grid)


func _build_inspector() -> void:
	_right_panel = _panel("RightStatsPanel", 1, 0, 1, 1, Vector4(-300, 104, -16, -126))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 11)
	scroll.add_child(_inspector)
	_label(_inspector, "DEINE KREATUR", 18)
	_complexity_bar = ProgressBar.new()
	_complexity_bar.max_value = Blueprint.COMPLEXITY_LIMIT
	_complexity_bar.show_percentage = false
	_complexity_bar.custom_minimum_size.y = 8
	_inspector.add_child(_complexity_bar)
	_stats_label = _label(_inspector, "", 15)
	_selection_label = _label(_inspector, "Körperpunkt wählen", 18)
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for field in [["width_scale", "Breite", 0.22, 2.6], ["height_scale", "Höhe", 0.22, 2.6], ["y_offset", "Krümmung", -1.8, 1.8], ["length", "Körperlänge", 0.45, 3.0]]:
		var container := VBoxContainer.new()
		_inspector.add_child(container)
		_label(container, field[1], 13)
		var slider := HSlider.new()
		slider.min_value = field[2]
		slider.max_value = field[3]
		slider.step = 0.01
		slider.custom_minimum_size.y = 28
		slider.drag_started.connect(_begin_gesture)
		slider.drag_ended.connect(func(_changed: bool) -> void: _end_gesture())
		slider.value_changed.connect(_change_shape.bind(field[0]))
		container.add_child(slider)
		_sliders[field[0]] = slider
	_base_picker = _color_picker("Hautfarbe", "base_color")
	_accent_picker = _color_picker("Musterfarbe", "accent_color")
	var part_actions := HBoxContainer.new()
	part_actions.name = "PartActions"
	_inspector.add_child(part_actions)
	_button(part_actions, "Kopie", _duplicate_selected_part)
	_button(part_actions, "Entfernen", _delete_selected_part)
	var transforms := HBoxContainer.new()
	transforms.name = "PartTransforms"
	_inspector.add_child(transforms)
	_button(transforms, "−", _scale_down)
	_button(transforms, "+", _scale_up)
	_button(transforms, "↶", _rotate_negative)
	_button(transforms, "↷", _rotate_positive)
	_label(_inspector, "ANGEBAUTE TEILE", 12)
	_part_list = ItemList.new()
	_part_list.name = "AttachedParts"
	_part_list.custom_minimum_size = Vector2(0, 166)
	_part_list.item_selected.connect(_select_part_by_index)
	_inspector.add_child(_part_list)
	_button(_inspector, "Ansicht einpassen  ·  F", _frame_creature)


func _color_picker(label: String, field: String) -> ColorPickerButton:
	var column := VBoxContainer.new()
	_inspector.add_child(column)
	_label(column, label, 13)
	var picker := ColorPickerButton.new()
	picker.text = label
	picker.edit_alpha = false
	picker.custom_minimum_size.y = 42
	picker.popup_closed.connect(_end_gesture)
	picker.pressed.connect(_begin_gesture)
	picker.color_changed.connect(_change_color.bind(field))
	column.add_child(picker)
	return picker


func _build_footer() -> void:
	_bottom_panel = _panel("BottomBar", 0, 1, 1, 1, Vector4(16, -110, -16, -14))
	var column := VBoxContainer.new()
	_bottom_panel.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	_creature_name_edit = LineEdit.new()
	_creature_name_edit.custom_minimum_size.x = 226
	_creature_name_edit.placeholder_text = "Name deiner Kreatur"
	_creature_name_edit.text_changed.connect(_on_name_changed)
	_creature_name_edit.focus_entered.connect(_begin_gesture)
	_creature_name_edit.focus_exited.connect(_end_gesture)
	row.add_child(_creature_name_edit)
	_undo_button = _button(row, "↶", _undo_edit)
	_undo_button.tooltip_text = "Rückgängig · Strg+Z"
	_redo_button = _button(row, "↷", _redo_edit)
	_redo_button.tooltip_text = "Wiederholen · Strg+Y"
	_assembly_symmetry_button = _button(row, "Symmetrie", _toggle_builder_symmetry)
	_assembly_symmetry_button.toggle_mode = true
	_snap_button = _button(row, "Andocken", _toggle_surface_snap)
	_snap_button.toggle_mode = true
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_button(row, "Neu", _reset_blueprint)
	_button(row, "Laden", _load_blueprint)
	_button(row, "Speichern", _save_blueprint).name = "SaveCreature"
	_builder_status_label = _label(column, "", 13)
	_builder_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_builder_status_label.modulate = MINT


func _build_builder_v7_toolbar() -> void:
	# Keep the public scene marker used by editor integration checks. The
	# actual actions live in the footer, with no overlapping legacy toolbar.
	_builder_panel = PanelContainer.new()
	_builder_panel.name = "CreatureBuilderV7Toolbar"
	_builder_panel.visible = false
	_ui_root.add_child(_builder_panel)


func _reconfigure_legacy_buttons() -> void:
	pass


func _clear_control_children(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _set_mode(mode: String) -> void:
	_end_gesture()
	_studio_mode = mode
	selected_body_segment = -1
	selected_part_index = -1
	current_category = _last_mode_category if mode == "parts" else ("paint" if mode == "paint" else "body")
	for key: String in _mode_buttons:
		_mode_buttons[key].set_pressed_no_signal(key == mode)
	_refresh_all()


func _refresh_category_buttons() -> void:
	if _category_grid == null:
		return
	_clear_control_children(_category_grid)
	_category_grid.visible = _studio_mode == "parts"
	if _studio_mode != "parts":
		return
	for category in ["mouth", "eyes", "legs", "arms", "tail", "horns", "plates", "spikes", "decor"]:
		var button := _button(_category_grid, CATEGORY_NAMES[category], _on_category_button_pressed.bind(category))
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(78, 34)
		button.toggle_mode = true
		button.set_pressed_no_signal(category == current_category)


func _refresh_part_palette() -> void:
	if _part_grid == null:
		return
	_clear_control_children(_part_grid)
	_palette_title.text = {"body": "KÖRPER FORMEN", "parts": "TEILE ANBAUEN", "paint": "FARBE & MUSTER", "test": "LEBENDIG WERDEN"}.get(_studio_mode, "TEILE")
	_help_label.text = {"body": "Punkt ziehen: Körper formen.\nMausrad: Stelle dicker / dünner.\nStrg + Mausrad: Körperlänge.", "parts": "Teile auf den Körper ziehen.\nMausrad: Größe · Alt + Ziehen: drehen.\nRechts ziehen: Ansicht drehen.", "paint": "Wähle Hautfarbe, Akzent und ein Muster. Alle Änderungen siehst du sofort.", "test": "Teste deine Form in Bewegung.\nDie Vorschau verändert deinen Entwurf nicht."}.get(_studio_mode, "")
	_part_grid.columns = 1 if _studio_mode == "test" else 2
	if _studio_mode == "test":
		for entry in [["idle", "Stehen & Atmen"], ["walk", "Gehen"], ["run", "Laufen"]]:
			var button := _button(_part_grid, entry[1], _choose_motion.bind(entry[0]))
			button.toggle_mode = true
			button.set_pressed_no_signal(_motion_choice == entry[0])
		return
	for part: Dictionary in PartLibrary.get_parts_for_category(current_category):
		var card := PartCard.new()
		var progression := get_node_or_null("/root/ProgressionService")
		var available: bool = progression == null or bool(progression.call("is_part_unlocked", str(part["id"])))
		card.configure(part, current_category, available)
		card.name = "Card_" + str(part["id"])
		card.pressed.connect(_on_part_button_pressed.bind(str(part["id"])))
		_part_grid.add_child(card)
	if _studio_mode == "body":
		for entry in [["upright", "Aufrecht"], ["grazer", "Langhals"], ["crawler", "Kriecher"], ["round", "Kugelbauch"]]:
			_button(_part_grid, entry[1], _apply_body_preset.bind(entry[0])).tooltip_text = "Nur den Körper umformen. Deine Teile bleiben erhalten. Rückgängig mit Strg+Z."


func _refresh_preview() -> void:
	if not is_instance_valid(_preview):
		return
	AnatomyV7.rebind_all_parts(blueprint)
	_preview.call("set_editor_state", blueprint, selected_part_index, selected_body_segment, _studio_mode == "body")
	_preview.call("set_motion", _motion_choice if _studio_mode == "test" else "edit")
	_update_plinth()


func _refresh_stats_panel() -> void:
	if _stats_label == null:
		return
	_syncing_ui = true
	var stats: Dictionary = Blueprint.calculate_stats(blueprint)
	_complexity_bar.value = Blueprint.calculate_complexity(blueprint)
	_stats_label.text = "%d / %d Formpunkte\n\nTempo  %.1f     Kraft  %.1f\nSchutz  %.1f     Sinne  %.1f" % [int(_complexity_bar.value), Blueprint.COMPLEXITY_LIMIT, float(stats.get("speed", 0)), float(stats.get("attack", 0)), float(stats.get("defense", 0)), float(stats.get("perception", 0))]
	var segment: Dictionary = SpineProfile.get_segment(blueprint, selected_body_segment)
	for field: String in _sliders:
		var slider: HSlider = _sliders[field]
		slider.get_parent().visible = _studio_mode == "body"
		slider.editable = selected_body_segment >= 0 or field == "length"
		slider.value = SpineProfile.get_body_length_scale(blueprint) if field == "length" else float(segment.get(field, 1.0))
	_base_picker.get_parent().visible = _studio_mode == "paint"
	_accent_picker.get_parent().visible = _studio_mode == "paint"
	var palette: Array[Color] = Surface.colors(blueprint)
	_base_picker.color = palette[0]
	_accent_picker.color = palette[1]
	_selection_label.text = "Punkt %d / 7" % (selected_body_segment + 1) if selected_body_segment >= 0 else "Körperpunkt wählen"
	if _studio_mode != "body":
		_selection_label.text = "Teil auswählen" if _studio_mode == "parts" else ("Deine Farbpalette" if _studio_mode == "paint" else "Bewegungsvorschau")
	if selected_part_index >= 0:
		var part: Dictionary = Blueprint.get_part_placement(blueprint, selected_part_index)
		_selection_label.text = str(PartLibrary.get_part(str(part.get("part_id", ""))).get("name", "Teil")) + "\nGröße  %.2f" % float(part.get("scale", 1.0))
	_inspector.get_node("PartActions").visible = _studio_mode == "parts"
	_inspector.get_node("PartTransforms").visible = _studio_mode == "parts"
	_part_list.clear()
	for part: Dictionary in blueprint.get("parts", []):
		_part_list.add_item(("↔  " if bool(part.get("mirrored", false)) else "•  ") + str(PartLibrary.get_part(str(part.get("part_id", ""))).get("name", "Teil")))
	if selected_part_index >= 0 and selected_part_index < _part_list.item_count:
		_part_list.select(selected_part_index)
	_syncing_ui = false
	_update_builder_toolbar()
	if _stage_caption != null:
		_stage_caption.text = {"body": "Ziehen, strecken, formen.", "parts": "Was soll deine Kreatur können?", "paint": "Gib ihr einen eigenen Charakter.", "test": "Eine Form wird lebendig."}.get(_studio_mode, "")


func _update_builder_toolbar() -> void:
	if _undo_button == null:
		return
	_undo_button.disabled = not bool(_history.call("can_undo"))
	_redo_button.disabled = not bool(_history.call("can_redo"))
	_assembly_symmetry_button.set_pressed_no_signal(AssemblyV7.is_symmetry_enabled(blueprint))
	_snap_button.set_pressed_no_signal(AssemblyV7.is_snap_to_surface(blueprint))


func _on_category_button_pressed(category_id: String) -> void:
	_end_gesture()
	_last_mode_category = category_id
	current_category = category_id
	selected_body_segment = -1
	_refresh_all()


func _select_part_by_index(index: int) -> void:
	if _syncing_ui:
		return
	var placement: Dictionary = Blueprint.get_part_placement(blueprint, index)
	if placement.is_empty():
		return
	_set_mode("parts")
	selected_part_index = index
	current_category = str(placement.get("category", "eyes"))
	_last_mode_category = current_category
	_refresh_all()


func _choose_motion(mode: String) -> void:
	_motion_choice = mode
	_preview.call("set_motion", mode)
	_refresh_part_palette()


func _begin_gesture() -> void:
	_gesture = true
	_gesture_recorded = false


func _end_gesture() -> void:
	_gesture = false
	_gesture_recorded = false
	_drag_spine = -1
	_drag_part = false
	_orbiting = false
	_last_edit_label = ""
	_update_builder_toolbar()


func _record_before_edit(label: String, force_new_entry: bool = false) -> void:
	if _suppress_history or (_gesture and _gesture_recorded):
		return
	super._record_before_edit(label, force_new_entry or _gesture)
	if _gesture:
		_gesture_recorded = true


func _change_shape(value: float, field: String) -> void:
	if _syncing_ui or (selected_body_segment < 0 and field != "length"):
		return
	_record_before_edit("Körper formen")
	_prepare_surface_anchors()
	if field == "length":
		SpineProfile.set_body_length_scale(blueprint, value)
	else:
		var segment: Dictionary = SpineProfile.get_segment(blueprint, selected_body_segment)
		segment[field] = value
		SpineProfile.set_segment(blueprint, selected_body_segment, segment)
	_refresh_preview()
	_refresh_stats_panel()


func _change_color(color: Color, field: String) -> void:
	if _syncing_ui:
		return
	_record_before_edit("Farbe ändern")
	var appearance: Dictionary = blueprint.get("appearance", {})
	appearance[field] = color.to_html(false)
	blueprint["appearance"] = appearance
	_refresh_preview()


func _apply_body_preset(preset: String) -> void:
	_record_before_edit("Körperform " + preset, true)
	var widths: Array = [0.95, 0.80, 0.78, 1.1, 1.2, 0.9, 0.5]
	var heights: Array = [1.05, 0.95, 0.9, 1.1, 1.15, 0.9, 0.55]
	var curves: Array = [0.2, 0.1, 0.0, 0.0, 0.0, -0.05, -0.1]
	var length: float = 1.0
	match preset:
		"upright":
			widths = [0.95, 0.72, 0.58, 0.8, 1.1, 1.0, 0.5]
			heights = [1.0, 0.8, 0.65, 1.0, 1.25, 1.0, 0.6]
			curves = [1.0, 0.85, 0.6, 0.25, -0.05, -0.15, -0.2]
			length = 0.8
		"grazer":
			widths = [0.65, 0.4, 0.38, 0.65, 1.15, 1.05, 0.6]
			heights = [0.8, 0.55, 0.5, 0.8, 1.3, 1.15, 0.6]
			curves = [0.8, 0.6, 0.35, 0.1, 0.0, 0.0, -0.1]
			length = 1.5
		"crawler":
			widths = [0.8, 0.65, 0.95, 0.7, 0.9, 0.65, 0.3]
			heights = [0.65, 0.6, 0.7, 0.6, 0.7, 0.55, 0.25]
			curves = [0.0, 0.0, 0.04, 0.0, 0.03, 0.0, -0.05]
			length = 1.7
		"round":
			widths = [0.9, 1.25, 1.6, 1.8, 1.6, 1.2, 0.7]
			heights = [0.9, 1.25, 1.6, 1.8, 1.6, 1.2, 0.7]
			curves = [0.0, 0.0, 0.05, 0.1, 0.05, 0.0, 0.0]
			length = 0.8
	_prepare_surface_anchors()
	SpineProfile.reset_all(blueprint)
	for index in range(7):
		SpineProfile.set_segment(blueprint, index, {"width_scale": widths[index], "height_scale": heights[index], "y_offset": curves[index]})
	SpineProfile.set_body_length_scale(blueprint, length)
	AnatomyV7.rebind_all_parts(blueprint)
	_refresh_all()
	_frame_creature()
	_set_builder_status("Körperform angewendet · Deine Anbauteile bleiben erhalten · Strg+Z macht es rückgängig.")


func _input(event: InputEvent) -> void:
	# Releases must end a drag even when the mouse has crossed a panel. Canvas
	# presses are handled through GUI routing so buttons never leak into 3D.
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		_end_gesture()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_gesture()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	if _is_typing_text() or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F:
		_frame_creature()
	elif event.ctrl_pressed and event.keycode == KEY_S:
		_save_blueprint()
	elif event.ctrl_pressed and event.keycode == KEY_Z:
		_redo_edit() if event.shift_pressed else _undo_edit()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo_edit()
	elif event.ctrl_pressed and event.keycode == KEY_D:
		_duplicate_selected_part()
	elif event.keycode == KEY_DELETE:
		_delete_selected_part()
	else:
		return
	get_viewport().set_input_as_handled()


func handle_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var position: Vector2 = event.position + _canvas.global_position
		if not event.pressed:
			_end_gesture()
			return
		get_viewport().gui_release_focus()
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_begin_gesture()
			_orbiting = true
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _studio_mode == "body":
				var picked: int = _pick_spine_segment(position)
				if picked >= 0:
					selected_body_segment = picked
					selected_part_index = -1
					_refresh_preview()
					_refresh_stats_panel()
					_begin_gesture()
					_drag_spine = picked
					return
			if _studio_mode == "parts":
				var picked: int = _pick_part_at_screen_position(position)
				if picked >= 0:
					_select_part_by_index(picked)
					var hit: Dictionary = _surface_hit(position)
					_drag_side = signf(hit["position"].x) if not hit.is_empty() and absf(hit["position"].x) > 0.01 else 1.0
					_begin_gesture()
					_drag_part = true
					return
			_begin_gesture()
			_orbiting = true
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step: float = 0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.08
			if event.ctrl_pressed:
				_change_shape(SpineProfile.get_body_length_scale(blueprint) + step, "length")
			elif _studio_mode == "body" and selected_body_segment >= 0:
				_record_before_edit("Körperradius")
				_prepare_surface_anchors()
				SpineProfile.adjust_segment(blueprint, selected_body_segment, step, step if not event.shift_pressed else 0.0, 0.0)
				_refresh_preview()
				_refresh_stats_panel()
			elif _studio_mode == "parts" and selected_part_index >= 0:
				_scale_selected_part_from_mouse(step)
			else:
				_zoom_camera(-step * 4.0)
	elif event is InputEventMouseMotion:
		if _orbiting:
			_preview_pivot.rotation.y -= event.relative.x * 0.008
			_preview_pivot.rotation.x = clampf(_preview_pivot.rotation.x - event.relative.y * 0.005, -0.5, 0.5)
		elif _drag_spine >= 0:
			_drag_body_point(event)
		elif _drag_part and selected_part_index >= 0:
			if event.alt_pressed:
				_record_before_edit("Teil drehen")
				Blueprint.rotate_part(blueprint, selected_part_index, Vector3(-event.relative.y, event.relative.x, 0.0) * 0.6)
				_refresh_preview()
				_refresh_stats_panel()
			else:
				_move_part_to_cursor(event.position + _canvas.global_position)


func _drag_body_point(event: InputEventMouseMotion) -> void:
	_record_before_edit("Körperpunkt ziehen")
	_prepare_surface_anchors()
	var depth: float = _camera.global_position.distance_to(_preview.global_position)
	var pixel_scale: float = 2.0 * depth * tan(deg_to_rad(_camera.fov * 0.5)) / get_viewport().get_visible_rect().size.y
	var world_delta: Vector3 = (_camera.global_basis.x * event.relative.x - _camera.global_basis.y * event.relative.y) * pixel_scale
	var local_delta: Vector3 = _preview.global_basis.inverse() * world_delta
	var body_scale: float = Blueprint.get_body_scale(blueprint)
	var base_length: float = Blueprint.get_body_shape(blueprint).z * body_scale
	var full_length: float = base_length * SpineProfile.get_body_length_scale(blueprint)
	SpineProfile.move_knot(blueprint, _drag_spine, local_delta.z / maxf(full_length, 0.01), local_delta.y / body_scale)
	if _drag_spine == 0 or _drag_spine == 6:
		var direction: float = -1.0 if _drag_spine == 0 else 1.0
		SpineProfile.adjust_body_length(blueprint, local_delta.z * 2.0 * direction / base_length)
	_refresh_preview()
	_refresh_stats_panel()


func _surface_hit(screen_position: Vector2) -> Dictionary:
	var origin: Vector3 = _preview.to_local(_camera.project_ray_origin(screen_position))
	var direction: Vector3 = (_preview.global_basis.inverse() * _camera.project_ray_normal(screen_position)).normalized()
	var length: float = Blueprint.get_body_shape(blueprint).z * Blueprint.get_body_scale(blueprint) * SpineProfile.get_body_length_scale(blueprint)
	var skin: MeshInstance3D = _preview.get_node_or_null("BodyV4/SculptedSkin")
	if skin == null or not (skin.mesh is ArrayMesh):
		return {}
	var hit: Dictionary = Voxels.raycast(skin.mesh, origin, direction)
	if not hit.is_empty():
		hit["t"] = clampf(hit["position"].z / maxf(length, 0.01) + 0.5, 0.002, 0.998)
	return hit


func can_drop_part(part_id: String, screen_position: Vector2) -> bool:
	if _studio_mode != "parts" or _is_pointer_over_editor_panel(screen_position):
		return false
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null and not bool(progression.call("is_part_unlocked", part_id)):
		return false
	var definition: Dictionary = PartLibrary.get_part(part_id)
	if definition.is_empty() or not definition.has("voxels"):
		return false
	return not _surface_hit(screen_position).is_empty()


func drop_part(part_id: String, screen_position: Vector2) -> void:
	if not can_drop_part(part_id, screen_position):
		return
	var hit: Dictionary = _surface_hit(screen_position)
	var candidate: Dictionary = blueprint.duplicate(true)
	var index: int = Blueprint.add_part(candidate, part_id)
	if index < 0:
		_set_builder_status("Zu viele Formpunkte. Entferne zuerst ein Teil.")
		return
	_record_before_edit("Teil anbauen", true)
	blueprint = candidate
	selected_part_index = index
	SurfaceSocketsV7.apply_symmetry(blueprint, index, AssemblyV7.is_symmetry_enabled(blueprint))
	AnatomyV7.ensure_anchors(blueprint, true)
	_place_on_hit(index, hit)
	current_category = str(blueprint["parts"][index]["category"])
	_refresh_all()
	_set_builder_status("Teil angebaut · Mausrad: Größe · Alt + Ziehen: drehen · Strg+Z: rückgängig")


func _place_on_hit(index: int, hit: Dictionary) -> void:
	var part: Dictionary = blueprint["parts"][index]
	var point: Vector3 = hit["position"]
	var cross: Dictionary = Surface.section(blueprint, float(hit["t"]))
	var radius: Vector2 = cross["radius"]
	part["anchor_t"] = hit["t"]
	part["anchor_side"] = clampf(point.x / maxf(radius.x * 1.04, 0.01), -1.0, 1.0)
	part["anchor_vertical"] = clampf((point.y - cross["center"].y) / maxf(radius.y * 1.10, 0.01), -1.0, 1.0)
	part["anchor_surface_offset"] = Vector3.ZERO
	part["manual_offset"] = Vector3.ZERO
	part["anchor_locked"] = true
	part["socket_type"] = "surface"
	# Mirrored placements store one side, while the renderer constructs both.
	if bool(part.get("mirrored", false)):
		part["anchor_side"] = absf(float(part["anchor_side"]))
	AnatomyV7.rebind_part(blueprint, index)


func _move_part_to_cursor(position: Vector2) -> void:
	if _is_pointer_over_editor_panel(position):
		return
	if AssemblyV7.is_snap_to_surface(blueprint):
		var hit: Dictionary = _surface_hit(position)
		if hit.is_empty():
			return
		_record_before_edit("Teil verschieben")
		_place_on_hit(selected_part_index, hit)
	else:
		var part: Dictionary = blueprint["parts"][selected_part_index]
		var current: Vector3 = Blueprint._as_vector3(part.get("position", Vector3.ZERO))
		var normal: Vector3 = _camera.global_basis.z
		var origin: Vector3 = _camera.project_ray_origin(position)
		var direction: Vector3 = _camera.project_ray_normal(position)
		var denominator: float = normal.dot(direction)
		if absf(denominator) < 0.0001:
			return
		var distance: float = normal.dot(_preview.to_global(current) - origin) / denominator
		var desired: Vector3 = _preview.to_local(origin + direction * distance)
		if bool(part.get("mirrored", false)):
			desired.x = absf(desired.x)
		var anchor: Vector3 = AnatomyV7.get_anchor_position(blueprint, part)
		var shape: Vector3 = Blueprint.get_body_shape(blueprint) * Blueprint.get_body_scale(blueprint)
		shape.z *= SpineProfile.get_body_length_scale(blueprint)
		var limit: Vector3 = AttachmentNormalizerV7._get_maximum_offset(str(part.get("category", "")), shape)
		var offset: Vector3 = (desired - anchor).clamp(-limit, limit)
		offset = offset.limit_length(limit.length() * 0.70)
		_record_before_edit("Teil frei verschieben")
		part["position"] = anchor + offset
		AnatomyV7.capture_manual_offset(blueprint, selected_part_index)
	_refresh_preview()
	_refresh_stats_panel()


func _is_pointer_over_editor_panel(position: Vector2) -> bool:
	for panel: Control in [_left_panel, _right_panel, _bottom_panel, _header]:
		if panel != null and panel.is_visible_in_tree() and panel.get_global_rect().has_point(position):
			return true
	return false


func _on_name_changed(value: String) -> void:
	if str(blueprint.get("name", "")) == value:
		return
	_record_before_edit("Kreatur benennen")
	blueprint["name"] = value.strip_edges()


func _save_migrated_assembly_without_revision() -> void:
	pass # Opening the workshop does not overwrite the saved design.


func _save_blueprint() -> void:
	_last_save_ok = false
	blueprint["name"] = _creature_name_edit.text.strip_edges()
	if str(blueprint["name"]).is_empty():
		blueprint["name"] = "Neue Kreatur"
	var candidate: Dictionary = blueprint.duplicate(true)
	AssemblyV7.normalize(candidate)
	AnatomyV7.rebind_all_parts(candidate)
	var design_id: String = str(candidate.get("design_id", ""))
	# Undo restores geometry and appearance, but must never reuse a revision
	# already written for this design earlier in the same editing session.
	candidate["assembly"]["revision"] = maxi(AssemblyV7.get_revision(candidate), int(_saved_revisions.get(design_id, 0)))
	AssemblyV7.increment_revision(candidate)
	var result: Error = AssemblyV7.save_to_file(candidate)
	if result != OK:
		_set_builder_status("Speichern fehlgeschlagen. Dein Entwurf bleibt hier geöffnet.")
		return
	blueprint = candidate
	_saved_revisions[design_id] = AssemblyV7.get_revision(candidate)
	_last_save_ok = true
	_saved_fingerprint = _fingerprint()
	# The canonical V7 design is authoritative. Keep undo history after save.
	_refresh_stats_panel()
	_set_builder_status("Gespeichert · %s · Revision %d" % [str(blueprint.get("name", "Kreatur")), AssemblyV7.get_revision(blueprint)])


func _play_test_placeholder() -> void:
	_save_blueprint()
	if not _last_save_ok:
		return
	var result: Error = get_tree().change_scene_to_file(MAIN_SCENE_PATH)
	if result != OK:
		_set_builder_status("Die Welt konnte nicht geöffnet werden. Dein Entwurf ist gespeichert.")


func _fingerprint() -> String:
	var content: Dictionary = blueprint.duplicate(true)
	content.erase("assembly")
	return JSON.stringify(content).sha256_text()


func _frame_creature() -> void:
	if not is_instance_valid(_preview):
		return
	var shape: Vector3 = Blueprint.get_body_shape(blueprint) * Blueprint.get_body_scale(blueprint)
	shape.z *= SpineProfile.get_body_length_scale(blueprint)
	var radius: float = maxf(shape.z * 0.65, maxf(shape.x, shape.y) * 1.5)
	var available: float = maxf(0.25, (get_viewport().get_visible_rect().size.x - 660.0) / get_viewport().get_visible_rect().size.x)
	_camera.position = Vector3(0, 1.3, clampf(radius / tan(deg_to_rad(_camera.fov * 0.5)) / sqrt(available), 5.6, 18.0))
	_camera.look_at(Vector3(0, 0.05, 0))


func _prepare_surface_anchors() -> void:
	var assembly: Dictionary = blueprint.get("assembly", {})
	if int(assembly.get("sculpt_surface_bindings", 0)) == 1:
		return
	var length: float = Blueprint.get_body_shape(blueprint).z * Blueprint.get_body_scale(blueprint) * SpineProfile.get_body_length_scale(blueprint)
	for part: Dictionary in blueprint.get("parts", []):
		if str(part.get("category", "")) in ["mouth", "tail"]:
			continue
		var point: Vector3 = Blueprint._as_vector3(part.get("position", Vector3.ZERO))
		var t: float = clampf(point.z / maxf(length, 0.01) + 0.5, 0.035, 0.965)
		var cross: Dictionary = Surface.section(blueprint, t)
		var radius: Vector2 = cross["radius"]
		var direction := Vector2(point.x / radius.x, (point.y - cross["center"].y) / radius.y).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.UP
		var cap: float = sqrt(maxf(0.0001, 1.0 - pow(absf(t * 2.0 - 1.0), 18.0)))
		part["anchor_t"] = t
		part["anchor_side"] = direction.x * cap / 1.04
		part["anchor_vertical"] = direction.y * cap / 1.10
		part["anchor_surface_offset"] = Vector3.ZERO
		part["manual_offset"] = Vector3.ZERO
		part["anchor_locked"] = true
	assembly["sculpt_surface_bindings"] = 1
	blueprint["assembly"] = assembly
	AnatomyV7.rebind_all_parts(blueprint)


func _geometry_bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var result := AABB()
	var initialized: bool = false
	for child in node.get_children():
		if not (child is Node3D) or child is CollisionObject3D:
			continue
		var local: Transform3D = transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var bounds: AABB = local * child.mesh.get_aabb()
			result = result.merge(bounds) if initialized else bounds
			initialized = true
		else:
			var bounds: AABB = _geometry_bounds(child, local)
			if bounds.has_volume():
				result = result.merge(bounds) if initialized else bounds
				initialized = true
	return result


func _update_plinth() -> void:
	var plinth: Node3D = get_node_or_null("SculptingPlinth")
	var rim: Node3D = get_node_or_null("PlinthRim")
	if plinth == null or rim == null:
		return
	var bounds: AABB = _geometry_bounds(_preview)
	if bounds.has_volume():
		plinth.position.y = bounds.position.y - 0.025
		rim.position.y = bounds.position.y - 0.010


func _reset_blueprint() -> void:
	super._reset_blueprint()
	_set_mode("body")
	_frame_creature()
	_set_builder_status("Neue Kreatur · Deinen vorherigen Entwurf erhältst du mit Strg+Z zurück.")


func _load_blueprint() -> void:
	super._load_blueprint()
	var design_id: String = str(blueprint.get("design_id", ""))
	_saved_revisions[design_id] = maxi(AssemblyV7.get_revision(blueprint), int(_saved_revisions.get(design_id, 0)))
	_set_mode("body")
	_frame_creature()
	_set_builder_status("Gespeicherte Kreatur geladen · Strg+Z stellt deine vorherige Bearbeitung wieder her.")
