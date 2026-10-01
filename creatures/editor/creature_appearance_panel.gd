extends VBoxContainer
## Presents existing cosmetic fields. submit_edit(command, first_in_gesture)
## returns true only after the host accepted, recorded and refreshed its draft.
const Edits = preload("res://creatures/editor/creature_appearance_edits.gd")
const SkinStyle = preload("res://creatures/editor/creature_skin_style.gd")
const Text = preload("res://creatures/editor/creature_editor_text.gd")
const Numbers = preload("res://core/localization/ui_text.gd")
const LABELS: Array[String] = ["APPEARANCE_COLOR_BASE", "APPEARANCE_COLOR_ACCENT", "APPEARANCE_COLOR_BELLY", "APPEARANCE_COLOR_EYE", "APPEARANCE_COLOR_HORN"]
var submit_edit: Callable
var pickers: Dictionary = {}
var hex_fields: Dictionary = {}
var ranges: Dictionary = {}
var values: Dictionary = {}
var palette: OptionButton
var palette_colors: Array[ColorRect] = []
var palette_status: Label
var skin_choice: OptionButton
var target: OptionButton
var color_status: Label
var hint: Label
var apply_button: Button
var reset_button: Button
var _state: Dictionary = {}
var _syncing: bool = false
var _in_gesture: bool = false
var _gesture_changed: bool = false
var _editable: bool = false
var _invalid_color_field: String = ""

