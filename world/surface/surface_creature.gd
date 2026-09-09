extends CharacterBody3D

## One lab specimen, using the existing creature runtime. No new species store,
## campaign AI, hunger, taming, or citizens. Inactive specimens do not simulate.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var adapter: RefCounted
var home: Dictionary
var goal: Dictionary
var returning: bool = false
var forward: Vector3 = Vector3.FORWARD
var traveled: float = 0.0
var enabled: bool = true
var waiting_for_terrain: bool = false
var preview: Node3D
var speed: float = 2.4
var commanded_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(60.0)
	# Stay below the 4 cm motion per 60 Hz tick: a 4 cm recovery margin
	# stopped the slow NPC before the sweep could report its trunk contact.
	safe_margin = 0.01
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	preview = Preview.new()
	add_child(preview)
	preview.set_editor_state(Blueprint.create_default(), -1, -1, false)
	_disable_picking(preview)
	preview.position.y = -0.9
	preview.scale = Vector3.ONE * 0.7
	preview.set_motion("walk")


func _disable_picking(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
		node.input_ray_pickable = false
	for child in node.get_children():
		_disable_picking(child)


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var here: Dictionary = adapter.location(self)
	up_direction = adapter.up_at(here)
	var target: Vector3 = adapter.to_local(home if returning else goal)
	var tangent: Vector3 = (target - position).slide(up_direction)
	if tangent.length() < 1.0:
		returning = not returning
	if commanded_direction != Vector3.ZERO:
		tangent = commanded_direction.slide(up_direction)
	forward = tangent.normalized() if tangent.length_squared() > 0.01 else -adapter.frame_at(here, forward).z
	basis = adapter.frame_at(here, forward)
	var desired: Vector3 = forward * speed
	var next: Dictionary = adapter.offset(here, desired * delta * 2.0)
	waiting_for_terrain = not adapter.collision_ready(here) or not adapter.collision_ready(next)
	# The player owns streaming and rebasing. Never consume an extra collision
	# budget or fall onto coarse/unloaded ground to keep this specimen moving.
	if waiting_for_terrain:
		velocity = Vector3.ZERO
		return
	var vertical: float = velocity.dot(up_direction) - adapter.terrain.surface.body.gravity * delta
	velocity = desired + up_direction * vertical
	var before: Vector3 = position
	if is_on_floor() and vertical <= 0.0:
		adapter.attempt_step(self, desired * delta)
	move_and_slide()
	if vertical <= 0.0:
		apply_floor_snap()
	traveled += position.distance_to(before)
