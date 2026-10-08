extends HBoxContainer
class_name BuildingTransformField
## Precise numeric entry with useful nudges, independent of display precision.
signal value_changed(value: float)
signal invalid_value
const Text = preload("res://civilization/buildings/building_editor_text.gd")
const UiText = preload("res://core/localization/ui_text.gd")
const Design = preload("res://ui/design/design_system.gd")
var value: float = 0.0
var nudge_step: float = 0.25
var min_value: float = 0.05
var max_value: float = 20.0
var limit_value: bool = false
var editable: bool = true:
	set(enabled):
		editable = enabled
		_line.editable = enabled
		_increase.disabled = not enabled
		_decrease.disabled = not enabled
var _line := LineEdit.new()
var _increase := Button.new()
var _decrease := Button.new()

func _init() -> void:
	add_theme_constant_override("separation", 2)
	_line.custom_minimum_size.x = 58.0
	# Three axis fields share one inspector row. Menu-sized input/button padding
	# would override their compact minima and force the inspector offscreen.
	_line.add_theme_constant_override("minimum_character_width", 3)
	_line.add_theme_stylebox_override("normal", Design.box(Design.INK, Design.CONTROL, 3))
	_line.add_theme_stylebox_override("read_only", Design.box(Design.DISABLED, Design.EDGE, 3))
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.text_submitted.connect(_submit)
	_line.focus_exited.connect(_commit)
	add_child(_line)
	var nudges := VBoxContainer.new()
	nudges.add_theme_constant_override("separation", 0)
	add_child(nudges)
	for button: Button in [_increase, _decrease]:
		button.custom_minimum_size = Vector2(22, 17)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", Design.box(Design.PANEL, Design.CONTROL, 2))
		button.add_theme_stylebox_override("hover", Design.box(Design.HOVER, Design.ACCENT, 2))
		button.add_theme_stylebox_override("pressed", Design.box(Design.PRESSED, Design.ACCENT, 2))
		button.add_theme_stylebox_override("disabled", Design.box(Design.DISABLED, Design.EDGE, 2))
		button.focus_mode = Control.FOCUS_NONE
		nudges.add_child(button)
	_increase.name = "Increase"
	_increase.text = "+"
	Text.bind(_increase, "tooltip_text", "BEDITOR_INCREASE")
	_increase.pressed.connect(_nudge.bind(1.0))
	_decrease.name = "Decrease"
	_decrease.text = "−"
	Text.bind(_decrease, "tooltip_text", "BEDITOR_DECREASE")
	_decrease.pressed.connect(_nudge.bind(-1.0))
	set_value_no_signal(0.0)

func get_line_edit() -> LineEdit:
	return _line

func set_value_no_signal(next: float) -> void:
	value = next
	_line.text = UiText.number(value, 6)

func _submit(_text: String) -> void:
	_commit()

func _commit() -> void:
	if not editable:
		return
	# Formatting a legacy float must not turn untouched input into a grid edit.
	if _line.text == UiText.number(value, 6):
		return
	var number := _line.text.strip_edges().replace(",", ".")
	if not number.is_valid_float() or not is_finite(number.to_float()):
		set_value_no_signal(value)
		invalid_value.emit()
		return
	_apply(number.to_float())

func _nudge(direction: float) -> void:
	if editable:
		_commit()
		_apply(value + direction * nudge_step)

func _apply(next: float) -> void:
	if limit_value:
		next = clampf(next, min_value, max_value)
	var changed := next != value
	set_value_no_signal(next)
	if changed:
		value_changed.emit(value)
