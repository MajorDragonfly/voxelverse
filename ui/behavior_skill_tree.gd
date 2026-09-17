extends CanvasLayer

const Keys = preload("res://core/input_preferences.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/skills_presentation.gd")
const Symbols = preload("res://ui/catalog/development_symbols.gd")
const Style = preload("res://ui/progression_style.gd")
const Development = preload("res://ui/development_path_panel.gd")
const PHASES = Presentation.Phases.PHASES

var player: Node
var _panel: Control
var _body: BoxContainer
var _branches: BoxContainer
var _details: VBoxContainer
var journal: CanvasLayer
var _scroll: ScrollContainer
var _phase_label: Label
var _wallet_labels: Dictionary = {}
var _cards: Dictionary = {}
var _nodes: Dictionary = {}
var _selected: String = "creature.social.approach"
var _title: Label
var _description: Label
var _requirements: Label
var _effect: Label
var _purchase: Button
var _message: Label
var _close: Button
var _tree_tab: Button
var _journal_tab: Button
var _phase_preview: Label
var _phase_choice: OptionButton
var _view_phase: int = 0
var _phase_selection: Dictionary = {0: "creature.social.approach", 1: "tribe.social.teamwork"}
var _tree_heading: Label
var _wallet_context: Label
var _availability: Label
var _planned_earning: Dictionary = {}
var _development: VBoxContainer
var _development_tab: Button
var _previous_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _previous_focus: WeakRef
var _owns_pause: bool = false
var _closing: bool = false
var _purchase_active: bool = false
var _detail_icon: TextureRect
var _header: BoxContainer
var _font_scale: float = 1.0
var _last_result: Dictionary = {}
var _last_purchase_id: String = ""
var _language_revision: int = 0
var _frame: PanelContainer
var _phase_navigation: VBoxContainer
var _phase_strip: HBoxContainer
var _phase_buttons: Array[Button] = []
var _era_hint: Label


func _ready() -> void:
	name = "PlayerProgression"
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.minimum_size_changed.connect(_fit_window, CONNECT_DEFERRED)
	visible = false
	var progression := get_node("/root/ProgressionService")
	progression.behavior_changed.connect(refresh)
	progression.discovery_points_changed.connect(func(_points: int) -> void: _refresh_journal())
	progression.species_discovered.connect(func(_key: String, _title_text: String) -> void: _refresh_journal())
	progression.region_discovered.connect(func(_key: String) -> void: _refresh_journal())
	progression.part_unlocked.connect(func(_id: String, _reason: String) -> void: _refresh_journal())
	get_node("/root/GameState").phase_changed.connect(func(_phase: int) -> void: refresh())
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: refresh(); _refresh_journal())
	get_node("/root/DisplaySettings").input_preferences.bindings_changed.connect(func() -> void: _refresh_static(_panel))
	get_viewport().size_changed.connect(_layout)
	_layout()


func open_panel() -> bool:
	var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
	var group_active: bool = tribe != null and tribe.is_active()
	if visible or _closing or get_tree().paused or not is_instance_valid(player) or (not player.is_physics_processing() and not group_active):
		return false
	_previous_mouse_mode = Input.mouse_mode
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_clear_message()
	_select_phase(clampi(int(get_node("/root/GameState").current_phase), 0, PHASES.size() - 1))
	_layout()
	_refresh_journal()
	_development.refresh()
	_tree_tab.grab_focus()
	return true


func close_panel() -> void:
	if not visible or _closing:
		return
	visible = false
	_closing = true
	# The closing click/Space/Enter must finish before player input polling resumes.
	_release_after_input_frame()


func _release_after_input_frame() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_release_pause()
	_closing = false
	var previous: Object = _previous_focus.get_ref() if _previous_focus != null else null
	if previous is Control and previous.is_visible_in_tree():
		previous.grab_focus()


func _release_pause() -> void:
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode


