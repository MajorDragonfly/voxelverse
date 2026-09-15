extends SceneTree
## Export the shared recipe and a complete runtime body, using actual meshes.
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Geometry = preload("res://creatures/editor/creature_part_geometry.gd")
const ID: String = "head_elephant_trunk"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Supply an output JSON path.")
		quit(1)
		return
	var design: Dictionary = Assembly.create_default()
	Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, ID)
	Anatomy.reset_all_anchors(design)
	preload("res://creatures/editor/creature_attachment_normalizer.gd").normalize(design)
	var preview := Preview.new()
	root.add_child(preview)
	preview.set_editor_state(design, -1, -1, false)
	preview.set_process(false)
	var model := Node3D.new()
	Geometry.build(model, Assembly.BaseBlueprint.PartLibrary.get_part(ID), {"category": "head"}, design)
	var isolated: Array = []
	var body: Array = []
	_meshes(model, Transform3D.IDENTITY, isolated)
	_meshes(preview, Transform3D.IDENTITY, body)
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write trunk review.")
		quit(1)
		return
	file.store_string(JSON.stringify([
		{"id": ID, "name": "Eigenes Kopfmodul", "meshes": isolated},
		{"id": "trunk_body", "name": "Rüssel und separater Mund am Körper", "meshes": body},
	]))
	file.close()
	model.free()
	preview.free()
	print("TRUNK_REVIEW_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)


func _meshes(node: Node3D, parent: Transform3D, output: Array) -> void:
	var pose: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: Array = []
			var colors: Array = []
			var material: Material = node.get_active_material(surface)
			var tint: Color = material.albedo_color if material is BaseMaterial3D else Color.WHITE
			var has_colors: bool = arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty()
			for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
				var point: Vector3 = pose * arrays[Mesh.ARRAY_VERTEX][index]
				vertices.append([point.x, point.y, point.z])
				var color: Color = arrays[Mesh.ARRAY_COLOR][index] * tint if has_colors else tint
				colors.append([color.r, color.g, color.b])
			var indices: Array = Array(arrays[Mesh.ARRAY_INDEX]) if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else range(vertices.size())
			output.append({"name": str(node.name), "vertices": vertices, "indices": indices, "colors": colors})
	for child: Node in node.get_children():
		if child is Node3D: _meshes(child, pose, output)
