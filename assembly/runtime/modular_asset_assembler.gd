extends Node3D
class_name ModularAssetAssembler
const Contract = preload("res://assembly/core/blueprint_contract.gd")

const MeshBuilder = preload(
	"res://assembly/runtime/modular_voxel_mesh_builder.gd"
)
const AssetResolver = preload(
	"res://assembly/runtime/modular_asset_resolver.gd"
)

var blueprint: Dictionary = {}
var part_definitions: Dictionary = {}
var selected_part_index: int = -1
var lod_tier: int = 0

var _primitive_mesh: MeshInstance3D
var _external_root: Node3D


func _ready() -> void:
	_ensure_nodes()
	rebuild()


func configure(
	new_blueprint: Dictionary,
	new_part_definitions: Dictionary,
	selected_index: int = -1,
	new_lod_tier: int = 0
) -> void:
	if not Contract.inspect(new_blueprint).ok: return
	blueprint = new_blueprint.duplicate(true)
	part_definitions = new_part_definitions.duplicate(true)
	selected_part_index = selected_index
	lod_tier = clampi(new_lod_tier, 0, 2)
	if is_inside_tree():
		rebuild()


func set_lod_tier(new_lod_tier: int) -> void:
	var clamped: int = clampi(new_lod_tier, 0, 2)
	if clamped == lod_tier:
		return
	lod_tier = clamped
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
		var scene_path: String = AssetResolver.resolve_scene_path(
			definition,
			lod_tier
		)
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue
		var packed := load(scene_path) as PackedScene
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		if instance == null:
			continue

		var part_root := Node3D.new()
		part_root.name = "Part_%d_%s" % [
			index,
			str(placement.get("part_id", "part")),
		]
		_apply_placement_transform(part_root, placement)
		_external_root.add_child(part_root)

		instance.name = "AuthoredAsset"
		_apply_asset_transform(instance, definition)
		part_root.add_child(instance)


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
		if not has_geometry and not has_voxels:
			continue
		var authored_path: String = AssetResolver.resolve_scene_path(
			definition,
			lod_tier
		)
		var authored_available: bool = (
			not authored_path.is_empty()
			and ResourceLoader.exists(authored_path)
		)
		# Primitive geometry is the development/failure fallback. As soon as a
		# registered authored asset exists it replaces the prototype without
		# changing part_id or any saved player blueprint.
		if not authored_available:
			result[part_id] = definition
	return result


func _apply_placement_transform(
	root: Node3D,
	placement: Dictionary
) -> void:
	root.position = _as_vector3(
		placement.get("position", Vector3.ZERO),
		Vector3.ZERO
	)
	root.rotation_degrees = _as_vector3(
		placement.get("rotation", Vector3.ZERO),
		Vector3.ZERO
	)
	root.scale = _as_vector3(
		placement.get("scale", Vector3.ONE),
		Vector3.ONE
	)


func _apply_asset_transform(
	instance: Node3D,
	definition: Dictionary
) -> void:
	var correction: Dictionary = AssetResolver.get_asset_transform(definition)
	instance.position = correction.get("position", Vector3.ZERO)
	instance.rotation_degrees = correction.get("rotation", Vector3.ZERO)
	instance.scale = correction.get("scale", Vector3.ONE)


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
