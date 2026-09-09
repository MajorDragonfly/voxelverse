extends CharacterBody3D
## Own-species nest resident. Deliberately separate from streamed wild animals
## and the social encounter ledger; it never grants points or recruits wildlife.

const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
const State = preload("res://world/home_group/home_group_state.gd")
const Space = preload("res://world/surface/gameplay_space.gd")

var controller: Node
var member_id: String
var move_speed: float = 5.4
var maximum_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false
var _visual: Node3D
var _label: Label3D
var status: String = "Wartet"
var _turn_sign: float = 1.0

func setup(owner_node: Node, member: Dictionary, blueprint: Dictionary, index: int) -> void:
	controller = owner_node
	member_id = str(member["id"])
	global_position = Space.resolve(self, member["position"])
	_turn_sign = -1.0 if index % 2 == 0 else 1.0
	name = "HomeCompanion%d" % index
	collision_layer = 0
	collision_mask = 1 | 2
	floor_snap_length = 0.65
	floor_max_angle = deg_to_rad(45.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.35
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.68
	add_child(collider)
	_visual = Node3D.new()
	_visual.name = "CreatureRuntimeVisual"
	add_child(_visual)
	var preview := Preview.new()
	preview.name = "BlueprintCreatureVisual"
	preview.position.y = 0.65
	preview.scale = Vector3.ONE * 0.68
	_visual.add_child(preview)
	preview.set_editor_state(blueprint.duplicate(true), -1, -1, false)
	_disable_collisions(preview)
	var animator := Animator.new()
	animator.name = "AdaptiveLocomotionAnimator"
	add_child(animator)
	_label = Label3D.new()
	_label.text = str(member["name"])
	_label.position.y = 2.0
	_label.font_size = 28
	_label.pixel_size = 0.007
	_label.modulate = Color(0.98, 0.87, 0.57)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	Space.track(self, member_id)

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collisions(child)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not controller.is_active():
		return
	Space.orient(self)
	var member: Dictionary = controller.member_record(member_id)
	if member.is_empty():
		return
	var player: Node3D = controller.player
	if player == null or player.global_position.distance_to(global_position) > 90.0 or not controller.has_ground(global_position):
		visible = false
		velocity = Vector3.ZERO
		status = "Außerhalb der geladenen Umgebung"
		return
	visible = true
	var target: Vector3 = global_position
	var order: String = str(member["order"])
	if order == "follow":
		target = Space.offset(self, player.global_position, Vector3(_turn_sign * 2.3, 0.0, 2.3))
	elif order == "home":
		target = Space.offset(self, controller.home_position(), Vector3(_turn_sign * 2.3, 0.0, 2.3))
	var offset: Vector3 = target - global_position
	offset = offset.slide(up_direction)
	var direction := Vector3.ZERO
	status = "Wartet" if order == "wait" else "Am Heimatplatz" if order == "home" else "Bei dir"
	if order != "wait" and offset.length() > 1.1:
		direction = offset.normalized()
		status = "Folgt dir" if order == "follow" else "Kehrt heim"
		# Small local avoidance, not global pathfinding. Never cross unknown floor,
		# a steep drop or deep water; waiting is preferable to teleporting a member.
		var chosen := Vector3.ZERO
		for angle in [0.0, _turn_sign * 0.65, -_turn_sign * 0.65, _turn_sign * 1.1]:
			var candidate: Vector3 = direction.rotated(up_direction, angle)
			if controller.safe_step(self, candidate):
				chosen = candidate
				break
		direction = chosen
		if direction == Vector3.ZERO:
			status = "Weg blockiert"
	velocity = direction * move_speed + up_direction * (-0.5 if is_on_floor() else maxf(-12.0, velocity.dot(up_direction) - 20.0 * delta))
	if is_on_floor() and direction != Vector3.ZERO:
		_step_up(direction * move_speed * delta)
	move_and_slide()
	if is_on_floor():
		apply_floor_snap()
	if direction != Vector3.ZERO:
		var local_direction: Vector3 = global_basis.inverse() * direction
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-local_direction.x, -local_direction.z), minf(delta * 7.0, 1.0))
	controller.record_position(member_id, global_position)

func _step_up(motion: Vector3) -> void:
	Space.step(self, motion, 0.55, 0.15)

func surface_origin_shifted(shift: Vector3) -> void:
	get_node("AdaptiveLocomotionAnimator").surface_origin_shifted(shift)
