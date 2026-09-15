extends SceneTree
## Export actual posed runtime triangles, including colored MultiMesh instances.
## For CPU layout/pose review; not a native screenshot or FPS measurement.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var output: String = OS.get_cmdline_user_args()[0]
	var names: Array[String] = ["Ruhig", "Neugierig", "Zuneigung", "Begrüßung", "Angst", "Drohen"]
	var contexts: Array[Dictionary] = [{}, {"intent": "social", "look_yaw": 0.18}, {"friendly_near": true}, {}, {"intent": "flee"}, {"intent": "alert"}]
	var models: Array = []
	for index in range(6):
		var design: Dictionary = Assembly.create_default()
		Assembly.BaseBlueprint.add_part(design, "legs_walker")
		Assembly.BaseBlueprint.add_part(design, "tail_balance")
		Anatomy.reset_all_anchors(design)
		design["appearance"] = {"base_color": "9cbd9d", "accent_color": "467278"}
		var actor := Preview.new()
		root.add_child(actor)
		actor.set_editor_state(design, -1, -1, false)
		actor.position.y = -float(actor.get_meta("ground_y"))
		actor.set_motion("idle")
		actor.set_process(false)
		var emotion := Emotion.new()
		emotion.configure(42)
		if index == 3: emotion.react("greet")
		for tick in range(48):
			actor.set_expression_pose(emotion.advance(1.0 / 30.0, contexts[index]))
			actor._process(1.0 / 30.0)
		var meshes: Array = []
		_meshes(actor, Transform3D.IDENTITY, meshes)
		models.append({"name": names[index], "state": emotion.state, "pose": emotion.pose(), "meshes": meshes})
		actor.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(models))
	file.close()
	print("CREATURE_EXPRESSION_MESH_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)

func _meshes(node: Node3D, parent: Transform3D, output: Array) -> void:
	var pose: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			_append(node.mesh, surface, pose, node.get_active_material(surface), Color.WHITE, output)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var mm: MultiMesh = node.multimesh
		for index in range(mm.instance_count):
			for surface in range(mm.mesh.get_surface_count()):
				_append(mm.mesh, surface, pose * mm.get_instance_transform(index), node.material_override, mm.get_instance_color(index) if mm.use_colors else Color.WHITE, output)
	for child: Node in node.get_children():
		if child is Node3D: _meshes(child, pose, output)

func _append(mesh: Mesh, surface: int, pose: Transform3D, material: Material, instance_color: Color, output: Array) -> void:
	var arrays: Array = mesh.surface_get_arrays(surface)
	var vertices: Array = []
	var colors: Array = []
	var tint: Color = instance_color * (material.albedo_color if material is BaseMaterial3D else Color.WHITE)
	var has_colors: bool = arrays[Mesh.ARRAY_COLOR] != null and not arrays[Mesh.ARRAY_COLOR].is_empty()
	for index in range(arrays[Mesh.ARRAY_VERTEX].size()):
		var point: Vector3 = pose * arrays[Mesh.ARRAY_VERTEX][index]
		vertices.append([point.x, point.y, point.z])
		var color: Color = arrays[Mesh.ARRAY_COLOR][index] * tint if has_colors else tint
		colors.append([color.r, color.g, color.b])
	var indices: Array = Array(arrays[Mesh.ARRAY_INDEX]) if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else range(vertices.size())
	output.append({"vertices": vertices, "indices": indices, "colors": colors})
