extends StaticBody3D


@export_category("Interaction")
@export var required_ability: StringName = &"chop"
@export var damage_per_interaction: float = 1.0

@export_category("Tree")
@export var maximum_health: float = 5.0

@export_category("Procedural Appearance")
@export_range(0.15, 0.75, 0.05) var voxel_size: float = 0.35
@export_range(4, 12, 1) var trunk_height_voxels: int = 8
@export_range(2, 4, 1) var crown_radius_voxels: int = 3
@export_range(1, 3, 1) var crown_vertical_radius_voxels: int = 2
@export_range(0.0, 0.40, 0.05) var leaf_gap_probability: float = 0.12


const BARK_COLOR: Color = Color(
	0.30,
	0.16,
	0.07,
	1.0
)

const LEAF_COLOR: Color = Color(
	0.10,
	0.40,
	0.07,
	1.0
)


var current_health: float


@onready var generated_mesh: MeshInstance3D = $TrunkMesh
@onready var old_crown_mesh: MeshInstance3D = $CrownMesh
@onready var trunk_collision: CollisionShape3D = $TrunkCollision


func _ready() -> void:
	current_health = maximum_health

	# Die Generierung wird aufgeschoben, damit TerrainChunk vorher
	# Position, Drehung und Skalierung des Baumes setzen kann.
	call_deferred("_generate_procedural_tree")


func interact(actor: Node) -> void:
	if actor == null:
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
			"Tree interaction blocked. Missing ability: ",
			required_ability
		)
		return

	receive_hit(damage_per_interaction)


func receive_hit(damage: float) -> void:
	current_health -= damage

	print(
		"Tree hit. Remaining health: ",
		current_health
	)

	if current_health <= 0.0:
		harvest()


func harvest() -> void:
	print("Tree harvested.")
	queue_free()


func _generate_procedural_tree() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _get_visual_seed()

	# Kleine reproduzierbare Abweichung der Stammhöhe.
	var generated_trunk_voxels := maxi(
		4,
		trunk_height_voxels
			+ random.randi_range(-1, 1)
	)

	var generated_crown_radius := maxi(
		2,
		crown_radius_voxels
			+ random.randi_range(-1, 1)
	)

	var trunk_height := (
		float(generated_trunk_voxels)
		* voxel_size
	)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_trunk(
		surface_tool,
		random,
		generated_trunk_voxels
	)

	_add_crown(
		surface_tool,
		random,
		generated_crown_radius,
		trunk_height
	)

	# Gleiche Eckpunkte innerhalb einer Fläche werden zusammengefasst.
	surface_tool.index()

	var tree_array_mesh: ArrayMesh = surface_tool.commit()

	if tree_array_mesh == null:
		push_error("Procedural tree mesh could not be generated.")
		return

	generated_mesh.mesh = tree_array_mesh
	generated_mesh.position = Vector3.ZERO
	generated_mesh.rotation = Vector3.ZERO
	generated_mesh.scale = Vector3.ONE

	# Der alte Platzhalter für die Baumkrone wird nicht mehr benötigt.
	old_crown_mesh.mesh = null
	old_crown_mesh.visible = false

	_apply_tree_material()
	_create_trunk_collision(trunk_height)


func _add_trunk(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator,
	generated_trunk_voxels: int
) -> void:
	# Der Stamm ist zwei Voxel breit und zwei Voxel tief.
	for voxel_y in range(generated_trunk_voxels):
		for voxel_x in range(2):
			for voxel_z in range(2):
				var center := Vector3(
					(
						float(voxel_x)
						- 0.5
					) * voxel_size,
					(
						float(voxel_y)
						+ 0.5
					) * voxel_size,
					(
						float(voxel_z)
						- 0.5
					) * voxel_size
				)

				var bark_color := _vary_color(
					BARK_COLOR,
					random,
					0.10
				)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					bark_color
				)


