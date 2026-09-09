extends CanvasLayer

const Text = preload("res://core/localization/ui_text.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Keys = preload("res://core/input_preferences.gd")
const Progress = preload("res://core/onboarding_progress.gd")
const TITLES: Dictionary = {"look": "Schau dich um", "move": "Erkunde deine Umgebung",
	"jump": "Mach einen Sprung", "inspect": "Scanne eine Kreatur"}
var _saves: Node
var _flow: Node
var _player: Node
var _panel: PanelContainer
var _heading: Label
var _title: Label
var _hint: Label
var _bar: ProgressBar
var _completion_timer: float = 0.0

func _ready() -> void:
	name = "FirstSteps"
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saves = get_node("/root/SaveGameService")
	_flow = get_parent()
	_saves.game_loaded.connect(func(_path: String): _completion_timer = 0.0)
	_panel = PanelContainer.new()
	_panel.name = "FirstStepsCard"
	_panel.theme = Style.theme()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 24
	_panel.offset_right = 474
	_panel.offset_top = -244
	_panel.offset_bottom = -24
	_panel.add_theme_stylebox_override("panel", Style.box(Color(0.03, 0.09, 0.12, 0.94)))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_heading = Style.label(box, "ERSTE SCHRITTE", 16, Style.ACCENT)
	_title = Style.label(box, "", 24)
	_hint = Style.paragraph(box, "", 18)
	_hint.custom_minimum_size.y = 62
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 5
	_bar.show_percentage = false
	box.add_child(_bar)
	Style.paragraph(box, "Esc → Erste Schritte: Hilfe oder überspringen", 15)
	_ignore_mouse(_panel)
	hide()

func _process(delta: float) -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != _player:
		_bind_player(player)
	if not _in_game():
		hide()
		return
	_completion_timer = maxf(0.0, _completion_timer - delta)
	var progress = _saves.guidance
	var step: String = progress.current_step()
	visible = not step.is_empty() or _completion_timer > 0.0
	if not visible:
		return
	_heading.text = Text.text("ERSTE SCHRITTE · %d / 4") % progress.completed_count()
	_title.text = TITLES[step] if not step.is_empty() else "Bereit für dein Abenteuer"
	_hint.text = hint(step) if not step.is_empty() else "Die Grundlagen sitzen. Erkunde deine Welt in deinem Tempo. Die Hilfe bleibt im Pausemenü erreichbar."
	_bar.value = 100.0 * progress.amount(step) / float(Progress.GOALS[step]) if not step.is_empty() else 100.0

func _bind_player(player: Node) -> void:
	if is_instance_valid(_player) and _player.has_signal("guidance_action") and _player.guidance_action.is_connected(_record_action):
		_player.guidance_action.disconnect(_record_action)
	_player = player
	_completion_timer = 0.0
	if is_instance_valid(player) and player.has_signal("guidance_action"):
		player.guidance_action.connect(_record_action)

func _in_game() -> bool:
	return _flow.can_pause() and _saves.session_active and not get_tree().paused and is_instance_valid(_player) and not bool(_player.get("is_dead")) and int(get_node("/root/GameState").current_phase) == 0

func _record_action(action: String, value: float) -> void:
	if not _in_game():
		return
	var before: int = _saves.guidance.completed_count()
	if not _saves.guidance.record(action, value):
		return
	if _saves.guidance.completed_count() > before:
		_saves.schedule_autosave(2.0)
		if _saves.guidance.completed_count() == 4:
			_completion_timer = 5.0

func hint(step: String) -> String:
	match step:
		"look":
			return "Bewege die Maus und schau dich in deiner Welt um."
		"move":
			return Text.text("%s / %s / %s / %s · Lege ein paar Meter zurück.") % [Keys.binding_label("move_forward"), Keys.binding_label("move_left"), Keys.binding_label("move_back"), Keys.binding_label("move_right")]
		"jump":
			return Text.text("%s · Springe vom Boden ab. Im Wasser steigst du mit derselben Taste auf; für diese Aufgabe suche festen Boden.") % Keys.binding_label("jump")
		"inspect":
			if is_instance_valid(_player) and bool(_player.get("inspection_mode_enabled")):
				return "Halte eine Kreatur im Fadenkreuz, bis der Kreis voll ist. Bekannte Arten erkennst du sofort."
			return Text.text("%s · Öffne den Scanmodus. Halte eine Kreatur 2,5 Sekunden im Fadenkreuz; danach findest du sie mit J im Entdeckungsbuch.") % Keys.binding_label("inspection_mode")
	return ""

func build_help(parent: VBoxContainer) -> void:
	Style.label(parent, "ERSTE SCHRITTE", 32, Style.ACCENT)
	Style.paragraph(parent, "Die Grundlagen werden beim Spielen erkannt. Du kannst sie in beliebiger Reihenfolge ausprobieren.", 19)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for step in Progress.STEPS:
		Style.label(list, ("✓ " if _saves.guidance.done(step) else "○ ") + Text.text(TITLES[step]), 22)
		Style.paragraph(list, hint(step), 18)
	var supported: bool = _saves.guidance.supported()
	var message: String = Text.text("%d / 4 erledigt. Der Fortschritt gehört zu diesem Abenteuer.") % _saves.guidance.completed_count()
	if not supported:
		message = "Diese Einführung wurde mit einer neueren Spielversion gespeichert. Die Hilfe kannst du weiterhin nachlesen."
	elif bool(_saves.guidance.data.skipped):
		message += Text.text(" Die Einführung ist ausgeschaltet.")
	Style.paragraph(parent, message, 18)
	var restart_button := Style.button(parent, "Einführung neu starten" if _saves.guidance.completed_count() > 0 else "Einführung starten", restart, "RestartFirstSteps")
	restart_button.disabled = not supported or int(get_node("/root/GameState").current_phase) != 0
	var skip_button := Style.button(parent, "Einführung überspringen", skip, "SkipFirstSteps")
	skip_button.disabled = not supported or _saves.guidance.current_step().is_empty()

func restart() -> void:
	if not _saves.guidance.supported():
		return
	_saves.guidance.reset(true)
	_completion_timer = 0.0
	_saves.schedule_autosave(0.2)
	_flow.resume()

func skip() -> void:
	_saves.guidance.skip()
	_completion_timer = 0.0
	_saves.schedule_autosave(0.2)
	_flow.resume()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
