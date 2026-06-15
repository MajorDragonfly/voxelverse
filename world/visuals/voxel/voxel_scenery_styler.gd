extends Node
class_name VoxelSceneryStyler


const VOXEL_SURFACE_MATERIAL: ShaderMaterial = preload(
	"res://world/visuals/voxel/voxel_surface_material.tres"
)

const GRASS_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/grass_01.png"
)

const STONE_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/stone_01.png"
)

const RUIN_TEXTURE: Texture2D = preload(
	"res://world/visuals/voxel/textures/ruin_stone_01.png"
)


@export_category("Pixel Materials")

@export_range(2, 8, 1)
var palette_steps: int = 4

@export_range(0.20, 1.00, 0.01)
var grass_texture_darkness: float = 0.62

@export_range(0.80, 1.50, 0.01)
var grass_texture_brightness: float = 1.18

@export_range(0.20, 1.00, 0.01)
var stone_texture_darkness: float = 0.48

@export_range(0.80, 1.50, 0.01)
var stone_texture_brightness: float = 1.28

@export_range(0.20, 1.00, 0.01)
var ruin_texture_darkness: float = 0.52

@export_range(0.80, 1.50, 0.01)
var ruin_texture_brightness: float = 1.24


@export_category("Debug")

@export
var print_styled_nodes: bool = true


var _target_chunk: Node = null

var _styled_instance_ids: Dictionary = {}


func _ready() -> void:
	_target_chunk = get_parent()

	if _target_chunk == null:
		push_error(
			"VoxelSceneryStyler requires a parent terrain chunk."
		)
		return

	var scene_tree := get_tree()

	if scene_tree == null:
		push_error(
			"VoxelSceneryStyler could not access the SceneTree."
		)
		return

	if not scene_tree.node_added.is_connected(
		_on_tree_node_added
	):
		scene_tree.node_added.connect(
			_on_tree_node_added
		)

	call_deferred(
		"_style_existing_scenery"
	)


func _exit_tree() -> void:
	var scene_tree := get_tree()

	if scene_tree == null:
		return

	if scene_tree.node_added.is_connected(
		_on_tree_node_added
	):
		scene_tree.node_added.disconnect(
			_on_tree_node_added
		)


func _on_tree_node_added(
	node: Node
) -> void:
	if node == null:
		return

	if not _belongs_to_target_chunk(
		node
	):
		return

	# Die Erzeugungsscripts setzen teilweise erst unmittelbar
	# vor oder nach add_child() ihr Mesh beziehungsweise MultiMesh.
	# Der verzögerte Aufruf stellt sicher, dass die Geometrie
	# vollständig vorhanden ist.
	call_deferred(
		"_try_style_node",
		node
	)


func _style_existing_scenery() -> void:
	if _target_chunk == null:
		return

	_style_descendants(
		_target_chunk
	)


func _style_descendants(
	root_node: Node
) -> void:
	for child in root_node.get_children():
		_try_style_node(
			child
		)

		_style_descendants(
			child
		)


