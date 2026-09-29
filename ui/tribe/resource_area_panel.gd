extends VBoxContainer
## A readout for canonical village deposits and placed production sites.
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

func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title = Style.label("", 17, Style.SOCIAL)
	add_child(_title)
	_amount = Style.label("", 15, Style.TEXT)
	add_child(_amount)
	_workers = Style.label("", 15, Style.MUTED)
	add_child(_workers)
	var actions := HFlowContainer.new()
	add_child(actions)
	_add = Style.button("")
	_add.name = "AddAreaWorker"
	actions.add_child(_add)
	_add.pressed.connect(func() -> void: controller.adjust_resource_workers(source_id, 1))
	_remove = Style.button("")
	_remove.name = "RemoveAreaWorker"
	actions.add_child(_remove)
	_remove.pressed.connect(func() -> void: controller.adjust_resource_workers(source_id, -1))
	hide()

func select_source(identity: String) -> void:
	source_id = identity
	refresh(controller.village())

func refresh(data: Dictionary) -> void:
	if source_id.is_empty() or data.is_empty():
		hide()
		return
	var site: Dictionary = controller.resource_details(source_id)
	visible = not site.is_empty()
	if site.is_empty(): return
	_title.text = Text.format_text("RESOURCE_AREA_TITLE", {"resource": Presentation.resource_title(site.kind)})
	_amount.text = Text.format_text("RESOURCE_AREA_AMOUNT", {"available": site.remaining, "stored": data.stock.get(site.kind, 0)})
	_workers.text = Text.format_text("RESOURCE_AREA_WORKERS", {"assigned": site.assigned, "total": data.members.size()})
	_add.text = Text.text("RESOURCE_AREA_ADD")
	_remove.text = Text.text("RESOURCE_AREA_REMOVE")
	_add.disabled = not controller.is_active() or site.assigned >= data.members.size()
	_remove.disabled = not controller.is_active() or site.assigned == 0
	_add.tooltip_text = Text.text("RESOURCE_AREA_ADD_HINT")
