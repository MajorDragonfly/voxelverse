extends "res://tools/export_trunk_review.gd"
## Actual shared meshes in two views and on complete four-legged bodies.
const ORNAMENTS: Array[String] = ["horns_stag_antlers", "horns_moose_antlers", "decor_low_crest", "decor_saw_crest", "decor_head_crest", "decor_frill"]


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Supply an output JSON path.")
		quit(1)
		return
	var result: Dictionary = {"models": [], "bodies": []}
	for id: String in ORNAMENTS:
		var definition: Dictionary = Assembly.BaseBlueprint.PartLibrary.get_part(id)
		var design: Dictionary = Assembly.create_default()
		for index in range(design.parts.size() - 1, -1, -1):
			if design.parts[index].category == "ornaments": design.parts.remove_at(index)
		Assembly.BaseBlueprint.add_part(design, "legs_walker")
		Assembly.BaseBlueprint.add_part(design, id)
		Anatomy.reset_all_anchors(design)
		preload("res://creatures/editor/creature_attachment_normalizer.gd").normalize(design)
		var preview := Preview.new()
		root.add_child(preview)
		preview.set_editor_state(design, -1, -1, false)
		preview.set_process(false)
		var model := Node3D.new()
		Geometry.build(model, definition, {"category": definition.category}, design)
		var isolated: Array = []
		var body: Array = []
		_meshes(model, Transform3D.IDENTITY, isolated)
		_meshes(preview, Transform3D.IDENTITY, body)
		result.models.append({"id": id, "name": definition.name, "meshes": isolated})
		result.bodies.append({"id": id, "name": definition.name, "meshes": body})
		model.free()
		preview.free()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write ornament review.")
		quit(1)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	print("ORNAMENT_REVIEW_EXPORT_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
