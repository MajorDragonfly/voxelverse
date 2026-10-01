extends Control
## Shared local picker for the workshop and new-game menu.
signal closed
signal template_chosen(package: Dictionary)

const Library = preload("res://assembly/exchange/creature_design_library.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Preview = preload("res://ui/discovery/journal_preview.gd")
const Style = preload("res://ui/frontend/menu_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/blueprints/creature_library_presentation.gd")
var prepare_template: Callable
var capture_current: Callable
## Optional read-only baseline; the frontend may supply its already chosen form.
var compare_current: Callable
var library_path: String = Library.PATH
var start_mode: bool = false
# Optional configured service; no default endpoint or startup polling.
var community_catalog_endpoint: String = str(ProjectSettings.get_setting("community/catalog_endpoint", ""))
var _entries: Array[Dictionary] = []
var _selected: String = ""
var _show_detail: bool = false
var _return_focus: Control
var _header_title: Label
var _tools: HFlowContainer
var _side: VBoxContainer
var _detail: VBoxContainer
var _list: VBoxContainer
var _preview: Preview
var _name: Label
var _origin: Label
var _requirements: Label
var _comparison: Label
var _selection_notice: Label
var _sort: OptionButton
var _visible_keys: Array[String] = []
var _reviewed_current: Dictionary = {}
var _can_use: bool = false
var _start_baseline: Dictionary = {}
var _preview_blueprint: Dictionary = {}
var _availability: Dictionary = {}
var _availability_context: Dictionary = {}
var _status: Label
var _search: LineEdit
var _filter: OptionButton
var _favorites_only: CheckButton
var _favorite: Button
var _favorites: Array = []
var _library_writable: bool = true
var _use: Button
var _export: Button
var _remove: Button
var _back: Button
var _variant_name: LineEdit
var _file: FileDialog
var _delete: ConfirmationDialog
var _delete_key: String = ""
var _last_result: Dictionary = {}
var _last_success: String = ""


func _ready() -> void:
	name = "CreatureLibrary"
	_return_focus = get_viewport().gui_get_focus_owner()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme()
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var background := ColorRect.new()
	background.color = Style.INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title: Label = Style.label(header, "", 28)
	_header_title = title
	title.name = "LibraryTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_text(title, "BP_LIBRARY_TITLE")
	_button(header, "BP_CLOSE", _close, "CloseLibrary")
	_back = _button(header, "BP_BACK_LIST", _back_to_list, "BackToTemplates")
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.move_child(_back, 0)
	var tools := HFlowContainer.new()
	_tools = tools
	content.add_child(tools)
	_button(tools, "BP_IMPORT", _open_import, "ImportBlueprint")
	_export = _button(tools, "BP_EXPORT", _open_export, "ExportBlueprint")
	_remove = _button(tools, "BP_REMOVE", _confirm_remove, "RemoveBlueprint")
	var community_launcher := preload("res://ui/blueprints/community_gallery_launcher.gd").new()
	add_child(community_launcher)
	community_launcher.attach(self, tools, community_catalog_endpoint)
	_status = Style.paragraph(content, "", 18)
	_status.name = "LibraryStatus"
	_status.visible = false
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	_side = VBoxContainer.new()
	_side.custom_minimum_size.x = 300
	columns.add_child(_side)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.name = "TemplateListScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side.add_child(scroll)
	var list_content := VBoxContainer.new()
	list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_content)
	_search = LineEdit.new()
	_search.name = "TemplateSearch"
	_search.custom_minimum_size.y = 48
	_search.text_changed.connect(func(_text: String):
		_clear_success()
		_build_list())
	list_content.add_child(_search)
	_filter = OptionButton.new()
	_filter.name = "TemplateFilter"
	_filter.custom_minimum_size.y = 48
	_filter.item_selected.connect(func(_index: int):
		_clear_success()
		_build_list())
	list_content.add_child(_filter)
	_sort = OptionButton.new()
	_sort.name = "TemplateSort"
	_sort.custom_minimum_size.y = 48
	_sort.item_selected.connect(func(_index: int):
		_clear_success()
		_build_list())
	list_content.add_child(_sort)
	_favorites_only = CheckButton.new()
	_favorites_only.name = "FavoriteTemplatesOnly"
	_favorites_only.custom_minimum_size.y = 48
	_bind_text(_favorites_only, "BP_FAVORITES_ONLY")
	_favorites_only.toggled.connect(func(_enabled: bool):
		_clear_success()
		_build_list())
	list_content.add_child(_favorites_only)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_content.add_child(_list)
	if capture_current.is_valid():
		var save_row := VBoxContainer.new()
		list_content.add_child(save_row)
		_variant_name = LineEdit.new()
		_variant_name.name = "VariantName"
		_variant_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_variant_name.max_length = 120
		_variant_name.custom_minimum_size.y = 48
		_variant_name.text = str(capture_current.call().get("name", ""))
		save_row.add_child(_variant_name)
		_button(save_row, "BP_SAVE_VARIANT", _save_variant, "SaveVariant")
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(_detail)
	var details_scroll := ScrollContainer.new()
	details_scroll.follow_focus = true
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(details_scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.add_child(details)
	_name = Style.label(details, "", 26)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.name = "TemplateName"
	_preview = Preview.new()
	_preview.name = "TemplatePreview"
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(_preview)
	_origin = Style.paragraph(details, "", 18)
	_origin.name = "TemplateOrigin"
	_requirements = Style.paragraph(details, "", 20)
	_requirements.name = "TemplateRequirements"
	_comparison = Style.paragraph(details, "", 18)
	_comparison.name = "TemplateComparison"
	# Restrictions and changes are visible before the large preview/provenance.
	details.move_child(_requirements, 1)
	details.move_child(_comparison, 2)
	_selection_notice = Style.paragraph(_detail, "", 18)
	_selection_notice.name = "TemplateSelectionNotice"
	_selection_notice.hide()
	_favorite = _button(_detail, "BP_FAVORITE_ADD", _toggle_favorite, "ToggleTemplateFavorite")
	_favorite.toggle_mode = true
	_use = _button(_detail, "BP_USE", _choose, "UseBlueprint", true)
	_file = FileDialog.new()
	_file.name = "BlueprintFileDialog"
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.filters = PackedStringArray(["*.json ; Voxelverse JSON"])
	_file.file_selected.connect(_file_selected)
	add_child(_file)
	_delete = ConfirmationDialog.new()
	_delete.name = "RemoveTemplateDialog"
	_delete.confirmed.connect(_remove_confirmed)
	add_child(_delete)
	resized.connect(_layout)
	get_node("/root/LocaleManager").language_changed.connect(_language_changed)
	_language_changed("")
	reload()
	_search.grab_focus()


func reload(preferred_key: String = "") -> void:
	_entries.clear()
	_availability.clear()
	for package in Starter.packages():
		_entries.append({"key": "builtin/" + Library.key_of(package), "builtin": true, "package": package})
	var stored: Dictionary = Library.read(library_path)
	_library_writable = stored.ok
	_favorites.clear()
	if stored.ok:
		_favorites.assign(stored.favorites)
		for package: Dictionary in stored.packages:
			_entries.append({"key": Library.key_of(package), "builtin": false, "package": package})
	else: show_result(stored)
	if not preferred_key.is_empty(): _selected = preferred_key
	if _entry().is_empty(): _selected = str(_entries[0].key) if not _entries.is_empty() else ""
	_build_list()
	_refresh_details()
	_layout()


func _entry() -> Dictionary:
	for entry: Dictionary in _entries:
		if entry.key == _selected: return entry
	return {}


func _title(entry: Dictionary) -> String:
	var package: Dictionary = entry.package
	return Text.text("BP_START_" + str(package.design_id).trim_prefix("starter_").to_upper()) if entry.builtin else str(package.title)


func _build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_visible_keys.clear()
	var context: Dictionary = _preparation_context()
	if context != _availability_context:
		_availability.clear()
		_availability_context = context
	var visible_entries: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		if _filter.selected == 1 and not entry.builtin: continue
		if _filter.selected == 2 and entry.builtin: continue
		if _favorites_only.button_pressed and not entry.key in _favorites: continue
		var searchable: String = _title(entry) + " " + str(entry.package.design_id) + " " + str(entry.package.author) + " " + str(entry.package.description) + " " + " ".join(entry.package.tags)
		if not _search.text.strip_edges().is_empty() and not searchable.to_lower().contains(_search.text.strip_edges().to_lower()): continue
		# Existing preparation is pure and remains the authority for usability.
		if not _availability.has(entry.key):
			_availability[entry.key] = prepare_template.is_valid() and bool(prepare_template.call(entry.package).get("ok", false))
		entry["available"] = _availability[entry.key]
		visible_entries.append(entry)
	if _sort.selected > 0: visible_entries.sort_custom(_entry_before)
	var count: int = 0
	for entry: Dictionary in visible_entries:
		count += 1
		_visible_keys.append(entry.key)
		var button: Button = _button(_list, "", _select.bind(str(entry.key)), "Template_" + str(count))
		button.text = ("★ " if entry.key in _favorites else "") + _title(entry) + "\n" + Text.text("BP_BUILTIN" if entry.builtin else "BP_LOCAL") + " · " + Text.format_text("BP_REVISION", {"revision": int(entry.package.revision)}) + " · " + Text.text("BP_USABLE" if entry.available else "BP_RESTRICTED") + "\n" + str(entry.package.design_id)
		button.tooltip_text = Presentation.identity(entry.package) + "\n" + str(entry.package.author)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.toggle_mode = true
		button.set_pressed_no_signal(entry.key == _selected)
		button.set_meta("template_key", entry.key)
	if count == 0: Style.paragraph(_list, Text.text("BP_NO_FAVORITES" if _favorites_only.button_pressed else "BP_NO_RESULTS"), 18)
	if _use != null:
		if _availability.has(_selected) and _can_use != bool(_availability[_selected]): _refresh_details()
		_selection_notice.visible = not _entry().is_empty() and not _selected in _visible_keys
		_selection_notice.text = Text.text("BP_SELECTION_FILTERED")
		_use.disabled = not _can_use or not _selected in _visible_keys


func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	if _sort.selected == 3 and a.available != b.available: return a.available
	if _sort.selected == 2 and a.package.revision != b.package.revision: return a.package.revision > b.package.revision
	var title_order: int = _title(a).to_lower().naturalnocasecmp_to(_title(b).to_lower())
	if title_order != 0: return title_order < 0
	return str(a.key) < str(b.key)


func _current_for_comparison() -> Dictionary:
	if compare_current.is_valid(): return compare_current.call().duplicate(true)
	if capture_current.is_valid(): return capture_current.call().duplicate(true)
	if start_mode and _start_baseline.is_empty(): _start_baseline = Package.Creature.create_default()
	return _start_baseline.duplicate(true) if start_mode else {}


func _preparation_context() -> Dictionary:
	# Reuse pure list checks only while the receiving form and actual unlock/phase
	# context match. Selection and adoption still call the authoritative preparer.
	var state: Node = get_node_or_null("/root/GameState")
	var progression: Node = get_node_or_null("/root/ProgressionService")
	var saves: Node = get_node_or_null("/root/SaveGameService")
	return {"current": _current_for_comparison(), "phase": state.get("current_phase") if state != null else -1,
		"unlocked": progression.call("get_unlocked_part_ids") if progression != null else [],
		"session": saves.get("session_active") if saves != null else false,
		"transition": saves.call("is_phase_transition_active") if saves != null else false}


func _select(key: String) -> void:
	_last_result.clear()
	_status.hide()
	_selected = key
	_show_detail = true
	_build_list()
	_refresh_details()
	_layout()
	if not _use.disabled: _use.grab_focus()
	elif _back.visible: _back.grab_focus()


func _refresh_details() -> void:
	var entry: Dictionary = _entry()
	_refresh_favorite()
	_can_use = false
	_use.disabled = true
	_export.disabled = entry.is_empty()
	_remove.disabled = entry.is_empty() or entry.get("builtin", true)
	_selection_notice.visible = not entry.is_empty() and not _selected in _visible_keys
	_selection_notice.text = Text.text("BP_SELECTION_FILTERED")
	if entry.is_empty():
		_name.text = ""
		_origin.text = ""
		_requirements.text = Text.text("BP_NO_RESULTS")
		_comparison.text = ""
		_preview.clear()
		_preview_blueprint.clear()
		return
	_name.text = _title(entry)
	_origin.text = ""
	_comparison.text = ""
	var checked: Dictionary = Package.inspect(entry.package)
	if not checked.ok:
		_requirements.text = error_text(checked)
		_preview.clear()
		_preview_blueprint.clear()
		return
	_origin.text = Presentation.origin(entry)
	if _preview_blueprint != checked.preview:
		_preview_blueprint = checked.preview.duplicate(true)
		_preview.show_blueprint(checked.preview)
		_preview._angle = -2.55
		_preview._frame_camera()
	var result: Dictionary = prepare_template.call(entry.package) if prepare_template.is_valid() else {"ok": false, "code": "no_campaign"}
	_requirements.text = Text.format_text("BP_COMPLEXITY", {"count": checked.stats.complexity, "limit": checked.stats.complexity_limit}) + "\n" + (Text.text("BP_AVAILABLE_START" if start_mode else "BP_AVAILABLE") if result.ok else error_text(result))
	_reviewed_current = _current_for_comparison()
	_comparison.text = Presentation.compare(_reviewed_current, checked.preview) + "\n\n" + Text.text("BP_START_LIMITS" if start_mode else "BP_ADOPT_LIMITS")
	_can_use = result.ok
	_availability[entry.key] = _can_use
	_use.disabled = not _can_use or not _selected in _visible_keys


func _refresh_favorite() -> void:
	var marked: bool = _selected in _favorites
	_favorite.disabled = _entry().is_empty() or not _library_writable
	_favorite.set_pressed_no_signal(marked)
	_favorite.text = Text.text("BP_FAVORITE_REMOVE" if marked else "BP_FAVORITE_ADD")
	_favorite.tooltip_text = Text.text("BP_FAVORITE_TOOLTIP")


func _toggle_favorite() -> void:
	var enabled: bool = _favorite.button_pressed
	var result: Dictionary = Library.set_favorite(_selected, enabled, library_path)
	if result.ok:
		_favorites.assign(result.favorites)
		var scroll: ScrollContainer = find_child("TemplateListScroll", true, false)
		var position: int = scroll.scroll_vertical
		_build_list()
		_restore_scroll.call_deferred(position)
	_refresh_favorite()
	show_result(result, "BP_FAVORITE_SAVED" if enabled else "BP_FAVORITE_CLEARED")


func _choose() -> void:
	var entry: Dictionary = _entry()
	if entry.is_empty() or _use.disabled or not prepare_template.is_valid() or not _selected in _visible_keys: return
	var package: Dictionary = entry.package
	if not entry.builtin:
		var latest: Dictionary = Library.get_package(_selected, library_path)
		if not latest.ok:
			show_result(latest)
			_use.disabled = true
			return
		if not Package.same_content(package, latest.package):
			reload(_selected)
			show_result({"ok": false, "code": "selection_changed"})
			return
		package = latest.package
	if _reviewed_current != _current_for_comparison():
		_refresh_details()
		show_result({"ok": false, "code": "selection_changed"})
		return
	var result: Dictionary = prepare_template.call(package)
	if not result.ok:
		show_result(result)
		_use.disabled = true
		return
	template_chosen.emit(package.duplicate(true))


func _open_import() -> void:
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.title = Text.text("BP_IMPORT")
	_file.popup_centered(Vector2i(mini(int(size.x * 0.9), 900), mini(int(size.y * 0.9), 620)))


func _open_export() -> void:
	if _entry().is_empty(): return
	_file.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_file.title = Text.text("BP_EXPORT")
	_file.current_file = "creature-" + str(int(_entry().package.revision)) + ".json"
	_file.popup_centered(Vector2i(mini(int(size.x * 0.9), 900), mini(int(size.y * 0.9), 620)))


func _file_selected(path: String) -> void:
	var result: Dictionary
	if _file.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		result = Library.import_file(path, library_path)
		if result.ok: reload(result.key)
	else:
		var entry: Dictionary = _entry()
		result = Package.write_file(path, entry.package) if not entry.is_empty() else {"ok": false, "code": "template_missing"}
	show_result(result, "BP_IMPORTED" if _file.file_mode == FileDialog.FILE_MODE_OPEN_FILE else "BP_EXPORTED")


func _save_variant() -> void:
	if not capture_current.is_valid(): return
	var result: Dictionary = Library.save_variant(capture_current.call(), _variant_name.text.strip_edges(), library_path)
	if result.ok:
		_filter.select(2)
		_favorites_only.set_pressed_no_signal(false)
		_search.clear()
		reload(result.key)
	show_result(result, "BP_VARIANT_SAVED")


func _confirm_remove() -> void:
	var entry: Dictionary = _entry()
	if entry.is_empty() or entry.builtin: return
	_delete_key = _selected
	_delete.dialog_text = Text.format_text("BP_REMOVE_CONFIRM", {"name": _title(entry)})
	_delete.popup_centered(Vector2i(mini(int(size.x * 0.85), 580), 180))


func _remove_confirmed() -> void:
	var result: Dictionary = Library.remove(_delete_key, library_path)
	if result.ok: reload()
	show_result(result, "BP_REMOVED")


func _clear_success() -> void:
	if _last_result.get("ok", false):
		_last_result.clear()
		_status.hide()


func show_result(result: Dictionary, success_key: String = "") -> void:
	_last_result = result.duplicate(true)
	_last_success = success_key
	_status.visible = true
	_status.text = Text.text(success_key) if result.ok else error_text(result)


static func error_text(result: Dictionary) -> String:
	var code: String = str(result.get("code", "invalid_package"))
	if code == "locked_parts":
		var names: Array[String] = []
		for id in result.get("missing_parts", []):
			names.append(Presentation.part_name(str(id)))
		return Text.format_text("BP_LOCKED", {"parts": ", ".join(names)})
	if code == "unknown_part" or code == "missing_part":
		return Text.format_text("BP_ERROR_PART_MISSING", {"part": result.get("item", "")})
	var key: String = {"library_unreadable": "BP_ERROR_LIBRARY", "library_full": "BP_ERROR_FULL",
		"selection_changed": "BP_SELECTION_CHANGED", "unsupported_catalog": "BP_ERROR_CATALOG",
		"favorites_full": "BP_ERROR_FAVORITES_FULL",
		"editor_incompatible": "BP_ERROR_EDITOR",
		"revision_conflict": "BP_ERROR_CONFLICT", "destination_conflict": "BP_ERROR_DESTINATION",
		"protected_destination": "BP_ERROR_DESTINATION", "write_failed": "BP_ERROR_WRITE",
		"phase_not_editable": "BP_ERROR_PHASE", "complexity_exceeded": "BP_ERROR_COMPLEXITY",
		"protected_target": "BP_ERROR_TARGET", "template_missing": "BP_ERROR_MISSING",
		"no_campaign": "BP_ERROR_CAMPAIGN", "transition_active": "BP_ERROR_PHASE",
		"provenance_limit": "BP_ERROR_PROVENANCE", "invalid_metadata": "BP_ERROR_NAME",
		"missing_title": "BP_ERROR_NAME"}.get(code, "BP_ERROR_PACKAGE")
	return Text.text(key)


func _back_to_list() -> void:
	_show_detail = false
	_layout()
	_search.grab_focus()


func _layout() -> void:
	if _side == null: return
	var narrow: bool = size.x < 900
	_side.visible = not narrow or not _show_detail
	_detail.visible = not narrow or _show_detail
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL
	_side.custom_minimum_size.x = 0 if narrow else 300
	_back.visible = narrow and _show_detail
	_header_title.visible = not _back.visible
	_tools.visible = not _back.visible
	_preview.custom_minimum_size.y = clampf(size.y * 0.44, 140, 260) if narrow else clampf(size.y * 0.5, 300, 520)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _file.visible and not _delete.visible:
		get_viewport().set_input_as_handled()
		if size.x < 900 and _show_detail: _back_to_list()
		else: _close()


func _close() -> void:
	closed.emit()
	if is_instance_valid(_return_focus): _return_focus.grab_focus()
	queue_free()


func _language_changed(_locale: String) -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	var focus_key: String = str(focus.get_meta("template_key", "")) if focus != null else ""
	var scroll: ScrollContainer = find_child("TemplateListScroll", true, false)
	var scroll_position: int = scroll.scroll_vertical
	var angle: float = _preview._angle
	var zoom: float = _preview._zoom
	for control in find_children("*", "Control", true, false):
		if control.has_meta("text_key"): control.text = Text.text(control.get_meta("text_key"))
	_preview.tooltip_text = Text.text("BP_PREVIEW_HELP")
	_search.placeholder_text = Text.text("BP_SEARCH")
	var selected: int = maxi(_filter.selected, 0)
	_filter.clear()
	for key in ["BP_ALL", "BP_BUILTINS", "BP_LOCALS"]: _filter.add_item(Text.text(key))
	_filter.select(selected)
	var sort_selected: int = maxi(_sort.selected, 0)
	_sort.clear()
	for key in ["BP_SORT_DEFAULT", "BP_SORT_NAME", "BP_SORT_REVISION", "BP_SORT_USABLE"]: _sort.add_item(Text.text(key))
	_sort.select(sort_selected)
	_use.text = Text.text("BP_SELECT_START" if start_mode else "BP_USE")
	_delete.title = Text.text("BP_REMOVE")
	_delete.ok_button_text = Text.text("BP_REMOVE")
	_delete.cancel_button_text = Text.text("BP_CANCEL")
	if _variant_name != null: _variant_name.placeholder_text = Text.text("BP_VARIANT_NAME")
	if not _entries.is_empty():
		_build_list()
		_refresh_details()
		_preview._angle = angle
		_preview._zoom = zoom
		_preview._frame_camera()
		_restore_scroll.call_deferred(scroll_position)
		if not focus_key.is_empty():
			for button in _list.get_children():
				if str(button.get_meta("template_key", "")) == focus_key: button.grab_focus()
	if not _last_result.is_empty(): show_result(_last_result, _last_success)


func _restore_scroll(value: int) -> void:
	var scroll: ScrollContainer = find_child("TemplateListScroll", true, false)
	scroll.scroll_vertical = value


func _button(parent: Node, key: String, action: Callable, id: String, primary: bool = false) -> Button:
	var button: Button = Style.button(parent, Text.text(key) if not key.is_empty() else "", action, id, primary)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 20)
	if not key.is_empty(): button.set_meta("text_key", key)
	return button


func _bind_text(control: Control, key: String) -> void:
	control.set_meta("text_key", key)
	control.text = Text.text(key)
