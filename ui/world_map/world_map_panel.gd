extends CanvasLayer
const Keys = preload("res://core/input_preferences.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/world_map/atlas_presentation.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Profile = preload("res://core/map/minimap_profile.gd")
const ProjectionModel = preload("res://core/map/atlas_projection.gd")
const Raster = preload("res://ui/minimap/minimap_terrain.gd")
const Tracker = preload("res://ui/world_map/exploration_tracker.gd")
const Source = preload("res://ui/world_map/world_map_source.gd")
const Markers = preload("res://ui/minimap/map_markers.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const PlaceQuery = preload("res://ui/world_map/atlas_place_query.gd")
var player: Node3D
var lab: Node3D
var tracker: Node
var is_open: bool = false
var _closing: bool = false
var _owns_pause: bool = false
var _previous_mouse: int
var _previous_focus: WeakRef
var projection := ProjectionModel.new()
var terrain := Raster.new(128)
var range_m: float = 192.0
var _places: Array[Dictionary] = []
var _place_offset: int = 0
var _place_total: int = 0
var _place_pager: HBoxContainer
var _place_previous: Button
var _place_next: Button
var _place_page_label: Label
var _place_search: LineEdit
var _search_status: Label
var _place_query := PlaceQuery.new()
var _search_delay: float = 0.0
var _search_pending: bool = false
var _show_own: bool = true
var _show_friends: bool = true
var _selected: String = ""
var _small: bool = false
var _show_list: bool = false
var _font_scale: float = 1.0
var _panel: PanelContainer
var _column: VBoxContainer
var _canvas: Control
var _body: HBoxContainer
var _sidebar: VBoxContainer
var _places_header: Label
var _legend: HFlowContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _detail: Label
var _scale_label: Label
var _close: Button
var _places_toggle: Button
var _header: Label
var _help: Label
var _request_delay: float = 0.0
var _request_pending: bool = false
var _rect_pending: bool = false

func _ready() -> void:
	name = "WorldMap"
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"world_map")
	terrain.sample_limit = 256
	tracker = Tracker.new()
	tracker.player = player
	tracker.lab = lab
	add_child(tracker)
	_build()
	_panel.minimum_size_changed.connect(_queue_panel_rect)
	hide()
	get_viewport().size_changed.connect(_layout)
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: close_map())
	get_node("/root/GameState").world_seed_changed.connect(func(_seed: int) -> void: close_map())
	_layout()

func shortcut_text() -> String:
	return Keys.binding_label("open_world_map")

