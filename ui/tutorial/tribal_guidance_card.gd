extends PanelContainer
## Context help embedded in the owner's scroll area. UI clicks only reveal text.
const Source = preload("res://ui/tutorial/tribal_context_source.gd")
const Advice = preload("res://ui/tutorial/tribal_context_guidance.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Style = preload("res://ui/progression_style.gd")
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
var controller: Node
var _source := Source.new()
var _reason: Label
var _title: Label
var _next: Label
var _detail: Label
var _toggle: Button
var view: Dictionary = {}
var _timer: float = 0.0

func _ready() -> void:
	name = "TribalContextHelp"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", Style.box(Design.PANEL, Style.SOCIAL, 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(box)
	_title = _label(box, "CurrentStep")
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Style.SOCIAL)
	_reason = _label(box, "Reason")
	_next = _label(box, "NextAction")
	_next.add_theme_color_override("font_color", Style.SOCIAL)
	_toggle = Style.button("")
	_toggle.custom_minimum_size.y = 30
	_toggle.name = "ExplainContext"
	Symbols.apply(_toggle, "book", 18)
	_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toggle.add_theme_font_size_override("font_size", 13)
	box.add_child(_toggle)
	_detail = _label(box, "Explanation")
	_detail.add_theme_color_override("font_color", Style.MUTED)
	_detail.hide()
	_toggle.pressed.connect(func() -> void: _detail.visible = not _detail.visible)
	refresh()

func _label(parent: Node, identity: String) -> Label:
	var label := Label.new()
	label.name = identity
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Style.TEXT)
	parent.add_child(label)
	return label

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		_timer = 0.2
		refresh()

func refresh() -> void:
	_source.bind(controller if is_instance_valid(controller) else null)
	var saves: Node = get_node_or_null("/root/SaveGameService")
	view = Advice.resolve(saves.guidance, _source.read()) if saves != null else {}
	visible = not view.is_empty()
	if not visible: return
	var copy: Dictionary = Advice.render(view)
	_title.text = copy.title
	_reason.text = copy.reason
	_next.text = copy.next
	_detail.text = copy.detail
	_toggle.text = Text.text("TG_EXPLAIN")

func _exit_tree() -> void:
	_source.bind(null)
