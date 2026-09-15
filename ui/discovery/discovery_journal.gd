extends CanvasLayer
## Shared discovery book, installed once by ProgressionHUD for J and the skilltree.

const Text = preload("res://ui/discovery/journal_presentation.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")
const Research = preload("res://core/discovery/research_goals.gd")
const Comparison = preload("res://ui/discovery/species_comparison.gd")
const PREFS_PATH := "user://discovery_journal_ui.cfg"
const PAGE_SIZE: int = 100
const Catalog = preload("res://core/discovery/journal_catalog.gd")
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const OwnedReader = preload("res://ui/discovery/owned_animal_reader.gd")
const OwnedRegister = preload("res://ui/discovery/owned_animal_register.gd")
const ANIMALS_TAB := 5
const AnimalText = preload("res://ui/discovery/owned_animal_presentation.gd")
const Symbols = preload("res://ui/catalog/development_symbols.gd")

var is_open: bool = false
var player: Node
var _owns_pause: bool = false
var _closing: bool = false
var _previous_mouse: int = Input.MOUSE_MODE_CAPTURED
var _progression: Node
var _surface: Control
var _summary: Label
var _search: LineEdit
var _filter: OptionButton
var _status: OptionButton
var _tabs: TabBar
var _list: ItemList
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _preview: SubViewportContainer
var _comparison: VBoxContainer
var _compare_button: Button
var _comparison_mode: bool = false
var _title: Label
var _description: Label
var _parts_label: Label
var _page_label: Label
var _previous_page: Button
var _next_page: Button
var _guide: Label
var _hint: Label
var _hud: Control
var _close: Button
var _pin: Button
var _wish: Button
var _goal_progress: ProgressBar
var _action_message: Label
var _pinned_button: Button
var _pinned_row: Dictionary = {}
var _state: Dictionary = {}
var _rows: Array[Dictionary] = []
var _selected_key: String = ""
var _page: int = 0
var _hint_enabled: bool = false
var _hint_timer: float = 0.0
var _animal_roles: Label
var _roles_toggle: Button
var _animal_contract: Script
var _compact_tabs: OptionButton
var _panel: PanelContainer
var _content: BoxContainer
var _browser: VBoxContainer
var _heading: BoxContainer
var _tools_row: BoxContainer
var _scale_factor: float = 1.0
var _owned_reader = OwnedReader.new()
var _owned_register: VBoxContainer
var _animals_result_code: String = "owned.unavailable"
var _status_badge: Label
var _thumbnail_preview: SubViewportContainer
var _thumbnail_cache: Dictionary = {}
var _thumbnail_queue: Array[Dictionary] = []
var _thumbnail_running: bool = false
var _parts_grid: GridContainer
var _catalog := Catalog.new()
var _row_total: int = 0
var _thumbnail_generation: int = 0
var _selected_row: Dictionary = {}
var _last_result: Dictionary = {}
var _language_pending: bool = false
const TAB_TITLES := ["Arten", "Körperteile", "Regionen", "Nächste Schritte", "Forschungsziele", "Eigene Tiere"]
const STATUS_TITLES := ["Alle Teile", "Freigeschaltet", "Noch gesperrt", "Merkliste"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"discovery_journal")
	layer = 30
	_progression = get_node_or_null("/root/ProgressionService")
	var prefs := ConfigFile.new()
	if prefs.load(PREFS_PATH) == OK:
		_hint_enabled = bool(prefs.get_value("journal", "show_hint", true))
	_animal_contract = Suitability.contract()
	_build()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_owned_reader.changed.connect(refresh_owned_animals)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if _progression != null:
		_progression.connect("species_discovered", _on_discovery)
		_progression.connect("discovery_points_changed", _on_points)
		_progression.connect("region_discovered", func(_key: String) -> void: _on_points(0))
		_progression.connect("part_unlocked", func(_id: String, _reason: String) -> void: _on_points(0))
		_progression.connect("research_changed", _on_research_changed)
	_update_hint()
	_update_research_hud()


func _exit_tree() -> void:
	_owned_reader.unbind()
	if _owns_pause and get_tree() != null:
		get_tree().paused = false
		Input.mouse_mode = _previous_mouse


func _process(delta: float) -> void:
	if is_open and _tabs.current_tab == ANIMALS_TAB:
		_owned_reader.check_context()
	_hud.visible = not is_open and not get_tree().paused and (player == null or player.is_physics_processing())
	_hint_timer -= delta
	if _hint_timer <= 0.0 and not is_open:
		_hint_timer = 1.0
		_update_hint()


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if not is_open or not event is InputEventKey:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if event.pressed and not event.echo and key == KEY_ESCAPE:
		close_journal()
		get_viewport().set_input_as_handled()
	elif key == KEY_J and not _search.has_focus():
		if event.pressed and not event.echo:
			close_journal()
		get_viewport().set_input_as_handled()
	elif key in [KEY_F2, KEY_F4, KEY_F8, KEY_F10, KEY_F11]:
		# Keep scene/editor/settings shortcuts from opening a second modal.
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_open or _closing:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_J or event.physical_keycode == KEY_J:
		if open_journal():
			get_viewport().set_input_as_handled()


func open_journal() -> bool:
	if is_open or _closing or get_tree().paused or _progression == null:
		return false
	var tribe := get_tree().get_first_node_in_group(&"tribe_controller")
	if player != null and not player.is_physics_processing() and not (tribe != null and tribe.is_active()):
		return false
	_previous_mouse = Input.mouse_mode
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	_surface.show()
	_hud.hide()
	refresh()
	_close.grab_focus()
	return true


