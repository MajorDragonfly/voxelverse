extends Control
## Separate opt-in catalogue. Only explicit searches/downloads make requests.
signal closed
signal imported(key: String)

const Client = preload("res://assembly/exchange/community_catalog_client.gd")
const Library = Client.Library
const Present = preload("res://ui/blueprints/community_gallery_presentation.gd")
const Text = Present.Text
const Style = preload("res://ui/frontend/menu_style.gd")
const Design = preload("res://ui/design/design_system.gd")
const Symbols = preload("res://ui/design/game_symbols.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
var library_path: String = Library.PATH
var prepare_template: Callable
var _client: Client = Client.new()
var _endpoint: String = ""
var _configured: bool = false
var _pages: Array[Dictionary] = []
var _page_index: int = -1
var _selected: Dictionary = {}
var _states: Dictionary = {}
var _pending: int = 0
var _operation: String = ""
var _download_key: String = ""
var _result: Dictionary = {}
var _status_key: String = "CG_IDLE"
var _show_detail: bool = false
var _return_focus: Control
var _title: Label
var _search_row: HBoxContainer
var _search: LineEdit
var _search_button: Button
var _status: Label
var _cancel: Button
var _side: VBoxContainer
var _list: VBoxContainer
var _list_scroll: ScrollContainer
var _previous: Button
var _next: Button
var _page_label: Label
var _detail: VBoxContainer
var _name: Label
var _origin: Label
var _revision: Label
var _requirements: Label
var _download_status: Label
var _download: Button
var _back: Button
var _preview: Preview
var _portrait_frame: PanelContainer
var _preview_blueprint: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Host supplies an explicitly configured endpoint; loopback HTTP is test-only.
## Configuring never contacts the service. There is no default public service.
func configure(endpoint: String, allow_loopback_http: bool = false) -> Dictionary:
	if _pending != 0: return Client.Contract.fail("busy")
	if endpoint.strip_edges().is_empty():
		_configured = false
		_endpoint = ""
		_pages.clear()
		_states.clear()
		_selected.clear()
		_page_index = -1
		visible = false
		return Client.Contract.fail("not_configured")
	var checked: Dictionary = _client.configure(endpoint, allow_loopback_http)
	if not checked.ok: return checked
	_configured = true
	_endpoint = endpoint.trim_suffix("/")
	_pages.clear()
	_states.clear()
	_selected.clear()
	_page_index = -1
	_show_detail = false
	_result.clear()
	_status_key = "CG_IDLE"
	visible = true
	if is_node_ready(): _refresh()
	return checked


func is_available() -> bool:
	return _configured


func _ready() -> void:
	name = "CommunityGallery"
	_return_focus = get_viewport().gui_get_focus_owner()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme = Style.theme()
	add_child(_client)
	_client.completed.connect(_completed)
	var background := ColorRect.new()
	background.color = Style.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 16)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	_back = _button(header, "BP_BACK_LIST", _back_to_list, "GalleryBack")
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Style.label(header, Text.text("CG_TITLE"), 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "BP_CLOSE", _close, "GalleryClose")
	var gallery_mark: TextureRect = Symbols.view("gallery", 34, Design.ACCENT)
	header.add_child(gallery_mark)
	header.move_child(gallery_mark, 1)
	_search_row = HBoxContainer.new()
	content.add_child(_search_row)
	_search = LineEdit.new()
	_search.name = "GalleryQuery"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.y = 44
	_search.right_icon = Symbols.texture("search", Design.MUTED)
	_search.text_submitted.connect(func(_query: String): search())
	_search_row.add_child(_search)
	_search_button = _button(_search_row, "CG_SEARCH", search, "GallerySearch")
	var status_row := HBoxContainer.new()
	content.add_child(status_row)
	_status = Style.paragraph(status_row, "", 17)
	_status.name = "GalleryStatus"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel = _button(status_row, "BP_CANCEL", cancel, "GalleryCancel")
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 20)
	content.add_child(columns)
	_side = VBoxContainer.new()
	columns.add_child(_side)
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "GalleryListScroll"
	_list_scroll.follow_focus = true
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	var paging := HBoxContainer.new()
	_side.add_child(paging)
	_previous = _button(paging, "CG_PREVIOUS", previous_page, "GalleryPrevious")
	_page_label = Style.label(paging, "", 17)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next = _button(paging, "CG_NEXT", next_page, "GalleryNext")
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_detail)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "GalleryDetailScroll"
	detail_scroll.follow_focus = true
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(detail_scroll)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 12)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(details)
	_name = Style.paragraph(details, "", 25)
	_name.name = "GalleryEntryTitle"
	_portrait_frame = PanelContainer.new()
	_portrait_frame.name = "GalleryPortraitFrame"
	_portrait_frame.add_theme_stylebox_override("panel", Design.box(Design.INK, Design.EDGE, 2))
	details.add_child(_portrait_frame)
	_preview = Preview.new()
	_preview.name = "GalleryCreaturePreview"
	_preview.custom_minimum_size.y = 220
	_portrait_frame.add_child(_preview)
	for child in _preview.viewport.get_children():
		if child is WorldEnvironment: child.environment.background_color = Design.INK
	_portrait_frame.hide()
	_origin = Style.paragraph(details, "", 18)
	_revision = Style.paragraph(details, "", 17)
	_requirements = Style.paragraph(details, "", 18)
	_requirements.name = "GalleryRequirements"
	_download_status = Style.paragraph(details, "", 18)
	_download_status.name = "GalleryDownloadStatus"
	_download = _button(_detail, "CG_DOWNLOAD", download_selected, "GalleryDownload", true)
	resized.connect(_layout)
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	visible = _configured
	_refresh()
	if visible: _search.grab_focus()


