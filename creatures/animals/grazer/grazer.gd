extends CharacterBody3D


@export_category("Movement")
@export_range(0.1, 10.0, 0.1) var move_speed: float = 1.6
@export_range(1.0, 20.0, 0.5) var rotation_speed: float = 5.0
@export_range(1.0, 10.0, 0.5) var minimum_wander_time: float = 2.0
@export_range(1.0, 15.0, 0.5) var maximum_wander_time: float = 5.0
@export_range(0.0, 1.0, 0.05) var idle_probability: float = 0.25
@export_range(1.0, 50.0, 0.5) var fall_acceleration: float = 20.0
@export_range(0.25, 5.0, 0.25) var terrain_check_distance: float = 1.5
@export_range(0.25, 3.0, 0.25) var maximum_step_height: float = 1.0

@export_category("Survival")
@export_range(1.0, 100.0, 1.0) var maximum_health: float = 5.0
@export_range(0.1, 20.0, 0.1) var bite_damage: float = 1.0

@export_category("Food")
@export_range(1, 10, 1) var meat_portions: int = 3
@export_range(1.0, 100.0, 1.0) var hunger_restore_per_portion: float = 25.0

@export_category("Procedural Appearance")
@export_range(0.15, 0.60, 0.05) var voxel_size: float = 0.25
@export_range(3, 8, 1) var body_length_voxels: int = 5
@export_range(2, 5, 1) var body_width_voxels: int = 3
@export_range(2, 5, 1) var body_height_voxels: int = 3
@export_range(2, 6, 1) var leg_height_voxels: int = 3

@export_category("Placement")
@export var snap_to_terrain: bool = true


const BODY_COLOR: Color = Color(
	0.48,
	0.30,
	0.14,
	1.0
)

const BELLY_COLOR: Color = Color(
	0.62,
	0.48,
	0.29,
	1.0
)

const EYE_COLOR: Color = Color(
	0.03,
	0.03,
	0.02,
	1.0
)

const CORPSE_TINT: Color = Color(
	0.52,
	0.40,
	0.34,
	1.0
)


var current_health: float
var remaining_meat_portions: int
var is_dead: bool = false

var _random := RandomNumberGenerator.new()
var _move_direction: Vector3 = Vector3.ZERO
var _decision_timer: float = 0.0
var _initialized: bool = false


@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var body_collision: CollisionShape3D = $BodyCollision


func _ready() -> void:
	current_health = maximum_health
	remaining_meat_portions = meat_portions

	call_deferred("_initialize_creature")


func _initialize_creature() -> void:
	if snap_to_terrain:
		_snap_to_terrain()

	_random.seed = _get_creature_seed()

	_generate_creature()
	_choose_new_behavior()

	_initialized = true


func _physics_process(delta: float) -> void:
	if not _initialized:
		return

	if is_dead:
		_process_corpse_physics(delta)
		return

	_decision_timer -= delta

	if _decision_timer <= 0.0:
		_choose_new_behavior()

	if (
		_move_direction.length_squared() > 0.0
		and not _is_direction_safe(_move_direction)
	):
		_choose_new_behavior()

	velocity.x = _move_direction.x * move_speed
	velocity.z = _move_direction.z * move_speed

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= fall_acceleration * delta

	if _move_direction.length_squared() > 0.0:
		var target_rotation := atan2(
			-_move_direction.x,
			-_move_direction.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			target_rotation,
			rotation_speed * delta
		)

	move_and_slide()


