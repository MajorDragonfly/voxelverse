extends PanelContainer
## Presentation only; the HUD host supplies a fresh canonical selection on refresh.
const Equipment = preload("res://world/tribe/resident_equipment_model.gd")
const View = preload("res://ui/tribe/resident_details_view.gd")
const Text = preload("res://core/localization/ui_text.gd")
const Presentation = preload("res://ui/tribe/tribe_presentation.gd")
const Style = preload("res://ui/progression_style.gd")
var observation: Dictionary = {}
var resident_name: Label
var health: Label
var activity: Label
var food_text: Label
var water_text: Label
var food: ProgressBar
var water: ProgressBar
var cargo: Label
var workplace: Label
var equipment: Label
var command_handler: Callable
var village_id: String = ""
var slot_choices: Dictionary = {}
var equip_buttons: Dictionary = {}
var return_buttons: Dictionary = {}
var craft_choice: OptionButton
var craft_cost: Label
var craft_button: Button
var equipment_controls: VBoxContainer
var last_result: Dictionary = {}

func _ready() -> void:
	name = "SelectedResidentDetail"
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.box(Color("223740"), Color("52706c"), 9))
	var content := Style.column(self, 4)
	resident_name = _label(content, "ResidentName", 18, Style.SOCIAL)
	health = _label(content, "ResidentHealth", 14, Style.TEXT)
	health.mouse_filter = Control.MOUSE_FILTER_PASS # Tooltip participates; panel still shields world clicks.
	activity = _label(content, "ResidentActivity", 15, Style.TEXT)
	food_text = _label(content, "ResidentFoodText", 14, Style.MUTED)
	food = _meter(content, "ResidentFood", Color("b5cc80"))
	water_text = _label(content, "ResidentWaterText", 14, Style.MUTED)
	water = _meter(content, "ResidentWater", Color("78bad0"))
	cargo = _label(content, "ResidentCargo", 14, Style.TEXT)
	cargo.mouse_filter = Control.MOUSE_FILTER_PASS
	workplace = _label(content, "ResidentWorkplace", 14, Style.TEXT)
	equipment = _label(content, "ResidentEquipment", 14, Style.MUTED)
	_build_equipment(content)
	hide()

func refresh(data: Dictionary, selected: Array, actors: Dictionary = {}, current_activity: String = "") -> void:
	observation = View.snapshot(data, selected, actors)
	visible = not observation.is_empty()
	if not visible: return
	resident_name.text = observation.name # Literal names, never translation keys.
	health.text = Text.text("RESIDENT_HEALTH_UNAVAILABLE") if observation.health_percent == null else Text.format_text("RESIDENT_HEALTH", {"percent": roundi(observation.health_percent)})
	health.tooltip_text = Text.text("RESIDENT_HEALTH_HINT")
	activity.text = Text.format_text("TRIBE_RESIDENT_DETAIL_ACTIVITY", {
		"profession": Presentation.job_title(observation.profession),
		"activity": current_activity if not current_activity.is_empty() else Presentation.activity_title(observation.order)})
	food.value = observation.food
	water.value = observation.water
	food_text.text = Text.format_text("TRIBE_RESIDENT_DETAIL_FOOD", {"percent": roundi(observation.food)})
	water_text.text = Text.format_text("TRIBE_RESIDENT_DETAIL_WATER", {"percent": roundi(observation.water)})
	cargo.text = Text.text("RESIDENT_CARGO_EMPTY") if observation.cargo.is_empty() else Text.format_text("RESIDENT_CARGO", {"resource": Presentation.resource_title(observation.cargo)})
	cargo.tooltip_text = Text.text("RESIDENT_CARGO_BUILDING") if not observation.construction_id.is_empty() else ""
	workplace.text = Text.text("RESIDENT_WORKPLACE_NONE") if observation.workplace_key.is_empty() else Text.format_text("RESIDENT_WORKPLACE", {
		"name": Text.text("VILLAGE_WORLD_WELL" if observation.workplace_kind == "well" else Presentation.PROJECTS[observation.workplace_kind]), "number": 2 if observation.workplace_key.ends_with(":2") else 1})
	_refresh_equipment(data)

func _build_equipment(parent: Node) -> void:
	equipment_controls = Style.column(parent, 4)
	for slot: String in Equipment.SLOTS:
		var choice := OptionButton.new()
		choice.name = "EquipmentChoice" + slot.capitalize()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.set_meta("tribe_base_font_size", 14)
		equipment_controls.add_child(choice)
		slot_choices[slot] = choice
		var equip := _equipment_button(equipment_controls, "EquipmentEquip" + slot.capitalize())
		equip.pressed.connect(func() -> void:
			var selection: OptionButton = slot_choices[slot]
			_send({"action": "equip", "slot": slot, "item_id": selection.get_item_metadata(selection.selected) if selection.selected >= 0 else ""}))
		equip_buttons[slot] = equip
		var give_back := _equipment_button(equipment_controls, "EquipmentReturn" + slot.capitalize())
		give_back.pressed.connect(func() -> void: _send({"action": "return", "slot": slot}))
		return_buttons[slot] = give_back
		choice.item_selected.connect(func(_index: int) -> void: _refresh_choice_buttons(slot))
	craft_choice = OptionButton.new()
	craft_choice.name = "EquipmentRecipe"
	craft_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_choice.set_meta("tribe_base_font_size", 14)
	equipment_controls.add_child(craft_choice)
	craft_cost = _label(equipment_controls, "EquipmentMaterialCosts", 14, Style.MUTED)
	craft_button = _equipment_button(equipment_controls, "EquipmentCraft")
	craft_button.pressed.connect(func() -> void: _send({"action": "craft", "kind": _craft_kind()}))
	craft_choice.item_selected.connect(func(_index: int) -> void:
		# The host refresh supplies current stock, never a retained dictionary.
		if refresh_handler.is_valid(): refresh_handler.call())