func search() -> void:
	if not _configured or _pending != 0: return
	# New search resets the cursor chain, not local designs or download states.
	_pages.clear()
	_page_index = -1
	_selected.clear()
	_show_detail = false
	_result.clear()
	_start(_client.search(_search.text.strip_edges()), "search")


func previous_page() -> void:
	if _pending != 0 or _page_index <= 0: return
	_page_index -= 1
	_selected.clear()
	_show_detail = false
	_result.clear()
	_status_key = "CG_RESULTS"
	_refresh()


func next_page() -> void:
	if _pending != 0 or _page_index < 0: return
	if _page_index + 1 < _pages.size():
		_page_index += 1
		_selected.clear()
		_show_detail = false
		_result.clear()
		_status_key = "CG_RESULTS"
		_refresh()
	elif _pages[_page_index].can_request_more:
		_start(_client.next_page(), "next")


func download_selected() -> void:
	if not _configured or _pending != 0 or _selected.is_empty(): return
	_download_key = Library.key_of(_selected)
	_start(_client.download(_selected, library_path), "download")


func _start(started: Dictionary, operation: String) -> void:
	_operation = operation
	_result.clear()
	if started.ok:
		_pending = int(started.request_id)
		_status_key = "CG_DOWNLOADING" if operation == "download" else "CG_LOADING"
	else:
		_pending = 0
		_result = started.duplicate(true)
	if operation == "download":
		_states[_download_key] = {"ok": false, "code": "downloading"} if started.ok else started.duplicate(true)
	_refresh()


func _completed(request_id: int, result: Dictionary) -> void:
	if request_id != _pending: return
	_pending = 0
	_result = result.duplicate(true)
	if _operation == "download":
		_states[_download_key] = result.duplicate(true)
		if result.ok:
			_status_key = "CG_IMPORTED"
			_refresh()
			imported.emit(str(result.key))
			return
	elif result.ok:
		_pages.append(result.duplicate(true))
		_page_index = _pages.size() - 1
		_selected.clear()
		_show_detail = false
		_status_key = "CG_EMPTY" if result.entries.is_empty() else "CG_RESULTS"
		if not result.can_request_more and not str(result.next_cursor).is_empty():
			_status_key = "CG_PAGE_BUDGET"
	_refresh()


func cancel() -> void:
	# Client cancellation emits exactly once synchronously; stale replies ignored.
	_client.cancel()


func _refresh() -> void:
	if _status == null: return
	for control in find_children("*", "Button", true, false):
		if control.has_meta("text_key"): control.text = Text.text(control.get_meta("text_key"))
	_title.text = Text.text("CG_TITLE")
	_search.placeholder_text = Text.text("CG_QUERY")
	_search.editable = _pending == 0
	_search_button.disabled = not _configured or _pending != 0
	_cancel.visible = _pending != 0
	_status.text = Present.error(_result) if not _result.is_empty() and not _result.ok else Text.format_text(_status_key, {"count": _entries().size()})
	_status.add_theme_color_override("font_color", Design.DANGER if not _result.is_empty() and not _result.ok else Design.MUTED)
	_page_label.text = Text.format_text("CG_PAGE", {"page": _page_index + 1}) if _page_index >= 0 else "—"
	_previous.disabled = _pending != 0 or _page_index <= 0
	_next.disabled = _pending != 0 or _page_index < 0 or (_page_index + 1 >= _pages.size() and not _pages[_page_index].can_request_more)
	_build_list()
	_refresh_details()
	_layout()


func _entries() -> Array:
	return _pages[_page_index].entries if _page_index >= 0 else []


