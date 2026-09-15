extends CanvasLayer

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


func _ready() -> void:
	name = "PlayerProgression"
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	var progression := get_node("/root/ProgressionService")
	progression.behavior_changed.connect(refresh)
	progression.discovery_points_changed.connect(func(_points: int) -> void: _refresh_journal())
	progression.species_discovered.connect(func(_key: String, _title_text: String) -> void: _refresh_journal())
	progression.region_discovered.connect(func(_key: String) -> void: _refresh_journal())
	progression.part_unlocked.connect(func(_id: String, _reason: String) -> void: _refresh_journal())
	get_node("/root/GameState").phase_changed.connect(func(_phase: int) -> void: refresh())
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: refresh(); _refresh_journal())
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
	# K remains ordinary text while searching the journal.
	var typing: bool = get_viewport().gui_get_focus_owner() is LineEdit
	if event.pressed and not event.echo and ((key == KEY_K and not typing and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed) or (visible and key == KEY_ESCAPE)):
		if visible:
			close_panel()
		else:
			open_panel()
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
	backdrop.color = Color(0.025, 0.042, 0.057, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	_panel = MarginContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_panel.add_theme_constant_override("margin_" + side, 32)
	add_child(_panel)
	var content := Style.column(_panel, 10)
	var header := BoxContainer.new()
	_header = header
	content.add_child(header)
	var heading := Style.column(header, 2)
	heading.add_child(_label("SKILLS_SPECIES", 15, Style.SOCIAL))
	heading.add_child(_label("SKILLS_TITLE", 32))
	_close = _button("SKILLS_CLOSE")
	_close.name = "Close"
	_close.custom_minimum_size.x = 150
	_close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(close_panel)
	header.add_child(_close)
	_phase_label = _label("", 17, Style.MUTED)
	content.add_child(_phase_label)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 12)
	tabs.add_theme_constant_override("v_separation", 8)
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
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	content.add_child(_scroll)
	var pages := Style.column(_scroll)
	_phase_choice = OptionButton.new()
	_phase_choice.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_phase_choice.name = "PhasePreviewChoice"
	_phase_choice.custom_minimum_size.y = 46
	_phase_choice.fit_to_longest_item = false
	_phase_choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_phase_choice.add_theme_font_size_override("font_size", 18)
	for index in range(PHASES.size()):
		_phase_choice.add_item(Presentation.phase_name(index) + (Text.text("SKILLS_PLAYABLE_CHOICE") if index <= 1 else Text.text("SKILLS_PLANNED_CHOICE")), index)
	_phase_choice.item_selected.connect(_select_phase)
	pages.add_child(_phase_choice)
	_body = BoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	pages.add_child(_body)
	var tree_area := Style.column(_body, 10)
	tree_area.size_flags_stretch_ratio = 2.0
	_tree_heading = _label("SKILLS_HEADING", 24)
	tree_area.add_child(_tree_heading)
	_wallet_context = _label("", 18, Style.MUTED)
	tree_area.add_child(_wallet_context)
	_branches = BoxContainer.new()
	_branches.add_theme_constant_override("separation", 16)
	tree_area.add_child(_branches)
	for track in ["social", "aggression"]:
		_build_branch(track)
	_availability = _label("SKILLS_EARNING", 17, Style.MUTED)
	_availability.name = "GameplayAvailability"
	_availability.set_meta("skills_font_size", 14)
	tree_area.add_child(_availability)
	_phase_preview = _label("", 17, Style.MUTED)
	_phase_preview.name = "PhasePreview"
	tree_area.add_child(_phase_preview)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	detail_panel.add_theme_stylebox_override("panel", Style.box())
	_body.add_child(detail_panel)
	_details = Style.column(detail_panel, 12)
	_detail_icon = Symbols.view("social", false, 94)
	_details.add_child(_detail_icon)
	_details.add_child(_label("SKILLS_DETAIL", 13, Style.MUTED))
	_title = _label("", 25)
	_details.add_child(_title)
	_description = _label("")
	_details.add_child(_description)
	_requirements = _label("", 17, Style.MUTED)
	_details.add_child(_requirements)
	_effect = _label("", 17, Style.SOCIAL)
	_details.add_child(_effect)
	_purchase = _button("")
	_purchase.name = "Purchase"
	_purchase.pressed.connect(_buy_selected)
	_details.add_child(_purchase)
	_details.add_child(_label("SKILLS_SAVE_HINT", 16, Style.MUTED))
	_development = Development.new()
	pages.add_child(_development)
	_message = _label("", 18, Style.SOCIAL)
	_message.name = "PurchaseMessage"
	content.add_child(_message)
	_show_tab(false)


