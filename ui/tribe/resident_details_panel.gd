extends PanelContainer
## Presentation only; the HUD host supplies a fresh canonical selection on refresh.
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
	equipment.text = Text.text("RESIDENT_TOOLS_UNAVAILABLE") + "\n" + Text.text("TRIBE_RESIDENT_DETAIL_CLOTHING")

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
