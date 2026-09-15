extends Button
## Exact workshop geometry; locked cards use the same outline as a flat silhouette.
## A cancelled palette drag never changes the creature.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const EditorText = preload("res://creatures/editor/creature_editor_text.gd")
var definition: Dictionary = {}
var category: String = ""
var _portrait: SubViewportContainer
var _title: Label
var _cost: Label


func configure(part: Dictionary, category_id: String, available: bool) -> void:
	definition = part
	category = category_id
	disabled = not available
	custom_minimum_size = Vector2(126.0, 152.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	refresh_translation()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN


func refresh_translation() -> void:
	tooltip_text = EditorText.part(definition) + "\n" + EditorText.part(definition, "description") + "\n" + EditorText.text("EDITOR_CARD_UNLOCK" if disabled else "EDITOR_CARD_HINT")
	if _title != null:
		_title.text = EditorText.part(definition)
		_cost.text = EditorText.text("EDITOR_CARD_LOCKED") if disabled else EditorText.format_text("EDITOR_CARD_COST", {"count": int(definition.get("complexity", 0))})


func set_text_scale(value: float) -> void:
	custom_minimum_size = Vector2(126 * value, 80 + 82 * value)
	if _title != null:
		_title.add_theme_font_size_override("font_size", roundi(14 * value))
		_cost.add_theme_font_size_override("font_size", roundi(14 * value))


func _ready() -> void:
	_portrait = preload("res://ui/discovery/journal_preview.gd").new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)
	_portrait.custom_minimum_size = Vector2.ZERO
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_portrait.offset_left = 5
	_portrait.offset_right = -5
	_portrait.offset_top = 5
	_portrait.offset_bottom = 79
	_portrait.call("show_part", str(definition.get("id", "")), not disabled)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_right = -8
	column.offset_top = 82
	column.offset_bottom = -6
	add_child(column)
	_title = Label.new()
	_cost = Label.new()
	for label: Label in [_title, _cost]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 14)
		label.set_meta("editor_font_size", 14)
		label.modulate = Color("d9eee7") if not disabled else Color("a5b9b7")
		column.add_child(label)
	refresh_translation()


func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or category in ["body", "paint"]:
		return null
	var card := get_script().new() as Control
	card.call("configure", definition, category, true)
	card.modulate.a = 0.85
	set_drag_preview(card)
	return {"creature_part": str(definition.get("id", ""))}