func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
	# Text entry and settings capture keep their input before any menu opens.
	var focus := get_viewport().gui_get_focus_owner()
	var typing: bool = focus is LineEdit or focus is TextEdit
	if event.pressed and not event.echo and ((Keys.menu_event(event, "open_development") and not typing) or (visible and key == KEY_ESCAPE)):
		if visible:
			close_panel()
			get_viewport().set_input_as_handled()
		elif open_panel():
			get_viewport().set_input_as_handled()
	elif visible and key >= KEY_F1 and key <= KEY_F35:
		# DisplaySettings handles F8 in _input on the parallel planet branch.
		# Block competing menus before their handlers run, including key repeats.
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if visible or _closing:
		get_viewport().set_input_as_handled()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.035, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_panel = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_panel.add_theme_constant_override("margin_" + side, 0)
	add_child(_panel)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", Style.box(Color("101c25"), Color("40535c"), 20))
	_panel.add_child(_frame)
	var content := Style.column(_frame, 10)
	var header := BoxContainer.new()
	_header = header
	content.add_child(header)
	var heading := Style.column(header, 2)
	heading.add_child(_label("SKILLS_SPECIES", 11, Style.SOCIAL))
	heading.add_child(_label("SKILLS_TITLE", 25))
	_close = _button("SKILLS_CLOSE")
	_close.name = "Close"
	_close.custom_minimum_size.x = 150
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close_panel)
	header.add_child(_close)
	_phase_label = _label("", 12, Style.MUTED)
	heading.add_child(_phase_label)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 4)
	content.add_child(tabs)
	_tree_tab = _button("SKILLS_TAB")
	_tree_tab.name = "SkilltreeTab"
	_tree_tab.pressed.connect(func() -> void: _show_tab(false))
	tabs.add_child(_tree_tab)
	_journal_tab = _button("SKILLS_JOURNAL")
	_journal_tab.name = "JournalTab"
	_journal_tab.pressed.connect(_open_journal)
	tabs.add_child(_journal_tab)
	_development_tab = _button("SKILLS_PATH")
	_development_tab.name = "DevelopmentTab"
	_development_tab.pressed.connect(_show_development)
	tabs.add_child(_development_tab)
	for tab: Button in [_tree_tab, _journal_tab, _development_tab]:
		tab.size_flags_horizontal = Control.SIZE_FILL
	_phase_navigation = Style.column(content, 5)
	_phase_strip = HBoxContainer.new()
	_phase_strip.add_theme_constant_override("separation", 6)
	_phase_navigation.add_child(_phase_strip)
	for index in range(PHASES.size()):
		var chapter := _button("")
		chapter.name = "EraChapter%d" % index
		chapter.set_meta("skills_font_size", 12)
		chapter.pressed.connect(_select_phase.bind(index))
		_phase_strip.add_child(chapter)
		_phase_buttons.append(chapter)
	_era_hint = _label("SKILLS_ERA_HINT", 12, Style.MUTED)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	content.add_child(_scroll)
	var pages := Style.column(_scroll, 10)
	_phase_choice = OptionButton.new()
	_phase_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_phase_choice.name = "PhasePreviewChoice"
	_phase_choice.custom_minimum_size.y = 34
	_phase_choice.fit_to_longest_item = false
	_phase_choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_phase_choice.add_theme_font_size_override("font_size", 14)
	for index in range(PHASES.size()):
		_phase_choice.add_item(Presentation.phase_name(index) + Text.text("SKILLS_PLAYABLE_CHOICE" if PHASES[index]["implemented"] else "SKILLS_PLANNED_CHOICE"), index)
	_phase_choice.item_selected.connect(_select_phase)
	_phase_navigation.add_child(_phase_choice)
	_phase_navigation.add_child(_era_hint)
	_body = BoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 16)
	pages.add_child(_body)
	var tree_area := Style.column(_body, 10)
	tree_area.size_flags_stretch_ratio = 1.65
	_tree_heading = _label("SKILLS_HEADING", 16)
	tree_area.add_child(_tree_heading)
	_wallet_context = _label("", 12, Style.MUTED)
	tree_area.add_child(_wallet_context)
	_branches = BoxContainer.new()
	_branches.add_theme_constant_override("separation", 10)
	tree_area.add_child(_branches)
	for track in ["social", "aggression"]:
		_build_branch(track)
	_availability = _label("SKILLS_EARNING_COMPACT", 12, Style.MUTED)
	_availability.name = "GameplayAvailability"
	tree_area.add_child(_availability)
	_phase_preview = _label("", 14, Style.MUTED)
	_phase_preview.name = "PhasePreview"
	tree_area.add_child(_phase_preview)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Color("40535c"), 16))
	_body.add_child(detail_panel)
	_details = Style.column(detail_panel, 10)
	var detail_heading := HBoxContainer.new()
	detail_heading.add_theme_constant_override("separation", 10)
	_details.add_child(detail_heading)
	_detail_icon = Symbols.view("social", false, 44)
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_heading.add_child(_detail_icon)
	var detail_titles := Style.column(detail_heading, 2)
	detail_titles.add_child(_label("SKILLS_DETAIL", 11, Style.MUTED))
	_title = _label("", 21)
	detail_titles.add_child(_title)
	_description = _label("", 15)
	_details.add_child(_description)
	_requirements = _label("", 13, Style.MUTED)
	_details.add_child(_requirements)
	_effect = _label("", 13, Style.SOCIAL)
	_details.add_child(_effect)
	_purchase = _button("")
	_purchase.name = "Purchase"
	_purchase.pressed.connect(_buy_selected)
	_details.add_child(_purchase)
	_details.add_child(_label("SKILLS_SAVE_HINT", 11, Style.MUTED))
	_development = Development.new()
	pages.add_child(_development)
	_message = _label("", 13, Style.SOCIAL)
	_message.name = "PurchaseMessage"
	content.add_child(_message)
	_show_tab(false)


