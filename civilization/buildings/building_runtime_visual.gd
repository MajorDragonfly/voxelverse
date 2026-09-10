extends Node3D
class_name BuildingRuntimeVisual

const AssetAssembler = preload(
	"res://assembly/runtime/modular_asset_assembler.gd"
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
var _assembler: Node3D
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
	if not Blueprint.Contract.inspect(blueprint, "building").ok: return
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
	if not Blueprint.Contract.inspect(building_blueprint, "building").ok: return
	_assembler.call(
		"configure",
		building_blueprint,
		Parts.get_all_parts(),
		selected_part_index
	)
	_apply_shadow_mode(_assembler)
	_rebuild_collision()


func get_combined_aabb() -> AABB:
	var result := AABB()
	var initialized: bool = false
	for mesh_instance in _find_mesh_instances(_assembler):
		if mesh_instance.mesh == null:
			continue
		var local_aabb: AABB = mesh_instance.mesh.get_aabb()
		var relative_transform: Transform3D = global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed: AABB = relative_transform * local_aabb
		if not initialized:
			result = transformed
			initialized = true
		else:
			result = result.merge(transformed)
	return result


func _ensure_nodes() -> void:
	if _assembler == null:
		_assembler = get_node_or_null("AssetAssembler") as Node3D
	if _assembler == null:
		_assembler = AssetAssembler.new()
		_assembler.name = "AssetAssembler"
		add_child(_assembler)
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


func _rebuild_collision() -> void:
	if not build_collision:
		if _static_body != null:
			_static_body.process_mode = Node.PROCESS_MODE_DISABLED
		return
	_ensure_nodes()
	_static_body.process_mode = Node.PROCESS_MODE_INHERIT
	var aabb: AABB = get_combined_aabb()
	if aabb.size.length_squared() <= 0.0001:
		_collision_shape.shape = null
		return
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(aabb.size.x, 0.1),
		maxf(aabb.size.y, 0.1),
		maxf(aabb.size.z, 0.1)
	)
	_collision_shape.position = aabb.get_center()
	_collision_shape.shape = box


func _apply_shadow_mode(root: Node) -> void:
	for child in root.get_children():
		if child is GeometryInstance3D:
			(child as GeometryInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if cast_shadow
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		_apply_shadow_mode(child)


func _find_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		result.append_array(_find_mesh_instances(child))
	return result
