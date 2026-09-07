extends Node

const BUILDING_BUILDER_SCENE: String = "res://civilization/buildings/building_builder.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_B:
		_open_building_builder()
		get_viewport().set_input_as_handled()


func _open_building_builder() -> void:
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("save_now"):
		save_service.call("save_now")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error: Error = get_tree().change_scene_to_file(BUILDING_BUILDER_SCENE)
	if error != OK:
		push_error("Could not open Building Builder: %s" % error)
