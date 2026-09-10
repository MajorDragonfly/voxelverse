extends "res://creatures/editor/creature_editor_seat_studio.gd"

const RuntimePartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const RuntimeBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)
const BlueprintLibraryPanel = preload("res://ui/blueprints/creature_library_panel.gd")
var _library_panel: Control


func _build_palette() -> void:
	super._build_palette()
	var column: Node = _left_panel.get_child(0)
	var button: Button = _button(column, "BP_TEMPLATES", _open_blueprint_library)
	button.name = "OpenBlueprintLibrary"
	column.move_child(button, 1)


func _open_blueprint_library() -> void:
	if is_instance_valid(_library_panel): return
	_end_gesture()
	_library_panel = BlueprintLibraryPanel.new()
	_library_panel.prepare_template = _prepare_library_template
	_library_panel.capture_current = func() -> Dictionary: return blueprint.duplicate(true)
	_library_panel.template_chosen.connect(_adopt_library_template)
	_library_panel.closed.connect(func(): _library_panel = null)
	_ui_root.add_child(_library_panel)


func _prepare_library_template(package: Dictionary) -> Dictionary:
	return BlueprintLibraryPanel.Starter.for_editor(BlueprintLibraryPanel.Package.prepare_for_active_editor(package, blueprint))


func _adopt_library_template(package: Dictionary) -> void:
	var result: Dictionary = _prepare_library_template(package)
	if not result.ok:
		_library_panel.show_result(result)
		return
	_end_gesture()
	_record_before_edit("Import creature template", true)
	_apply_restored_blueprint(result.blueprint, BlueprintLibraryPanel.Text.text("BP_ADOPTED"))
	_set_mode("body")
	_frame_creature()
	_library_panel._close()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_library_panel): return
	super._unhandled_input(event)


func _ready() -> void:
	var saves := get_node_or_null("/root/SaveGameService")
	if saves != null:
		saves.call("load_if_present")
	super._ready()
	_merge_current_creature_parts_into_progression()
	_sync_progression_into_blueprint()
	_refresh_all()
	if not blueprint.get("compatibility_warnings", []).is_empty():
		_set_builder_status("\n".join(blueprint["compatibility_warnings"]))


func _refresh_part_palette() -> void:
	super._refresh_part_palette()

func _on_part_button_pressed(part_id: String) -> void:
	var progression := get_node_or_null("/root/ProgressionService")
	if not RuntimePartLibrary.is_terminal(part_id) and progression != null and progression.has_method("is_part_unlocked"):
		if not bool(progression.call("is_part_unlocked", part_id)):
			_set_builder_status("This part has not been discovered yet.")
			return
	super._on_part_button_pressed(part_id)


func _save_blueprint() -> void:
	_sync_progression_into_blueprint()
	super._save_blueprint()
	var save_service := get_node_or_null("/root/SaveGameService")
	if _last_save_ok and save_service != null and save_service.has_method("save_now"):
		if not bool(save_service.call("save_now")):
			_last_save_ok = false
			_set_builder_status("Kreatur gespeichert; Spielstand konnte nicht gespeichert werden. Bitte erneut versuchen.")


func _refresh_stats_panel() -> void:
	super._refresh_stats_panel()

func _merge_current_creature_parts_into_progression() -> void:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null or not progression.has_method("merge_unlocked_parts"):
		return
	progression.call("merge_unlocked_parts", _get_current_creature_part_ids())
	var progression_data: Dictionary = blueprint.get("progression", {})
	progression.call(
		"merge_unlocked_parts",
		progression_data.get("unlocked_parts", [])
	)


func _sync_progression_into_blueprint() -> void:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null:
		return
	var progression_data: Dictionary = blueprint.get("progression", {})
	if progression.has_method("get_unlocked_part_ids"):
		progression_data["unlocked_parts"] = progression.call("get_unlocked_part_ids")
	progression_data["discoveries"] = []
	progression_data.erase("phase")
	blueprint["progression"] = progression_data


func _get_current_creature_part_ids() -> Array[String]:
	var result: Array[String] = []
	var body_id: String = RuntimeBlueprint.get_body_part_id(blueprint)
	_append_unique(result, body_id)
	var paint_id: String = RuntimeBlueprint.get_paint_part_id(blueprint)
	_append_unique(result, paint_id)
	for placement_value in blueprint.get("parts", []):
		if placement_value is Dictionary:
			_append_unique(result, str(placement_value.get("part_id", "")))
	return result


func _append_unique(values: Array[String], value: String) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)


func _load_blueprint() -> void:
	super._load_blueprint()
	if not blueprint.get("compatibility_warnings", []).is_empty():
		_set_builder_status("\n".join(blueprint["compatibility_warnings"]))
