extends StaticBody3D


@export_category("Interaction")
@export var required_ability: StringName = &"eat"
@export_range(1.0, 100.0, 1.0) var hunger_restore: float = 30.0

@export_category("Procedural Appearance")
@export_range(0.15, 0.60, 0.05) var voxel_size: float = 0.25
@export_range(2, 6, 1) var bush_radius_voxels: int = 3
@export_range(2, 7, 1) var bush_height_voxels: int = 4
@export_range(0.0, 0.50, 0.05) var foliage_gap_probability: float = 0.12
@export_range(1, 20, 1) var minimum_berries: int = 5
@export_range(1, 30, 1) var maximum_berries: int = 9

@export_category("Placement")
@export var snap_to_terrain: bool = true


const STEM_COLOR: Color = Color(
	0.25,
	0.13,
	0.05,
	1.0
)

const FOLIAGE_COLOR: Color = Color(
	0.08,
	0.38,
	0.06,
	1.0
)

const BERRY_COLOR: Color = Color(
	0.68,
	0.02,
	0.08,
	1.0
)


var is_depleted: bool = false


@onready var bush_mesh: MeshInstance3D = $BushMesh
@onready var bush_collision: CollisionShape3D = $BushCollision


func _ready() -> void:
	add_to_group(&"berry_bush")

	# Aufgeschoben, damit ein Chunk vorher Position, Drehung und
	# Skalierung der Pflanze festlegen kann.
	call_deferred("_initialize_bush")


func _initialize_bush() -> void:
	if snap_to_terrain:
		_snap_to_terrain()

	_generate_bush()


func has_food_available() -> bool:
	return not is_depleted


func interact(actor: Node) -> void:
	if actor == null:
		return

	if is_depleted:
		print("Berry bush is empty.")
		return

	if not actor.has_method("can_perform_action"):
		return

	var action_allowed := bool(
		actor.call(
			"can_perform_action",
			required_ability
		)
	)

	if not action_allowed:
		print(
			"Berry bush interaction blocked. Missing ability: ",
			required_ability
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
			print("Actor is not hungry.")
			return

	actor.call(
		"restore_hunger",
		hunger_restore
	)

	_harvest_berries()


func _harvest_berries() -> void:
	is_depleted = true

	# Der Busch wird mit demselben Seed erneut generiert,
	# dieses Mal jedoch ohne Beeren.
	_generate_bush()

	print("Berries eaten. Bush is now empty.")


func _generate_bush() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_visual_seed()

	var generated_radius := maxi(
		2,
		bush_radius_voxels
			+ random.randi_range(-1, 1)
	)

	var generated_height := maxi(
		2,
		bush_height_voxels
			+ random.randi_range(-1, 1)
	)

	var minimum_count := mini(
		minimum_berries,
		maximum_berries
	)

	var maximum_count := maxi(
		minimum_berries,
		maximum_berries
	)

	var generated_berry_count := random.randi_range(
		minimum_count,
		maximum_count
	)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_stems(
		surface_tool,
		random,
		generated_height
	)

	var berry_candidates: Array[Vector3] = []

	_add_foliage(
		surface_tool,
		random,
		generated_radius,
		generated_height,
		berry_candidates
	)

	if not is_depleted:
		_add_berries(
			surface_tool,
			random,
			generated_berry_count,
			berry_candidates
		)

	surface_tool.index()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	if generated_mesh == null:
		push_error(
			"Procedural berry bush mesh could not be generated."
		)
		return

	bush_mesh.mesh = generated_mesh

	_apply_material()

	_create_collision(
		generated_radius,
		generated_height
	)


func _add_stems(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator,
	generated_height: int
) -> void:
	var stem_height := maxi(
		2,
		generated_height - 1
	)

	for voxel_y in range(stem_height):
		var center := Vector3(
			0.0,
			(
				float(voxel_y)
				+ 0.5
			) * voxel_size,
			0.0
		)

		var stem_color := _vary_color(
			STEM_COLOR,
			random,
			0.10
		)

		_add_voxel(
			surface_tool,
			center,
			voxel_size,
			stem_color
		)

	# Zwei kleine seitliche Äste.
	var branch_height := (
		float(stem_height)
		* voxel_size
		* 0.55
	)

	for direction in [
		Vector3.LEFT,
		Vector3.RIGHT
	]:
		var branch_center := Vector3(
			direction.x * voxel_size,
			branch_height,
			0.0
		)

		var branch_color := _vary_color(
			STEM_COLOR,
			random,
			0.10
		)

		_add_voxel(
			surface_tool,
			branch_center,
			voxel_size,
			branch_color
		)


func _add_foliage(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator,
	generated_radius: int,
	generated_height: int,
	berry_candidates: Array[Vector3]
) -> void:
	var vertical_center := (
		float(generated_height - 1)
		* 0.5
	)

	var vertical_radius := (
		float(generated_height)
		* 0.5
		+ 0.35
	)

	for voxel_y in range(generated_height):
		for voxel_x in range(
			-generated_radius,
			generated_radius + 1
		):
			for voxel_z in range(
				-generated_radius,
				generated_radius + 1
			):
				var normalized_x := (
					float(voxel_x)
					/ (
						float(generated_radius)
						+ 0.35
					)
				)

				var normalized_y := (
					(
						float(voxel_y)
						- vertical_center
					)
					/ vertical_radius
				)

				var normalized_z := (
					float(voxel_z)
					/ (
						float(generated_radius)
						+ 0.35
					)
				)

				var distance_squared := (
					normalized_x * normalized_x
					+ normalized_y * normalized_y
					+ normalized_z * normalized_z
				)

				if distance_squared > 1.0:
					continue

				var is_core := (
					absi(voxel_x) <= 1
					and absi(voxel_z) <= 1
				)

				if (
					not is_core
					and random.randf()
						< foliage_gap_probability
				):
					continue

				var center := Vector3(
					float(voxel_x) * voxel_size,
					(
						float(voxel_y)
						+ 0.5
					) * voxel_size,
					float(voxel_z) * voxel_size
				)

				var foliage_color := _vary_color(
					FOLIAGE_COLOR,
					random,
					0.16
				)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					foliage_color
				)

				# Nur äußere und nicht zu tief liegende Blätter
				# kommen als Beerenposition infrage.
				if (
					distance_squared >= 0.50
					and float(voxel_y)
						>= vertical_center * 0.45
				):
					var outward_direction := Vector3(
						normalized_x,
						normalized_y,
						normalized_z
					).normalized()

					var berry_position := (
						center
						+ outward_direction
							* voxel_size
							* 0.58
					)

					berry_candidates.append(
						berry_position
					)