func close_journal() -> void:
	if not is_open:
		return
	is_open = false
	_closing = true
	_surface.hide()
	_preview.call("clear")
	_thumbnail_queue.clear()
	_thumbnail_preview.call("clear")
	_thumbnail_generation += 1
	_thumbnail_cache.clear()
	_catalog.clear()
	_state = {}
	_rows.clear()
	_selected_row.clear()
	_row_total = 0
	_comparison.call("clear")
	_comparison_mode = false
	_release_after_input_frame()


func _release_after_input_frame() -> void:
	# A closing Space/Enter/click must finish before gameplay polls actions again.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
		Input.mouse_mode = _previous_mouse
	_closing = false
	_hud.show()


func refresh() -> void:
	if _progression == null:
		return
	_catalog.bind(_progression, Suitability.read.bind(_animal_contract), Text.discovery_search)
	_state = _catalog.state
	_thumbnail_generation += 1
	_thumbnail_cache.clear()
	# Keep the selected discovery visible when a new observation changes sort order.
	if _paged_discoveries():
		_discovery_page()
		var selected_page: int = _catalog.page_for(_selected_key)
		if selected_page >= 0: _page = selected_page
	_refresh_summary()
	_apply_filters()


func bind_owned_animals(source: Object, context: Callable, names: Callable = Callable()) -> bool:
	# Called by the D2 host after configure; no autoload, inferred IDs or lab save.
	var bound: bool = _owned_reader.bind_source(source, context, names)
	refresh_owned_animals()
	return bound


func unbind_owned_animals() -> void:
	_owned_reader.unbind()
	refresh_owned_animals()


func refresh_owned_animals() -> void:
	# Also called by the host after a successful load into the same controller.
	if is_open and _tabs.current_tab == ANIMALS_TAB:
		var scroll: int = _detail_scroll.scroll_vertical
		_apply_filters()
		_detail_scroll.set_deferred("scroll_vertical", scroll)


func _build() -> void:
	_surface = Control.new()
	_surface.name = "JournalSurface"
	_surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_surface.theme = _theme()
	add_child(_surface)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.05, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.add_child(shade)
	var panel := PanelContainer.new()
	_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 28
	panel.offset_top = 24
	panel.offset_right = -28
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", _box(Color("101c27"), 20))
	_surface.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	var heading := BoxContainer.new()
	_heading = heading
	layout.add_child(heading)
	var heading_text := _label("Entdeckungsbuch", 32)
	heading_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_text)
	_close = _button("Zurück zum Spiel  ·  Esc", close_journal)
	_close.name = "CloseJournal"
	_close.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(_close)
	_summary = _label("", 15)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	layout.add_child(_summary)
	_tabs = TabBar.new()
	_tabs.name = "JournalTabs"
	for tab in TAB_TITLES:
		_tabs.add_tab(Text.text(tab))
	_tabs.tab_changed.connect(_on_tab_changed)
	_tabs.clip_tabs = true
	layout.add_child(_tabs)
	_compact_tabs = OptionButton.new()
	_compact_tabs.name = "CompactJournalTabs"
	for index in _tabs.tab_count:
		_compact_tabs.add_item(_tabs.get_tab_title(index))
	_compact_tabs.item_selected.connect(func(index: int) -> void: _tabs.current_tab = index)
	layout.add_child(_compact_tabs)
	var tools_row := BoxContainer.new()
	_tools_row = tools_row
	tools_row.name = "Filters"
	layout.add_child(tools_row)
	_search = LineEdit.new()
	_search.name = "JournalSearch"
	Text.bind(_search, "placeholder_text", "Name oder Fundort suchen …")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value: String) -> void: _page = 0; _apply_filters())
	tools_row.add_child(_search)
	var choices := HBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_row.add_child(choices)
	_filter = OptionButton.new()
	_filter.name = "JournalFilter"
	_filter.fit_to_longest_item = false
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.item_selected.connect(func(_index: int) -> void: _page = 0; _apply_filters())
	choices.add_child(_filter)
	_status = OptionButton.new()
	_status.name = "PartStatus"
	_status.fit_to_longest_item = false
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in STATUS_TITLES:
		_status.add_item(Text.text(text))
	_status.item_selected.connect(func(_index: int) -> void: _page = 0; _apply_filters())
	choices.add_child(_status)
	var content := BoxContainer.new()
	_content = content
	content.name = "JournalContent"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	layout.add_child(content)
	var browser := VBoxContainer.new()
	_browser = browser
	browser.custom_minimum_size.x = 240
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser.size_flags_stretch_ratio = 0.92
	content.add_child(browser)
	_list = ItemList.new()
	_list.name = "JournalEntries"
	_list.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("v_separation", 8)
	_list.fixed_icon_size = Vector2i(78, 78)
	_list.add_theme_constant_override("icon_margin", 12)
	_list.add_theme_font_size_override("font_size", 16)
	_list.item_selected.connect(_select_entry)
	browser.add_child(_list)
	var paging := HBoxContainer.new()
	browser.add_child(paging)
	_previous_page = _button("‹", func() -> void: _page -= 1; _apply_filters())
	Text.bind(_previous_page, "tooltip_text", "Vorherige Seite")
	paging.add_child(_previous_page)
	_page_label = _label("", 13)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	paging.add_child(_page_label)
	_next_page = _button("›", func() -> void: _page += 1; _apply_filters())
	Text.bind(_next_page, "tooltip_text", "Nächste Seite")
	paging.add_child(_next_page)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.follow_focus = true
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	_detail_scroll.add_child(_detail)
	_title = _label("", 26)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_title)
	_owned_register = OwnedRegister.new()
	_owned_register.name = "OwnedAnimalRegister"
	_detail.add_child(_owned_register)
	_owned_register.hide()
	_roles_toggle = _button("Tierrollen ansehen", func() -> void: _animal_roles.visible = not _animal_roles.visible)
	_roles_toggle.name = "ToggleAnimalSuitability"
	_roles_toggle.hide()
	_detail.add_child(_roles_toggle)
	_animal_roles = _label("", 16)
	_animal_roles.name = "AnimalSuitability"
	_animal_roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_animal_roles.hide()
	_detail.add_child(_animal_roles)
	_status_badge = _label("", 14)
	_status_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_badge.add_theme_color_override("font_color", Color("83d6bf"))
	_detail.add_child(_status_badge)
	_compare_button = _button("Mit meiner Kreatur vergleichen", _toggle_comparison)
	_compare_button.name = "CompareSpecies"
	_compare_button.hide()
	_detail.add_child(_compare_button)
	_comparison = Comparison.new()
	_comparison.name = "SpeciesComparison"
	_comparison.connect("wish_requested", func(id: String, desired: bool) -> void:
		_research_result(_progression.call("set_part_wished", id, desired)))
	_detail.add_child(_comparison)
	_comparison.hide()
	_preview = Preview.new()
	_preview.name = "SpeciesPreview"
	_detail.add_child(_preview)
	_description = _label("", 17)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_description)
	_goal_progress = ProgressBar.new()
	_goal_progress.name = "ResearchProgress"
	_goal_progress.show_percentage = false
	_goal_progress.custom_minimum_size.y = 14
	_detail.add_child(_goal_progress)
	_pin = _button("Im Spiel verfolgen", _pin_selected)
	_pin.name = "PinResearch"
	_detail.add_child(_pin)
	_wish = _button("Auf Merkliste setzen", _toggle_wish)
	_wish.name = "WishPart"
	_detail.add_child(_wish)
	_parts_label = _label("", 16)
	_parts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_parts_label)
	_parts_grid = GridContainer.new()
	_parts_grid.columns = 2
	_parts_grid.add_theme_constant_override("h_separation", 8)
	_parts_grid.add_theme_constant_override("v_separation", 8)
	_detail.add_child(_parts_grid)
	_guide = _label("", 19)
	_guide.name = "JournalGuide"
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_guide)
	_action_message = _label("", 15)
	_action_message.name = "ResearchSaveMessage"
	_action_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_message.hide()
	layout.add_child(_action_message)
	var hints := CheckButton.new()
	Text.bind(hints, "text", "Kurzen Spielhinweis anzeigen")
	hints.button_pressed = _hint_enabled
	hints.toggled.connect(_toggle_hint)
	layout.add_child(hints)
	_thumbnail_preview = Preview.new()
	_thumbnail_preview.name = "CatalogThumbnailRenderer"
	_thumbnail_preview.position = Vector2(-2000, -2000)
	_surface.add_child(_thumbnail_preview)
	_thumbnail_preview.custom_minimum_size = Vector2.ZERO
	_thumbnail_preview.size = Vector2(128, 128)
	_surface.hide()
	get_viewport().size_changed.connect(_layout_catalog)
	_layout_catalog()
	_build_hud()
	_populate_filter()


