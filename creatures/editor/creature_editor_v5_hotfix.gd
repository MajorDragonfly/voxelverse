extends "res://creatures/editor/creature_editor_v5.gd"


func _ready() -> void:
	super._ready()
	_install_safe_name_handlers()


func _install_safe_name_handlers() -> void:
	if _creature_name_edit == null:
		return

	_disconnect_signal_connections(_creature_name_edit.text_changed)
	_disconnect_signal_connections(_creature_name_edit.text_submitted)

	_creature_name_edit.text_changed.connect(
		_on_creature_name_changed_safe
	)
	_creature_name_edit.text_submitted.connect(
		_on_creature_name_submitted_safe
	)


func _disconnect_signal_connections(target_signal: Signal) -> void:
	for connection_value in target_signal.get_connections():
		if not (connection_value is Dictionary):
			continue

		var connection: Dictionary = connection_value
		var callback_value: Variant = connection.get("callable")

		if not (callback_value is Callable):
			continue

		var callback: Callable = callback_value

		if target_signal.is_connected(callback):
			target_signal.disconnect(callback)


func _on_creature_name_changed_safe(new_text: String) -> void:
	blueprint["name"] = new_text
	_refresh_stats_panel()


func _on_creature_name_submitted_safe(new_text: String) -> void:
	var clean_name: String = new_text.strip_edges()

	if clean_name.is_empty():
		clean_name = "New Creature"

	blueprint["name"] = clean_name

	if _creature_name_edit != null:
		_creature_name_edit.text = clean_name

	_refresh_stats_panel()
	_set_v5_status("Creature name updated.")
