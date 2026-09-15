extends SceneTree
## Export real full-body Godot meshes at exact rest/open poses for CPU review.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var output: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node3D.new()
	root.add_child(stage)
	var actors: Array[Preview] = []
	var ids: Array[String] = ["mouth_canine_snout", "mouth_crocodile_snout", "mouth_octopus_beak"]
	for index in range(ids.size()):
		var design: Dictionary = Assembly.create_default()
		design.parts = []
		for id: String in ["legs_walker", "legs_walker", ids[index], "arms_grasping"]:
			Assembly.BaseBlueprint.add_part(design, id)
		Anatomy.reset_all_anchors(design)
		design.parts[3].end_part_id = "hands_crab_claws"
		design.parts[3].end_scale = 1.4
		Anatomy.rebind_all_parts(design)
		design.appearance = {"base_color": ["89bfa0", "bdaf89", "8faac7"][index], "accent_color": "30566c"}
		var mount := Node3D.new()
		mount.position.x = (index - 1) * 3.5
		mount.rotation.y = -0.48
		stage.add_child(mount)
		var actor := Preview.new()
		mount.add_child(actor)
		actor.set_editor_state(design, -1, -1, false)
		actor.position.y = -float(actor.get_meta("ground_y"))
		actors.append(actor)
	var models: Array = []
	for amount: float in [0.0, 1.0]:
		for index in range(actors.size()):
			var actor: Preview = actors[index]
			actor.set_articulation_pose(amount, amount)
			var meshes: Array = []
			_meshes(actor, actor.global_transform.affine_inverse(), meshes)
			models.append({"id": ids[index], "name": ["Hundeschnauze", "Krokodilschnauze", "Oktopusmund"][index],
				"pose": "Ausgangspose" if amount == 0 else "Geöffnet", "meshes": meshes})
	var file := FileAccess.open(output.path_join("bodies.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(models))
	file.close()
	stage.free()
	print("PART_ARTICULATION_MESH_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)


func _meshes(node: Node, frame: Transform3D, output: Array) -> void:
	if node.has_meta("editor_guide"): return
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			var data: Array = node.mesh.surface_get_arrays(surface)
			var vertices: Array = []
			var colors: Array = []
			var transform: Transform3D = frame * node.global_transform
			var tint: Color = node.material_override.albedo_color if node.material_override is StandardMaterial3D else Color.WHITE
			for i in range(data[Mesh.ARRAY_VERTEX].size()):
				var point: Vector3 = transform * data[Mesh.ARRAY_VERTEX][i]
				vertices.append([point.x, point.y, point.z])
				var color: Color = data[Mesh.ARRAY_COLOR][i] if data[Mesh.ARRAY_COLOR] != null and not data[Mesh.ARRAY_COLOR].is_empty() else Color.WHITE
				color *= tint
				colors.append([color.r, color.g, color.b])
			var indices: Array = Array(data[Mesh.ARRAY_INDEX]) if data[Mesh.ARRAY_INDEX] != null and not data[Mesh.ARRAY_INDEX].is_empty() else range(vertices.size())
			output.append({"name": str(node.name), "vertices": vertices, "indices": indices, "colors": colors})
	for child: Node in node.get_children(): _meshes(child, frame, output)