func _ready() -> void:
	name = "CreatureAppearancePanel"
	add_theme_constant_override("separation", 8)
	_label("APPEARANCE_TITLE", 18)
	_label("APPEARANCE_COSMETIC", 12)
	reset_button = _button("APPEARANCE_RESET", func() -> void: _send({"reset": true}))
	reset_button.name = "ResetAppearance"
	palette_status = _label("", 12)
	palette = OptionButton.new()
	palette.name = "AppearancePalette"
	for index: int in SkinStyle.PALETTES.size(): Text.add_option(palette, "EDITOR_COLOR_PALETTE_" + str(index))
	palette.item_selected.connect(func(_index: int) -> void: _refresh_palette())
	add_child(palette)
	var palette_row := HBoxContainer.new()
	add_child(palette_row)
	for index: int in Edits.COLORS.size():
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 20)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.mouse_filter = Control.MOUSE_FILTER_PASS
		palette_row.add_child(swatch)
		palette_colors.append(swatch)
	apply_button = _button("APPEARANCE_APPLY_PALETTE", _apply_palette)
	apply_button.name = "ApplyAppearancePalette"
	for index: int in Edits.COLORS.size():
		var field: String = Edits.COLORS[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var label: Label = _label(LABELS[index], 12, row)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picker := ColorPickerButton.new()
		picker.name = "AppearanceColor_" + field
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(40, 34)
		Text.bind(picker, "tooltip_text", LABELS[index])
		picker.pressed.connect(func() -> void: _begin(); target.select(index))
		picker.popup_closed.connect(_end)
		picker.color_changed.connect(func(color: Color) -> void: _send({field: color.to_html(false)}))
		row.add_child(picker)
		pickers[field] = picker
		var hex := LineEdit.new()
		hex.name = "AppearanceHex_" + field
		hex.custom_minimum_size.x = 88
		hex.max_length = 7
		Text.bind(hex, "tooltip_text", "APPEARANCE_HEX_HINT")
		hex.text_submitted.connect(func(value: String) -> void: _submit_hex(value, field))
		row.add_child(hex)
		hex_fields[field] = hex
	color_status = _label("APPEARANCE_HEX_INVALID", 12)
	color_status.visible = false
	color_status.modulate = Color("ffbdab")
	_label("APPEARANCE_SWATCH_TARGET", 12)
	target = OptionButton.new()
	target.name = "AppearanceSwatchTarget"
	for key: String in LABELS: Text.add_option(target, key)
	add_child(target)
	var swatches := GridContainer.new()
	swatches.columns = 6
	add_child(swatches)
	for hex: String in SkinStyle.SWATCHES:
		var button := Button.new()
		button.name = "AppearanceSwatch_" + hex
		button.custom_minimum_size = Vector2(28, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "#" + hex.to_upper()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(hex)
		style.set_border_width_all(1)
		style.border_color = Color(hex).lightened(0.3)
		button.add_theme_stylebox_override("normal", style)
		var hover: StyleBoxFlat = style.duplicate()
		hover.set_border_width_all(2)
		hover.border_color = Color.WHITE
		button.add_theme_stylebox_override("hover", hover)
		button.pressed.connect(func() -> void: _send({Edits.COLORS[target.selected]: hex}))
		swatches.add_child(button)
	_label("EDITOR_SKIN_TYPE", 13)
	skin_choice = OptionButton.new()
	skin_choice.name = "AppearanceSkinType"
	for kind: String in SkinStyle.TYPES: Text.add_option(skin_choice, "EDITOR_SKIN_" + kind.to_upper())
	skin_choice.item_selected.connect(func(index: int) -> void: _send({"skin_type": SkinStyle.TYPES.keys()[index]}))
	add_child(skin_choice)
	_range("skin_strength", "APPEARANCE_STRENGTH", 0.0, 100.0, 5.0)
	_range("pattern_size", "APPEARANCE_PATTERN_SIZE", 0.4, 2.5, 0.05)
	_range("pattern_strength", "EDITOR_PATTERN_STRENGTH", 0.0, 100.0, 5.0)
	hint = _label("APPEARANCE_SIZE_HINT", 12)
	_refresh_palette()

func _label(key: String, font_size: int, parent: Node = null) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	(self if parent == null else parent).add_child(label)
	Text.bind(label, "text", key)
	return label

func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = 32
	Text.bind(button, "text", key)
	button.pressed.connect(action)
	add_child(button)
	return button

func _range(field: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var label: Label = _label(key, 12, row)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Label.new()
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	# Keep numeric units clear of the host scroll bar in compact layouts.
	var padding := Control.new()
	padding.custom_minimum_size.x = 8
	row.add_child(padding)
	values[field] = value
	var slider := HSlider.new()
	slider.name = "Appearance_" + field
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.y = 26
	slider.drag_started.connect(_begin)
	slider.drag_ended.connect(func(_changed: bool) -> void: _end())
	slider.value_changed.connect(func(amount: float) -> void:
		_send({"skin_scale": 1.0 / amount} if field == "pattern_size" else {field: amount / 100.0}))
	add_child(slider)
	ranges[field] = slider

func sync(blueprint: Dictionary) -> void:
	if not is_node_ready(): return
	_syncing = true
	_editable = Edits.can_edit(blueprint)
	_state = Edits.read(blueprint)
	for key: String in Edits.COLORS:
		pickers[key].color = Color(_state[key])
		hex_fields[key].editable = _editable
		# Preserve an unfinished numeric/color draft during language changes.
		if not hex_fields[key].has_focus():
			hex_fields[key].text = "#" + str(_state[key]).to_upper()
			if _invalid_color_field == key:
				color_status.visible = false
				_invalid_color_field = ""
		pickers[key].disabled = not _editable
	skin_choice.disabled = not _editable
	skin_choice.select(SkinStyle.TYPES.keys().find(_state.skin_type))
	ranges.pattern_strength.editable = _editable
	ranges.pattern_strength.set_value_no_signal(float(_state.pattern_strength) * 100.0)
	ranges.skin_strength.set_value_no_signal(float(_state.skin_strength) * 100.0)
	ranges.pattern_size.set_value_no_signal(1.0 / float(_state.skin_scale))
	var textured: bool = _state.skin_type != "smooth"
	ranges.skin_strength.editable = _editable and textured
	ranges.pattern_size.editable = _editable and textured
	reset_button.disabled = not _editable
	apply_button.disabled = not _editable
	_syncing = false
	refresh_translation()

func refresh_translation() -> void:
	if _state.is_empty(): return
	var current: int = Edits.palette_index(_state)
	Text.bind(palette_status, "text", "APPEARANCE_CUSTOM" if current < 0 else Text.formatted("APPEARANCE_CURRENT_PALETTE", [{"key": "EDITOR_COLOR_PALETTE_" + str(current)}]))
	values.pattern_strength.text = "%d %%" % roundi(float(_state.pattern_strength) * 100.0)
	values.skin_strength.text = "%d %%" % roundi(float(_state.skin_strength) * 100.0)
	values.pattern_size.text = Numbers.number(1.0 / float(_state.skin_scale), 2) + " ×"
	Text.bind(hint, "text", "APPEARANCE_SMOOTH_HINT" if _state.skin_type == "smooth" else "APPEARANCE_SIZE_HINT")
	_refresh_palette()

func _refresh_palette() -> void:
	if palette == null: return
	for index: int in Edits.COLORS.size():
		var hex: String = SkinStyle.PALETTES[palette.selected][Edits.COLORS[index]]
		palette_colors[index].color = Color(hex)
		palette_colors[index].tooltip_text = Text.text(LABELS[index]) + " · #" + hex.to_upper()

func _apply_palette() -> void:
	var command: Dictionary = SkinStyle.PALETTES[palette.selected].duplicate()
	command.erase("name")
	_send(command)

func _submit_hex(value: String, field: String) -> void:
	var hex: String = value.strip_edges().trim_prefix("#")
	if hex.length() != 6 or not hex.is_valid_hex_number(false):
		hex_fields[field].tooltip_text = Text.text("APPEARANCE_HEX_INVALID")
		color_status.visible = true
		_invalid_color_field = field
		return
	color_status.visible = false
	_send({field: hex})
	hex_fields[field].text = "#" + str(_state[field]).to_upper()
	Text.bind(hex_fields[field], "tooltip_text", "APPEARANCE_HEX_HINT")

func _begin() -> void:
	_in_gesture = true
	_gesture_changed = false

func _end() -> void:
	_in_gesture = false
	_gesture_changed = false

func _send(command: Dictionary) -> void:
	if _syncing or not _editable or not submit_edit.is_valid(): return
	var accepted: bool = bool(submit_edit.call(command, not _in_gesture or not _gesture_changed))
	if accepted:
		color_status.visible = false
		_invalid_color_field = ""
		if _in_gesture: _gesture_changed = true