func _build_branch(track: String) -> void:
	var color: Color = Style.SOCIAL if track == "social" else Style.AGGRESSION
	var column := Style.column(_branches, 8)
	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", Style.box(Color("162630"), color, 10))
	column.add_child(wallet)
	var info := Style.column(wallet, 4)
	info.add_child(_label("SKILLS_SOCIAL" if track == "social" else "SKILLS_AGGRESSION", 12, color))
	var balance := _label("", 16)
	info.add_child(balance)
	_wallet_labels[track] = balance
	var progression := get_node("/root/ProgressionService")
	var definitions: Array[Dictionary] = []
	for phase in range(PHASES.size()):
		definitions.append_array(progression.get_behavior_nodes(phase))
	for definition: Dictionary in definitions:
		if definition["track"] != track:
			continue
		var id: String = definition["id"]
		# The container measures the content. Measuring wrapped labels inside an
		# anchored child of a Button feeds its old width back into its minimum
		# height and can leave cards hundreds of pixels tall after UI relayout.
		var card_frame := PanelContainer.new()
		card_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		column.add_child(card_frame)
		var card := _button("", color)
		card.name = id.replace(".", "_")
		card.set_meta("skill_card", true)
		card.custom_minimum_size.y = 76
		card_frame.add_child(card)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 10)
		card_frame.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)
		var icon := Symbols.view(id.get_slice(".", 2), false, 32)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var labels := Style.column(row, 3)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(Presentation.node_text(id, "name"), 15, color)
		labels.add_child(name_label)
		var state_label := _label("", 12)
		labels.add_child(state_label)
		if not definition["legacy"].is_empty():
			labels.add_child(_label("SKILLS_LEGACY_CAPTION", 11, Style.MUTED))
		card.pressed.connect(_select.bind(id))
		_cards[id] = {"button": card, "container": card_frame, "status": state_label, "phase": definition["phase"], "icon": icon, "name": name_label, "content": margin}
	var planned := _label("", 13, Style.MUTED)
	planned.visible = false
	column.add_child(planned)
	_planned_earning[track] = planned