func _process_corpse_physics(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= fall_acceleration * delta

	move_and_slide()


func interact(actor: Node) -> void:
	if actor == null:
		return

	if is_dead:
		_try_eat_corpse(actor)
		return

	if not actor.has_method("can_perform_action"):
		return

	var can_bite := bool(
		actor.call(
			"can_perform_action",
			&"bite"
		)
	)

	if not can_bite:
		print(
			"Grazer interaction blocked. Missing ability: bite"
		)
		return

	receive_hit(
		bite_damage,
		actor
	)


func _try_eat_corpse(actor: Node) -> void:
	if remaining_meat_portions <= 0:
		queue_free()
		return

	if not actor.has_method("can_perform_action"):
		return

	var can_eat := bool(
		actor.call(
			"can_perform_action",
			&"eat"
		)
	)

	if not can_eat:
		print(
			"Grazer corpse interaction blocked. Missing ability: eat"
		)
		return

	if not actor.has_method("restore_hunger"):
		print("Actor cannot restore hunger.")
		return

	if actor.has_method("get_hunger_ratio"):
		var hunger_ratio := float(
			actor.call("get_hunger_ratio")
		)

		if hunger_ratio >= 0.999:
			print("Player is not hungry.")
			return

	actor.call(
		"restore_hunger",
		hunger_restore_per_portion
	)

	remaining_meat_portions -= 1

	print(
		"Grazer meat eaten. Remaining portions: ",
		remaining_meat_portions
	)

	if remaining_meat_portions <= 0:
		print("Grazer carcass consumed.")
		queue_free()


func receive_hit(
	damage: float,
	attacker: Node = null
) -> void:
	if is_dead:
		return

	if damage <= 0.0:
		return

	current_health = maxf(
		current_health - damage,
		0.0
	)

	print(
		"Grazer hit. Remaining health: ",
		current_health
	)

	if current_health <= 0.0:
		_die()
		return

	_flee_from(attacker)


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0

	_move_direction = Vector3.ZERO
	_decision_timer = 0.0

	velocity.x = 0.0
	velocity.z = 0.0

	_apply_corpse_material()

	print(
		"Grazer died. Meat portions available: ",
		remaining_meat_portions
	)


func _flee_from(attacker: Node) -> void:
	if attacker is not Node3D:
		_choose_new_behavior()
		return

	var attacker_3d := attacker as Node3D

	var flee_direction := (
		global_position
		- attacker_3d.global_position
	)

	flee_direction.y = 0.0

	if flee_direction.length_squared() <= 0.001:
		_choose_new_behavior()
		return

	flee_direction = flee_direction.normalized()

	if _is_direction_safe(flee_direction):
		_move_direction = flee_direction
		_decision_timer = maximum_wander_time
	else:
		_choose_new_behavior()


func _choose_new_behavior() -> void:
	_decision_timer = _random.randf_range(
		minimum_wander_time,
		maximum_wander_time
	)

	if _random.randf() < idle_probability:
		_move_direction = Vector3.ZERO
		return

	for _attempt in range(8):
		var angle := _random.randf_range(
			0.0,
			TAU
		)

		var candidate_direction := Vector3(
			sin(angle),
			0.0,
			cos(angle)
		).normalized()

		if _is_direction_safe(candidate_direction):
			_move_direction = candidate_direction
			return

	_move_direction = Vector3.ZERO


func _is_direction_safe(
	direction: Vector3
) -> bool:
	if direction.length_squared() <= 0.001:
		return true

	var check_position := (
		global_position
		+ direction.normalized()
			* terrain_check_distance
	)

	var current_height := WorldGenerator.get_terrain_height(
		global_position.x,
		global_position.z
	)

	var next_height := WorldGenerator.get_terrain_height(
		check_position.x,
		check_position.z
	)

	if (
		next_height
		<= WorldGenerator.get_sea_level() + 0.20
	):
		return false

	if (
		absf(next_height - current_height)
		> maximum_step_height
	):
		return false

	return true


func _generate_creature() -> void:
	var generated_length := maxi(
		4,
		body_length_voxels
			+ _random.randi_range(-1, 1)
	)

	var generated_width := maxi(
		2,
		body_width_voxels
			+ _random.randi_range(-1, 1)
	)

	var generated_height := maxi(
		2,
		body_height_voxels
			+ _random.randi_range(-1, 1)
	)

	var generated_leg_height := maxi(
		2,
		leg_height_voxels
			+ _random.randi_range(-1, 1)
	)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_body(
		surface_tool,
		generated_length,
		generated_width,
		generated_height,
		generated_leg_height
	)

	_add_legs(
		surface_tool,
		generated_length,
		generated_width,
		generated_leg_height
	)

	_add_head(
		surface_tool,
		generated_length,
		generated_height,
		generated_leg_height
	)

	_add_tail(
		surface_tool,
		generated_length,
		generated_height,
		generated_leg_height
	)

	surface_tool.index()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	if generated_mesh == null:
		push_error("Grazer mesh could not be generated.")
		return

	body_mesh.mesh = generated_mesh

	_apply_material()

	_create_collision(
		generated_length,
		generated_width,
		generated_height,
		generated_leg_height
	)


func _add_body(
	surface_tool: SurfaceTool,
	length: int,
	width: int,
	height: int,
	leg_height: int
) -> void:
	for voxel_y in range(height):
		for voxel_x in range(width):
			for voxel_z in range(length):
				var center := Vector3(
					(
						float(voxel_x)
						- float(width - 1) * 0.5
					) * voxel_size,
					(
						float(leg_height)
						+ float(voxel_y)
						+ 0.5
					) * voxel_size,
					(
						float(voxel_z)
						- float(length - 1) * 0.5
					) * voxel_size
				)

				var color := _vary_color(
					BODY_COLOR,
					0.10
				)

				if voxel_y == 0:
					color = _vary_color(
						BELLY_COLOR,
						0.08
					)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					color
				)


func _add_legs(
	surface_tool: SurfaceTool,
	length: int,
	width: int,
	leg_height: int
) -> void:
	var leg_x := (
		float(width - 1)
		* voxel_size
		* 0.5
	)

	var leg_z := (
		float(length - 2)
		* voxel_size
		* 0.5
	)

	var leg_positions: Array[Vector2] = [
		Vector2(-leg_x, -leg_z),
		Vector2(leg_x, -leg_z),
		Vector2(-leg_x, leg_z),
		Vector2(leg_x, leg_z)
	]

	for leg_position in leg_positions:
		for voxel_y in range(leg_height):
			var center := Vector3(
				leg_position.x,
				(
					float(voxel_y)
					+ 0.5
				) * voxel_size,
				leg_position.y
			)

			_add_voxel(
				surface_tool,
				center,
				voxel_size,
				_vary_color(
					BODY_COLOR,
					0.08
				)
			)


