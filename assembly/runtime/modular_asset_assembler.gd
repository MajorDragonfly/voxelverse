extends Node3D
class_name ModularAssetAssembler

const MeshBuilder = preload(
	"res://assembly/runtime/modular_voxel_mesh_builder.gd"
)

var blueprint: Dictionary = {}
var part_definitions: Dictionary = {}
var selected_part_index: int = -1

var _primitive_mesh: MeshInstance3D
var _external_root: Node3D


func _ready() -> void:
	_ensure_nodes()
	rebuild()


func configure(
	new_blueprint: Dictionary,
	new_part_definitions: Dictionary,
	selected_index: int = -1
) -> void:
	blueprint = new_blueprint.duplicate(true)
	part_definitions = new_part_definitions.duplicate(true)
	selected_part_index = selected_index
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	_ensure_nodes()
	_primitive_mesh.mesh = MeshBuilder.build_mesh(
		blueprint,
		_filter_primitive_definitions(),
		selected_part_index
	)
	_clear_external_assets()
	var parts: Array = blueprint.get("parts", [])
	for index in range(parts.size()):
		if not (parts[index] is Dictionary):
			continue
		var placement: Dictionary = parts[index]
		var definition: Dictionary = part_definitions.get(
			str(placement.get("part_id", "")),
			{}
		)
		var scene_path: String = str(definition.get("scene_path", ""))
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = "Part_%d_%s" % [index, str(placement.get("part_id", "part"))]
		_apply_transform(instance, placement)
		_external_root.add_child(instance)


func _filter_primitive_definitions() -> Dictionary:
	var result: Dictionary = {}
	for part_id in part_definitions.keys():
		var definition_value: Variant = part_definitions[part_id]
		if not (definition_value is Dictionary):
			continue
		var definition: Dictionary = definition_value
		var has_geometry: bool = (
			definition.get("geometry", []) is Array
			and not definition.get("geometry", []).is_empty()
		)
		var has_voxels: bool = (
			definition.get("voxels", []) is Array
			and not definition.get("voxels", []).is_empty()
		)
		var scene_path: String = str(definition.get("scene_path", ""))
		if has_geometry or has_voxels or scene_path.is_empty():
			result[part_id] = definition
	return result


func _apply_transform(instance: Node3D, placement: Dictionary) -> void:
	instance.position = _as_vector3(placement.get("position", Vector3.ZERO), Vector3.ZERO)
	instance.rotation_degrees = _as_vector3(placement.get("rotation", Vector3.ZERO), Vector3.ZERO)
	instance.scale = _as_vector3(placement.get("scale", Vector3.ONE), Vector3.ONE)


func _ensure_nodes() -> void:
	if _primitive_mesh == null:
		_primitive_mesh = get_node_or_null("PrimitiveAssembly") as MeshInstance3D
	if _primitive_mesh == null:
		_primitive_mesh = MeshInstance3D.new()
		_primitive_mesh.name = "PrimitiveAssembly"
		add_child(_primitive_mesh)
	if _external_root == null:
		_external_root = get_node_or_null("ExternalParts") as Node3D
	if _external_root == null:
		_external_root = Node3D.new()
		_external_root.name = "ExternalParts"
		add_child(_external_root)


func _clear_external_assets() -> void:
	for child in _external_root.get_children():
		child.queue_free()


func _as_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
