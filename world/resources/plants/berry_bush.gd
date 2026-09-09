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
	# A scene/chunk can leave the tree before this deferred callback runs.
	if not is_inside_tree() or is_queued_for_deletion():
		return
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
	# Stable outer form and collision even after harvesting or reloading. Small
	# voxel lobes, shaded lower leaves and exposed berry clusters replace the
	# old solid ellipsoid. Shared food identity/stock is untouched.
	var random := RandomNumberGenerator.new()
	random.seed = _get_visual_seed()
	var radius: int = maxi(2, bush_radius_voxels + random.randi_range(-1, 1))
	var height: int = maxi(2, bush_height_voxels + random.randi_range(-1, 1))
	var berry_count: int = random.randi_range(mini(minimum_berries, maximum_berries), maxi(minimum_berries, maximum_berries))
	var span: float = float(radius) * voxel_size
	var tall: float = float(height) * voxel_size
	var cell: float = voxel_size * 0.48
	var leaves: Dictionary = {}
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Five offset crowns create an irregular shrub with openings at ground level.
	for branch in range(5):
		var angle: float = float(branch) * TAU / 5.0 + random.randf_range(-0.24, 0.24)
		var center := Vector3(cos(angle) * span * 0.43, tall * random.randf_range(0.45, 0.68), sin(angle) * span * 0.43)
		var lobe := Vector3(span * random.randf_range(0.43, 0.61), tall * random.randf_range(0.29, 0.43), span * random.randf_range(0.43, 0.61))
		for step in range(7):
			var point: Vector3 = Vector3(0, cell * 0.5, 0).lerp(center, float(step) / 6.0)
			_add_voxel(surface, point, cell * 0.7, Color("705037").lightened(float(step) * 0.012))
		var origin := Vector3i((center / cell).round())
		var reach := Vector3i((lobe / cell).ceil())
		for x in range(-reach.x, reach.x + 1):
			for y in range(-reach.y, reach.y + 1):
				for z in range(-reach.z, reach.z + 1):
					var key := origin + Vector3i(x, y, z)
					var p := Vector3(key) * cell
					var distance: float = ((p - center) / lobe).length_squared()
					if distance > 1.0 or p.y < cell * 1.5: continue
					if distance > 0.76 and random.randf() < foliage_gap_probability * 1.5: continue
					var sunlight: float = clampf(p.y / maxf(tall, 0.1), 0.0, 1.0)
					leaves[key] = Color("294c36").lerp(Color("709455"), sunlight * 0.85 + random.randf_range(-0.08, 0.08))
	var candidates: Array[Vector3] = []
	var directions := [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for key: Vector3i in leaves:
		var exposed: bool = false
		for direction in directions:
			if not leaves.has(key + direction):
				exposed = true
				break
		if not exposed: continue
		var p := Vector3(key) * cell
		_add_voxel(surface, p, cell, leaves[key])
		var outward := Vector3(p.x, 0, p.z).normalized()
		if p.y > tall * 0.32 and not leaves.has(key + Vector3i((outward * 1.5).round())):
			candidates.append(p + outward * cell * 0.75)
	# Consume exactly the same RNG path for full and empty bushes.
	for index in range(mini(berry_count, candidates.size())):
		var selected: int = random.randi_range(0, candidates.size() - 1)
		var point: Vector3 = candidates[selected]
		candidates.remove_at(selected)
		var berry_color: Color = Color("b8445b").lightened(random.randf_range(-0.12, 0.1))
		if is_depleted: continue
		for offset in [Vector3.ZERO, Vector3(cell * 0.5, -cell * 0.5, 0), Vector3(-cell * 0.45, -cell * 0.45, 0)]:
			_add_voxel(surface, point + offset, cell * 0.74, berry_color)
		_add_voxel(surface, point + Vector3(-cell * 0.16, cell * 0.22, -cell * 0.30), cell * 0.23, Color("ed99a2"))
	surface.index()
	bush_mesh.mesh = surface.commit()
	_apply_material()
	_create_collision(radius, height)


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