func _layout() -> void:
	if not is_inside_tree() or _surface == null:
		return
	var extent := get_viewport().get_visible_rect().size
	_scale_factor = extent.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * _scale_factor, 0.0, Vector2.ZERO)
	extent /= _scale_factor
	var animal_scale: float = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	_animal_fonts(_surface, animal_scale)
	_close.custom_minimum_size.x = (190 if extent.x < 1100 * animal_scale else 280) * animal_scale
	_close.text = Text.text("JOURNAL_CLOSE_COMPACT" if extent.x < 1100 * animal_scale else "Zurück zum Spiel  ·  Esc")
	_surface.size = extent
	_preview.custom_minimum_size.y = 110 if extent.y <= 600 else 230
	_title.add_theme_font_size_override("font_size", roundi((20 if extent.y <= 600 else 26) * animal_scale))
	var narrow := extent.x < 1100 * animal_scale
	_summary.visible = extent.y >= 600 and not (animal_scale > 1.0 and extent.y < 720)
	_panel.get_child(0).add_theme_constant_override("separation", 6 if narrow else 12)
	_tabs.visible = not narrow
	_compact_tabs.visible = narrow
	_heading.vertical = extent.x < 700
	_tools_row.vertical = extent.x < 680 * animal_scale
	_content.vertical = extent.x < 600
	_browser.custom_minimum_size.x = 0 if _content.vertical else 210
	_browser.custom_minimum_size.y = 115 if _content.vertical else 0
	_browser.size_flags_stretch_ratio = 0.32
	_panel.offset_left = 12 if narrow else 28
	_panel.offset_right = -_panel.offset_left
	_panel.offset_top = 12 if narrow else 24
	_panel.offset_bottom = -_panel.offset_top
	if _hud != null:
		var hud_height := 192.0 if _pinned_button != null and _pinned_button.visible else 108.0
		_hud.position = Vector2(maxf(12.0, extent.x - 480), maxf(12.0, extent.y - 122 - hud_height))
		_hud.size = Vector2(minf(456.0, extent.x - 24), hud_height)

func _species_rows(query: String, role: String) -> Array[Dictionary]:
	return _catalog.page("species", query, role, _page, Suitability.search_roles()).rows

func _paged_discoveries() -> bool:
	return _tabs != null and _tabs.current_tab in [0, 2]

func _discovery_page() -> Dictionary:
	var role: String = str(_filter.get_item_metadata(_filter.selected)) if _filter.selected >= 0 else ""
	return _catalog.page("species" if _tabs.current_tab == 0 else "regions", _search.text, role if _tabs.current_tab == 0 else "", _page, Suitability.search_roles())

