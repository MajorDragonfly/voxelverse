extends "res://creatures/editor/creature_editor_v5.gd"

const SafeBaseBlueprint = preload("res://creatures/editor/creature_blueprint.gd")
const SafeBlueprintV5 = preload("res://creatures/editor/creature_blueprint_v5.gd")
const SafeAnatomy = preload("res://creatures/editor/creature_anatomy.gd")
const AttachmentNormalizer = preload("res://creatures/editor/creature_attachment_normalizer.gd")

const LEGACY_BLUEPRINT_SAVE_PATH := "user://creature_editor_blueprint.json"


func _ready() -> void:
	super._ready()
	_install_safe_name_handlers()
	call_deferred("_repair_loaded_attachments")


func _repair_loaded_attachments() -> void:
	var changed: bool = AttachmentNormalizer.normalize(blueprint)
	if changed:
		SafeBlueprintV5.save_to_file(blueprint)
		SafeBaseBlueprint.save_to_file(blueprint, LEGACY_BLUEPRINT_SAVE_PATH)
		_set_v5_status("Detached legacy parts were rebound to the body.")
	if has_method("_refresh_preview"):
		call("_refresh_preview")
	elif has_method("_rebuild_preview"):
		call("_rebuild_preview")


func _on_name_changed(new_text: String) -> void:
	_apply_creature_name(new_text, false)


func _on_name_submitted(new_text: String) -> void:
	_apply_creature_name(new_text, true)


func _install_safe_name_handlers() -> void:
	if _creature_name_edit == null:
		return
	_disconnect_signal_connections(_creature_name_edit.text_changed)
	_disconnect_signal_connections(_creature_name_edit.text_submitted)
	_creature_name_edit.text_changed.connect(_on_creature_name_changed_safe)
	_creature_name_edit.text_submitted.connect(_on_creature_name_submitted_safe)


func _disconnect_signal_connections(target_signal: Signal) -> void:
	for connection_value in target_signal.get_connections():
		if not (connection_value is Dictionary):
			continue
		var callback_value: Variant = connection_value.get("callable")
		if not (callback_value is Callable):
			continue
		var callback: Callable = callback_value
		if target_signal.is_connected(callback):
			target_signal.disconnect(callback)


func _on_creature_name_changed_safe(new_text: String) -> void:
	_apply_creature_name(new_text, false)


func _on_creature_name_submitted_safe(new_text: String) -> void:
	_apply_creature_name(new_text, true)


func _apply_creature_name(new_text: String, finalize: bool) -> void:
	var creature_name: String = new_text
	if finalize:
		creature_name = creature_name.strip_edges()
		if creature_name.is_empty():
			creature_name = "New Creature"
	blueprint["name"] = creature_name
	if finalize and _creature_name_edit != null:
		_creature_name_edit.text = creature_name
	_refresh_stats_panel()
	if finalize:
		_set_v5_status("Creature name updated.")


func _save_blueprint() -> void:
	if _creature_name_edit != null:
		_apply_creature_name(_creature_name_edit.text, true)

	AttachmentNormalizer.normalize(blueprint)
	SafeAnatomy.rebind_all_parts(blueprint)

	var legacy_save_error: Error = SafeBaseBlueprint.save_to_file(
		blueprint,
		LEGACY_BLUEPRINT_SAVE_PATH
	)
	if legacy_save_error != OK:
		push_error("Creature legacy save failed: %s" % legacy_save_error)
		_set_v5_status("Legacy save failed: %s" % legacy_save_error)
		return

	var v5_save_error: Error = SafeBlueprintV5.save_to_file(blueprint)
	if v5_save_error != OK:
		push_error("Creature V5 save failed: %s" % v5_save_error)
		_set_v5_status("V5 save failed: %s" % v5_save_error)
		return

	_set_v5_status("Saved creature blueprint for editor and runtime.")
