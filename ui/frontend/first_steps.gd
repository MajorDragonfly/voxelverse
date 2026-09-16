extends CanvasLayer

const Layout = preload("res://ui/hud_layout.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Progress = preload("res://core/onboarding_progress.gd")
const Copy = preload("res://ui/frontend/guidance_text.gd")
const Development = preload("res://core/progression/development_path.gd")
const TribeText = preload("res://ui/tribe/tribe_presentation.gd")
var _saves: Node
var _flow: Node
var _player: Node
var _home: Node
var _panel: PanelContainer
var _heading: Label
var _title: Label
var _hint: Label
var _footer: Label
var _bar: ProgressBar
var _observe_timer: float = 0.0
var _help_parent: VBoxContainer
var _help_scroll: ScrollContainer

func _ready() -> void:
	name = "FirstSteps"
	layer = 65
	process_mode = Node.PROCESS_MODE_ALWAYS
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_saves = get_node("/root/SaveGameService")
	_flow = get_parent()
	_saves.game_loaded.connect(func(_path: String):
		_observe_timer = 0.0)
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	_panel = PanelContainer.new()
	_panel.name = "FirstStepsCard"
	_panel.theme = Style.theme()
	_panel.add_theme_stylebox_override("panel", Style.box(Color(0.03, 0.09, 0.12, 0.94), Style.EDGE, 14))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_heading = Style.paragraph(box, "", 12)
	_heading.add_theme_color_override("font_color", Style.ACCENT)
	_title = Style.paragraph(box, "", 18)
	_title.add_theme_color_override("font_color", Style.TEXT)
	_hint = Style.paragraph(box, "", 14)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 5
	_bar.show_percentage = false
	box.add_child(_bar)
	_footer = Style.paragraph(box, "", 12)
	_ignore_mouse(_panel)
	hide()

func _process(delta: float) -> void:
	_layout_help()
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != _player:
		_bind_player(player)
	var home: Node = get_tree().get_first_node_in_group(&"home_group_controller")
	if home != _home:
		_bind_home(home)
	if not _live_session() or get_tree().paused:
		hide()
		return
	_observe_timer -= delta
	if _observe_timer <= 0.0:
		_observe_timer = 0.5
		_observe_world()
	var progress = _saves.guidance
	var step: String = progress.current_step()
	var phase: int = int(get_node("/root/GameState").current_phase)
	visible = phase == 0 and not step.is_empty() and not bool(_player.get("inspection_mode_enabled"))
	if not visible:
		return
	var chapter_id: String = progress.chapter_for(step)
	_heading.text = Text.format_text("GUIDE_CARD_COUNT", {"chapter": Copy.chapter(chapter_id), "done": progress.chapter_completed(chapter_id), "total": Progress.CHAPTER_STEPS[chapter_id].size()})
	_title.text = Copy.title(step)
	_hint.text = hint(step)
	_bar.value = 100.0 * progress.amount(step) / float(Progress.GOALS[step])
	_footer.text = Text.text("GUIDE_FOOTER")
	var scaling := clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	_heading.add_theme_font_size_override("font_size", roundi(12 * scaling))
	_title.add_theme_font_size_override("font_size", roundi(18 * scaling))
	_hint.add_theme_font_size_override("font_size", roundi(14 * scaling))
	_footer.add_theme_font_size_override("font_size", roundi(12 * scaling))
	var screen := Layout.screen_size(self)
	var width := minf(350.0, screen.x * 0.44) if scaling > 1.0 else (292.0 if screen.x >= 1000 else 248.0)
	Layout.place(_panel, Rect2(Vector2(16, 0), Vector2(width, 0)))
	Layout.place(_panel, Rect2(Vector2(16, screen.y - 108 - _panel.size.y), _panel.size))

func _bind_player(player: Node) -> void:
	if is_instance_valid(_player) and _player.has_signal("guidance_action") and _player.guidance_action.is_connected(_record_action):
		_player.guidance_action.disconnect(_record_action)
	_player = player
	_observe_timer = 0.0
	if is_instance_valid(player) and player.has_signal("guidance_action"):
		player.guidance_action.connect(_record_action)

func _bind_home(home: Node) -> void:
	if is_instance_valid(_home) and _home.order_committed.is_connected(_record_order):
		_home.order_committed.disconnect(_record_order)
	_home = home
	if is_instance_valid(_home):
		_home.order_committed.connect(_record_order)

func _live_session() -> bool:
	return _flow.can_pause() and _saves.session_active and is_instance_valid(_player) and _player.has_signal("guidance_action") and not bool(_player.get("is_dead"))

func _record_action(action: String, value: float) -> void:
	if _live_session() and not get_tree().paused and int(get_node("/root/GameState").current_phase) == 0:
		_record(action, value)

func _record(action: String, value: float = 1.0) -> void:
	var before: int = _saves.guidance.completed_count()
	if _saves.guidance.record(action, value) and _saves.guidance.completed_count() > before:
		_saves.schedule_autosave(2.0)

func _record_order(order: String) -> void:
	# Deliberate commands are issued in a paused home panel. Only its successful
	# commit emits this signal; a rolled-back save never earns a checkmark.
	if _live_session() and int(get_node("/root/GameState").current_phase) == 0 and order in ["follow", "home"]:
		_observe_world()
		if _saves.guidance.done("home"):
			_record("command")

func _observe_world() -> void:
	if not _live_session() or _saves.guidance.current_step().is_empty():
		return
	var state: Node = get_node("/root/GameState")
	var home: Dictionary = Development.read_home(state.campaign.data, str(state.active_body_id))
	if home.status == "saved":
		_record("home")
		# Recover successful orders already persisted before this UI was bound.
		for member: Dictionary in state.campaign.data.bodies[state.active_body_id].home_group.members:
			if member.order in ["follow", "home"]:
				_record("command")
	var tribe: Node = get_tree().get_first_node_in_group(&"tribe_controller")
	if int(state.current_phase) == 1 and tribe != null and tribe.is_active():
		_record("tribe")

func hint(step: String) -> String:
	return Copy.hint(step)

func context_hint() -> String:
	if not _live_session():
		return Text.text("GUIDE_CONTEXT_WORLD")
	var state: Node = get_node("/root/GameState")
	if int(state.current_phase) != 0:
		return Text.text("GUIDE_TRIBE_NEXT")
	var step: String = _saves.guidance.current_step()
	if step == "eat" and _player.get_hunger_ratio() >= 0.99:
		return Text.text("GUIDE_CONTEXT_FULL")
	if step == "drink" and _player.get_thirst_ratio() >= 0.99:
		return Text.text("GUIDE_CONTEXT_HYDRATED")
	if step == "tribe":
		var tribe: Node = get_tree().get_first_node_in_group(&"tribe_controller")
		if tribe != null:
			var reasons: Array = tribe.blockers()
			return TribeText.legacy_status(str(reasons[0])) if not reasons.is_empty() else Text.text("GUIDE_CONTEXT_READY")
	return Text.text("GUIDE_CONTEXT_ANY_ORDER")


func build_help(parent: VBoxContainer) -> void:
	_help_parent = parent
	var body := VBoxContainer.new()
	body.name = "GuidanceHelp"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(body)
	Style.paragraph(body, Text.text("GUIDE_TITLE"), 26)
	var scroll := ScrollContainer.new()
	scroll.name = "GuidanceChapters"
	_help_scroll = scroll
	scroll.custom_minimum_size.y = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	Style.paragraph(list, Text.text("GUIDE_INTRO"), 18)
	Style.paragraph(list, context_hint(), 18)
	var supported: bool = _saves.guidance.supported()
	var creature_phase: bool = int(get_node("/root/GameState").current_phase) == 0
	for chapter_id in Progress.CHAPTERS:
		var heading: String = Text.format_text("GUIDE_CARD_COUNT", {"chapter": Copy.chapter(chapter_id), "done": _saves.guidance.chapter_completed(chapter_id), "total": Progress.CHAPTER_STEPS[chapter_id].size()})
		Style.paragraph(list, heading, 22)
		var choose := Style.button(list, Text.format_text("GUIDE_CHOOSE", {"chapter": Copy.chapter(chapter_id)}), select_chapter.bind(chapter_id), "GuideChapter_" + chapter_id)
		choose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choose.disabled = not supported or not creature_phase or _saves.guidance.chapter_completed(chapter_id) == Progress.CHAPTER_STEPS[chapter_id].size()
		for step: String in Progress.CHAPTER_STEPS[chapter_id]:
			Style.paragraph(list, ("✓ " if _saves.guidance.done(step) else "○ ") + Copy.title(step), 20)
			Style.paragraph(list, Copy.hint(step, true), 18)
	var message: String = Text.format_text("GUIDE_TOTAL", {"done": _saves.guidance.completed_count(), "total": Progress.STEPS.size()})
	if not supported:
		message = Text.text("GUIDE_FUTURE")
	elif _saves.guidance.done("tribe"):
		message = Text.text("GUIDE_FINISHED") + " · " + message
	elif bool(_saves.guidance.data.skipped):
		message += " " + Text.text("GUIDE_DISABLED")
	Style.paragraph(list, message, 18)
	Style.button(list, Text.text("GUIDE_RESTART"), restart, "RestartFirstSteps").disabled = not supported or not creature_phase
	Style.button(list, Text.text("GUIDE_SKIP"), skip, "SkipFirstSteps").disabled = not supported or _saves.guidance.current_step().is_empty()

	_layout_help()

func _layout_help() -> void:
	if not is_instance_valid(_help_scroll) or not _help_scroll.is_visible_in_tree():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel: Control = _help_parent.get_parent()
	panel.custom_minimum_size.x = minf(700, viewport_size.x - 48)
	_help_scroll.custom_minimum_size.y = clampf(viewport_size.y - 180, 100, 500)
	_apply_help_fonts(_help_parent.get_node("GuidanceHelp"), clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5))