var refresh_handler: Callable

func _equipment_button(parent: Node, node_name: String) -> Button:
	var button: Button = Style.button("")
	button.name = node_name
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("tribe_base_font_size", 14)
	parent.add_child(button)
	return button

func _request(action: Dictionary) -> Dictionary:
	return action.merged({"village_id": village_id, "resident_id": observation.get("id", "")}, true)

func _send(action: Dictionary) -> void:
	if command_handler.is_valid(): last_result = command_handler.call(_request(action))

func _item_text(item: Dictionary) -> String:
	return Text.format_text("EQUIPMENT_ITEM", {"name": Text.text("EQUIPMENT_KIND_" + str(item.kind).to_upper()), "number": int(item.sequence)})

func _selection(choice: OptionButton) -> String:
	return str(choice.get_item_metadata(choice.selected)) if choice.selected >= 0 else ""

func _craft_kind() -> String:
	return _selection(craft_choice)

func _refresh_choice_buttons(slot: String) -> void:
	var choice: OptionButton = slot_choices[slot]
	equip_buttons[slot].disabled = not command_handler.is_valid() or choice.disabled or choice.selected < 0 or _selection(choice).is_empty()

func _refresh_equipment(data: Dictionary) -> void:
	village_id = str(data.id)
	var lines := PackedStringArray()
	for slot: String in Equipment.SLOTS:
		var personal: Dictionary = observation.personal_equipment.get(slot, {})
		lines.append(Text.format_text("EQUIPMENT_PERSONAL_" + slot.to_upper(), {"item": Text.text("EQUIPMENT_NONE") if personal.is_empty() else _item_text(personal)}))
		var choice: OptionButton = slot_choices[slot]
		var old: String = _selection(choice)
		choice.clear()
		var free: Array[Dictionary] = Equipment.free_items(data, slot) if Equipment.validate(data).is_empty() else []
		if free.is_empty():
			choice.add_item(Text.text("EQUIPMENT_FREE_EMPTY"))
			choice.set_item_metadata(0, "")
		for item: Dictionary in free:
			choice.add_item(_item_text(item))
			var index: int = choice.item_count - 1
			choice.set_item_metadata(index, item.id)
			if item.id == old: choice.select(index)
		var request: Dictionary = _request({"action": "equip", "slot": slot, "item_id": _selection(choice)})
		var problem: String = Equipment.preflight(data, request)
		choice.disabled = not command_handler.is_valid() or not problem.is_empty()
		choice.tooltip_text = Text.text("EQUIPMENT_FREE_HINT") if problem.is_empty() else Text.text(problem)
		equip_buttons[slot].text = Text.text("EQUIPMENT_EQUIP_" + slot.to_upper())
		equip_buttons[slot].tooltip_text = choice.tooltip_text
		_refresh_choice_buttons(slot)
		var returned: String = Equipment.preflight(data, _request({"action": "return", "slot": slot}))
		return_buttons[slot].text = Text.text("EQUIPMENT_RETURN_" + slot.to_upper())
		return_buttons[slot].disabled = not command_handler.is_valid() or not returned.is_empty()
		return_buttons[slot].tooltip_text = Text.text("EQUIPMENT_RETURN_HINT") if returned.is_empty() else Text.text(returned)
	equipment.text = "\n".join(lines)
	equipment.tooltip_text = Text.text("EQUIPMENT_EFFECTS_HINT")
	var old_recipe: String = _craft_kind()
	craft_choice.clear()
	for kind: String in Equipment.KINDS:
		craft_choice.add_item(Text.text("EQUIPMENT_KIND_" + kind.to_upper()))
		var index: int = craft_choice.item_count - 1
		craft_choice.set_item_metadata(index, kind)
		if kind == old_recipe: craft_choice.select(index)
	var definition: Dictionary = Equipment.recipe(_craft_kind())
	var costs := PackedStringArray()
	for resource: String in definition.get("inputs", {}):
		costs.append("%d %s" % [int(definition.inputs[resource]), Presentation.resource_title(resource)])
	craft_cost.text = Text.format_text("EQUIPMENT_COSTS", {"materials": ", ".join(costs)})
	craft_button.text = Text.text("EQUIPMENT_CRAFT")
	var problem: String = Equipment.preflight(data, _request({"action": "craft", "kind": _craft_kind()}))
	craft_button.disabled = not command_handler.is_valid() or not problem.is_empty()
	craft_button.tooltip_text = Text.text("EQUIPMENT_CRAFT_HINT") if problem.is_empty() else Text.text(problem)


func _label(parent: Node, node_name: String, font_size: int, color: Color) -> Label:
	var result := Style.label("", font_size, color)
	result.name = node_name
	result.set_meta("tribe_base_font_size", font_size)
	parent.add_child(result)
	return result

func _meter(parent: Node, node_name: String, color: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.name = node_name
	meter.show_percentage = false
	meter.custom_minimum_size.y = 9
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("14252d")
	meter.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	meter.add_theme_stylebox_override("fill", fill)
	parent.add_child(meter)
	return meter
