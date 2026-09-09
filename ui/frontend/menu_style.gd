extends RefCounted

const INK := Color("081820")
const PANEL := Color("102831")
const TEXT := Color("edf1df")
const MUTED := Color("a5b9b7")
const ACCENT := Color("c6df91")
const EDGE := Color("31525a")

static func box(color: Color, border: Color = EDGE, padding: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 22
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, box(PANEL))
		result.set_stylebox("hover", type, box(Color("20444c"), ACCENT))
		result.set_stylebox("pressed", type, box(Color("345747"), ACCENT))
		result.set_stylebox("disabled", type, box(Color("122229"), Color("21393f")))
		var focus := box(Color(0, 0, 0, 0), ACCENT)
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type, focus)
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, TEXT)
		result.set_color("font_pressed_color", type, ACCENT)
		result.set_color("font_disabled_color", type, Color("657c7d"))
	result.set_stylebox("normal", "LineEdit", box(INK))
	result.set_stylebox("focus", "LineEdit", box(INK, ACCENT))
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "CheckButton", TEXT)
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_stylebox("panel", "PopupMenu", box(PANEL))
	result.set_stylebox("panel", "PanelContainer", box(PANEL))
	result.set_constant("separation", "VBoxContainer", 12)
	return result

static func label(parent: Node, text: String, size: int = 22, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	parent.add_child(node)
	return node

static func button(parent: Node, text: String, action: Callable, id: String = "", primary: bool = false) -> Button:
	var node := Button.new()
	if not id.is_empty():
		node.name = id
	node.text = text
	node.custom_minimum_size.y = 56
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if primary:
		node.add_theme_stylebox_override("normal", box(ACCENT, ACCENT))
		node.add_theme_color_override("font_color", INK)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

static func paragraph(parent: Node, text: String, size: int = 20) -> Label:
	var node := label(parent, text, size, MUTED)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
