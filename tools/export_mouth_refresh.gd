extends "res://tools/export_trunk_review.gd"
const Mouths = preload("res://creatures/catalog/creature_mouth_catalog.gd")
const Articulation = preload("res://creatures/runtime/creature_part_articulation.gd")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var result: Dictionary = {"before": [], "after": [], "open": [], "bodies": []}
	for id: String in Mouths.REFRESHED_IDS:
		var definition: Dictionary = Assembly.BaseBlueprint.PartLibrary.get_part(id)
		var design: Dictionary = Assembly.create_default()
		for index in range(design.parts.size() - 1, -1, -1):
			if design.parts[index].category == "mouth": design.parts.remove_at(index)
		Assembly.BaseBlueprint.add_part(design, "legs_walker")
		var index: int = Assembly.BaseBlueprint.add_part(design, id)
		design.parts[index].part_revision = 2
		Anatomy.reset_all_anchors(design)
		for variant: String in ["before", "after", "open"]:
			var model := Node3D.new()
			Geometry.build(model, definition, {"part_id": id, "category": "mouth", "part_revision": 1 if variant == "before" else 2}, design)
			var motion := Articulation.new()
			motion.bind(model)
			if variant == "open": motion.set_pose(1, 0)
			var meshes: Array = []
			_meshes(model, Transform3D.IDENTITY, meshes)
			result[variant].append({"id": id, "name": definition.name, "meshes": meshes})
			motion.unbind()
			model.free()
		var preview := Preview.new()
		root.add_child(preview)
		preview.set_editor_state(design, -1, -1, false)
		preview.set_process(false)
		var meshes: Array = []
		_meshes(preview, Transform3D.IDENTITY, meshes)
		result.bodies.append({"id": id, "name": definition.name, "meshes": meshes})
		preview.free()
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	print("MOUTH_REFRESH_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
