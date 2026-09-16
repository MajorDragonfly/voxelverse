extends ScrollContainer
var _content: VBoxContainer
const Style = preload("res://ui/progression_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Collection = preload("res://world/tribe/settlement_collection.gd")
var runtime: Node
var _help: Label
var _places: OptionButton
var _details: Label
var _found: Button
var _visit: Button
var _ids: Array = []
var _timer: float = 0.0
var _freight: VBoxContainer

func _ready() -> void:
	name = "Siedlungen"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)
	_help = Style.label(Text.text("SETTLEMENT_HELP"), 16, Style.MUTED)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_help)
	_places = OptionButton.new()
	_places.name = "SettlementChoice"
	_places.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_places)
	_places.item_selected.connect(func(_index: int) -> void: refresh())
	_details = Style.label("", 16)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_details)
	_visit = Style.button(Text.text("SETTLEMENT_MANAGE"))
	_visit.name = "ManageSettlement"
	_visit.pressed.connect(func() -> void:
		if _places.selected >= 0: await runtime.select(_ids[_places.selected])
		refresh())
	_content.add_child(_visit)
	_found = Style.button(Text.text("SETTLEMENT_FOUND"))
	_found.name = "FoundSettlement"
	_found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_found.pressed.connect(func() -> void:
		await runtime.found()
		refresh())
	_content.add_child(_found)
	_freight = preload("res://ui/tribe/site_transport_panel.gd").new()
	_freight.runtime = runtime.controller.site_transport
	_content.add_child(_freight)
	refresh()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		_timer = 0.25
		refresh()

func refresh() -> void:
	if _places == null: return
	if _freight != null: _freight.refresh()
	_help.text = Text.text("SETTLEMENT_HELP")
	_visit.text = Text.text("SETTLEMENT_MANAGE")
	_found.text = Text.text("SETTLEMENT_FOUND")
	var tabs := get_parent() as TabContainer
	if tabs != null:
		var index: int = tabs.get_tab_idx_from_control(self)
		if index >= 0 and index < tabs.get_tab_bar().tab_count: tabs.set_tab_title(index, Text.text("SETTLEMENT_TAB"))
	var body: Dictionary = runtime.controller.body()
	var ids: Array = Collection.ids(body)
	if ids != _ids:
		_ids = ids
		_places.clear()
		for id: String in _ids: _places.add_item(Text.text("SETTLEMENT_HOME") if id == Collection.origin_id(body) else Text.text("SETTLEMENT_OUTPOST"))
	for index in range(_ids.size()): _places.set_item_text(index, Text.text("SETTLEMENT_HOME") if _ids[index] == Collection.origin_id(body) else Text.text("SETTLEMENT_OUTPOST"))
	if _places.selected < 0 or _places.selected >= _ids.size(): return
	var id: String = _ids[_places.selected]
	var data: Dictionary = Collection.village(body, id)
	var active: bool = id == Collection.selected_id(body)
	var reason: String = runtime.founding_reason()
	_details.text = Text.text("SETTLEMENT_DETAIL") % [Text.text("SETTLEMENT_NEAR") if active else Text.text("SETTLEMENT_FAR"), data.members.size(), data.stock.wood, data.stock.stone, data.stock.food, data.stock.water, Text.text("SETTLEMENT_ARRIVED") if reason.is_empty() else reason]
	_visit.disabled = runtime.busy or active or not runtime.controller.is_active()
	_found.disabled = not reason.is_empty()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh()
