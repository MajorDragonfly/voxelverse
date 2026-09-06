extends Node

var _player: Node3D
var _ray: RayCast3D
var _hud: CanvasLayer
var _label: Label


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
	_label = Label.new()
	_label.name = "ContextActionLabel"
	_label.anchor_left = 0.5
	_label.anchor_top = 0.5
	_label.anchor_right = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -330.0
	_label.offset_top = 80.0
	_label.offset_right = 330.0
	_label.offset_bottom = 132.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.91, 0.95))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.visible = false
	_hud.add_child(_label)


func _update_context() -> void:
	if _label == null or _ray == null:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_label.visible = false
		return
	if not _ray.is_colliding():
		_label.visible = false
		return
	var collider := _ray.get_collider() as Node
	var point: Vector3 = _ray.get_collision_point()
	if collider != null and collider.is_in_group(&"wildlife"):
		_show_wildlife_context(collider)
		return
	if collider != null and collider.is_in_group(&"berry_bush"):
		var depleted: bool = bool(collider.get("is_depleted"))
		_label.text = "Berry bush · empty" if depleted else "Berry bush · LMB eat"
		_label.visible = true
		return
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator != null and generator.has_method("is_below_sea_level"):
		if bool(generator.call("is_below_sea_level", point.x, point.z)):
			_label.text = "Water · LMB drink"
			_label.visible = true
			return
	_label.visible = false


func _show_wildlife_context(target: Node) -> void:
	var blueprint_value: Variant = target.get("blueprint")
	var blueprint: Dictionary = blueprint_value if blueprint_value is Dictionary else {}
	var species: Dictionary = blueprint.get("species", {})
	var species_seed: int = int(target.get("species_seed"))
	var role: String = str(target.get("ecological_role"))
	var dead: bool = bool(target.get("is_dead"))
	if dead:
		var food_remaining: float = float(target.get("carcass_food_remaining"))
		_label.text = "Carcass · %d food · LMB eat" % roundi(food_remaining)
		_label.visible = true
		return

	var known: bool = _is_species_known(species_seed)
	var display_name: String = "Unknown creature"
	if known:
		display_name = str(
			species.get("display_name", blueprint.get("name", "Known creature"))
		)
	var current_health: float = float(target.get("current_health"))
	var maximum_health: float = maxf(float(target.get("maximum_health")), 1.0)
	_label.text = "%s · %s · HP %d/%d · LMB observe · RMB/Q bite" % [
		display_name,
		role.capitalize(),
		roundi(current_health),
		roundi(maximum_health),
	]
	_label.visible = true


func _is_species_known(species_seed: int) -> bool:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null:
		return false
	var discoveries_value: Variant = progression.get("discovered_species")
	if not (discoveries_value is Dictionary):
		return false
	var world_seed: int = 1
	var generator := get_node_or_null("/root/WorldGenerator")
	if generator != null and generator.has_method("get_world_seed"):
		world_seed = int(generator.call("get_world_seed"))
	var key: String = "%d:%d" % [world_seed, species_seed]
	return discoveries_value.has(key)