func refresh(refresh_development: bool = true) -> void:
	if _purchase == null:
		return
	var progression := get_node("/root/ProgressionService")
	_refresh_view_label()
	_refresh_chapters()
	var wallet: Dictionary = progression.call("get_behavior_wallet", _view_phase)
	var definitions: Array[Dictionary] = progression.get_behavior_nodes(_view_phase)
	_tree_heading.text = Text.text("SKILLS_OPEN_PATH") if _view_phase == 0 else Text.text("SKILLS_TRIBE_PATH") if _view_phase == 1 else Presentation.phase_name(_view_phase) + Text.text("SKILLS_FUTURE_PATH")
	_wallet_context.text = Text.text("SKILLS_ERA_PLANNED") if definitions.is_empty() else Text.text("SKILLS_COMBINE")
	_wallet_context.tooltip_text = Text.text("SKILLS_WALLET_CONTEXT") % Presentation.phase_name(_view_phase)
	if _view_phase > 0: _wallet_context.tooltip_text += Text.text("SKILLS_OLD_POINTS")
	_availability.visible = _view_phase == 0
	_details.get_parent().visible = not definitions.is_empty()
	_branches.visible = not definitions.is_empty()
	for card in _cards.values():
		card["button"].visible = int(card["phase"]) == _view_phase
		card["container"].visible = int(card["phase"]) == _view_phase
	for track: String in _wallet_labels:
		_wallet_labels[track].text = Text.text("SKILLS_POINTS_COMPACT") % int(wallet["available"][track])
		_wallet_labels[track].tooltip_text = Text.text("SKILLS_WALLET") % [int(wallet["available"][track]), int(wallet["earned"][track]), int(wallet["spent"][track])]
		_wallet_labels[track].mouse_filter = Control.MOUSE_FILTER_PASS
		_planned_earning[track].visible = _view_phase > 0
		_planned_earning[track].text = Text.text("SKILLS_PLANNED_EARNING") + Presentation.phase_text(_view_phase, track) + Text.text("SKILLS_PLANNED_SKILLS")
	if _view_phase == 1:
		_planned_earning["social"].text = Text.text("SKILLS_TRIBE_EARNING")
		_planned_earning["aggression"].text = Text.text("SKILLS_TRIBE_CONFLICT")
	_nodes.clear()
	for definition: Dictionary in definitions:
		var id: String = definition["id"]
		_nodes[id] = definition
		if not _cards.has(id):
			continue
		var status: Dictionary = definition["purchase_status"]
		_cards[id]["name"].text = Presentation.node_text(id, "name")
		_cards[id]["icon"].texture = Symbols.texture(id.get_slice(".", 2), bool(definition["purchased"]))
		_cards[id]["status"].text = Text.text("SKILLS_UNLOCKED") if definition["purchased"] else Text.text("SKILLS_CARD_COST") % [int(definition["cost"]), Text.text("SKILLS_AVAILABLE") if status["ok"] else Text.text("SKILLS_LOCKED")]
		var color: Color = Style.SOCIAL if definition["track"] == "social" else Style.AGGRESSION
		_cards[id]["status"].add_theme_color_override("font_color", color if status["ok"] or definition["purchased"] else Style.MUTED)
		_cards[id]["button"].add_theme_stylebox_override("normal", Style.box(Color("2b4149") if id == _selected else Style.PANEL, color if id == _selected else Color("40535c"), 12))
	_update_details()
	_refresh_phase_preview()
	_phase_preview.visible = _view_phase > 0
	if refresh_development:
		_development.refresh()


func _select(id: String) -> void:
	_selected = id
	_phase_selection[_view_phase] = id
	_clear_message()
	refresh()
	if _body.vertical:
		_scroll.ensure_control_visible.call_deferred(_details.get_parent())


