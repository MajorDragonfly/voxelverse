extends RefCounted
## Stat labels and the HUD use the same pictogram family as the discovery book.
## The 32px texture contract is retained for existing comparison consumers.

const Design = preload("res://ui/design/design_system.gd")
const Family = preload("res://ui/design/game_symbols.gd")
const IDS := ["thirst", "attack", "defense", "health", "speed", "jump", "swim",
	"perception", "grip", "diet_plant", "diet_meat", "flight", "hunger_drain"]
static var ICONS: Dictionary = _build_icons()


static func _build_icons() -> Dictionary:
	var result: Dictionary = {}
	for id: String in IDS:
		var source: Texture2D = Family.texture(id, Design.TEXT, 64)
		if source == null:
			continue
		var picture: Image = source.get_image()
		picture.resize(32, 32, Image.INTERPOLATE_LANCZOS)
		result[id] = ImageTexture.create_from_image(picture)
	return result


static func label_for(metric: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.tooltip_text = str(metric.get("hint", metric["label"]))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := TextureRect.new()
	icon.name = "Symbol_" + str(metric["id"])
	icon.texture = ICONS.get(metric["id"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.text = metric["label"]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Design.TEXT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row
