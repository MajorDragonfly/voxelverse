extends RefCounted
## Expedition: one visual language for campaign, progression and front end.
## Bone text on warm charcoal; brass marks an action, verdigris a friendly state.

const INK := Color("181e1b")
const PANEL := Color("252c26")
const TEXT := Color("eee7d7")
const MUTED := Color("a6b0a0")
const ACCENT := Color("cfad6c")
const EDGE := Color("505d4e")
const CONTROL := Color("84937d")
const SOCIAL := Color("75b29a")
const AGGRESSION := Color("ce986d")
const DANGER := Color("dc8578")
const HOVER := Color("343e33")
const PRESSED := Color("414936")
const DISABLED := Color("202720")
const DISABLED_TEXT := Color("778173")
const SPACING := 8
const PANEL_SPACING := 16
const TOUCH_HEIGHT := 46

static var _theme: Theme


static func box(color: Color = PANEL, border: Color = EDGE, padding: int = 16) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(3)
	result.content_margin_left = padding
	result.content_margin_right = padding
	result.content_margin_top = padding
	result.content_margin_bottom = padding
	return result


static func theme() -> Theme:
	if _theme != null:
		return _theme.duplicate(true) as Theme
	var result := Theme.new()
	result.default_font_size = 18
	for type in ["Label", "RichTextLabel", "Button", "OptionButton", "CheckBox", "CheckButton", "LineEdit", "TextEdit", "SpinBox", "PopupMenu", "Tree", "ItemList", "TabBar", "TabContainer"]:
		result.set_color("font_color", type, TEXT)
		result.set_color("font_disabled_color", type, DISABLED_TEXT)
	for type in ["Button", "OptionButton", "CheckBox", "CheckButton", "MenuButton"]:
		result.set_stylebox("normal", type, _control_box(PANEL, CONTROL))
		result.set_stylebox("hover", type, _control_box(HOVER, ACCENT))
		result.set_stylebox("pressed", type, _control_box(PRESSED, ACCENT))
		result.set_stylebox("hover_pressed", type, _control_box(PRESSED, ACCENT))
		result.set_stylebox("disabled", type, _control_box(DISABLED, EDGE))
		result.set_stylebox("focus", type, _focus())
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, TEXT)
		result.set_color("font_pressed_color", type, ACCENT)
		result.set_color("font_hover_pressed_color", type, ACCENT)
		result.set_color("font_focus_color", type, TEXT)
		result.set_color("font_disabled_color", type, DISABLED_TEXT)
		result.set_color("icon_normal_color", type, Color.WHITE)
		result.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.38))
		result.set_constant("h_separation", type, 12)
		result.set_constant("icon_max_width", type, 24)
	result.set_icon("arrow", "OptionButton", _glyph('<path d="M5 9 12 16 19 9"/>', ACCENT))
	for type in ["CheckBox", "CheckButton"]:
		result.set_icon("checked", type, _glyph('<rect x="3" y="3" width="18" height="18" rx="2"/><path d="m7 12 3 3 7-7"/>', ACCENT))
		result.set_icon("unchecked", type, _glyph('<rect x="3" y="3" width="18" height="18" rx="2"/>', CONTROL))
		result.set_icon("checked_disabled", type, _glyph('<rect x="3" y="3" width="18" height="18" rx="2"/><path d="m7 12 3 3 7-7"/>', DISABLED_TEXT))
		result.set_icon("unchecked_disabled", type, _glyph('<rect x="3" y="3" width="18" height="18" rx="2"/>', DISABLED_TEXT))
	result.set_icon("radio_checked", "CheckBox", _glyph('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4" fill="#%s"/>' % ACCENT.to_html(false), ACCENT))
	result.set_icon("radio_unchecked", "CheckBox", _glyph('<circle cx="12" cy="12" r="9"/>', CONTROL))
	result.set_icon("radio_checked_disabled", "CheckBox", _glyph('<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/>', DISABLED_TEXT))
	result.set_icon("radio_unchecked_disabled", "CheckBox", _glyph('<circle cx="12" cy="12" r="9"/>', DISABLED_TEXT))
	for suffix in ["", "_mirrored"]:
		var active_x := "8" if suffix == "_mirrored" else "16"
		var inactive_x := "16" if suffix == "_mirrored" else "8"
		result.set_icon("checked" + suffix, "CheckButton", _glyph('<rect x="1" y="5" width="22" height="14" rx="7"/><circle cx="%s" cy="12" r="4"/>' % active_x, SOCIAL))
		result.set_icon("unchecked" + suffix, "CheckButton", _glyph('<rect x="1" y="5" width="22" height="14" rx="7"/><circle cx="%s" cy="12" r="4"/>' % inactive_x, CONTROL))
		result.set_icon("checked_disabled" + suffix, "CheckButton", _glyph('<rect x="1" y="5" width="22" height="14" rx="7"/><circle cx="%s" cy="12" r="4"/>' % active_x, DISABLED_TEXT))
		result.set_icon("unchecked_disabled" + suffix, "CheckButton", _glyph('<rect x="1" y="5" width="22" height="14" rx="7"/><circle cx="%s" cy="12" r="4"/>' % inactive_x, DISABLED_TEXT))
	for type in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", type, _control_box(INK, CONTROL))
		result.set_stylebox("focus", type, _focus())
		result.set_stylebox("read_only", type, _control_box(DISABLED, EDGE))
		result.set_color("font_placeholder_color", type, MUTED)
		result.set_color("caret_color", type, ACCENT)
		result.set_color("selection_color", type, Color("526145"))
		result.set_color("font_selected_color", type, TEXT)
	for type in ["Panel", "PanelContainer", "PopupPanel", "AcceptDialog", "Window", "PopupMenu"]:
		result.set_stylebox("panel", type, box(PANEL))
	var window_frame := box(PANEL, ACCENT, 8)
	window_frame.content_margin_top = 32
	result.set_stylebox("embedded_border", "Window", window_frame)
	var unfocused_frame := window_frame.duplicate() as StyleBoxFlat
	unfocused_frame.border_color = EDGE
	result.set_stylebox("embedded_unfocused_border", "Window", unfocused_frame)
	result.set_color("title_color", "Window", TEXT)
	result.set_color("title_color", "AcceptDialog", TEXT)
	result.set_stylebox("hover", "PopupMenu", _control_box(HOVER, ACCENT))
	result.set_stylebox("separator", "PopupMenu", _rule())
	result.set_color("font_hover_color", "PopupMenu", TEXT)
	result.set_constant("v_separation", "PopupMenu", 12)
	for type in ["HSlider", "VSlider"]:
		var track := box(INK, EDGE, 0)
		track.set_corner_radius_all(2)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		track.content_margin_left = 3
		track.content_margin_right = 3
		result.set_stylebox("slider", type, track)
		result.set_stylebox("grabber_area", type, box(ACCENT, ACCENT, 3))
		result.set_stylebox("grabber_area_highlight", type, box(Color("dfc18a"), ACCENT, 3))
		result.set_icon("grabber", type, _glyph('<path d="M6 4h12v16H6z" fill="#%s"/>' % ACCENT.to_html(false), ACCENT))
		result.set_icon("grabber_highlight", type, _glyph('<path d="M6 4h12v16H6z" fill="#%s"/>' % TEXT.to_html(false), TEXT))
		result.set_constant("center_grabber", type, 1)
	result.set_stylebox("background", "ProgressBar", box(INK, EDGE, 0))
	result.set_stylebox("fill", "ProgressBar", box(SOCIAL, SOCIAL, 0))
	result.set_color("font_color", "ProgressBar", TEXT)
	result.set_color("font_outline_color", "ProgressBar", INK)
	result.set_constant("outline_size", "ProgressBar", 2)
	for type in ["HScrollBar", "VScrollBar"]:
		result.set_stylebox("scroll", type, box(INK, INK, 3))
		result.set_stylebox("grabber", type, box(EDGE, EDGE, 3))
		result.set_stylebox("grabber_highlight", type, box(CONTROL, CONTROL, 3))
		result.set_stylebox("grabber_pressed", type, box(ACCENT, ACCENT, 3))
	result.set_stylebox("panel", "Tree", box(INK, EDGE, 10))
	result.set_stylebox("selected", "Tree", box(HOVER, ACCENT, 4))
	result.set_stylebox("selected_focus", "Tree", box(HOVER, ACCENT, 4))
	result.set_stylebox("cursor", "Tree", _focus())
	result.set_stylebox("cursor_unfocused", "Tree", _focus())
	result.set_stylebox("title_button_normal", "Tree", _control_box(PANEL, EDGE))
	result.set_stylebox("title_button_hover", "Tree", _control_box(HOVER, ACCENT))
	result.set_color("font_selected_color", "Tree", TEXT)
	result.set_color("guide_color", "Tree", EDGE)
	result.set_constant("v_separation", "Tree", 8)
	result.set_constant("h_separation", "Tree", 10)
	result.set_stylebox("panel", "ItemList", box(INK, EDGE, 10))
	result.set_stylebox("selected", "ItemList", box(HOVER, ACCENT, 4))
	result.set_stylebox("selected_focus", "ItemList", box(HOVER, ACCENT, 4))
	result.set_stylebox("panel", "TabContainer", box(INK, EDGE, 12))
	for type in ["TabContainer", "TabBar"]:
		result.set_stylebox("tab_selected", type, _control_box(PANEL, ACCENT))
		result.set_stylebox("tab_unselected", type, _control_box(INK, EDGE))
		result.set_stylebox("tab_hovered", type, _control_box(HOVER, ACCENT))
		result.set_stylebox("tab_disabled", type, _control_box(DISABLED, EDGE))
		result.set_stylebox("tab_focus", type, _focus())
		result.set_color("font_selected_color", type, TEXT)
		result.set_color("font_unselected_color", type, MUTED)
		result.set_color("font_hovered_color", type, TEXT)
		result.set_constant("h_separation", type, 10)
		result.set_constant("icon_max_width", type, 24)
	result.set_stylebox("separator", "HSeparator", _rule())
	result.set_stylebox("separator", "VSeparator", _rule())
	result.set_constant("separation", "HSeparator", 12)
	result.set_constant("separation", "VSeparator", 12)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	result.set_constant("h_separation", "GridContainer", 12)
	result.set_constant("v_separation", "GridContainer", 12)
	result.set_stylebox("panel", "TooltipPanel", box(PANEL, ACCENT, 10))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_font_size("font_size", "TooltipLabel", 16)
	_theme = result
	return _theme.duplicate(true) as Theme


static func _control_box(color: Color, border: Color) -> StyleBoxFlat:
	var result := box(color, border, 14)
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result


static func _focus() -> StyleBoxFlat:
	var result := box(Color.TRANSPARENT, ACCENT, 0)
	result.set_border_width_all(2)
	result.expand_margin_left = 2
	result.expand_margin_right = 2
	result.expand_margin_top = 2
	result.expand_margin_bottom = 2
	return result


static func _rule() -> StyleBoxFlat:
	var result := box(EDGE, EDGE, 0)
	result.set_border_width_all(0)
	result.content_margin_top = 1
	result.content_margin_left = 1
	return result


static func _glyph(body: String, tone: Color) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#%s" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [tone.to_html(false), body]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		return null
	return ImageTexture.create_from_image(image)