func _update_details() -> void:
	var definition: Dictionary = _nodes.get(_selected, {})
	if definition.is_empty():
		_purchase.disabled = true
		return
	_detail_icon.texture = Symbols.texture(_selected.get_slice(".", 2), bool(definition["purchased"]))
	_title.text = Presentation.node_text(_selected, "name")
	_description.text = Presentation.node_text(_selected, "description")
	var names: PackedStringArray = []
	for id: String in definition["requires"]:
		names.append(Presentation.node_text(id, "name"))
	_requirements.text = Text.text("SKILLS_REQUIREMENT") + (Text.text("SKILLS_NONE") if names.is_empty() else ", ".join(names))
	var phase: int = get_node("/root/GameState").current_phase
	var legacy: bool = not definition["legacy"].is_empty()
	_effect.text = Text.text("SKILLS_LEGACY_EFFECT") if legacy else Text.text("SKILLS_CREATURE_EFFECT")
	if definition["purchased"]:
		_effect.text += Text.text("SKILLS_PURCHASED") + (Text.text("SKILLS_FROM_TRIBE") if legacy and phase == 0 else Text.text("SKILLS_GROUP_PENDING") if legacy else Text.text("SKILLS_ACTIVE_NOW") if phase == 0 else Text.text("SKILLS_CREATURE_LEFT"))
	if _view_phase == 1:
		_effect.text = Text.text("SKILLS_TRIBE_EFFECT") + (Text.text("SKILLS_ACTIVE_PURCHASE") if definition["purchased"] and phase == 1 else "")
	var status: Dictionary = definition["purchase_status"]
	_purchase.disabled = not status["ok"] or _purchase_active
	_purchase.text = Text.text("SKILLS_UNLOCKED") if definition["purchased"] else Text.text("SKILLS_UNLOCK") % [int(definition["cost"]), Text.text("SKILLS_SOCIAL_POINTS") if definition["track"] == "social" else Text.text("SKILLS_AGGRESSION_POINTS")]
	if not status["ok"] and not definition["purchased"]:
		_requirements.text += "\n" + _reason(str(status.get("reason", "")))


func _buy_selected() -> void:
	if _purchase_active or not visible or not _nodes.has(_selected) or not _body.visible:
		return
	_purchase_active = true
	_purchase.disabled = true
	_last_purchase_id = _selected
	var result: Dictionary = get_node("/root/ProgressionService").call("purchase_behavior_node", _selected)
	_last_result = result.duplicate(true)
	_purchase_active = false
	refresh()
	_refresh_message()
	_message.add_theme_color_override("font_color", Style.SOCIAL if result.get("ok", false) else Style.AGGRESSION)
	# A disabled purchase button must not strand keyboard focus after success.
	if _purchase.disabled:
		_cards[_selected]["button"].grab_focus()


func _reason(reason: String) -> String:
	match reason:
		"insufficient_points": return Text.text("SKILLS_POINTS_MISSING")
		"prerequisite_missing": return Text.text("SKILLS_PREREQUISITE_MISSING")
		"already_purchased": return Text.text("SKILLS_ALREADY_PURCHASED")
		"future_phase": return Text.text("SKILLS_FUTURE_PHASE")
		"save_failed": return Text.text("SKILLS_SAVE_FAILED")
		"purchase_in_progress": return Text.text("SKILLS_IN_PROGRESS")
		_: return Text.text("SKILLS_UNAVAILABLE")


func _refresh_phase_preview() -> void:
	if _phase_preview == null:
		return
	var index: int = _phase_choice.selected
	var data: Dictionary = get_node("/root/ProgressionService").get_phase_progression_preview(index)
	_phase_preview.text = (Text.text("SKILLS_IMPLEMENTED") if data["implemented"] else Text.text("SKILLS_PLANNED")) + " · " + Presentation.phase_text(index, "scope")
	_phase_preview.text += "\n%s\n%s\n%s" % [Presentation.phase_text(index, "control"), Presentation.phase_loop(index), Presentation.phase_text(index, "next")]
	if index > 0:
		_phase_preview.text += Text.text("SKILLS_GROUP_BONUSES") % [roundi((float(data["legacy"]["group_cooperation"]["value"]) - 1.0) * 100.0), roundi((float(data["legacy"]["group_defense"]["value"]) - 1.0) * 100.0)]
		_phase_preview.text += Text.text("SKILLS_BONUS_SCOPE")
		_phase_preview.text += Text.text("SKILLS_POINT_SCOPE")


