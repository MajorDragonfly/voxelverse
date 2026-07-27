extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_editor_test")


func _run_editor_test() -> void:
	var packed_scene := load(
		"res://creatures/editor/creature_editor.tscn"
	) as PackedScene
	_expect(packed_scene != null, "Creature Builder scene could not load.")
	if packed_scene == null:
		_finish()
		return
	var editor := packed_scene.instantiate()
	_expect(editor != null, "Creature Builder scene could not instantiate.")
	if editor == null:
		_finish()
		return
	root.add_child(editor)
	for _frame in range(12):
		await process_frame

	var toolbar := editor.find_child(
		"CreatureBuilderV7Toolbar",
		true,
		false
	)
	_expect(toolbar != null, "Creature Builder V7 toolbar was not created.")
	var blueprint_value: Variant = editor.get("blueprint")
	_expect(blueprint_value is Dictionary, "Editor blueprint is not a dictionary.")
	if blueprint_value is Dictionary:
		var blueprint: Dictionary = blueprint_value
		_expect(
			int(blueprint.get("assembly", {}).get("schema", 0)) == 7,
			"Editor did not migrate to assembly schema V7."
		)
		for forbidden_field in [
			"generation",
			"genes",
			"genome",
			"genetics",
			"mutation",
			"lineage",
		]:
			_expect(
				not blueprint.has(forbidden_field),
				"Editor runtime still contains forbidden field: %s"
				% forbidden_field
			)

	if editor.has_method("_toggle_surface_snap"):
		editor.call("_toggle_surface_snap")
		await process_frame
		editor.call("_toggle_surface_snap")
		await process_frame
	else:
		_failures.append("Creature Builder has no surface-snap action.")

	editor.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Creature Editor V7 runtime test passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
