extends "res://tools/export_trunk_review.gd"
## Reuse the actual mesh-array exporter, with one standard body per fin.
const Fins = preload("res://creatures/catalog/creature_fin_catalog.gd")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Supply an output JSON path.")
		quit(1)
		return
	var result: Dictionary = {"models": [], "bodies": [], "stretched": []}
	for profile: Dictionary in Fins.get_parts():
		var design: Dictionary = Assembly.create_default()
		for index in range(design.parts.size() - 1, -1, -1):
			if design.parts[index].category == "fins": design.parts.remove_at(index)
		Assembly.BaseBlueprint.add_part(design, "legs_walker")
		Assembly.BaseBlueprint.add_part(design, profile.id)
		Anatomy.reset_all_anchors(design)
		preload("res://creatures/editor/creature_attachment_normalizer.gd").normalize(design)
		var preview := Preview.new()
		root.add_child(preview)
		preview.set_editor_state(design, -1, -1, false)
		preview.set_process(false)
		var model := Node3D.new()
		Geometry.build(model, profile, {"category": "fins"}, design)
		var isolated: Array = []
		var body: Array = []
		_meshes(model, Transform3D.IDENTITY, isolated)
		_meshes(preview, Transform3D.IDENTITY, body)
		result.models.append({"id": profile.id, "name": profile.name, "meshes": isolated})
		result.bodies.append({"id": profile.id, "name": profile.name, "meshes": body})
		preview._articulation.set_fin_pose(1.0)
		var stretched: Array = []
		_meshes(preview, Transform3D.IDENTITY, stretched)
		result.stretched.append({"id": profile.id, "name": profile.name, "meshes": stretched})
		model.free()
		preview.free()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write fin review.")
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("FIN_REVIEW_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
