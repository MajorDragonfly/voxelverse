extends Button
## Exact workshop geometry; locked cards use the same outline as a flat silhouette.
## A cancelled palette drag never changes the creature.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
var definition: Dictionary = {}
var category: String = ""
var _portrait: SubViewportContainer


func configure(part: Dictionary, category_id: String, available: bool) -> void:
	definition = part
	category = category_id
	disabled = not available
	custom_minimum_size = Vector2(126.0, 126.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = str(part.get("description", "")) + ("\nZur Kreatur ziehen oder anklicken." if available else "\nDurch das Entdecken von Arten freischalten.")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN


func _draw() -> void:
	var tint := Color("d9eee7") if not disabled else Color("627c83")
	var font: Font = get_theme_default_font()
	var title: String = str(definition.get("name", "Teil"))
	if title.length() > 17:
		title = title.left(16) + "…"
	draw_string(font, Vector2(10, size.y - 28), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 14, tint)
	draw_string(font, Vector2(10, size.y - 10), "Gesperrt" if disabled else "%d Formpunkte" % int(definition.get("complexity", 0)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 11, tint.darkened(0.18))


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


func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or category in ["body", "paint"]:
		return null
	var card := get_script().new() as Control
	card.call("configure", definition, category, true)
	card.modulate.a = 0.85
	set_drag_preview(card)
	return {"creature_part": str(definition.get("id", ""))}
