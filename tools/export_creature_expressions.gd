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
	if "--eyes" in OS.get_cmdline_user_args():
		await _export_eyes(output)
		return
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
	if not node.visible: return
	var pose: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in range(node.mesh.get_surface_count()):
			_append(node.mesh, surface, pose, node.get_active_material(surface), Color.WHITE, output)
	elif node is MultiMeshInstance3D and node.multimesh != null:
		var mm: MultiMesh = node.multimesh
		for index in range(mm.instance_count):
			for surface in range(mm.mesh.get_surface_count()):
				_append(mm.mesh, surface, pose * _instance_pose(mm, index), node.material_override, _instance_color(mm, index), output)
	for child: Node in node.get_children():
		if child is Node3D: _meshes(child, pose, output)

# Read submitted buffers: individual instance getters return identity in
# Godot's dummy/headless renderer, hiding the actual geometry from CPU review.
func _instance_pose(mm: MultiMesh, index: int) -> Transform3D:
	var buffer: PackedFloat32Array = mm.buffer
	var offset: int = index * (12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0))
	return Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]),
		Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]),
		Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])),
		Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11]))

func _instance_color(mm: MultiMesh, index: int) -> Color:
	if not mm.use_colors: return Color.WHITE
	var buffer: PackedFloat32Array = mm.buffer
	var offset: int = index * (16 + (4 if mm.use_custom_data else 0)) + 12
	return Color(buffer[offset], buffer[offset + 1], buffer[offset + 2], buffer[offset + 3])

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

func _export_eyes(output: String) -> void:
	var models: Array = []
	var labels: Dictionary = {"eyes_beady": "Knopfaugen", "eyes_wide": "Große Augen", "eyes_stalks": "Stielaugen", "eyes_cluster": "Augengruppe"}
	for id: String in labels:
		for opening: float in [1.0, 0.5, 0.0]:
			var stage := Node3D.new()
			root.add_child(stage)
			var part := Node3D.new()
			stage.add_child(part)
			part.set_meta("creature_part_category", "eyes")
			var design: Dictionary = Assembly.create_default()
			design["appearance"] = {"base_color": "9cbd9d", "accent_color": "467278"}
			preload("res://creatures/editor/creature_part_geometry.gd").build(part, {"id": id}, {"category": "eyes"}, design)
			var rig := preload("res://creatures/runtime/creature_eye_expression.gd").new()
			rig.bind(stage)
			rig.apply({"eye_open": opening, "look_yaw": 0.22 if opening == 0.5 else 0.0})
			var meshes: Array = []
			_meshes(part, Transform3D.IDENTITY, meshes)
			models.append({"name": labels[id] + " · " + ("offen" if opening == 1.0 else "halb geschlossen" if opening > 0.0 else "Blinzeln"), "family": id, "opening": opening, "meshes": meshes})
			stage.free()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(models))
	file.close()
	print("CREATURE_EYE_MESH_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