func _build_list() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	var focused: String = str(focus.get_meta("entry_key", "")) if focus != null else ""
	var position: int = _list_scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _entries().is_empty(): Style.paragraph(_list, Text.text("CG_EMPTY" if _page_index >= 0 else "CG_IDLE"), 18)
	var count: int = 0
	for entry: Dictionary in _entries():
		count += 1
		var key: String = Library.key_of(entry)
		var button: Button = _button(_list, "", _select.bind(entry), "GalleryEntry_%d" % count)
		button.text = str(entry.title) + "\n" + Text.format_text("CG_SHORT_REVISION", {"revision": int(entry.revision)})
		Symbols.apply(button, "creature", 28)
		button.add_theme_font_size_override("font_size", 17)
		button.custom_minimum_size.y = 82
		button.add_theme_stylebox_override("pressed", Design.box(Design.PANEL.lightened(0.07), Design.ACCENT, 16))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.set_pressed_no_signal(not _selected.is_empty() and Library.key_of(_selected) == key)
		button.set_meta("entry_key", key)
		button.disabled = _pending != 0
		if key == focused and not button.disabled: button.grab_focus()
	_list_scroll.set_deferred("scroll_vertical", position)


func _select(entry: Dictionary) -> void:
	_selected = entry.duplicate(true)
	_show_detail = true
	_build_list()
	_refresh_details()
	_layout()
	_download.grab_focus()


func _refresh_details() -> void:
	_download.disabled = _pending != 0 or _selected.is_empty() or not _configured
	if _selected.is_empty():
		_name.text = Text.text("CG_SELECT")
		for label in [_origin, _revision, _requirements, _download_status]: label.text = ""
		_portrait_frame.hide()
		_preview.clear()
		_preview_blueprint.clear()
		return
	var key: String = Library.key_of(_selected)
	_name.text = str(_selected.title)
	_origin.text = Present.origin(_selected, _endpoint)
	_revision.text = Present.revision(_selected)
	var local: Dictionary = Library.get_package(key, library_path)
	# Until this exact remote revision has been validated, do not present a
	# potentially conflicting local revision as confirmed service requirements.
	var state: Dictionary = _states.get(key, {})
	var confirmed: bool = state.get("ok", false) and local.ok
	# A real preview is shown only after this exact remote revision was validated.
	# Catalogue metadata cannot be used to invent a creature or borrow another revision.
	var checked: Dictionary = Package.inspect(local.package) if confirmed else {}
	_portrait_frame.visible = bool(checked.get("ok", false))
	if _portrait_frame.visible:
		if _preview_blueprint != checked.preview:
			_preview_blueprint = checked.preview.duplicate(true)
			_preview.show_blueprint(checked.preview)
	else:
		_preview.clear()
		_preview_blueprint.clear()
	_requirements.text = Present.requirements(local.package if confirmed else {}, prepare_template)
	if state.get("code", "") == "downloading": _download_status.text = Text.text("CG_DOWNLOADING")
	elif not state.is_empty(): _download_status.text = Text.text("CG_IMPORTED") if state.ok else Present.error(state)
	else: _download_status.text = Text.text("CG_LOCAL_UNVERIFIED" if local.ok else "CG_NOT_DOWNLOADED")


func _layout() -> void:
	if _side == null: return
	var narrow: bool = size.x < 900
	_side.visible = not narrow or not _show_detail
	_detail.visible = not narrow or _show_detail
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	_side.custom_minimum_size.x = 0 if narrow else 300
	_back.visible = narrow and _show_detail
	_title.visible = not _back.visible
	_search_row.visible = not _back.visible


func _back_to_list() -> void:
	_show_detail = false
	_layout()
	_search.grab_focus()


func _language_changed(_locale: String) -> void:
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"): return
	get_viewport().set_input_as_handled()
	if _pending != 0: cancel()
	elif size.x < 900 and _show_detail: _back_to_list()
	else: _close()


func _close() -> void:
	cancel()
	closed.emit()
	if is_instance_valid(_return_focus): _return_focus.grab_focus()
	queue_free()


func _exit_tree() -> void:
	_pending = 0
	_client.cancel()


func _notification(what: int) -> void:
	# Also release configured objects rejected by a host before entering tree.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_client) and _client.get_parent() == null:
		_client.free()


func _button(parent: Node, key: String, action: Callable, id: String, primary: bool = false) -> Button:
	var button: Button = Style.button(parent, Text.text(key) if not key.is_empty() else "", action, id, primary)
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	var symbol: String = {"BP_CLOSE": "close", "BP_BACK_LIST": "back", "CG_SEARCH": "search", "BP_CANCEL": "close", "CG_PREVIOUS": "back", "CG_NEXT": "next", "CG_DOWNLOAD": "import"}.get(key, "")
	if not symbol.is_empty():
		Symbols.apply(button, symbol, 22)
		if primary: button.icon = Symbols.texture(symbol, Design.INK, 44)
	if not key.is_empty(): button.set_meta("text_key", key)
	return button
