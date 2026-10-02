extends VBoxContainer
## Canonical source details plus saved gathering boundaries. No UI-owned amounts.
const Economy = preload("res://world/tribe/village_economy.gd")
const Areas = preload("res://world/tribe/resource_area_model.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
var controller: Node
var source_id: String = ""
var _title: Label
var _amount: Label
var _workers: Label
var _add: Button
var _remove: Button
var _sources: VBoxContainer
var _list: VBoxContainer
var _editor: VBoxContainer
var _new: Button
var _heading: Label
var _details: Label
var _radius: SpinBox
var _target: SpinBox
var _count: SpinBox
var _kind: OptionButton
var _apply: Button
var _move: Button
var _delete: Button
var _assign: Button
var _fields: Dictionary = {}
var _rows: Dictionary = {}
var _editing: String = ""
var _confirm_delete: bool = false

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_sources = VBoxContainer.new()
	add_child(_sources)
	_title = Style.label("", 17, Style.SOCIAL)
	_sources.add_child(_title)
	_amount = Style.label("", 15, Style.TEXT)
	_sources.add_child(_amount)
	_workers = Style.label("", 15, Style.MUTED)
	_sources.add_child(_workers)
	var actions := HFlowContainer.new()
	_sources.add_child(actions)
	_add = Style.button("")
	_add.name = "AddAreaWorker"
	actions.add_child(_add)
	_add.pressed.connect(func() -> void: controller.adjust_resource_workers(source_id, 1))
	_remove = Style.button("")
	_remove.name = "RemoveAreaWorker"
	actions.add_child(_remove)
	_remove.pressed.connect(func() -> void: controller.adjust_resource_workers(source_id, -1))
	_sources.hide()
	_build_areas()

func select_source(identity: String) -> void:
	var adapter: Node = controller.get("resource_areas")
	if adapter != null: adapter.selected_id = ""
	source_id = identity
	refresh(controller.village())

func refresh(data: Dictionary) -> void:
	_refresh_areas(data)
	if source_id.is_empty() or data.is_empty():
		_sources.hide()
		return
	var site: Dictionary = controller.resource_details(source_id)
	_sources.visible = not site.is_empty()
	if site.is_empty(): return
	_title.text = Text.format_text("RESOURCE_AREA_TITLE", {"resource": Presentation.resource_title(site.kind)})
	_amount.text = Text.format_text("RESOURCE_AREA_AMOUNT", {"available": site.remaining, "stored": data.stock.get(site.kind, 0)})
	_workers.text = Text.format_text("RESOURCE_AREA_WORKERS", {"assigned": site.assigned, "total": data.members.size()})
	_add.text = Text.text("RESOURCE_AREA_ADD")
	_remove.text = Text.text("RESOURCE_AREA_REMOVE")
	_add.disabled = not controller.is_active() or site.assigned >= data.members.size()
	_remove.disabled = not controller.is_active() or site.assigned == 0
	_add.tooltip_text = Text.text("RESOURCE_AREA_ADD_HINT")

func select_area(identity: String) -> void:
	var adapter: Node = controller.get("resource_areas")
	if adapter == null: return
	adapter.selected_id = identity
	source_id = ""
	_editing = ""
	refresh(controller.village())

func _build_areas() -> void:
	_heading = Style.label("", 17, Style.SOCIAL)
	add_child(_heading)
	_new = Style.button("")
	_new.name = "CreateGatherArea"
	add_child(_new)
	_new.pressed.connect(func() -> void: controller.resource_areas.begin())
	_list = VBoxContainer.new()
	add_child(_list)
	_editor = VBoxContainer.new()
	add_child(_editor)
	_details = Style.label("", 15, Style.MUTED)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(_details)
	_kind = OptionButton.new()
	_kind.name = "GatherKind"
	_editor.add_child(_kind)
	for kind: String in Areas.KINDS: _kind.add_item(Presentation.resource_title(kind))
	_radius = _spin("GATHER_RADIUS", "GatherRadius", 1, Areas.MAX_RADIUS, 0.5)
	_target = _spin("GATHER_TARGET", "GatherTarget", 0, 48, 1)
	_count = _spin("GATHER_COUNT", "GatherCount", 0, 8, 1)
	var actions := HFlowContainer.new()
	_editor.add_child(actions)
	_apply = Style.button("")
	_apply.name = "ApplyGatherArea"
	actions.add_child(_apply)
	_apply.pressed.connect(_apply_changes)
	_assign = Style.button("")
	_assign.name = "AssignGatherArea"
	actions.add_child(_assign)
	_assign.pressed.connect(func() -> void: controller.resource_areas.command({"action": "assign", "id": _editing}))
	_move = Style.button("")
	_move.name = "MoveGatherArea"
	actions.add_child(_move)
	_move.pressed.connect(func() -> void: controller.resource_areas.begin(_editing))
	_delete = Style.button("")
	_delete.name = "DeleteGatherArea"
	actions.add_child(_delete)
	_delete.pressed.connect(func() -> void:
		if _confirm_delete: controller.resource_areas.command({"action": "delete", "id": _editing})
		else: _confirm_delete = true
		refresh(controller.village()))

func _spin(key: String, node_name: String, minimum: float, maximum: float, step_value: float) -> SpinBox:
	var label := Style.label("", 15, Style.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(label)
	_fields[key] = label
	var control := SpinBox.new()
	control.name = node_name
	control.min_value = minimum
	control.max_value = maximum
	control.step = step_value
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.get_line_edit().custom_minimum_size.x = 60
	_editor.add_child(control)
	return control

func _apply_changes() -> void:
	var data: Dictionary = controller.village()
	var area: Dictionary = Areas.get_area(data, _editing)
	if area.is_empty(): return
	controller.resource_areas.command({"action": "configure", "id": _editing,
		"center": area.center, "radius": _radius.value, "kind": Areas.KINDS[_kind.selected],
		"target": int(_target.value), "count": int(_count.value)})

func _refresh_areas(data: Dictionary) -> void:
	var adapter: Node = controller.get("resource_areas")
	var ready: bool = adapter != null and not data.is_empty()
	_heading.visible = ready
	_new.visible = ready
	_list.visible = ready
	_heading.text = Text.text("GATHER_TITLE")
	_new.text = Text.text("GATHER_NEW")
	_new.disabled = not ready or not controller.is_active() or Areas.entries(data).size() >= Areas.MAX_AREAS
	for id: String in _rows.keys():
		if not Areas.entries(data).has(id):
			_list.remove_child(_rows[id])
			_rows[id].queue_free()
			_rows.erase(id)
	for area: Dictionary in Areas.entries(data).values():
		if not _rows.has(area.id):
			var row := Style.button("")
			row.name = "GatherArea_%d" % area.sequence
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_list.add_child(row)
			_rows[area.id] = row
			row.pressed.connect(func() -> void: select_area(area.id))
		_rows[area.id].text = Text.format_text("GATHER_ROW", {"number": int(area.sequence), "resource": Presentation.resource_title(area.kind), "workers": area.workers})
		_rows[area.id].disabled = not controller.is_active()
	var identity: String = adapter.selected_id if ready else ""
	var area: Dictionary = Areas.get_area(data, identity)
	_editor.visible = not area.is_empty()
	if area.is_empty():
		_editing = ""
		return
	if _editing != identity:
		_editing = identity
		_confirm_delete = false
		_kind.select(Areas.KINDS.find(area.kind))
		_radius.value = area.radius
		_target.value = area.target
		_count.value = area.workers
	_count.max_value = data.members.size()
	for i in range(Areas.KINDS.size()): _kind.set_item_text(i, Presentation.resource_title(Areas.KINDS[i]))
	for key: String in _fields: _fields[key].text = Text.text(key)
	var view: Dictionary = Areas.summary(data, identity, adapter.reachable)
	var state_key: String = "GATHER_TARGET_REACHED" if Economy.reserve(data, area.kind) >= int(area.target) else "GATHER_EMPTY" if view.remaining == 0 else "GATHER_UNREACHABLE" if view.reachable == 0 else "GATHER_READY"
	_details.text = Text.format_text("GATHER_DETAILS", {"sources": view.sources, "remaining": view.remaining,
		"reserved": view.reserved, "carried": view.carried, "stock": data.stock[area.kind], "target": area.target, "state": Text.text(state_key)})
	_apply.text = Text.text("GATHER_APPLY")
	_assign.text = Text.text("GATHER_ASSIGN")
	_move.text = Text.text("GATHER_MOVE")
	_delete.text = Text.text("GATHER_DELETE_CONFIRM" if _confirm_delete else "GATHER_DELETE")
	for control: Button in [_apply, _assign, _move, _delete]: control.disabled = not controller.is_active()
	_assign.disabled = not controller.is_active() or controller.selected.is_empty()
	_apply.tooltip_text = Text.text("GATHER_TARGET_HINT")