func _entry_index(index: int) -> int:
	return index if _paged_discoveries() else _page * PAGE_SIZE + index


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_hud.offset_left = -292
	_hud.offset_top = 82
	_hud.offset_right = -24
	_hud.offset_bottom = 140
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.theme = _surface.theme
	add_child(_hud)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(layout)
	_hint = _label("", 14)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	layout.add_child(_hint)
	_pinned_button = _button("", _open_pinned)
	_pinned_button.name = "PinnedResearch"
	_pinned_button.custom_minimum_size.y = 60
	_pinned_button.clip_text = true
	_pinned_button.hide()
	layout.add_child(_pinned_button)
	var open_button := _button("Entdeckungsbuch · J", func() -> void: open_journal())
	open_button.name = "OpenJournal"
	open_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	layout.add_child(open_button)


func _on_tab_changed(_index: int) -> void:
	_compact_tabs.select(_index)
	_layout()
	_comparison_mode = false
	_page = 0
	_selected_key = ""
	_action_message.hide()
	_search.clear()
	_populate_filter()
	_apply_filters()


func _populate_filter() -> void:
	_filter.clear()
	if _tabs.current_tab == ANIMALS_TAB:
		for item in [["Lebende Tiere", "living"], ["Verstorbene Tiere", "dead"], ["Alle eigenen Tiere", "all"]]:
			_filter.add_item(Text.text(item[0]))
			_filter.set_item_metadata(_filter.item_count - 1, item[1])
		_filter.select(0)
		_filter.show()
		_status.hide()
		Text.bind(_search, "placeholder_text", "Tier, Art oder Auftrag suchen …")
		return
	_filter.add_item(Text.text("Alle Lebensweisen / Tierrollen" if _tabs.current_tab == 0 else "Alle Kategorien"))
	_filter.set_item_metadata(0, "")
	var labels: Dictionary = Records.ROLES if _tabs.current_tab == 0 else Records.CATEGORIES
	for key in labels:
		_filter.add_item(Text.text(str(labels[key])))
		_filter.set_item_metadata(_filter.item_count - 1, key)
	if _tabs.current_tab == 0:
		for role in Suitability.ROLES:
			_filter.add_item(Text.text("Tierrolle: %s") % Text.text(Suitability.ROLES[role]))
			_filter.set_item_metadata(_filter.item_count - 1, "domestic:" + role)
	_filter.select(0)
	_status.visible = _tabs.current_tab == 1
	_filter.visible = _tabs.current_tab < 2
	Text.bind(_search, "placeholder_text", "Teil oder Herkunft suchen …" if _tabs.current_tab == 1 else "Name oder Fundort suchen …")
	if _tabs.current_tab == 4:
		Text.bind(_search, "placeholder_text", "Forschungsziel suchen …")


func _apply_filters() -> void:
	if _tabs == null:
		return
	_thumbnail_generation += 1
	_thumbnail_queue.clear()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_description.auto_translate_mode = _title.auto_translate_mode
	var guide_mode: bool = _tabs.current_tab == 3
	_search.get_parent().visible = not guide_mode
	_list.get_parent().visible = not guide_mode
	_guide.visible = guide_mode
	_owned_register.hide()
	_description.show()
	_parts_label.text = ""
	_animal_roles.hide()
	_roles_toggle.hide()
	_clear_part_tiles()
	_status_badge.text = ""
	_clear_comparison()
	_pin.hide()
	_wish.hide()
	_goal_progress.hide()
	_preview.call("clear")
	_preview.hide()
	_selected_row = {}
	if guide_mode:
		_render_empty()
		return
	var filter_value: String = str(_filter.get_item_metadata(_filter.selected)) if _filter.selected >= 0 else ""
	var animals: Dictionary = {}
	match _tabs.current_tab:
		0, 2:
			var result: Dictionary = _discovery_page()
			_rows = result.rows
			_page = result.page
			_row_total = result.total
		1: _rows = Text.part_rows(_state, _search.text, filter_value, _status.selected)
		4: _rows = Text.goals(_state, _search.text)
		ANIMALS_TAB:
			animals = _owned_reader.read(_search.text, filter_value)
			_animals_result_code = animals.code
			_rows.assign(animals["rows"])
	if not _paged_discoveries():
		_row_total = _rows.size()
		_page = clampi(_page, 0, maxi((_row_total - 1) / PAGE_SIZE, 0))
	_list.clear()
	var selected_index: int = 0
	var start: int = 0 if _paged_discoveries() else _page * PAGE_SIZE
	for index in range(start, mini(start + PAGE_SIZE, _rows.size())):
		var row: Dictionary = _rows[index]
		var label: String = _row_label(row)
		var visual_key: String = _visual_key(row, _tabs.current_tab)
		_list.add_item(label, _thumbnail_cache.get(visual_key, Symbols.texture("creature" if _tabs.current_tab == 0 else "part", bool(row.get("unlocked", true)))))
		_list.set_item_metadata(_list.item_count - 1, visual_key)
		if not _thumbnail_cache.has(visual_key) and _tabs.current_tab in [0, 1]:
			_thumbnail_queue.append({"row": row, "tab": _tabs.current_tab, "key": visual_key})
		_list.set_item_tooltip(_list.item_count - 1, label + " · " + _row_tooltip(row))
		if str(row.get("key", row.get("id", ""))) == _selected_key:
			selected_index = _list.item_count - 1
	_refresh_page_label()
	_previous_page.disabled = _page == 0
	_next_page.disabled = (_page + 1) * PAGE_SIZE >= _row_total
	if _rows.is_empty():
		_selected_key = ""
		_render_empty()
		return
	_render_thumbnails()
	_list.select(selected_index)
	_select_entry(selected_index)