func _add_berries(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator,
	generated_berry_count: int,
	berry_candidates: Array[Vector3]
) -> void:
	if berry_candidates.is_empty():
		return

	var available_candidates := berry_candidates.duplicate()

	var berries_to_create := mini(
		generated_berry_count,
		available_candidates.size()
	)

	for berry_index in range(berries_to_create):
		var candidate_index := random.randi_range(
			0,
			available_candidates.size() - 1
		)

		var berry_position: Vector3 = (
			available_candidates[candidate_index]
		)

		available_candidates.remove_at(
			candidate_index
		)

		var berry_color := _vary_color(
			BERRY_COLOR,
			random,
			0.10
		)

		_add_voxel(
			surface_tool,
			berry_position,
			voxel_size * 0.65,
			berry_color
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
	var back := center.z - half_size
	var front := center.z + half_size

	_add_face(
		surface_tool,
		Vector3(right, bottom, back),
		Vector3(right, top, back),
		Vector3(right, top, front),
		Vector3(right, bottom, front),
		Vector3.RIGHT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, top, front),
		Vector3(left, top, back),
		Vector3(left, bottom, back),
		Vector3.LEFT,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, top, back),
		Vector3(left, top, front),
		Vector3(right, top, front),
		Vector3(right, top, back),
		Vector3.UP,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, bottom, back),
		Vector3(right, bottom, back),
		Vector3(right, bottom, front),
		Vector3.DOWN,
		color
	)

	_add_face(
		surface_tool,
		Vector3(right, bottom, front),
		Vector3(right, top, front),
		Vector3(left, top, front),
		Vector3(left, bottom, front),
		Vector3.FORWARD,
		color
	)

	_add_face(
		surface_tool,
		Vector3(left, bottom, back),
		Vector3(left, top, back),
		Vector3(right, top, back),
		Vector3(right, bottom, back),
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
	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_b,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_a,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_c,
		normal,
		color
	)

	_add_mesh_vertex(
		surface_tool,
		point_d,
		normal,
		color
	)


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

	bush_mesh.material_override = material


func _create_collision(
	generated_radius: int,
	generated_height: int
) -> void:
	var collision_shape := BoxShape3D.new()

	var collision_width := (
		float(generated_radius * 2)
		* voxel_size
		* 0.72
	)

	var collision_height := (
		float(generated_height)
		* voxel_size
		* 0.85
	)

	collision_shape.size = Vector3(
		collision_width,
		collision_height,
		collision_width
	)

	bush_collision.shape = collision_shape

	bush_collision.position = Vector3(
		0.0,
		collision_height * 0.5,
		0.0
	)

	bush_collision.disabled = false


func _snap_to_terrain() -> void:
	var terrain_height := WorldGenerator.get_terrain_height(
		global_position.x,
		global_position.z
	)

	global_position.y = terrain_height


func _vary_color(
	base_color: Color,
	random: RandomNumberGenerator,
	variation: float
) -> Color:
	var value := random.randf_range(
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


func _get_visual_seed() -> int:
	return (
		GameState.world_seed * 47
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
