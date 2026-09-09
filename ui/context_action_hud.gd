extends Node
const KeyHints = preload("res://core/input_preferences.gd")

var _player: Node3D
var _ray: RayCast3D
var _hud: CanvasLayer
var _label: Label
var _crosshair: Label


func _ready() -> void:
	_player = get_parent() as Node3D
	call_deferred("_install")


func _process(_delta: float) -> void:
	_update_context()


func _install() -> void:
	if _player == null:
		return
	_ray = _player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D/InteractionRay"
	) as RayCast3D
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _ray == null or _hud == null:
		return

	_crosshair = Label.new()
	_crosshair.name = "GameplayCrosshair"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -18.0
	_crosshair.offset_top = -18.0
	_crosshair.offset_right = 18.0
	_crosshair.offset_bottom = 18.0
	_crosshair.text = "+"
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_theme_font_size_override("font_size", 20)
	_crosshair.add_theme_color_override("font_color", Color(0.92, 0.96, 0.94, 0.82))
	_crosshair.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_crosshair.add_theme_constant_override("shadow_offset_x", 1)
	_crosshair.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_child(_crosshair)

	_label = Label.new()
	_label.name = "ContextActionLabel"
	_label.anchor_left = 0.5
	_label.anchor_top = 0.5
	_label.anchor_right = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -380.0
	_label.offset_top = 72.0
	_label.offset_right = 380.0
	_label.offset_bottom = 132.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.94, 0.96))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.visible = false
	_hud.add_child(_label)


func _update_context() -> void:
	if _label == null or _ray == null or _player == null:
		return
	if bool(_player.get("inspection_mode_enabled")):
		_label.hide()
		if _crosshair != null:
			_crosshair.hide()
		return
	if _crosshair != null:
		_crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_label.visible = false
		return

	var wildlife_target: Node = null
	if _player.has_method("get_interaction_target"):
		wildlife_target = _player.call("get_interaction_target")
	if wildlife_target != null and wildlife_target.is_in_group(&"wildlife"):
		_show_wildlife_context(wildlife_target)
		if _crosshair != null:
			_crosshair.add_theme_color_override(
				"font_color",
				Color(1.0, 0.88, 0.58, 0.96)
			)
		return

	if _crosshair != null:
		_crosshair.add_theme_color_override(
			"font_color",
			Color(0.92, 0.96, 0.94, 0.82)
		)

	if bool(_player.get("is_swimming")):
		_label.text = "Schwimmen · %s trinken · %s auftauchen" % [KeyHints.binding_label("primary_action"), KeyHints.binding_label("jump")]
		_label.visible = true
		return
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		_label.visible = false
		return
	var collider := _resolve_parent_target(_ray.get_collider())
	var point: Vector3 = _ray.get_collision_point()
	if collider != null and collider.is_in_group(&"berry_bush"):
		var depleted: bool = bool(collider.get("is_depleted"))
		_label.text = "Beerenstrauch · abgeerntet" if depleted else "Beeren · %s fressen" % KeyHints.binding_label("primary_action")
		_label.visible = true
		return
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator != null and generator.has_method("is_water_at"):
		var interaction_range: float = 3.2
		var range_value: Variant = _player.get("interaction_range")
		if range_value != null:
			interaction_range = float(range_value)
		if (
			_player.global_position.distance_to(point) <= interaction_range
			and bool(generator.call("is_water_at", point.x, point.z))
		):
			_label.text = "Wasser · %s trinken" % KeyHints.binding_label("primary_action")
			_label.visible = true
			return
	_label.visible = false


func _show_wildlife_context(target: Node) -> void:
	# Species identity, role and stats belong exclusively to the E scanner.
	# Keep the food action for a carcass without revealing species information.
	if bool(target.get("is_dead")):
		_label.text = "Nahrung · %s fressen" % KeyHints.binding_label("primary_action")
		_label.show()
	else:
		_label.hide()


func _resolve_parent_target(value: Variant) -> Node:
	var current := value as Node
	var depth: int = 0
	while current != null and depth < 8:
		if (
			current.is_in_group(&"wildlife")
			or current.is_in_group(&"berry_bush")
			or current.has_method("interact")
		):
			return current
		current = current.get_parent()
		depth += 1
	return null