func _select_entry(index: int) -> void:
	var absolute: int = _entry_index(index)
	if absolute < 0 or absolute >= _rows.size(): return
	var row: Dictionary = _rows[absolute]
	if _tabs.current_tab == 0:
		row = _catalog.species_detail(str(row.key))
		if row.is_empty(): refresh(); return
		_thumbnail_queue.assign(_thumbnail_queue.filter(func(job: Dictionary) -> bool: return int(job.tab) == 0))
	_selected_row = row
	_selected_key = str(row.get("key", row.get("id", "")))
	_detail_scroll.scroll_vertical = 0
	_animal_roles.hide()
	_roles_toggle.hide()
	_clear_part_tiles()
	_clear_comparison()
	_pin.hide()
	_wish.hide()
	_goal_progress.hide()
	_preview.call("clear")
	_preview.hide()
	_owned_register.hide()
	if _tabs.current_tab == ANIMALS_TAB:
		_description.hide()
		_owned_register.show()
		_owned_register.present(row)
	elif _tabs.current_tab == 0:
		_roles_toggle.show()
		var blueprint: Dictionary = Records.visual_for(row)
		if not blueprint.is_empty():
			var own: Dictionary = _player_blueprint()
			_compare_button.show()
			_compare_button.disabled = own.is_empty()
			if _comparison_mode and not own.is_empty():
				_list.get_parent().hide()
				_search.get_parent().hide()
				_comparison.show()
				_comparison.call("present", own, blueprint, _state)
				_description.hide()
				_roles_toggle.hide()
			else:
				_preview.show()
				_preview.call("show_blueprint", blueprint)
				for id in Records.part_ids(blueprint):
					_add_part_tile(id, Records.as_dictionary(_state.get("unlocked_parts", {})).has(id))
	elif _tabs.current_tab == 4:
		_goal_progress.max_value = row.target
		_goal_progress.value = row.current
		_goal_progress.show()
		_pin.show()
	elif _tabs.current_tab == 1:
		if row.category != "missing":
			_preview.show()
			_preview.call("show_part", str(row.id), bool(row.unlocked))
		_wish.visible = row.get("wished", false) or (not row.unlocked and row.category != "missing")
		_pin.visible = row.get("wished", false)
	_render_entry_text()
	_layout()


func _render_entry_text() -> void:
	var row: Dictionary = _selected_row
	if row.is_empty(): return
	_title.text = Text.name(row, _tabs.current_tab)
	_parts_label.text = ""
	_status_badge.text = ""
	if _tabs.current_tab == ANIMALS_TAB: return
	if _tabs.current_tab == 0:
		var profile: Dictionary = Suitability.read(row, _animal_contract)
		_animal_roles.text = Suitability.describe(profile) if Records.as_dictionary(row.get("scan", {})).get("complete", false) else Text.text("JOURNAL_UNSCANNED")
		var roles: Array = profile.get("roles", []).map(func(role: String) -> String: return Text.text(Suitability.ROLES[role]))
		_roles_toggle.text = Text.text("Tierrollen · %s") % (" · ".join(roles) if not roles.is_empty() else Text.text("noch nicht bekannt"))
		_roles_toggle.tooltip_text = Text.text("Gespeicherte Art-Eignung ein- oder ausblenden. Kein Tierbesitz.")
		_description.text = Text.text("JOURNAL_SPECIES_DETAIL") % [Text.text(Records.ROLES.get(str(row.get("role", "")), "Noch nicht bekannt")), Text.location(row)]
		var has_view: bool = _preview.visible or _comparison.visible
		if not has_view:
			_description.text += Text.text("JOURNAL_MISSING_VIEW")
		else:
			_compare_button.tooltip_text = Text.text("Dein Körperbau ist noch nicht verfügbar." if _compare_button.disabled else "Körperbauwerte und beobachtete Teile vergleichen.")
			_compare_button.text = Text.text("Zur Artenansicht" if _comparison.visible else "Mit meiner Kreatur vergleichen")
			_description.text += Text.text("JOURNAL_VIEW_HINT")
			_parts_label.text = Text.text("KÖRPERTEILE DIESER ART")
		var awarded: String = str(row.get("unlocked_part", ""))
		if not awarded.is_empty(): _description.text += Text.text("JOURNAL_AWARDED") % Text.part(awarded)
	elif _tabs.current_tab == 4:
		var goal := Text.goal(row)
		_description.text = Text.text("JOURNAL_GOAL_DETAIL") % [goal.description, row.current, row.target, goal.unit, Text.text("Ziel erreicht" if row.complete else "In Arbeit")]
	elif _tabs.current_tab == 2:
		_description.text = Text.text("JOURNAL_REGION_DETAIL") % [Text.location(row), Records.saved_integer(row.get("x", "?")), Records.saved_integer(row.get("z", "?"))]
	else:
		_status_badge.text = Text.text("FREIGESCHALTET" if row.unlocked else "GESPERRT · SILHOUETTE") + "  /  " + Text.text(Records.CATEGORIES.get(row.category, "Teil"))
		var description := Text.text("Dieses gespeicherte Teil ist im aktuellen Teilekatalog nicht verfügbar.") if row.category == "missing" else Text.part(row.id, "description")
		_description.text = description + "\n\n" + Text.source(row.id, _state)
		if row.unlocked and row.category != "missing": _parts_label.text = Text.text("Im Kreatureneditor verfügbar · Buch schließen und F2 drücken.")
		_wish.text = Text.text("Von Merkliste entfernen" if row.get("wished", false) else "Auf Merkliste setzen")
		if row.get("wished", false) and row.unlocked: _description.text += Text.text("JOURNAL_WISH_COMPLETE")
		elif not row.unlocked and row.category != "missing": _description.text += Text.text("JOURNAL_WISH_HINT")
	if _pin.visible:
		var id: String = "part:" + _selected_key if _tabs.current_tab == 1 else _selected_key
		_pin.text = Text.text("Nicht mehr verfolgen" if _state.get("research", {}).get("pinned", "") == id else "Im Spiel verfolgen")
	for tile: Button in _parts_grid.get_children():
		tile.text = Text.part(tile.get_meta("part_id")) + "\n" + Text.text("Verfügbar" if tile.get_meta("unlocked") else "Gesperrt")


