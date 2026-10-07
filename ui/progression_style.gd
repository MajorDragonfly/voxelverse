extends RefCounted

const Design := preload("res://ui/design/design_system.gd")
const MenuStyle := preload("res://ui/frontend/menu_style.gd")
const TEXT := Design.TEXT
const MUTED := Design.MUTED
const SOCIAL := Design.SOCIAL
const AGGRESSION := Design.AGGRESSION
const PANEL := Design.PANEL


static func box(color: Color = PANEL, border: Color = Design.EDGE, margin: int = 18) -> StyleBoxFlat:
	var style := MenuStyle.box(color, border, margin)
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
	result.theme = Design.theme()
	result.text = text
	result.custom_minimum_size.y = 46
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_hover_color", TEXT)
	result.add_theme_color_override("font_pressed_color", TEXT)
	result.add_theme_color_override("font_disabled_color", Design.DISABLED_TEXT)
	result.add_theme_stylebox_override("normal", box(PANEL, Design.CONTROL, 12))
	result.add_theme_stylebox_override("hover", box(Design.HOVER, color, 12))
	result.add_theme_stylebox_override("pressed", box(Design.PRESSED, color, 12))
	result.add_theme_stylebox_override("disabled", box(Design.DISABLED, Design.EDGE, 12))
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