func _add_head(
	surface_tool: SurfaceTool,
	length: int,
	height: int,
	leg_height: int
) -> void:
	var head_center_y := (
		float(leg_height)
		+ float(height) * 0.72
	) * voxel_size

	var head_center_z := (
		-float(length) * 0.5
		- 0.75
	) * voxel_size

	for voxel_y in range(2):
		for voxel_x in range(2):
			for voxel_z in range(2):
				var center := Vector3(
					(
						float(voxel_x)
						- 0.5
					) * voxel_size,
					head_center_y
						+ float(voxel_y)
							* voxel_size,
					head_center_z
						- float(voxel_z)
							* voxel_size
				)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					_vary_color(
						BODY_COLOR,
						0.10
					)
				)

	var eye_y := (
		head_center_y
		+ voxel_size * 0.75
	)

	var eye_z := (
		head_center_z
		- voxel_size * 1.05
	)

	for side in [-1.0, 1.0]:
		_add_voxel(
			surface_tool,
			Vector3(
				side * voxel_size * 0.58,
				eye_y,
				eye_z
			),
			voxel_size * 0.35,
			EYE_COLOR
		)


func _add_tail(
	surface_tool: SurfaceTool,
	length: int,
	height: int,
	leg_height: int
) -> void:
	var tail_y := (
		float(leg_height)
		+ float(height) * 0.65
	) * voxel_size

	var tail_z := (
		float(length) * 0.5
		+ 0.5
	) * voxel_size

	for tail_part in range(2):
		_add_voxel(
			surface_tool,
			Vector3(
				0.0,
				tail_y
					- float(tail_part)
						* voxel_size * 0.35,
				tail_z
					+ float(tail_part)
						* voxel_size
			),
			voxel_size * 0.75,
			_vary_color(
				BODY_COLOR,
				0.10
			)
		)


func _add_voxel(
	surface_tool: SurfaceTool,
	center: Vector3,
	size: float,
	color: Color
) -> void:
	var half_size := size * 0.5

	var left := center.x - half_size
	var right := center.x + half_size
	var bottom := center.y - half_size
	var top := center.y + half_size
	var front := center.z - half_size
	var back := center.z + half_size

	_add_face(
		surface_tool,
		Vector3(right, bottom, front),
		Vector3(right, top, front),
		Vector3(right, top, back),
		Vector3(right, bottom, back),
		Vector3.RIGHT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, top, back),
		Vector3(left, top, front),
		Vector3(left, bottom, front),
		Vector3.LEFT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, top, front),
		Vector3(left, top, back),
		Vector3(right, top, back),
		Vector3(right, top, front),
		Vector3.UP,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, bottom, front),
		Vector3(right, bottom, front),
		Vector3(right, bottom, back),
		Vector3.DOWN,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, top, front),
		Vector3(right, top, front),
		Vector3(right, bottom, front),
		Vector3.FORWARD,
		color
	)

	_add_face(
		surface_tool,
		Vector3(right, bottom, back),
		Vector3(right, top, back),
		Vector3(left, top, back),
		Vector3(left, bottom, back),
		Vector3.BACK,
		color
	)


func _add_face(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	point_d: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	_add_mesh_vertex(surface_tool, point_a, normal, color)
	_add_mesh_vertex(surface_tool, point_b, normal, color)
	_add_mesh_vertex(surface_tool, point_c, normal, color)

	_add_mesh_vertex(surface_tool, point_a, normal, color)
	_add_mesh_vertex(surface_tool, point_c, normal, color)
	_add_mesh_vertex(surface_tool, point_d, normal, color)


func _add_mesh_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)
	surface_tool.add_vertex(vertex_position)


func _apply_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	body_mesh.material_override = material


func _apply_corpse_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = CORPSE_TINT
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	body_mesh.material_override = material


func _create_collision(
	length: int,
	width: int,
	height: int,
	leg_height: int
) -> void:
	var collision_shape := BoxShape3D.new()

	var collision_height := (
		float(leg_height + height)
		* voxel_size
	)

	collision_shape.size = Vector3(
		float(width) * voxel_size,
		collision_height,
		float(length + 1) * voxel_size
	)

	body_collision.shape = collision_shape

	body_collision.position = Vector3(
		0.0,
		collision_height * 0.5,
		-voxel_size * 0.25
	)


func _snap_to_terrain() -> void:
	var terrain_height := WorldGenerator.get_terrain_height(
		global_position.x,
		global_position.z
	)

	global_position.y = terrain_height + 0.05


func _vary_color(
	base_color: Color,
	variation: float
) -> Color:
	var value := _random.randf_range(
		-variation,
		variation
	)

	if value >= 0.0:
		return base_color.lerp(
			Color.WHITE,
			value
		)

	return base_color.lerp(
		Color.BLACK,
		-value
	)


func _get_creature_seed() -> int:
	return (
		GameState.world_seed * 59
		+ int(
			round(
				global_position.x * 100.0
			)
		) * 73_856_093
		+ int(
			round(
				global_position.z * 100.0
			)
		) * 19_349_663
	)
