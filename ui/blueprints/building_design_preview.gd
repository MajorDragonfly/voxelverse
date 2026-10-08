extends SubViewportContainer
## One read-only workshop design, rendered by the existing building renderer.
## Selection replaces the prior model; hidden previews perform no render work.

const Visual = preload("res://civilization/buildings/building_runtime_visual.gd")
const Blueprint = preload("res://civilization/buildings/building_blueprint.gd")
const Design = preload("res://ui/design/design_system.gd")

var _viewport: SubViewport
var _camera: Camera3D
var _visual: Visual
var _blueprint: Dictionary = {}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 160)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(420, 240)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Design.INK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("eee7d7")
	environment.environment.ambient_light_energy = 0.7
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -32, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)
	_camera = Camera3D.new()
	_camera.fov = 38
	_camera.current = true
	_viewport.add_child(_camera)
	resized.connect(_frame)
	visibility_changed.connect(_update_visibility)
	if not _blueprint.is_empty(): _build()


func show_design(blueprint: Dictionary) -> bool:
	if not Blueprint.Contract.inspect(blueprint, "building").ok:
		clear()
		return false
	if _blueprint == blueprint: return true
	_blueprint = blueprint.duplicate(true)
	if is_node_ready(): _build()
	return true


func clear() -> void:
	_blueprint.clear()
	_release_model()
	if _viewport != null: _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _release_model() -> void:
	if is_instance_valid(_visual):
		_viewport.remove_child(_visual)
		_visual.queue_free()
	_visual = null


func _build() -> void:
	_release_model()
	_visual = Visual.new()
	_visual.build_collision = false
	_visual.set_blueprint(_blueprint)
	_viewport.add_child(_visual)
	_frame()


func _frame() -> void:
	if not is_instance_valid(_visual) or _camera == null: return
	var bounds: AABB = _visual.get_combined_aabb()
	var radius: float = maxf(bounds.size.length() * 0.5, 0.5)
	var aspect: float = maxf(size.x, 1.0) / maxf(size.y, 1.0)
	var half_angle: float = atan(tan(deg_to_rad(_camera.fov * 0.5)) * minf(aspect, 1.0))
	var distance: float = radius / sin(half_angle) * 1.08
	var center: Vector3 = bounds.get_center()
	_camera.position = center + Vector3(1, 0.65, 1).normalized() * distance
	_camera.far = maxf(distance + radius * 4.0, 100.0)
	_camera.look_at(center)
	_update_visibility()


func _update_visibility() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() and is_instance_valid(_visual) else SubViewport.UPDATE_DISABLED