func _row_label(row: Dictionary) -> String:
	if _tabs.current_tab == ANIMALS_TAB: return AnimalText.list_text(row)
	var label := Text.name(row, _tabs.current_tab)
	if _tabs.current_tab == 1:
		label = ("✓  " if row.get("unlocked", false) else "○  ") + label
		if row.get("wished", false): label += Text.text(" · gemerkt")
	elif _tabs.current_tab == 4: label = ("✓  " if row.complete else "○  ") + label
	return label


func _row_tooltip(row: Dictionary) -> String:
	if _tabs.current_tab == 1: return Text.source(row.id, _state)
	return Text.location(row) if _tabs.current_tab in [0, 2] else str(row.get("location", ""))


func _render_empty() -> void:
	if _tabs.current_tab == 3:
		_title.text = Text.text("Dein nächster Schritt")
		_description.text = _current_hint()
		_guide.text = Text.Text.format_text("JOURNAL_GUIDE", {"scan": Records.KeyHints.binding_label("inspection_mode")})
	elif _tabs.current_tab == ANIMALS_TAB:
		_title.text = AnimalText.text("Eigene Tiere")
		_description.text = AnimalText.result_text(_animals_result_code)
	elif _tabs.current_tab == 1 and _status.selected == 3 and _search.text.is_empty():
		_title.text = Text.text("Deine Teile-Merkliste")
		_description.text = Text.text("Wähle unter »Noch gesperrt« ein Körperteil und setze es auf deine Merkliste. Du kannst ein Wunschteil als Ziel im Spiel verfolgen.")
	else:
		var first: bool = _tabs.current_tab == 0 and Records.as_dictionary(_state.get("discovered_species", {})).is_empty()
		_title.text = Text.text("Noch keine Arten entdeckt" if first else "Keine passenden Einträge")
		_description.text = Text.text("Öffne den Scanmodus und halte ein Tier 2,5 Sekunden im Fadenkreuz. Sobald der Kreis voll ist, erscheint die Art hier." if first else "Ändere die Suche oder den Filter, um weitere Einträge zu sehen.")


func _player_blueprint() -> Dictionary:
	var active_player := player if is_instance_valid(player) else get_tree().get_first_node_in_group(&"player")
	if active_player == null:
		return {}
	var visual := active_player.get_node_or_null("CreatureRuntimeVisual")
	if visual == null:
		return {}
	var value: Variant = visual.get("blueprint")
	return value.duplicate(true) if value is Dictionary else {}


func _toggle_comparison() -> void:
	_comparison_mode = not _comparison_mode
	var selected: PackedInt32Array = _list.get_selected_items()
	if not selected.is_empty():
		_select_entry(selected[0])


func _clear_comparison() -> void:
	_compare_button.hide()
	_comparison.call("clear")
	_comparison.hide()
	_description.show()
	_list.get_parent().visible = _tabs.current_tab != 3
	_search.get_parent().visible = _tabs.current_tab != 3


func _show_pin(id: String) -> void:
	_pin.show()
	_pin.text = "Nicht mehr verfolgen" if _state.get("research", {}).get("pinned", "") == id else "Im Spiel verfolgen"


func _pin_selected() -> void:
	if _selected_key.is_empty():
		return
	var id: String = "part:" + _selected_key if _tabs.current_tab == 1 else _selected_key
	if _state.get("research", {}).get("pinned", "") == id:
		id = ""
	_research_result(_progression.call("set_research_pin", id))


func _toggle_wish() -> void:
	if _selected_key.is_empty():
		return
	var wishes: Array = _state.get("research", {}).get("wished_parts", [])
	_research_result(_progression.call("set_part_wished", _selected_key, not wishes.has(_selected_key)))


