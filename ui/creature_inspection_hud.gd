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
	_panel.offset_left = -425.0
	_panel.offset_top = 82.0
	_panel.offset_right = -22.0
	_panel.offset_bottom = 566.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.022, 0.032, 0.040, 0.90)
	panel_style.border_color = Color(0.36, 0.68, 0.64, 0.34)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 9
	panel_style.corner_radius_top_right = 9
	panel_style.corner_radius_bottom_left = 9
	panel_style.corner_radius_bottom_right = 9
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", panel_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_title = Label.new()
	_title.text = "CREATURE INSPECTION"
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", Color(0.66, 0.92, 0.84, 1.0))
	box.add_child(_title)

	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(370.0, 240.0)
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color(0.91, 0.94, 0.92, 0.98))
	box.add_child(_detail)

	var separator := HSeparator.new()
	box.add_child(separator)

	_nearby = Label.new()
	_nearby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nearby.add_theme_font_size_override("font_size", 12)
	_nearby.add_theme_color_override("font_color", Color(0.72, 0.79, 0.77, 0.96))
	box.add_child(_nearby)

	var controls := Label.new()
	controls.text = "E close  ·  LMB observe  ·  RMB / Q bite"
	controls.add_theme_font_size_override("font_size", 11)
	controls.add_theme_color_override("font_color", Color(0.54, 0.64, 0.62, 0.92))
	box.add_child(controls)

	_panel.visible = false
	_hud.add_child(_panel)


func _refresh() -> void:
	var target: Node = null
	if _player.has_method("get_interaction_target"):
		target = _player.call("get_interaction_target")
	if target == null or not target.is_in_group(&"wildlife"):
		var nearby_value: Variant = _player.call(
			"get_nearby_wildlife",
			maximum_listed_creatures
		)
		if nearby_value is Array and not nearby_value.is_empty():
			target = nearby_value[0]
	_show_target(target)
	_show_nearby(target)


func _show_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		_detail.text = (
			"No creature inside inspection range.\n\n"
			+ "Move closer to wildlife. The closest visible creature "
			+ "will be inspected automatically."
		)
		return
	if not target.has_method("get_inspection_data"):
		_detail.text = "This creature has no inspection data."
		return

	var data: Dictionary = target.call("get_inspection_data")
	var distance: float = 0.0
	if target is Node3D and _player is Node3D:
		distance = (
			(_player as Node3D).global_position.distance_to(
				(target as Node3D).global_position
			)
		)
	var diet_text: String = _diet_label(
		float(data.get("diet_plant", 0.0)),
		float(data.get("diet_meat", 0.0))
	)
	var life_state: String = "DEAD" if bool(data.get("dead", false)) else "ALIVE"
	_detail.text = (
		"%s\n"
		+ "%s  ·  %.1f m  ·  %s\n\n"
		+ "HEALTH      %d / %d\n"
		+ "SPEED       %.1f\n"
		+ "JUMP        %.1f\n"
		+ "ATTACK      %.1f\n"
		+ "DEFENSE     %.1f\n"
		+ "PERCEPTION  %.1f\n"
		+ "GRIP        %.1f\n"
		+ "SWIM        %.1f\n"
		+ "DIET        %s\n"
		+ "BODY PARTS  %d"
	) % [
		str(data.get("name", "Unknown Creature")),
		str(data.get("role", "unknown")).capitalize(),
		distance,
		life_state,
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


func _show_nearby(selected: Node) -> void:
	var values: Variant = _player.call(
		"get_nearby_wildlife",
		maximum_listed_creatures
	)
	if not (values is Array):
		_nearby.text = "NEARBY\nnone"
		return
	var creatures: Array = values
	if creatures.is_empty():
		_nearby.text = "NEARBY\nnone"
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
		var distance: float = (
			(_player as Node3D).global_position.distance_to(
				creature.global_position
			)
		)
		var marker: String = ">" if creature == selected else "•"
		lines.append(
			"%s %s · %s · %.0f m"
			% [marker, name_value, role.capitalize(), distance]
		)
	_nearby.text = "\n".join(lines)


func _diet_label(plant: float, meat: float) -> String:
	if plant > meat * 1.35:
		return "Plant eater"
	if meat > plant * 1.35:
		return "Meat eater"
	if plant > 0.05 and meat > 0.05:
		return "Omnivore"
	return "Unknown"
