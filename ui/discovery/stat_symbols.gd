extends RefCounted
## Original, angular SVG pictograms. Labels remain visible beside every icon.

const ICONS := {
	"attack": preload("res://ui/discovery/icons/attack.svg"),
	"defense": preload("res://ui/discovery/icons/defense.svg"),
	"health": preload("res://ui/discovery/icons/health.svg"),
	"speed": preload("res://ui/discovery/icons/speed.svg"),
	"jump": preload("res://ui/discovery/icons/jump.svg"),
	"swim": preload("res://ui/discovery/icons/swim.svg"),
	"perception": preload("res://ui/discovery/icons/perception.svg"),
	"grip": preload("res://ui/discovery/icons/grip.svg"),
	"diet_plant": preload("res://ui/discovery/icons/diet_plant.svg"),
	"diet_meat": preload("res://ui/discovery/icons/diet_meat.svg"),
	"flight": preload("res://ui/discovery/icons/flight.svg"),
	"hunger_drain": preload("res://ui/discovery/icons/hunger_drain.svg"),
}


static func label_for(metric: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row
