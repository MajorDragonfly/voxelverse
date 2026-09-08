extends CharacterBody3D
class_name RadialWalker

const Cube = preload("res://world/space/cube_sphere.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var terrain: Node3D
var forward: Vector3 = Vector3.FORWARD
var move_input: Vector2 = Vector2.ZERO
var speed: float = 10.0
var enabled: bool = true
var swimming: bool = false
var jump_requested: bool = false
var automatic: bool = false
var orbit_axis: Vector3 = Vector3.FORWARD
var preview: Node3D
var camera: Camera3D
var pitch: float = -0.18
var traveled: float = 0.0
var creature_design: Dictionary = {}


func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 2.0
	collider.shape = capsule
	add_child(collider)
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(60.0)
	safe_margin = 0.04
	preview = Preview.new()
	add_child(preview)
	preview.set_editor_state(creature_design if not creature_design.is_empty() else Blueprint.load_best_available(), -1, -1, false)
	_disable_picking(preview)
	preview.position.y = -0.9
	preview.scale = Vector3.ONE * 0.7
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 1800.0
	add_child(camera)
	_update_camera()


func _disable_picking(node: Node) -> void:
	# Editor selection shapes are not part of the creature's physical body.
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.input_ray_pickable = false
	for child in node.get_children():
		_disable_picking(child)


func location() -> Dictionary:
	return Cube.from_cartesian(terrain.surface.body.id, Cube.global_position(position, terrain.origin), terrain.surface.body.radius)


func place(location_value: Dictionary, heading: Vector3 = Vector3.FORWARD) -> void:
	var point: Array = Cube.cartesian(location_value, terrain.surface.body.radius)
	terrain.rebase(point)
	position = Vector3.ZERO
	up_direction = Cube.vector(Cube.direction(location_value.face, location_value.u, location_value.v))
	forward = -Cube.frame(up_direction, heading).z
	basis = Cube.frame(up_direction, forward)
	velocity = Vector3.ZERO
	terrain.stream_at(up_direction, true)
	_update_camera()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var address_value: Dictionary = location()
	up_direction = Cube.vector(Cube.direction(address_value.face, address_value.u, address_value.v))
	forward = -Cube.frame(up_direction, forward).z
	if automatic:
		# Steer back onto the selected great-circle plane after lateral slope
		# deflection. This changes input heading, never position or gravity.
		forward = (orbit_axis.cross(up_direction) - orbit_axis.slide(up_direction) * up_direction.dot(orbit_axis) * 16.0).normalized()
		move_input = Vector2(0.0, 1.0)
	else:
		move_input = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))).limit_length()
	basis = Cube.frame(up_direction, forward)
	terrain.stream_at(up_direction)
	var desired: Vector3 = (basis.x * move_input.x + forward * move_input.y) * speed
	var vertical: float = velocity.dot(up_direction)
	var sample: Dictionary = terrain.surface.sample(address_value)
	swimming = sample.water and address_value.height < 1.0
	if swimming:
		vertical += (0.6 - float(address_value.height)) * 18.0 * delta - vertical * minf(1.0, delta * 7.0)
	else:
		vertical -= float(terrain.surface.body.gravity) * delta
	if jump_requested and (is_on_floor() or swimming):
		vertical = 7.0
	jump_requested = false
	velocity = desired + up_direction * vertical
	var old_position: Vector3 = position
	move_and_slide()
	traveled += position.distance_to(old_position)
	if position.length() > 64.0:
		var point: Array = Cube.global_position(position, terrain.origin)
		terrain.rebase(point)
		position = Vector3.ZERO
	_update_camera()


func turn(relative: Vector2) -> void:
	forward = forward.rotated(up_direction, -relative.x * 0.003)
	pitch = clampf(pitch - relative.y * 0.003, -0.85, 0.5)


func _update_camera() -> void:
	if not is_instance_valid(camera):
		return
	camera.position = Vector3(0.0, 3.2 - sin(pitch) * 9.0, cos(pitch) * 9.0)
	camera.look_at_from_position(camera.global_position, global_position + basis.y * 1.0, basis.y)