func _select_phase(index: int) -> void:
	if index not in range(PHASES.size()):
		return
	_view_phase = index
	_selected = _phase_selection.get(index, "")
	if _selected.is_empty():
		var definitions: Array[Dictionary] = get_node("/root/ProgressionService").get_behavior_nodes(index)
		if not definitions.is_empty(): _selected = str(definitions[0]["id"])
	_phase_choice.select(index)
	_clear_message()
	refresh()
	_scroll.scroll_vertical = 0


func _show_tab(show_journal: bool) -> void:
	if show_journal:
		_open_journal()
		return
	_body.visible = not show_journal
	_phase_navigation.visible = not show_journal
	_development.visible = false
	_style_tabs(_tree_tab)
	if _message != null:
		_clear_message()
	_scroll.scroll_vertical = 0
	_refresh_view_label()


func _show_development() -> void:
	_body.visible = false
	_phase_navigation.visible = false
	_development.visible = true
	_style_tabs(_development_tab)
	_clear_message()
	_development.refresh()
	_scroll.scroll_vertical = 0
	_refresh_view_label()


func _refresh_view_label() -> void:
	var phase: int = get_node("/root/GameState").current_phase
	var page: String = Text.text("SKILLS_PATH") if _development.visible else Presentation.phase_name(_view_phase)
	_phase_label.text = Text.text("SKILLS_VIEW") % [Presentation.phase_name(phase), page]


func _refresh_journal() -> void:
	# The shared journal refreshes itself when opened and owns its subscriptions.
	pass


func _open_journal() -> void:
	if not visible or _closing or not is_instance_valid(journal):
		return
	close_panel()
	await get_tree().process_frame
	if is_inside_tree() and is_instance_valid(journal):
		journal.open_journal()


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_font_scale = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	var inset := 12.0 if viewport_size.x < 1000 else 24.0
	var book_size := Vector2(minf(1180 * _font_scale, viewport_size.x - inset * 2), minf(680 * _font_scale, viewport_size.y - inset * 2))
	_panel.position = (viewport_size - book_size) * 0.5
	_panel.size = book_size
	var width: float = book_size.x - 40
	_apply_fonts(_panel)
	_phase_choice.add_theme_font_size_override("font_size", roundi(14 * _font_scale))
	_phase_choice.custom_minimum_size.y = 34 * _font_scale
	_phase_strip.visible = width >= 920 * _font_scale
	_phase_choice.visible = not _phase_strip.visible
	_header.vertical = false
	_body.vertical = width < 920 * _font_scale
	_branches.vertical = width < 540 * _font_scale
	_close.custom_minimum_size.x = 135 * _font_scale
	# Flow whole navigation buttons onto another row before breaking a word.
	for tab: Button in [_tree_tab, _journal_tab, _development_tab]:
		var font := tab.get_theme_font("font")
		var font_size := tab.get_theme_font_size("font_size")
		tab.custom_minimum_size.x = minf(width - 32, font.get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 32)
	for card: Dictionary in _cards.values():
		card.button.custom_minimum_size.y = 76 * _font_scale
		card.icon.custom_minimum_size = Vector2.ONE * 32 * _font_scale
	_detail_icon.custom_minimum_size = Vector2.ONE * 44 * _font_scale
	# Breakpoints follow the actual book width, including on ultrawide displays.
	_development._stages.vertical = width < 840 * _font_scale
	_development._future.vertical = width < 540 * _font_scale
	_fit_window.call_deferred()


func _fit_window() -> void:
	# Container minimums settle after text wrapping. Reapply the bounded window
	# when they shrink as well, instead of retaining the initial one-word width.
	var viewport_size := get_viewport().get_visible_rect().size
	var inset := 12.0 if viewport_size.x < 1000 else 24.0
	_panel.size = Vector2(minf(1180 * _font_scale, viewport_size.x - inset * 2), minf(680 * _font_scale, viewport_size.y - inset * 2))
	_panel.position = (viewport_size - _panel.size) * 0.5


