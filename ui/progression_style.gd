extends RefCounted

const TEXT := Color("e9eee9")
const MUTED := Color("a1b2b5")
const SOCIAL := Color("80cbb2")
const AGGRESSION := Color("e8ae7d")
const PANEL := Color("1c2b34")


static func box(color: Color = PANEL, border: Color = Color("354750"), margin: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func button(text: String, color: Color = SOCIAL) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 46
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_stylebox_override("normal", box(PANEL, Color("40535c"), 12))
	result.add_theme_stylebox_override("hover", box(Color("2b414b"), color, 12))
	result.add_theme_stylebox_override("pressed", box(Color("304b52"), color, 12))
	result.add_theme_stylebox_override("disabled", box(Color("18242c"), Color("304049"), 12))
	var focus := box(Color.TRANSPARENT, color, 0)
	focus.set_border_width_all(3)
	result.add_theme_stylebox_override("focus", focus)
	return result


static func column(parent: Node, spacing: int = 12) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("separation", spacing)
	parent.add_child(result)
	return result
