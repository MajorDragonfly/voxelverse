extends Node

func _ready() -> void:
	call_deferred("_install_back_button")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_world()
		get_viewport().set_input_as_handled()


func _install_back_button() -> void:
	var canvas := get_parent().get_node_or_null("BuildingBuilderUI") as CanvasLayer
	if canvas == null:
		return
	var button := Button.new()
	button.name = "BackToWorld"
	button.text = "Back to World"
	button.anchor_left = 1.0
	button.anchor_top = 0.0
	button.anchor_right = 1.0
	button.anchor_bottom = 0.0
	button.offset_left = -190.0
	button.offset_top = 18.0
	button.offset_right = -24.0
	button.offset_bottom = 54.0
	button.pressed.connect(_return_to_world)
	canvas.add_child(button)


func _return_to_world() -> void:
	var builder: Node = get_parent()
	if builder != null:
		var blueprint_value: Variant = builder.get("blueprint")
		if blueprint_value is Dictionary:
			var BuildingBlueprint = load("res://civilization/buildings/building_blueprint.gd")
			BuildingBlueprint.save_autosave(blueprint_value)
	var error: Error = get_node("/root/SessionFlow").return_from_editor()
	if error != OK:
		push_error("Could not return to world: %s" % error)