func _style_tabs(active: Button) -> void:
	for tab: Button in [_tree_tab, _journal_tab, _development_tab]:
		tab.add_theme_stylebox_override("normal", Style.box(Color("2b4149") if tab == active else Color("162630"), Style.SOCIAL if tab == active else Color("354750"), 8))
		tab.add_theme_color_override("font_color", Style.TEXT if tab == active else Style.MUTED)


func _refresh_chapters() -> void:
	var current: int = get_node("/root/GameState").current_phase
	for index in range(_phase_buttons.size()):
		var chapter := _phase_buttons[index]
		var status_key := "SKILLS_ERA_PREVIEW"
		if index == current: status_key = "SKILLS_ERA_CURRENT"
		elif index < current: status_key = "SKILLS_ERA_PREVIOUS"
		elif bool(PHASES[index]["implemented"]): status_key = "SKILLS_LOCKED"
		chapter.text = Text.text("SKILLS_ERA_%d_NAME" % index) + "\n" + Text.text(status_key)
		chapter.tooltip_text = Presentation.phase_name(index) + " · " + Text.text(status_key)
		chapter.add_theme_stylebox_override("normal", Style.box(Color("2b4149") if index == _view_phase else Color("162630"), Style.SOCIAL if index == _view_phase else Color("354750"), 6))
		chapter.add_theme_color_override("font_color", Style.TEXT if index == _view_phase else Style.MUTED)


func _label(key: String, size_value: int = 18, color: Color = Style.TEXT) -> Label:
	var label := Style.label(Keys.hint(key) if key.begins_with("SKILLS_") else key, size_value, color)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.set_meta("skills_font_size", size_value)
	if key.begins_with("SKILLS_"): label.set_meta("skills_text_key", key)
	return label


func _button(key: String, color: Color = Style.SOCIAL) -> Button:
	var button := Style.button(Keys.hint(key) if key.begins_with("SKILLS_") else key, color)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("skills_font_size", 14)
	if key.begins_with("SKILLS_"): button.set_meta("skills_text_key", key)
	return button


func _clear_message() -> void:
	_last_result = {}
	_last_purchase_id = ""
	_message.text = ""
	_message.visible = false


func _refresh_message() -> void:
	_message.visible = not _last_result.is_empty()
	if _last_result.is_empty():
		_message.text = ""
		return
	_message.text = Text.text("SKILLS_SUCCESS") % Presentation.node_text(_last_purchase_id, "name") if _last_result.get("ok", false) else _reason(str(_last_result.get("reason", "")))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		call_deferred("_refresh_language")


func _refresh_language() -> void:
	# Translate existing Controls only. No phase selection, purchase, reload or
	# development-path rebuild: focus, selected phase/node and pause stay owned.
	_language_revision += 1
	var revision := _language_revision
	var scroll_before := _scroll.scroll_vertical
	_refresh_static(_panel)
	for index in range(PHASES.size()):
		_phase_choice.set_item_text(index, Presentation.phase_name(index) + Text.text("SKILLS_PLAYABLE_CHOICE" if PHASES[index]["implemented"] else "SKILLS_PLANNED_CHOICE"))
	refresh(false)
	_refresh_message()
	_layout()
	# Container layout is deferred; restore pixels after translated text wraps.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree() and revision == _language_revision:
		_scroll.scroll_vertical = scroll_before


func _refresh_static(node: Node) -> void:
	if node.has_meta("skills_text_key"):
		node.text = Keys.hint(str(node.get_meta("skills_text_key")))
	for child in node.get_children(): _refresh_static(child)


func _apply_fonts(node: Node) -> void:
	if node.has_meta("skills_font_size"):
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("skills_font_size")) * _font_scale))
		if node is Button and not node.has_meta("skill_card"): node.custom_minimum_size.y = 36 * _font_scale
	for child in node.get_children(): _apply_fonts(child)