func _research_result(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	_action_message.show()
	if result.get("ok", false):
		_action_message.text = Text.text("Auswahl gespeichert.")
	else:
		match str(result.get("reason", "")):
			"wishlist_full": _action_message.text = Text.text("Deine Merkliste ist voll (32 Teile). Entferne zuerst ein anderes Teil.")
			"part_unavailable": _action_message.text = Text.text("Dieses Teil ist bereits verfügbar oder fehlt im Teilekatalog.")
			"save_in_progress": _action_message.text = Text.text("Es wird gerade gespeichert. Versuche es gleich erneut.")
			_: _action_message.text = Text.text("Speichern fehlgeschlagen. Deine bisherige Auswahl bleibt erhalten; du kannst es erneut versuchen.")


func _on_research_changed() -> void:
	_action_message.hide()
	if is_open:
		refresh()
	_update_research_hud()


func _update_research_hud() -> void:
	if _progression == null:
		return
	_pinned_row = _progression.call("get_pinned_research")
	_pinned_button.visible = not _pinned_row.is_empty()
	_layout()
	if _pinned_row.is_empty():
		return
	var row := Text.goal(_pinned_row)
	var status: String = Text.text("Ziel erreicht" if row.complete else "Dein Forschungsziel")
	if not _pinned_row["available"]:
		status = Text.text("Ziel nicht verfügbar")
	_pinned_button.text = Text.text("JOURNAL_PINNED") % [status, row.name, row.current, row.target, row.unit]
	_pinned_button.tooltip_text = _pinned_button.text


func _open_pinned() -> void:
	if _pinned_row.is_empty() or not open_journal():
		return
	_tabs.current_tab = 1 if _pinned_row["kind"] == "part" else 4
	_search.clear()
	_filter.select(0)
	if _tabs.current_tab == 1:
		_status.select(3)
	_selected_key = _pinned_row["key"]
	_page = 0
	_apply_filters()


func _current_hint() -> String:
	if _progression == null:
		return Text.text("Entdecke deine Welt.")
	if int(get_node("/root/GameState").current_phase) == 1:
		return Text.text("Dein Stamm · wähle Bewohner aus und gib der Gruppe einen Auftrag. J öffnet eure gemeinsamen Entdeckungen.")
	var state := {"discovered_species": _progression.get("discovered_species")}
	var active_player := player if player != null else get_tree().get_first_node_in_group(&"player")
	if active_player != null and active_player.has_method("get_health_ratio"):
		return Text.hint(state, float(active_player.call("get_health_ratio")), float(active_player.call("get_thirst_ratio")), float(active_player.call("get_hunger_ratio")))
	return Text.hint(state)


func _update_hint() -> void:
	_hint.visible = _hint_enabled
	if _hint_enabled:
		_hint.text = _current_hint()


func _toggle_hint(enabled: bool) -> void:
	_hint_enabled = enabled
	_update_hint()
	var prefs := ConfigFile.new()
	prefs.set_value("journal", "show_hint", enabled)
	if prefs.save(PREFS_PATH) != OK:
		_hint.tooltip_text = Text.text("Die Anzeige wurde geändert, konnte aber nicht für den nächsten Start gespeichert werden.")


func _on_discovery(_key: String, _name: String) -> void:
	if is_open:
		refresh()
	_update_hint()
	_update_research_hud()


func _on_points(_points: int) -> void:
	# Import/reset emit this too. No fabricated discovery notification on loading.
	if is_open:
		call_deferred("refresh")
	_update_hint()
	_update_research_hud()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	if not text.is_empty(): Text.bind(label, "text", text)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	if not text.is_empty(): Text.bind(button, "text", text)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 40
	button.pressed.connect(action)
	return button


func _box(color: Color, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_border_width_all(1)
	box.border_color = Color("344c5d")
	box.set_corner_radius_all(3)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	for type in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "ItemList", "TabBar"]:
		theme.set_color("font_color", type, Color("e7eff2"))
		theme.set_color("font_selected_color", type, Color("ffffff"))
	for type in ["Button", "OptionButton", "LineEdit"]:
		theme.set_stylebox("normal", type, _box(Color("1c3040")))
		theme.set_stylebox("hover", type, _box(Color("2e4b5b")))
		theme.set_stylebox("pressed", type, _box(Color("356557")))
		var focus: StyleBoxFlat = _box(Color(0, 0, 0, 0))
		focus.border_color = Color("e0c785")
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type, focus)
	theme.set_stylebox("panel", "ItemList", _box(Color("142431")))
	theme.set_stylebox("selected", "ItemList", _box(Color("2c4c56")))
	theme.set_stylebox("selected_focus", "ItemList", _box(Color("365f67")))
	theme.set_stylebox("tab_selected", "TabBar", _box(Color("2c4f59")))
	theme.set_stylebox("tab_unselected", "TabBar", _box(Color("172936")))
	return theme


func _layout_catalog() -> void:
	_layout()
	var extent: Vector2 = get_viewport().get_visible_rect().size / maxf(_scale_factor, 0.001)
	_browser.size_flags_vertical = Control.SIZE_FILL if _content.vertical else Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 72 if _content.vertical else 0
	_list.fixed_icon_size = Vector2i(60, 60) if extent.x < 940 else Vector2i(78, 78)
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.clip_tabs = true
	_parts_grid.columns = 1 if extent.x < 640 else 2


func _visual_key(row: Dictionary, tab: int) -> String:
	return str(tab) + ":" + str(row.get("id", row.get("key", ""))) + ":" + str(row.get("unlocked", true))


func _render_thumbnails() -> void:
	if _thumbnail_running or not is_open or DisplayServer.get_name() == "headless":
		return
	_thumbnail_running = true
	while not _thumbnail_queue.is_empty() and is_open:
		var job: Dictionary = _thumbnail_queue.pop_front()
		var generation: int = _thumbnail_generation
		var row: Dictionary = job["row"]
		if int(job["tab"]) == 1:
			_thumbnail_preview.call("show_part", str(row["id"]), bool(row["unlocked"]))
		else:
			var blueprint: Dictionary = Records.visual_for(_catalog.species_detail(str(row.get("key", ""))))
			if blueprint.is_empty(): continue
			_thumbnail_preview.call("show_blueprint", blueprint)
		await RenderingServer.frame_post_draw
		if not is_inside_tree() or not is_open: break
		if generation != _thumbnail_generation: continue
		var picture: Image = _thumbnail_preview.viewport.get_texture().get_image()
		var texture := ImageTexture.create_from_image(picture)
		if _thumbnail_cache.size() >= 192: _thumbnail_cache.clear()
		_thumbnail_cache[job["key"]] = texture
		for index in range(_list.item_count):
			if _list.get_item_metadata(index) == job["key"]:
				_list.set_item_icon(index, texture)
		for tile in _parts_grid.get_children():
			if tile.get_meta("visual_key", "") == job["key"]:
				tile.icon = texture
		await get_tree().process_frame
	_thumbnail_preview.call("clear")
	_thumbnail_running = false