func _apply_help_fonts(node: Node, factor: float) -> void:
	if node is Label or node is Button:
		if not node.has_meta("guidance_base_font"):
			node.set_meta("guidance_base_font", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("guidance_base_font")) * factor))
	for child in node.get_children():
		_apply_help_fonts(child, factor)

func _language_changed(_locale: String) -> void:
	if is_instance_valid(_help_parent) and _help_parent.is_visible_in_tree():
		var previous := _help_parent.get_node_or_null("GuidanceHelp")
		if previous != null:
			_help_parent.remove_child(previous)
			previous.queue_free()
			build_help(_help_parent)
			_help_parent.move_child(_help_parent.get_node("GuidanceHelp"), 0)

func select_chapter(chapter_id: String) -> void:
	if int(get_node("/root/GameState").current_phase) != 0 or not _saves.guidance.select_chapter(chapter_id):
		return
	_observe_timer = 0.0
	_saves.schedule_autosave(0.2)
	_flow.resume()

func restart() -> void:
	if not _saves.guidance.supported() or int(get_node("/root/GameState").current_phase) != 0:
		return
	_saves.guidance.reset(true)
	_observe_timer = 0.0
	_saves.schedule_autosave(0.2)
	_flow.resume()

func skip() -> void:
	_saves.guidance.skip()
	_saves.schedule_autosave(0.2)
	_flow.resume()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
