extends Node

@export_range(0.5, 12.0, 0.5) var linger_time: float = 5.0

var _player: Node
var _hud: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _target: Node
var _timer: float = 0.0
var _connected_health_target: Node


func _ready() -> void:
	_player = get_parent()
	call_deferred("_install")


func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_timer -= delta
	if _target == null or not is_instance_valid(_target):
		_hide_target()
		return
	_refresh_target()
	if _timer <= 0.0:
		_hide_target()


func _install() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return

	_panel = PanelContainer.new()
	_panel.name = "CombatTargetPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -230.0
	_panel.offset_top = 22.0
	_panel.offset_right = 230.0
	_panel.offset_bottom = 116.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.045, 0.86)
	panel_style.border_color = Color(0.68, 0.74, 0.72, 0.28)
	panel_style.set_border_width_all(1)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", panel_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.94, 1.0))
	box.add_child(_name_label)

	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(420.0, 14.0)
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.10, 0.12, 0.13, 0.96)
	background_style.corner_radius_top_left = 5
	background_style.corner_radius_top_right = 5
	background_style.corner_radius_bottom_left = 5
	background_style.corner_radius_bottom_right = 5
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.77, 0.25, 0.20, 1.0)
	fill_style.corner_radius_top_left = 5
	fill_style.corner_radius_top_right = 5
	fill_style.corner_radius_bottom_left = 5
	fill_style.corner_radius_bottom_right = 5
	_health_bar.add_theme_stylebox_override("background", background_style)
	_health_bar.add_theme_stylebox_override("fill", fill_style)
	box.add_child(_health_bar)

	_health_label = Label.new()
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 12)
	_health_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.84, 0.95))
	box.add_child(_health_label)

	_panel.visible = false
	_hud.add_child(_panel)
	if _player.has_signal("creature_attacked"):
		_player.connect("creature_attacked", Callable(self, "_on_creature_attacked"))


func _on_creature_attacked(target: Node, _damage: float) -> void:
	if target == null:
		return
	_bind_target(target)
	_timer = linger_time
	_panel.visible = true
	_refresh_target()


func _bind_target(target: Node) -> void:
	if _connected_health_target != null and is_instance_valid(_connected_health_target):
		if _connected_health_target.has_signal("health_changed"):
			var old_callback := Callable(self, "_on_target_health_changed")
			if _connected_health_target.is_connected("health_changed", old_callback):
				_connected_health_target.disconnect("health_changed", old_callback)
	_target = target
	_connected_health_target = target
	if target.has_signal("health_changed"):
		var callback := Callable(self, "_on_target_health_changed")
		if not target.is_connected("health_changed", callback):
			target.connect("health_changed", callback)


func _on_target_health_changed(_current: float, _maximum: float) -> void:
	_timer = linger_time
	_refresh_target()


func _refresh_target() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var data: Dictionary = {}
	if _target.has_method("get_target_health_data"):
		data = _target.call("get_target_health_data")
	else:
		data = {
			"name": str(_target.name),
			"current_health": float(_target.get("current_health")),
			"maximum_health": maxf(float(_target.get("maximum_health")), 1.0),
			"dead": bool(_target.get("is_dead")),
		}
	var maximum: float = maxf(float(data.get("maximum_health", 1.0)), 1.0)
	var current: float = clampf(float(data.get("current_health", 0.0)), 0.0, maximum)
	_name_label.text = str(data.get("name", "Creature"))
	_health_bar.max_value = maximum
	_health_bar.value = current
	var dead: bool = bool(data.get("dead", false))
	_health_label.text = "DEFEATED" if dead else "%d / %d HP" % [roundi(current), roundi(maximum)]
	if dead:
		_timer = maxf(_timer, 2.2)


func _hide_target() -> void:
	if _panel != null:
		_panel.visible = false
	_target = null
	_connected_health_target = null
