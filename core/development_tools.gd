extends Node

const BUILDING_BUILDER_SCENE: String = "res://civilization/buildings/building_builder.tscn"
const PLANET_LAB_SCENE: String = "res://world/planet_lab/planet_lab.tscn"


func _ready() -> void:
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and bool(flow.loading):
		await flow.world_started
		if not is_inside_tree():
			return
	if "--input-smoke" in OS.get_cmdline_user_args() and not get_tree().has_meta("menu_smoke_consumed"):
		get_tree().set_meta("menu_smoke_consumed", true)
		get_tree().root.add_child.call_deferred(load("res://core/diagnostics/menu_input_probe.gd").new())
	# Official release templates reject scene-path overrides. This uses the
	# same saved transition as F4, including in a packaged acceptance run.
	if "--planet-lab" in OS.get_cmdline_user_args() and not get_tree().has_meta("planet_lab_boot_consumed"):
		get_tree().set_meta("planet_lab_boot_consumed", true)
		call_deferred("_open_planet_lab")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		get_viewport().set_input_as_handled()
		_open_planet_lab()
		return
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_B:
		get_viewport().set_input_as_handled()
		_open_building_builder()


func _open_building_builder() -> void:
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("save_now"):
		save_service.call("save_now")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error: Error = get_tree().change_scene_to_file(BUILDING_BUILDER_SCENE)
	if error != OK:
		push_error("Could not open Building Builder: %s" % error)


func _open_planet_lab() -> bool:
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and not bool(save_service.call("save_now")):
		return false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error: Error = get_tree().change_scene_to_file(PLANET_LAB_SCENE)
	if error != OK:
		push_error("Could not open Planet Lab: %s" % error)
	return error == OK