func _build_branch(track: String) -> void:
	var color: Color = Style.SOCIAL if track == "social" else Style.AGGRESSION
	var column := Style.column(_branches, 10)
	var wallet := PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", Style.box(Style.PANEL, color))
	column.add_child(wallet)
	var info := Style.column(wallet, 6)
	info.add_child(_label("SKILLS_SOCIAL" if track == "social" else "SKILLS_AGGRESSION", 17, color))
	var balance := _label("", 24)
	info.add_child(balance)
	_wallet_labels[track] = balance
	var progression := get_node("/root/ProgressionService")
	for definition: Dictionary in progression.get_behavior_nodes(0) + progression.get_behavior_nodes(1):
		if definition["track"] != track:
			continue
		var id: String = definition["id"]
		var card := _button("", color)
		card.name = id.replace(".", "_")
		card.custom_minimum_size.y = 94
		column.add_child(card)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 14)
		card.add_child(margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		margin.add_child(row)
		var icon := Symbols.view(id.get_slice(".", 2), false, 56)
		row.add_child(icon)
		var labels := Style.column(row, 3)
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_label := _label(Presentation.node_text(id, "name"), 19, color)
		labels.add_child(name_label)
		var state_label := _label("", 17)
		labels.add_child(state_label)
		labels.add_child(_label("SKILLS_LEGACY_CAPTION" if not definition["legacy"].is_empty() else "SKILLS_TRIBE_CAPTION" if int(definition["phase"]) == 1 else "SKILLS_CREATURE_CAPTION", 15, Style.MUTED))
		card.pressed.connect(_select.bind(id))
		_cards[id] = {"button": card, "status": state_label, "phase": definition["phase"], "icon": icon, "name": name_label, "content": margin}
	var planned := _label("", 18, Style.MUTED)
	planned.visible = false
	column.add_child(planned)
	_planned_earning[track] = planned


func refresh(refresh_development: bool = true) -> void:
	if _purchase == null:
		return
	var progression := get_node("/root/ProgressionService")
	_refresh_view_label()
	var wallet: Dictionary = progression.call("get_behavior_wallet", _view_phase)
	var preview: Dictionary = progression.get_phase_progression_preview(_view_phase)
	_tree_heading.text = Text.text("SKILLS_OPEN_PATH") if _view_phase == 0 else Text.text("SKILLS_TRIBE_PATH") if _view_phase == 1 else Presentation.phase_name(_view_phase) + Text.text("SKILLS_FUTURE_PATH")
	_wallet_context.text = Text.text("SKILLS_WALLET_CONTEXT") % Presentation.phase_name(_view_phase)
	if _view_phase > 0:
		_wallet_context.text += Text.text("SKILLS_OLD_POINTS")
	_availability.visible = _view_phase == 0
	_details.get_parent().visible = _view_phase <= 1
	for card in _cards.values():
		card["button"].visible = int(card["phase"]) == _view_phase
	for track: String in _wallet_labels:
		_wallet_labels[track].text = Text.text("SKILLS_WALLET") % [int(wallet["available"][track]), int(wallet["earned"][track]), int(wallet["spent"][track])]
		_planned_earning[track].visible = _view_phase > 0
		_planned_earning[track].text = Text.text("SKILLS_PLANNED_EARNING") + Presentation.phase_text(_view_phase, track) + Text.text("SKILLS_PLANNED_SKILLS")
	if _view_phase == 1:
		_planned_earning["social"].text = Text.text("SKILLS_TRIBE_EARNING")
		_planned_earning["aggression"].text = Text.text("SKILLS_TRIBE_CONFLICT")
	_nodes.clear()
	for definition: Dictionary in progression.call("get_behavior_nodes", _view_phase):
		var id: String = definition["id"]
		_nodes[id] = definition
		if not _cards.has(id):
			continue
		var status: Dictionary = definition["purchase_status"]
		_cards[id]["name"].text = Presentation.node_text(id, "name")
		_cards[id]["icon"].texture = Symbols.texture(id.get_slice(".", 2), bool(definition["purchased"]))
		_cards[id]["status"].text = Text.text("SKILLS_UNLOCKED") if definition["purchased"] else Text.text("SKILLS_CARD_COST") % [int(definition["cost"]), Text.text("SKILLS_AVAILABLE") if status["ok"] else Text.text("SKILLS_LOCKED")]
		var color: Color = Style.SOCIAL if definition["track"] == "social" else Style.AGGRESSION
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
	_purchase.disabled = not status["ok"] or _purchase_active or _view_phase > 1
	_purchase.text = Text.text("SKILLS_UNLOCKED") if definition["purchased"] else Text.text("SKILLS_UNLOCK") % [int(definition["cost"]), Text.text("SKILLS_SOCIAL_POINTS") if definition["track"] == "social" else Text.text("SKILLS_AGGRESSION_POINTS")]
	if not status["ok"] and not definition["purchased"]:
		_requirements.text += "\n" + _reason(str(status.get("reason", "")))


func _buy_selected() -> void:
	if _purchase_active or not visible or _view_phase > 1 or not _body.visible:
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
	_phase_choice.select(index)
	_clear_message()
	refresh()
	_scroll.scroll_vertical = 0


func _show_tab(show_journal: bool) -> void:
	if show_journal:
		_open_journal()
		return
	_body.visible = not show_journal
	_phase_choice.visible = not show_journal
	_development.visible = false
	_tree_tab.modulate = Color.WHITE if not show_journal else Style.MUTED
	_journal_tab.modulate = Color.WHITE if show_journal else Style.MUTED
	_development_tab.modulate = Style.MUTED
	if _message != null:
		_clear_message()
	_scroll.scroll_vertical = 0
	_refresh_view_label()


func _show_development() -> void:
	_body.visible = false
	_phase_choice.visible = false
	_development.visible = true
	_tree_tab.modulate = Style.MUTED
	_journal_tab.modulate = Style.MUTED
	_development_tab.modulate = Color.WHITE
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
	var width: float = get_viewport().get_visible_rect().size.x
	_font_scale = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	_apply_fonts(_panel)
	_phase_choice.add_theme_font_size_override("font_size", roundi(18 * _font_scale))
	_phase_choice.custom_minimum_size.y = 46 * _font_scale
	_header.vertical = width < 650
	_body.vertical = width < 1100 * _font_scale
	_branches.vertical = width < 620 * _font_scale
	_close.custom_minimum_size.x = 150 * _font_scale
	# Flow whole navigation buttons onto another row before breaking a word.
	for tab: Button in [_tree_tab, _journal_tab, _development_tab]:
		var font := tab.get_theme_font("font")
		var font_size := tab.get_theme_font_size("font_size")
		tab.custom_minimum_size.x = minf(width - 32, font.get_string_size(tab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 32)
	for side in ["left", "right", "top", "bottom"]:
		_panel.add_theme_constant_override("margin_" + side, 16 if width < 1000 else 32)
	call_deferred("_fit_cards")


func _label(key: String, size_value: int = 18, color: Color = Style.TEXT) -> Label:
	var label := Style.label(Text.text(key) if key.begins_with("SKILLS_") else key, size_value, color)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.set_meta("skills_font_size", size_value)
	if key.begins_with("SKILLS_"): label.set_meta("skills_text_key", key)
	return label


func _button(key: String, color: Color = Style.SOCIAL) -> Button:
	var button := Style.button(Text.text(key) if key.begins_with("SKILLS_") else key, color)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("skills_font_size", 18)
	if key.begins_with("SKILLS_"): button.set_meta("skills_text_key", key)
	return button


func _clear_message() -> void:
	_last_result = {}
	_last_purchase_id = ""
	_message.text = ""


func _refresh_message() -> void:
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
		_phase_choice.set_item_text(index, Presentation.phase_name(index) + Text.text("SKILLS_PLAYABLE_CHOICE" if index <= 1 else "SKILLS_PLANNED_CHOICE"))
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
		node.text = Text.text(str(node.get_meta("skills_text_key")))
	for child in node.get_children(): _refresh_static(child)


func _apply_fonts(node: Node) -> void:
	if node.has_meta("skills_font_size"):
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("skills_font_size")) * _font_scale))
		if node is Button: node.custom_minimum_size.y = 46 * _font_scale
	for child in node.get_children(): _apply_fonts(child)


func _fit_cards() -> void:
	for card: Dictionary in _cards.values():
		card.button.custom_minimum_size.y = maxf(94 * _font_scale, card.content.get_combined_minimum_size().y)