func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.031, 0.094, 0.125, 0.94)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = PanelContainer.new()
	_panel.name = "WorldMapPanel"
	_panel.theme = Style.theme()
	_panel.theme.set_stylebox("normal", "Button", Style.box(Style.PANEL, Style.CONTROL))
	_panel.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.EDGE, 16))
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	_panel.add_child(_column)
	var header := HBoxContainer.new()
	_column.add_child(header)
	_header = Style.label(header, "Weltkarte", 32)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close = _button(header, "Schließen", close_map, "CloseWorldMap")
	_close.tooltip_text = "Karte schließen · Esc"
	var tools_row := HFlowContainer.new()
	tools_row.add_theme_constant_override("h_separation", 8)
	_column.add_child(tools_row)
	_button(tools_row, "−", func() -> void: zoom(1), "AtlasZoomOut").tooltip_text = "Weiter herauszoomen"
	_button(tools_row, "+", func() -> void: zoom(-1), "AtlasZoomIn").tooltip_text = "Näher heranzoomen"
	_button(tools_row, "Zu mir", focus_player, "AtlasPlayer")
	_button(tools_row, "Erkundetes", fit_explored, "AtlasExplored")
	_places_toggle = _button(tools_row, "Orte", func() -> void: _show_list = not _show_list; _layout(), "AtlasPlaces")
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(_body)
	_canvas = preload("res://ui/world_map/world_map_canvas.gd").new()
	_canvas.name = "AtlasCanvas"
	_canvas.terrain = terrain
	_canvas.custom_minimum_size = Vector2(180, 180)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.tooltip_text = "Linksklick ziehen: Karte verschieben · Mausrad: zoomen\nPfeiltasten: verschieben · + / −: zoomen · Pos1: zu dir"
	_canvas.dragged.connect(_pan_pixels)
	_canvas.zoomed.connect(zoom)
	_canvas.place_selected.connect(select_place)
	_body.add_child(_canvas)
	_sidebar = VBoxContainer.new()
	_sidebar.custom_minimum_size.x = 280
	_body.add_child(_sidebar)
	_places_header = Style.label(_sidebar, "Bekannte Orte", 22)
	_place_search = LineEdit.new()
	_place_search.name = "AtlasPlaceSearch"
	_place_search.placeholder_text = "ATLAS_SEARCH_PLACEHOLDER"
	_place_search.tooltip_text = "ATLAS_SEARCH_TOOLTIP"
	_place_search.clear_button_enabled = true
	_place_search.max_length = 180
	_place_search.custom_minimum_size.y = 44
	_place_search.text_changed.connect(_search_changed)
	_sidebar.add_child(_place_search)
	_search_status = Style.label(_sidebar, "", 16, Style.MUTED)
	_search_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_search_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_search_status.hide()
	var filters := HBoxContainer.new()
	_sidebar.add_child(filters)
	for own in [true, false]:
		var button := _button(filters, "Eigene" if own else "Freunde", func() -> void: pass, "AtlasOwnFilter" if own else "AtlasFriendFilter")
		button.toggle_mode = true
		button.button_pressed = true
		button.toggled.connect(func(enabled: bool) -> void:
			if own: _show_own = enabled
			else: _show_friends = enabled
			_search_pending = false
			_refresh_places())
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_place_pager = HBoxContainer.new()
	_sidebar.add_child(_place_pager)
	_place_previous = _button(_place_pager, "←", func() -> void: _turn_place_page(-1), "AtlasPlacesPrevious")
	_place_page_label = Style.label(_place_pager, "", 18)
	_place_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_place_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_next = _button(_place_pager, "→", func() -> void: _turn_place_page(1), "AtlasPlacesNext")
	_place_previous.tooltip_text = "ATLAS_SEARCH_PREVIOUS"
	_place_next.tooltip_text = "ATLAS_SEARCH_NEXT"
	_place_pager.hide()
	var legend := HFlowContainer.new()
	_legend = legend
	legend.add_theme_constant_override("h_separation", 16)
	_sidebar.add_child(legend)
	for pair in [["nest", "Eigenes Nest"], ["home", "Heimat"], ["friend_habitat", "Befreundet"]]:
		var row := HBoxContainer.new()
		legend.add_child(row)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(24, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		icon.draw.connect(func() -> void: Markers.draw_place(icon, icon.size * 0.5, pair[0]))
		Style.label(row, pair[1], 18)
	_scale_label = Style.label(_column, "", 18, Style.MUTED)
	_detail = Style.paragraph(_column, "Dunkle Flächen sind noch nicht erkundet.", 18)
	_detail.max_lines_visible = 2
	_detail.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_scale_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_help = Style.label(_column, "Ziehen: verschieben · Mausrad: zoomen · Ortsname: Karte zentrieren", 16, Style.MUTED)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _button(parent: Node, text: String, action: Callable, id: String = "") -> Button:
	var button := Button.new()
	button.text = text
	if not id.is_empty(): button.name = id
	button.custom_minimum_size = Vector2(44, 44)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func open_map() -> bool:
	if is_open or _closing or get_tree().paused: return false
	tracker.update_exploration()
	if tracker.snapshot.is_empty() or tracker.atlas.data.is_empty():
		if not tracker.problem.is_empty():
			if is_instance_valid(lab): lab.status.text = Presentation.problem_text(tracker.problem_code)
			elif is_instance_valid(player) and player.has_method("show_gameplay_message"): player.show_gameplay_message(Presentation.problem_text(tracker.problem_code))
		return false
	var data: Dictionary = tracker.snapshot
	if not projection.configure(data.address, float(data.body_radius)): return false
	_previous_mouse = Input.mouse_mode
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_open = true
	show()
	_show_list = false
	_selected = ""
	_place_offset = 0
	_place_search.text = ""
	_search_pending = false
	_place_query.cancel()
	range_m = Profile.for_phase(int(data.phase)).radius_m * 3.0
	terrain.reset()
	_request_delay = 0
	projection.center = projection.project(data.explorers[0] if not data.explorers.is_empty() else data.address)
	_refresh_places()
	_request()
	_layout()
	_canvas.grab_focus()
	return true

func close_map() -> void:
	if not is_open: return
	is_open = false
	_search_pending = false
	_place_query.cancel()
	_closing = true
	hide()
	_canvas.cancel_drag()
	terrain.reset()
	_release_later()

func _release_later() -> void:
	await get_tree().process_frame
	if not is_inside_tree(): return
	_closing = false
	_release_pause()
	var previous: Object = _previous_focus.get_ref() if _previous_focus != null else null
	if previous is Control and previous.is_visible_in_tree(): previous.grab_focus()

func _release_pause() -> void:
	if not _owns_pause: return
	_owns_pause = false
	if get_tree() != null: get_tree().paused = false
	Input.mouse_mode = _previous_mouse

func _exit_tree() -> void:
	_place_query.cancel()
	_release_pause()

func _input(event: InputEvent) -> void:
	if _closing: get_viewport().set_input_as_handled(); return
	if not is_open or not event is InputEventKey: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if _place_search.has_focus():
		# Let the LineEdit receive letters (including M), arrows, clipboard and
		# selection shortcuts. Escape first leaves text input; then closes the map.
		if event.pressed and not event.echo and key == KEY_ESCAPE:
			_canvas.grab_focus() if _canvas.is_visible_in_tree() else _places_toggle.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if event.pressed and not event.echo and key == KEY_F and (event.ctrl_pressed or event.meta_pressed):
		_show_list = true
		_layout()
		_place_search.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.pressed and not event.echo:
		if Keys.menu_event(event, "open_world_map"):
			close_map()
			get_viewport().set_input_as_handled()
			return
		match key:
			KEY_ESCAPE: close_map()
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: zoom(-1)
			KEY_MINUS, KEY_KP_SUBTRACT: zoom(1)
			KEY_HOME: focus_player()
			KEY_LEFT: _pan_pixels(Vector2(64, 0))
			KEY_RIGHT: _pan_pixels(Vector2(-64, 0))
			KEY_UP: _pan_pixels(Vector2(0, 64))
			KEY_DOWN: _pan_pixels(Vector2(0, -64))
	if key not in [KEY_TAB, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and Keys.menu_event(event, "open_world_map"):
		if open_map(): get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_open: return
	if _search_pending:
		_search_delay -= delta
		if _search_delay <= 0.0:
			_search_pending = false
			_refresh_places()
	elif _place_query.active:
		_place_query.step()
		if not _place_query.active: _finish_search()
		else: _update_search_status()
	_request_delay -= delta
	if _request_pending and _request_delay <= 0.0:
		_request_pending = false
		_request_delay = 0.08
		terrain.request(projection.center, range_m, _sample)
	terrain.step_work()
	if not tracker.problem.is_empty(): _detail.text = tracker.problem
	_canvas.queue_redraw()

func _sample(point: Vector2) -> Color:
	var address: Dictionary = projection.address_at(point)
	if address.is_empty() or not tracker.atlas.known(address): return Style.INK
	return tracker.snapshot.sample.call(address)

func _request() -> void:
	projection.center = projection.clamp_center(projection.center)
	_request_pending = true
	_canvas.explorers.clear()
	for address: Dictionary in tracker.snapshot.get("explorers", []): _canvas.explorers.append(projection.project(address))
	_refresh_canvas_places()
	_refresh_description()

func zoom(direction: int, screen_point: Vector2 = Vector2(INF, INF)) -> void:
	if not is_open: return
	var previous: float = range_m
	var maximum: float = PI * projection.radius if projection.radius > 0 else 1048576.0
	range_m = clampf(range_m * pow(1.5, direction), 48.0, maximum)
	if screen_point.is_finite() and minf(_canvas.size.x, _canvas.size.y) > 0:
		projection.center += (screen_point - _canvas.size * 0.5) / minf(_canvas.size.x, _canvas.size.y) * 2.0 * (previous - range_m)
	_request()

func _pan_pixels(delta: Vector2) -> void:
	if minf(_canvas.size.x, _canvas.size.y) <= 0: return
	projection.center -= delta / minf(_canvas.size.x, _canvas.size.y) * 2.0 * range_m
	_request()

func focus_player() -> void:
	if tracker.snapshot.is_empty(): return
	var explorers: Array = tracker.snapshot.get("explorers", [])
	projection.center = projection.project(explorers[0] if not explorers.is_empty() else tracker.snapshot.address)
	_show_list = false
	_request()
	_layout()

func fit_explored() -> void:
	var extent: Array = tracker.atlas.explored_extent()
	if extent.is_empty(): focus_player(); return
	var start := Vector2(extent[0], extent[1])
	var end := Vector2(extent[2], extent[3])
	if projection.local.mode != Cube.MODE:
		var origin: Array = projection.local.origin.position
		start -= Vector2(origin[0], origin[2])
		end -= Vector2(origin[0], origin[2])
	var bounds := Rect2(start, end - start)
	projection.center = bounds.get_center()
	range_m = maxf(maxf(bounds.size.x, bounds.size.y) * 0.6, 64.0)
	_show_list = false
	_request()
	_layout()

func _refresh_places() -> void:
	_search_pending = false
	_place_query.cancel()
	if _uses_place_query():
		_start_search()
		return
	_search_status.hide()
	var page: Dictionary = Source.visible_place_page(tracker.atlas, get_tree(), _place_offset)
	_places.clear()
	_place_total = int(page.get("total", 0))
	if not page.is_empty(): _places.assign(page.places)
	var page_size: int = tracker.atlas.Places.PAGE_SIZE
	_place_pager.visible = _place_total > page_size
	_place_previous.disabled = _place_offset <= 0
	_place_next.disabled = _place_offset + page_size >= _place_total
	_place_page_label.text = "%d / %d" % [floori(float(_place_offset) / page_size) + 1, maxi(1, ceili(float(_place_total) / page_size))]
	_render_places()

func _render_places() -> void:
	for child in _list.get_children(): _list.remove_child(child); child.queue_free()
	var shown: int = 0
	for place: Dictionary in _places:
		if not _place_visible(place): continue
		shown += 1
		var button := _button(_list, Presentation.place_name(place), func() -> void: select_place(place.id))
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.set_meta("atlas_place_id", place.id)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = place.id == _selected
		button.tooltip_text = Presentation.place_name(place)
	if shown == 0 and not _uses_place_query(): Style.paragraph(_list, "Hier erscheinen deine Nester und bekannte Orte befreundeter Kreaturen.", 18)
	_refresh_canvas_places()
	_refresh_description()

func _uses_place_query() -> bool:
	return not _place_search.text.strip_edges().is_empty() or not _show_own or not _show_friends

func _search_changed(_value: String) -> void:
	_place_offset = 0
	_selected = ""
	_place_query.cancel()
	_places.clear()
	_render_places()
	_scroll.scroll_vertical = 0
	_search_pending = true
	_search_delay = 0.18
	_place_previous.disabled = true
	_place_next.disabled = true
	_search_status.text = Text.text("ATLAS_SEARCH_WAITING")
	_search_status.show()

func _start_search() -> void:
	_places.clear()
	_place_query.begin(tracker.atlas, _place_search.text, _show_own, _show_friends, _place_offset,
		func(place: Dictionary) -> bool: return Source.place_is_visible(place, tracker.atlas.data.body_id, get_tree()), Presentation.place_name)
	_place_previous.disabled = true
	_place_next.disabled = true
	_place_pager.visible = _place_offset > 0
	_render_places()
	# Tiny registers finish immediately; large ones resume with the same bounded
	# amount of work in _process, which also runs while the atlas owns the pause.
	_place_query.step()
	if not _place_query.active: _finish_search()
	else: _update_search_status()

func _finish_search() -> void:
	if _place_query.invalidated:
		close_map()
		return
	if not _place_query.failed and _place_query.results.is_empty() and _place_offset > 0:
		# A narrower filter may have fewer pages; find the last available page.
		_place_offset = maxi(0, floori(float(_place_query.matched - 1) / PlaceQuery.PAGE_SIZE)) * PlaceQuery.PAGE_SIZE
		_start_search()
		return
	_places.assign(_place_query.results)
	_place_previous.disabled = _place_offset <= 0 or _place_query.failed
	_place_next.disabled = not _place_query.has_next or _place_query.failed
	_place_pager.visible = not _place_query.failed and (_place_offset > 0 or _place_query.has_next)
	_place_page_label.text = Text.format_text("ATLAS_SEARCH_PAGE", {"page": _place_offset / PlaceQuery.PAGE_SIZE + 1})
	_render_places()
	_update_search_status()
	_layout()

func _update_search_status() -> void:
	_search_status.show()
	if _place_query.failed:
		_search_status.text = Text.text("ATLAS_SEARCH_FAILED")
	elif _place_query.active:
		_search_status.text = Text.format_text("ATLAS_SEARCH_PROGRESS", {"scanned": _place_query.scanned, "total": _place_query.total})
	elif _places.is_empty():
		_search_status.text = Text.text("ATLAS_SEARCH_NO_RESULTS")
	else:
		_search_status.text = Text.format_text("ATLAS_SEARCH_RESULTS", {"count": _places.size()})

func _turn_place_page(direction: int) -> void:
	if _search_pending or _place_query.active: return
	if _uses_place_query():
		if (direction > 0 and not _place_query.has_next) or (direction < 0 and _place_offset == 0): return
		_place_offset = maxi(0, _place_offset + direction * PlaceQuery.PAGE_SIZE)
		_scroll.scroll_vertical = 0
		_refresh_places()
		return
	var page_size: int = tracker.atlas.Places.PAGE_SIZE
	var last: int = maxi(0, floori(float(_place_total - 1) / page_size) * page_size)
	_place_offset = clampi(_place_offset + direction * page_size, 0, last)
	_scroll.scroll_vertical = 0
	_refresh_places()
	_layout()

func _place_visible(place: Dictionary) -> bool:
	return _show_own if place.own else _show_friends

func _refresh_canvas_places() -> void:
	_canvas.places.clear()
	for place: Dictionary in _places:
		if not _place_visible(place): continue
		var copy: Dictionary = place.duplicate()
		copy["position"] = projection.project(place.address)
		copy["display_name"] = Presentation.place_name(place)
		_canvas.places.append(copy)
	_canvas.selected_id = _selected
	_canvas.queue_redraw()

func select_place(id: String) -> void:
	for place: Dictionary in _places:
		if place.id != id: continue
		_selected = id
		projection.center = projection.project(place.address)
		_show_list = false
		_render_places()
		_request()
		_layout()
		_canvas.grab_focus()
		return

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		call_deferred("_refresh_language")

func _refresh_language() -> void:
	# Do not rebuild the list or request new terrain: selection, focus, scroll,
	# projection and the exploration record all belong to the existing session.
	if not is_instance_valid(_panel) or not is_instance_valid(tracker): return
	if is_open and not _place_search.text.strip_edges().is_empty():
		# Built-in names change language; keep the term and map position, but
		# recompute membership. Player-authored names stay verbatim.
		_search_pending = false
		_refresh_places()
		return
	var labels: Dictionary = {}
	for place: Dictionary in _places: labels[place.id] = Presentation.place_name(place)
	for child: Node in _list.get_children():
		if child is Button and child.has_meta("atlas_place_id"):
			child.text = labels.get(child.get_meta("atlas_place_id"), child.text)
			child.tooltip_text = child.text
	_refresh_canvas_places()
	_refresh_description()
	if _uses_place_query(): _update_search_status()
	_layout()

func _refresh_description() -> void:
	_scale_label.text = Presentation.scale_text(range_m * 2.0, projection.local.mode == Cube.MODE)
	var selected: Dictionary = {}
	for place: Dictionary in _places:
		if place.id == _selected:
			selected = place
			break
	_detail.text = Presentation.detail_text(selected, tracker.atlas.full)
	_detail.tooltip_text = _detail.text

func _layout() -> void:
	if _panel == null: return
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = logical.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO)
	var pixels: Vector2 = logical / factor
	_font_scale = clampf(float(get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)
	_panel.theme.default_font_size = roundi(20 * _font_scale)
	_canvas.ui_scale = _font_scale
	_scale_contents(_panel)
	_small = pixels.x < 1100 or _font_scale >= 1.5
	_sidebar.visible = not _small or _show_list
	_canvas.visible = not _small or not _show_list
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _small else Control.SIZE_FILL
	_sidebar.custom_minimum_size.x = 0 if _small else 280
	_places_toggle.visible = _small
	# Paging and language changes keep at least one full place action reachable.
	var compact_places: bool = _small and _show_list
	_places_header.visible = not compact_places
	_legend.visible = not compact_places
	_scroll.custom_minimum_size.y = 44 * _font_scale if compact_places else 0.0
	_scale_label.visible = not compact_places
	_detail.visible = not compact_places
	_places_toggle.text = "Zur Karte" if _show_list else "Orte"
	_help.visible = pixels.y >= 720 and not compact_places
	_panel.size = Vector2(minf(pixels.x * 0.94, 1600), pixels.y * 0.92)
	_panel.position = (pixels - _panel.size) * 0.5
	# Container minimum sizes settle after visibility/font changes. Recenter once
	# they have propagated instead of keeping the old, larger panel's origin.
	_queue_panel_rect()

func _queue_panel_rect() -> void:
	if _rect_pending: return
	_rect_pending = true
	call_deferred("_settle_panel_rect")

func _settle_panel_rect() -> void:
	_rect_pending = false
	if not is_instance_valid(_panel): return
	var logical: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = logical.x / maxf(float(get_window().size.x), 1.0)
	transform = Transform2D(0.0, Vector2.ONE * factor, 0.0, Vector2.ZERO)
	var pixels: Vector2 = logical / factor
	_panel.size = Vector2(minf(pixels.x * 0.94, 1600), pixels.y * 0.92)
	_panel.position = (pixels - _panel.size) * 0.5

func _scale_contents(node: Node) -> void:
	if node is Label:
		if not node.has_meta("atlas_font_base"): node.set_meta("atlas_font_base", node.get_theme_font_size("font_size"))
		node.add_theme_font_size_override("font_size", roundi(float(node.get_meta("atlas_font_base")) * _font_scale))
	elif node is Button or node is LineEdit:
		node.custom_minimum_size.y = 44 * _font_scale
	for child in node.get_children(): _scale_contents(child)
