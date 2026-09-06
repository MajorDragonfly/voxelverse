extends Node

@export_range(0.5, 12.0, 0.5) var linger_time: float = 4.5

var _player: Node
var _hud: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _target: Node
var _timer: float = 0.0


func _ready() -> void:
	_player = get_parent()
	call_deferred("_install")


func _process(delta: float) -> void:
	if _panel == null or not _panel.visible:
		return
	_timer -= delta
	if _target == null or not is_instance_valid(_target):
		_panel.visible = false
		_target = null
		return
	_refresh_target()
	if _timer <= 0.0:
		_panel.visible = false
		_target = null


func _install() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return
	_panel = PanelContainer.new()
	_panel.name = "CombatTargetPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -210.0
	_panel.offset_top = 22.0
	_panel.offset_right = 210.0
	_panel.offset_bottom = 102.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_name_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(390.0, 16.0)
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.show_percentage = false
	box.add_child(_health_bar)
	_health_label = Label.new()
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_health_label)
	_panel.visible = false
	_hud.add_child(_panel)
	if _player.has_signal("creature_attacked"):
		_player.connect("creature_attacked", Callable(self, "_on_creature_attacked"))


func _on_creature_attacked(target: Node, _damage: float) -> void:
	if target == null:
		return
	_target = target
	_timer = linger_time
	_panel.visible = true
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
	_health_label.text = "DEFEATED" if bool(data.get("dead", false)) else "%d / %d HP" % [roundi(current), roundi(maximum)]