func _clear_part_tiles() -> void:
	if _parts_grid == null: return
	for child in _parts_grid.get_children():
		_parts_grid.remove_child(child)
		child.queue_free()


func _add_part_tile(id: String, unlocked: bool) -> void:
	var row: Dictionary = {"id": id, "unlocked": unlocked}
	var key: String = _visual_key(row, 1)
	var tile := _button(str(Records.Parts.get_part(id).get("name", id)) + ("\nVerfügbar" if unlocked else "\nGesperrt"), func() -> void:
		_tabs.current_tab = 1
		_status.select(0)
		_filter.select(0)
		_search.clear()
		_selected_key = id
		_apply_filters())
	tile.remove_meta("journal_text")
	tile.set_meta("part_id", id)
	tile.set_meta("unlocked", unlocked)
	tile.set_meta("visual_key", key)
	tile.icon = _thumbnail_cache.get(key, Symbols.texture("part", unlocked))
	tile.expand_icon = true
	tile.add_theme_constant_override("icon_max_width", 60)
	tile.add_theme_font_size_override("font_size", 14)
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size.y = 74
	_parts_grid.add_child(tile)
	if not _thumbnail_cache.has(key):
		_thumbnail_queue.append({"row": row, "tab": 1, "key": key})
	_render_thumbnails()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if not _language_pending:
			_language_pending = true
			call_deferred("_refresh_language")

func _refresh_summary() -> void:
	_summary.text = AnimalText.format_text("OWNED_JOURNAL_SUMMARY", {
		"species": Records.as_dictionary(_state.get("discovered_species", {})).size(),
		"regions": Records.as_dictionary(_state.get("discovered_regions", {})).size(),
		"parts": Records.as_dictionary(_state.get("unlocked_parts", {})).size(),
		"points": int(_state.get("discovery_points", 0))})

func _refresh_page_label() -> void:
	_page_label.text = AnimalText.format_text("OWNED_JOURNAL_PAGE", {
		"count": _row_total, "page": _page + 1, "pages": maxi(ceili(float(_row_total) / PAGE_SIZE), 1)})

func _refresh_animal_language() -> void:
	_refresh_summary()
	_refresh_page_label()
	if _tabs.current_tab != ANIMALS_TAB: return
	# No read/filter/reselection: preserve search/caret, page, list and scrolls.
	for index in _rows.size(): _rows[index] = AnimalText.project(_rows[index]._display_data)
	for index in _list.item_count:
		var row: Dictionary = _rows[_page * PAGE_SIZE + index]
		var label: String = AnimalText.list_text(row)
		_list.set_item_text(index, label)
		_list.set_item_tooltip(index, label + " · " + str(row.location))
	if _rows.is_empty():
		_title.text = AnimalText.text("Eigene Tiere")
		_description.text = AnimalText.result_text(_animals_result_code)
	else:
		for row: Dictionary in _rows:
			if row.key == _selected_key:
				_title.text = row.name
				_owned_register.present(row)
				break
	_layout()

func _animal_fonts(node: Node, scale: float) -> void:
	if node is Control and node != _title and node.get_class() in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit", "ItemList", "TabBar"]:
		if not node.has_meta("animal_base_font"):
			node.set_meta("animal_base_font", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("animal_base_font")) * scale))
	for child in node.get_children(): _animal_fonts(child, scale)

func _refresh_language() -> void:
	_language_pending = false
	if not is_inside_tree(): return
	var detail_scroll := _detail_scroll.scroll_vertical
	var list_scroll := _list.get_v_scroll_bar().value
	Text.refresh(_surface)
	Text.refresh(_hud)
	for index in _tabs.tab_count:
		_tabs.set_tab_title(index, Text.text(TAB_TITLES[index]))
		_compact_tabs.set_item_text(index, Text.text(TAB_TITLES[index]))
	for index in _status.item_count: _status.set_item_text(index, Text.text(STATUS_TITLES[index]))
	for index in _filter.item_count:
		var code: String = str(_filter.get_item_metadata(index))
		var label := ""
		if _tabs.current_tab == ANIMALS_TAB:
			label = Text.text({"living": "Lebende Tiere", "dead": "Verstorbene Tiere", "all": "Alle eigenen Tiere"}.get(code, code))
		elif code.is_empty(): label = Text.text("Alle Lebensweisen / Tierrollen" if _tabs.current_tab == 0 else "Alle Kategorien")
		elif code.begins_with("domestic:"): label = Text.text("Tierrolle: %s") % Text.text(Suitability.ROLES[code.trim_prefix("domestic:")])
		else: label = Text.text((Records.ROLES if _tabs.current_tab == 0 else Records.CATEGORIES).get(code, code))
		_filter.set_item_text(index, label)
	if is_open:
		if _tabs.current_tab == ANIMALS_TAB:
			_refresh_animal_language()
		else:
			for index in _list.item_count:
				var row: Dictionary = _rows[_entry_index(index)]
				_list.set_item_text(index, _row_label(row))
				_list.set_item_tooltip(index, _row_label(row) + " · " + _row_tooltip(row))
			if _selected_row.is_empty() or _tabs.current_tab == 3: _render_empty()
			else: _render_entry_text()
			if _comparison.visible: _comparison.refresh_language()
		_refresh_summary()
		_refresh_page_label()
	if _action_message.visible: _research_result(_last_result)
	_update_hint()
	_update_research_hud()
	_layout()
	_detail_scroll.set_deferred("scroll_vertical", detail_scroll)
	_list.get_v_scroll_bar().set_deferred("value", list_scroll)
