extends Control
var editor: Node


func _gui_input(event: InputEvent) -> void:
	if editor != null:
		editor.call("handle_canvas_input", event)
		accept_event()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if editor == null or not (data is Dictionary) or not data.has("creature_part"):
		return false
	return bool(editor.call("can_drop_part", str(data["creature_part"]), at_position + global_position))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	editor.call("drop_part", str(data["creature_part"]), at_position + global_position)