func _try_style_node(
	node: Node
) -> void:
	if node == null:
		return

	if not node is GeometryInstance3D:
		return

	var geometry_instance := (
		node as GeometryInstance3D
	)

	var selected_texture: Texture2D = null

	var selected_texture_scale: float = 1.0
	var selected_darkness: float = 0.60
	var selected_brightness: float = 1.20

	match StringName(node.name):
		&"GrassTufts":
			selected_texture = GRASS_TEXTURE
			selected_texture_scale = 2.0
			selected_darkness = (
				grass_texture_darkness
			)
			selected_brightness = (
				grass_texture_brightness
			)

		&"ScatteredRocks":
			selected_texture = STONE_TEXTURE

			# Niedriger als zuvor, damit die einzelnen
			# Pixel auf kleinen Felsen sichtbar bleiben.
			selected_texture_scale = 0.85

			selected_darkness = (
				stone_texture_darkness
			)
			selected_brightness = (
				stone_texture_brightness
			)

		&"RockSpires":
			selected_texture = STONE_TEXTURE
			selected_texture_scale = 0.70

			selected_darkness = (
				stone_texture_darkness
			)
			selected_brightness = (
				stone_texture_brightness
			)

		&"AncientRuin":
			selected_texture = RUIN_TEXTURE
			selected_texture_scale = 0.90

			selected_darkness = (
				ruin_texture_darkness
			)
			selected_brightness = (
				ruin_texture_brightness
			)

		_:
			return

	var instance_id := node.get_instance_id()

	if _styled_instance_ids.has(
		instance_id
	):
		return

	var voxel_material := (
		_create_voxel_material(
			selected_texture,
			selected_texture_scale,
			selected_darkness,
			selected_brightness
		)
	)

	if voxel_material == null:
		return

	# Das Material wird am GeometryInstance gesetzt.
	geometry_instance.material_override = (
		voxel_material
	)

	# Zusätzlich wird es direkt auf das zur Laufzeit
	# erzeugte Mesh geschrieben. Das ist besonders für
	# MultiMeshInstance3D robuster als eine ausschließlich
	# nachträgliche Node-Überschreibung.
	_apply_material_to_generated_mesh(
		geometry_instance,
		voxel_material
	)

	_styled_instance_ids[
		instance_id
	] = true

	if print_styled_nodes:
		print(
			"Applied pixel voxel material to: ",
			node.name
		)


func _create_voxel_material(
	texture: Texture2D,
	texture_scale_value: float,
	texture_darkness_value: float,
	texture_brightness_value: float
) -> ShaderMaterial:
	var voxel_material := (
		VOXEL_SURFACE_MATERIAL.duplicate()
		as ShaderMaterial
	)

	if voxel_material == null:
		push_error(
			"Scenery voxel material could not be duplicated."
		)
		return null

	voxel_material.set_shader_parameter(
		&"object_tint",
		Color.WHITE
	)

	voxel_material.set_shader_parameter(
		&"use_pixel_texture",
		texture != null
	)

	if texture != null:
		voxel_material.set_shader_parameter(
			&"pixel_texture",
			texture
		)

	voxel_material.set_shader_parameter(
		&"texture_scale",
		maxf(
			texture_scale_value,
			0.10
		)
	)

	voxel_material.set_shader_parameter(
		&"palette_steps",
		float(
			clampi(
				palette_steps,
				2,
				8
			)
		)
	)

	voxel_material.set_shader_parameter(
		&"texture_darkness",
		clampf(
			texture_darkness_value,
			0.20,
			1.00
		)
	)

	voxel_material.set_shader_parameter(
		&"texture_brightness",
		clampf(
			texture_brightness_value,
			0.80,
			1.50
		)
	)

	return voxel_material


func _apply_material_to_generated_mesh(
	geometry_instance: GeometryInstance3D,
	material: Material
) -> void:
	if geometry_instance is MultiMeshInstance3D:
		var multi_mesh_instance := (
			geometry_instance
			as MultiMeshInstance3D
		)

		if multi_mesh_instance.multimesh == null:
			return

		var generated_mesh := (
			multi_mesh_instance.multimesh.mesh
		)

		_apply_material_to_mesh_surfaces(
			generated_mesh,
			material
		)

		return

	if geometry_instance is MeshInstance3D:
		var mesh_instance := (
			geometry_instance
			as MeshInstance3D
		)

		_apply_material_to_mesh_surfaces(
			mesh_instance.mesh,
			material
		)


func _apply_material_to_mesh_surfaces(
	mesh_resource: Mesh,
	material: Material
) -> void:
	if mesh_resource == null:
		return

	var surface_count := (
		mesh_resource.get_surface_count()
	)

	for surface_index in range(
		surface_count
	):
		mesh_resource.surface_set_material(
			surface_index,
			material
		)


func _belongs_to_target_chunk(
	node: Node
) -> bool:
	if _target_chunk == null:
		return false

	var current_node: Node = node

	while current_node != null:
		if current_node == _target_chunk:
			return true

		current_node = (
			current_node.get_parent()
		)

	return false