func _add_crown(
	surface_tool: SurfaceTool,
	random: RandomNumberGenerator,
	generated_crown_radius: int,
	trunk_height: float
) -> void:
	# Die Krone überschneidet sich etwas mit dem oberen Stamm.
	var crown_center_y := (
		trunk_height
		- voxel_size * 0.20
	)

	for voxel_y in range(
		-crown_vertical_radius_voxels,
		crown_vertical_radius_voxels + 1
	):
		for voxel_x in range(
			-generated_crown_radius,
			generated_crown_radius + 1
		):
			for voxel_z in range(
				-generated_crown_radius,
				generated_crown_radius + 1
			):
				var normalized_x := (
					float(voxel_x)
					/ (
						float(generated_crown_radius)
						+ 0.35
					)
				)

				var normalized_y := (
					float(voxel_y)
					/ (
						float(crown_vertical_radius_voxels)
						+ 0.35
					)
				)

				var normalized_z := (
					float(voxel_z)
					/ (
						float(generated_crown_radius)
						+ 0.35
					)
				)

				var distance_squared := (
					normalized_x * normalized_x
					+ normalized_y * normalized_y
					+ normalized_z * normalized_z
				)

				# Nur Voxel innerhalb der ellipsoiden Krone verwenden.
				if distance_squared > 1.0:
					continue

				var is_crown_core := (
					absi(voxel_x) <= 1
					and absi(voxel_y) <= 1
					and absi(voxel_z) <= 1
				)

				# Außerhalb des Kerns entstehen einzelne Lücken.
				if (
					not is_crown_core
					and random.randf()
						< leaf_gap_probability
				):
					continue

				var center := Vector3(
					float(voxel_x) * voxel_size,
					crown_center_y
						+ float(voxel_y) * voxel_size,
					float(voxel_z) * voxel_size
				)

				var leaf_color := _vary_color(
					LEAF_COLOR,
					random,
					0.14
				)

				_add_voxel(
					surface_tool,
					center,
					voxel_size,
					leaf_color
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

	# Rechte Seite.
	_add_face(
		surface_tool,
		Vector3(right, bottom, back),
		Vector3(right, top, back),
		Vector3(right, top, front),
		Vector3(right, bottom, front),
		Vector3.RIGHT,
		color
	)

	# Linke Seite.
	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, top, front),
		Vector3(left, top, back),
		Vector3(left, bottom, back),
		Vector3.LEFT,
		color
	)

	# Oberseite.
	_add_face(
		surface_tool,
		Vector3(left, top, back),
		Vector3(left, top, front),
		Vector3(right, top, front),
		Vector3(right, top, back),
		Vector3.UP,
		color
	)

	# Unterseite.
	_add_face(
		surface_tool,
		Vector3(left, bottom, front),
		Vector3(left, bottom, back),
		Vector3(right, bottom, back),
		Vector3(right, bottom, front),
		Vector3.DOWN,
		color
	)

	# Vorderseite.
	_add_face(
		surface_tool,
		Vector3(right, bottom, front),
		Vector3(right, top, front),
		Vector3(left, top, front),
		Vector3(left, bottom, front),
		Vector3.FORWARD,
		color
	)

	# Rückseite.
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
	# Erstes Dreieck.
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

	# Zweites Dreieck.
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


func _apply_tree_material() -> void:
	var material := StandardMaterial3D.new()

	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	generated_mesh.material_override = material


func _create_trunk_collision(
	trunk_height: float
) -> void:
	var collision_shape := BoxShape3D.new()

	# Leicht schmaler als die sichtbare Außenkante.
	var collision_width := voxel_size * 1.8

	collision_shape.size = Vector3(
		collision_width,
		trunk_height,
		collision_width
	)

	trunk_collision.shape = collision_shape
	trunk_collision.position = Vector3(
		0.0,
		trunk_height * 0.5,
		0.0
	)

	trunk_collision.rotation = Vector3.ZERO
	trunk_collision.scale = Vector3.ONE
	trunk_collision.disabled = false


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
		GameState.world_seed * 31
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
