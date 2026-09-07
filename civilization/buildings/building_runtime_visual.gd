extends Node3D
class_name BuildingRuntimeVisual

const MeshBuilder = preload(
	"res://assembly/runtime/modular_voxel_mesh_builder.gd"
)
const Parts = preload(
	"res://civilization/buildings/building_part_library.gd"
)
const Blueprint = preload(
	"res://civilization/buildings/building_blueprint.gd"
)

@export var build_collision: bool = false
@export var cast_shadow: bool = true

var building_blueprint: Dictionary = {}
var selected_part_index: int = -1
var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D


func _ready() -> void:
	_ensure_nodes()
	if building_blueprint.is_empty():
		building_blueprint = Blueprint.create_default()
	rebuild()


func set_blueprint(
	blueprint: Dictionary,
	selected_index: int = -1
) -> void:
	building_blueprint = blueprint.duplicate(true)
	Blueprint.normalize(building_blueprint)
	selected_part_index = selected_index
	if is_inside_tree():
		rebuild()


func set_selected_part(index: int) -> void:
	selected_part_index = index
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	_ensure_nodes()
	var mesh: ArrayMesh = MeshBuilder.build_mesh(
		building_blueprint,
		Parts.get_all_parts(),
		selected_part_index
	)
	_mesh_instance.mesh = mesh
	_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if cast_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_rebuild_collision(mesh)


func get_combined_aabb() -> AABB:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return AABB()
	return _mesh_instance.mesh.get_aabb()


func _ensure_nodes() -> void:
	if _mesh_instance == null:
		_mesh_instance = get_node_or_null("AssemblyMesh") as MeshInstance3D
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "AssemblyMesh"
		add_child(_mesh_instance)
	if not build_collision:
		return
	if _static_body == null:
		_static_body = get_node_or_null("AssemblyCollision") as StaticBody3D
	if _static_body == null:
		_static_body = StaticBody3D.new()
		_static_body.name = "AssemblyCollision"
		add_child(_static_body)
	if _collision_shape == null:
		_collision_shape = _static_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		_static_body.add_child(_collision_shape)


func _rebuild_collision(mesh: ArrayMesh) -> void:
	if not build_collision:
		if _static_body != null:
			_static_body.visible = false
		return
	_ensure_nodes()
	_static_body.visible = true
	if mesh == null or mesh.get_surface_count() == 0:
		_collision_shape.shape = null
		return
	_collision_shape.shape = mesh.create_trimesh_shape()
