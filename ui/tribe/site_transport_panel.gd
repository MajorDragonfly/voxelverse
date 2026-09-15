extends VBoxContainer
const Model = preload("res://world/tribe/transport/site_transport_state.gd")
const Style = preload("res://ui/progression_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
var runtime: Node
var _title: Label
var _resource: OptionButton
var _amount: SpinBox
var _send: Button
var _cancel: Button
var _state: Label
var _destination: String = ""

func _ready() -> void:
	name = "SiteFreight"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title = Style.label("", 17)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_title)
	var row := HBoxContainer.new()
	add_child(row)
	_resource = OptionButton.new()
	_resource.name = "FreightResource"
	_resource.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_resource)
	for kind: String in Model.Ledger.KINDS: _resource.add_item(Text.text("TRIBE_RESOURCE_" + kind.to_upper()))
	_amount = SpinBox.new()
	_amount.name = "FreightAmount"
	_amount.min_value = 1
	_amount.max_value = Model.CAPACITY
	_amount.value = 1
	_amount.allow_greater = false
	row.add_child(_amount)
	_send = Style.button("")
	_send.name = "SendSiteFreight"
	_send.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_send.pressed.connect(func() -> void:
		runtime.send(_destination, Model.Ledger.KINDS[_resource.selected], int(_amount.value))
		refresh())
	add_child(_send)
	_cancel = Style.button("")
	_cancel.name = "CancelSiteFreight"
	_cancel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cancel.pressed.connect(func() -> void: runtime.cancel(); refresh())
	add_child(_cancel)
	_state = Style.label("", 15, Style.MUTED)
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_state)
	refresh()

func refresh() -> void:
	if _title == null: return
	var body: Dictionary = runtime.controller.body()
	var source: String = runtime.controller.village().get("id", "")
	_destination = ""
	for id: String in body.get("settlements", {}).get("entries", {}):
		if id != source: _destination = id
	var collection = runtime.controller.Settlements
	var target_key: String = "SETTLEMENT_HOME" if _destination == collection.origin_id(body) else "SETTLEMENT_OUTPOST"
	_title.text = Text.text("SITE_FREIGHT_TITLE") % Text.text(target_key)
	_send.text = Text.text("SITE_FREIGHT_SEND")
	_cancel.text = Text.text("SITE_FREIGHT_CANCEL")
	_amount.tooltip_text = Text.text("SITE_FREIGHT_AMOUNT")
	for index: int in Model.Ledger.KINDS.size(): _resource.set_item_text(index, Text.text("TRIBE_RESOURCE_" + Model.Ledger.KINDS[index].to_upper()))
	var reason: String = runtime.reason(_destination)
	_send.disabled = not reason.is_empty()
	_cancel.disabled = not runtime.controller.is_active() or not Model.active(body) or body[Model.FIELD].cancel_requested
	var value: Dictionary = Model.job(body)
	var detail: String = Text.text(reason if not reason.is_empty() else "SITE_FREIGHT_HELP")
	if not value.is_empty():
		var status: String = "SITE_FREIGHT_STATUS_" + str(value.status).to_upper()
		if Model.active(body) and not value.blocked.is_empty(): status = "SITE_FREIGHT_STATUS_BLOCKED"
		elif Model.active(body) and body[Model.FIELD].cancel_requested: status = "SITE_FREIGHT_STATUS_RETURNING"
		detail = Text.text("SITE_FREIGHT_DETAIL") % [Text.text(status), int(value.amount), Text.text("TRIBE_RESOURCE_" + str(value.resource_id).to_upper())]
		if not Model.active(body): detail += "\n" + Text.text(reason if not reason.is_empty() else "SITE_FREIGHT_HELP")
	if not runtime.message.is_empty(): detail += "\n" + Text.text(runtime.message)
	_state.text = detail
