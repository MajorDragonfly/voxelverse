extends Node

@export_range(3, 12, 1) var maximum_listed_creatures: int = 6

var _player: Node
var _hud: CanvasLayer
var _panel: PanelContainer
var _title: Label
var _detail: Label
var _nearby: Label


func _ready() -> void:
	_player = get_parent()
	call_deferred("_install")


func _process(_delta: float) -> void:
	if _panel == null or _player == null:
		return
	var enabled: bool = false
	if _player.has_method("is_inspection_mode_enabled"):
		enabled = bool(_player.call("is_inspection_mode_enabled"))
	_panel.visible = enabled
	if enabled:
		_refresh()


func _install() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "CreatureInspectionPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -405.0
	_panel.offset_top = 78.0
	_panel.offset_right = -22.0
	_panel.offset_bottom = 530.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	_panel.add_child(box)
	_title = Label.new()
	_title.text = "CREATURE INSPECTION"
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(360.0, 210.0)
	_detail.add_theme_font_size_override("font_size", 13)
	box.add_child(_detail)
	var separator := HSeparator.new()
	box.add_child(separator)
	_nearby = Label.new()
	_nearby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nearby.add_theme_font_size_override("font_size", 12)
	box.add_child(_nearby)
	_panel.visible = false
	_hud.add_child(_panel)


func _refresh() -> void:
	var target: Node = null
	if _player.has_method("get_interaction_target"):
		target = _player.call("get_interaction_target")
	if target == null or not target.is_in_group(&"wildlife"):
		var nearby_value: Variant = _player.call("get_nearby_wildlife", maximum_listed_creatures)
		if nearby_value is Array and not nearby_value.is_empty():
			target = nearby_value[0]
	_show_target(target)
	_show_nearby()


func _show_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		_detail.text = "No creature in inspection range.\n\nLook at a creature or move closer."
		return
	var data: Dictionary = {}
	if target.has_method("get_inspection_data"):
		data = target.call("get_inspection_data")
	else:
		_detail.text = "Target has no inspection data."
		return
	var distance: float = 0.0
	if target is Node3D and _player is Node3D:
		distance = (_player as Node3D).global_position.distance_to((target as Node3D).global_position)
	var diet_text: String = _diet_label(
		float(data.get("diet_plant", 0.0)),
		float(data.get("diet_meat", 0.0))
	)
	_detail.text = (
		"%s\n"
		+ "%s · %.1f m away\n\n"
		+ "Health     %d / %d\n"
		+ "Speed      %.1f\n"
		+ "Jump       %.1f\n"
		+ "Attack     %.1f\n"
		+ "Defense    %.1f\n"
		+ "Perception %.1f\n"
		+ "Grip       %.1f\n"
		+ "Swim       %.1f\n"
		+ "Diet       %s\n"
		+ "Parts      %d\n\n"
		+ "LMB observe · RMB/Q bite · E close inspection"
	) % [
		str(data.get("name", "Unknown Creature")),
		str(data.get("role", "unknown")).capitalize(),
		distance,
		roundi(float(data.get("health", 0.0))),
		roundi(float(data.get("maximum_health", 0.0))),
		float(data.get("speed", 0.0)),
		float(data.get("jump", 0.0)),
		float(data.get("attack", 0.0)),
		float(data.get("defense", 0.0)),
		float(data.get("perception", 0.0)),
		float(data.get("grip", 0.0)),
		float(data.get("swim", 0.0)),
		diet_text,
		int(data.get("part_count", 0)),
	]


func _show_nearby() -> void:
	var values: Variant = _player.call("get_nearby_wildlife", maximum_listed_creatures)
	if not (values is Array):
		_nearby.text = "Nearby creatures: none"
		return
	var creatures: Array = values
	if creatures.is_empty():
		_nearby.text = "Nearby creatures: none"
		return
	var lines: Array[String] = ["NEARBY"]
	for creature_value in creatures:
		var creature := creature_value as Node3D
		if creature == null or not is_instance_valid(creature):
			continue
		var name_value: String = str(creature.name)
		if creature.has_method("get_display_name"):
			name_value = str(creature.call("get_display_name"))
		var role: String = str(creature.get("ecological_role"))
		var distance: float = (_player as Node3D).global_position.distance_to(creature.global_position)
		lines.append("• %s · %s · %.0f m" % [name_value, role.capitalize(), distance])
	_nearby.text = "\n".join(lines)


func _diet_label(plant: float, meat: float) -> String:
	if plant > meat * 1.35:
		return "Plant eater"
	if meat > plant * 1.35:
		return "Meat eater"
	if plant > 0.05 and meat > 0.05:
		return "Omnivore"
	return "Unknown"
