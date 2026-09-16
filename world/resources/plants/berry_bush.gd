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


const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
var visual_profile: Dictionary = {}
var visual_biome: String = "grassland"
var _appearance_key: String = ""

var is_depleted: bool = false


@onready var bush_mesh: MeshInstance3D = $BushMesh
@onready var fruit_mesh: MeshInstance3D = $FruitMesh
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

	# Nur die Früchte ausblenden; Form und Kollision bleiben erhalten.
	_generate_bush()

	print("Berries eaten. Bush is now empty.")


func _generate_bush() -> void:
	var seed_value: int = _get_visual_seed()
	var key: String = str([seed_value, voxel_size, bush_radius_voxels, bush_height_voxels,
		minimum_berries, maximum_berries, foliage_gap_probability, visual_profile.hash(), visual_biome])
	if key != _appearance_key:
		var random := RandomNumberGenerator.new()
		random.seed = seed_value
		# Keep the previous collision dimensions/RNG draws for existing food IDs.
		var radius: int = maxi(2, bush_radius_voxels + random.randi_range(-1, 1))
		var height: int = maxi(2, bush_height_voxels + random.randi_range(-1, 1))
		var count: int = random.randi_range(mini(minimum_berries, maximum_berries), maxi(minimum_berries, maximum_berries))
		var appearance: Dictionary = Visuals.forage(seed_value, radius*voxel_size, height*voxel_size,
			count, voxel_size, foliage_gap_probability, visual_profile, visual_biome)
		bush_mesh.mesh = appearance.foliage
		fruit_mesh.mesh = appearance.fruit
		set_meta("resource_form", appearance.form)
		set_meta("resource_species", appearance.species_id)
		_create_collision(radius, height)
		_appearance_key = key
	# Eating/regrowth retains both meshes, the stable shape and collision object.
	fruit_mesh.visible = not is_depleted


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
