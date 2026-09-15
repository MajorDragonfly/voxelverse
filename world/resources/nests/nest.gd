extends Node3D


@export_category("Procedural Appearance")
@export_range(0.15, 0.60, 0.05) var voxel_size: float = 0.25
@export_range(0.75, 3.0, 0.05) var nest_radius: float = 1.25
@export_range(12, 48, 1) var ring_voxel_count: int = 24
@export_range(1, 4, 1) var ring_height_voxels: int = 2
@export_range(0.0, 0.50, 0.05) var bedding_gap_probability: float = 0.12

@export_category("Placement")
@export var snap_to_terrain: bool = true
@export_range(0.1, 3.0, 0.1) var respawn_height: float = 0.75


const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
var persistent_visual_key: String = ""
var visual_profile: Dictionary = {}
var visual_biome: String = "grassland"
var _stable_visual_seed: int = 0
var _visual_seed_ready: bool = false


@onready var nest_mesh: MeshInstance3D = $NestMesh
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	add_to_group("player_nest")

	call_deferred("_initialize_nest")


func _initialize_nest() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	if snap_to_terrain:
		_snap_to_terrain()

	spawn_point.position = Vector3(
		0.0,
		respawn_height,
		0.0
	)

	_generate_nest()


func get_respawn_position() -> Vector3:
	return spawn_point.global_position


func _generate_nest() -> void:
	nest_mesh.mesh = Visuals.nest(_get_visual_seed(), nest_radius, voxel_size,
		ring_voxel_count, ring_height_voxels, bedding_gap_probability, visual_profile, visual_biome)


func _snap_to_terrain() -> void:
	var terrain_height := WorldGenerator.get_terrain_height(
		global_position.x,
		global_position.z
	)

	global_position.y = terrain_height + 0.02


func _get_visual_seed() -> int:
	if not persistent_visual_key.is_empty():
		return ("nest:" + persistent_visual_key).sha256_text().left(15).hex_to_int()
	# Historical scenes also keep their appearance when the home runtime moves it.
	if not _visual_seed_ready:
		_stable_visual_seed = GameState.world_seed * 71 + roundi(global_position.x*100.0)*73_856_093 + roundi(global_position.z*100.0)*19_349_663
		_visual_seed_ready = true
	return _stable_visual_seed
