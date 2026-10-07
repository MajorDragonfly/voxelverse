extends RefCounted

const Design := preload("res://ui/design/design_system.gd")
const Symbols := preload("res://ui/design/game_symbols.gd")
const INK := Design.INK
const PANEL := Design.PANEL
const TEXT := Design.TEXT
const MUTED := Design.MUTED
const ACCENT := Design.ACCENT
const EDGE := Design.EDGE
const CONTROL := Design.CONTROL

const BUTTON_SYMBOLS := {
	"Continue": "play", "NewGame": "new_game", "TribalPlaytest": "tribe",
	"FleetTrial": "fleet", "Saves": "save", "Settings": "settings", "Controls": "controls",
	"Quit": "quit", "Begin": "play", "Back": "back", "ChooseStartingCreature": "creature",
	"BeginTribalPlaytest": "tribe", "CancelTribalPlaytest": "back",
	"ResumeGame": "play", "PauseSettings": "settings", "SaveGame": "save",
	"TravelDestinations": "route", "ReturnToTitle": "house", "QuitGame": "quit",
	"BackToPause": "back", "RestartFirstSteps": "history", "SkipFirstSteps": "right",
}


static func box(color: Color, border: Color = EDGE, padding: int = 20) -> StyleBoxFlat:
	var style := Design.box(_surface(color), _edge(border), padding)
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func theme() -> Theme:
	var result := Design.theme()
	result.default_font_size = 22
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
	var symbol: String = str(BUTTON_SYMBOLS.get(id, ""))
	if not symbol.is_empty():
		Symbols.apply(node, symbol, 24)
	if primary:
		node.add_theme_stylebox_override("normal", box(ACCENT, ACCENT))
		node.add_theme_stylebox_override("hover", box(Color("dfc18a"), ACCENT))
		node.add_theme_stylebox_override("pressed", box(Color("ba995b"), ACCENT))
		node.add_theme_color_override("font_color", INK)
		node.add_theme_color_override("font_focus_color", INK)
		node.add_theme_color_override("font_hover_color", INK)
		node.add_theme_color_override("font_pressed_color", INK)
		if not symbol.is_empty():
			node.icon = Symbols.texture(symbol, INK, 48)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


static func paragraph(parent: Node, text: String, size: int = 20) -> Label:
	var node := label(parent, text, size, MUTED)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


static func _surface(color: Color) -> Color:
	# Exact legacy surface colors only; semantic fills and transparency survive.
	if color in [Color("081820"), Color("122229"), Color("162630"), Color("101e28")]:
		return INK
	if color in [Color("102831"), Color("1c2b34"), Color("15272e"), Color("223740"), Color("213743")]:
		return PANEL
	if color in [Color("20444c"), Color("2b4149"), Color("2b414b")]:
		return Design.HOVER
	if color in [Color("345747"), Color("304b52")]:
		return Design.PRESSED
	return color


static func _edge(color: Color) -> Color:
	if color in [Color("31525a"), Color("354750"), Color("21393f"), Color("365363"), Color("436070"), Color("40535c"), Color("304049")]:
		return EDGE
	if color == Color("52706c"):
		return CONTROL
	return color
