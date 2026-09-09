extends SubViewportContainer
## One selected creature, using the same renderer as wildlife. No world actors.

const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")

var viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _center := Vector3.ZERO
var _bounds := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
var _radius: float = 2.0
var _angle: float = 0.65
var _zoom: float = 1.0


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 230)
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = "Mit gedrückter linker Maustaste drehen · Mausrad zum Zoomen"
	viewport = SubViewport.new()
	viewport.size = Vector2i(600, 300)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("172e2d")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dbebe1")
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -32, 0)
	light.light_energy = 1.1
	viewport.add_child(light)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 38
	_camera.current = true
	viewport.add_child(_camera)
	resized.connect(_frame_camera)
	visibility_changed.connect(_update_rendering)
	gui_input.connect(_on_gui_input)


func show_blueprint(blueprint: Dictionary) -> void:
	clear()
	_angle = 0.65
	_zoom = 1.0
	_model = Preview.new()
	_model.set("blueprint", blueprint.duplicate(true))
	# Avoid editor handles and collision; setting the data before ready builds once.
	_model.set("show_spine_handles", false)
	_pivot.add_child(_model)
	var boxes: Array[AABB] = []
	_collect_bounds(_model, Transform3D.IDENTITY, boxes)
	var bounds := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	if not boxes.is_empty():
		bounds = boxes[0]
		for index in range(1, boxes.size()):
			bounds = bounds.merge(boxes[index])
	_center = bounds.get_center()
	_bounds = bounds
	_radius = maxf(bounds.size.length() * 0.5, 0.5)
	_frame_camera()
	_update_rendering()


func clear() -> void:
	if is_instance_valid(_model):
		_pivot.remove_child(_model)
		_model.queue_free()
	_model = null
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _collect_bounds(node: Node, parent_transform: Transform3D, boxes: Array[AABB]) -> void:
	var transform: Transform3D = parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	if node is VisualInstance3D:
		boxes.append(transform * node.get_aabb())
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_collect_bounds(child, transform, boxes)


func _frame_camera() -> void:
	if _camera == null:
		return
	var aspect: float = maxf(size.x / maxf(size.y, 1.0), 0.3)
	var tangent: float = tan(deg_to_rad(_camera.fov * 0.5))
	var direction := Vector3(sin(_angle), 0.30, cos(_angle)).normalized()
	var right: Vector3 = Vector3.UP.cross(direction).normalized()
	var up: Vector3 = direction.cross(right).normalized()
	# Fit projected bounds, not an oversized sphere around a long, narrow body.
	var distance: float = 0.5
	for corner in range(8):
		var offset: Vector3 = _bounds.get_endpoint(corner) - _center
		var depth: float = offset.dot(direction)
		distance = maxf(distance, absf(offset.dot(right)) / (tangent * aspect) + depth)
		distance = maxf(distance, absf(offset.dot(up)) / tangent + depth)
	distance *= 1.12 * _zoom
	_camera.position = _center + direction * distance
	_camera.far = maxf(distance + _radius * 4.0, 100.0)
	_camera.look_at(_center)
	if is_instance_valid(_model) and is_visible_in_tree():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _update_rendering() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if is_visible_in_tree() and is_instance_valid(_model) else SubViewport.UPDATE_DISABLED


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_angle -= event.relative.x * 0.012
		_frame_camera()
		accept_event()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(_zoom * 0.9, 0.65)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(_zoom * 1.1, 2.0)
		else:
			return
		_frame_camera()
		accept_event()
