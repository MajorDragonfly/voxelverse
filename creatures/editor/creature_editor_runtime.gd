extends "res://creatures/editor/creature_editor_v7.gd"

const RuntimePartLibrary = preload(
	"res://creatures/editor/creature_part_library.gd"
)
const RuntimeBlueprint = preload(
	"res://creatures/editor/creature_blueprint.gd"
)


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
	_clear_control_children(_part_grid)
	var parts: Array = RuntimePartLibrary.get_parts_for_category(current_category)
	var progression := get_node_or_null("/root/ProgressionService")
	for part_value in parts:
		if not (part_value is Dictionary):
			continue
		var part: Dictionary = part_value
		var part_id: String = str(part.get("id", ""))
		var unlocked: bool = true
		if progression != null and progression.has_method("is_part_unlocked"):
			unlocked = bool(progression.call("is_part_unlocked", part_id))
		var button := Button.new()
		button.custom_minimum_size = Vector2(148.0, 92.0)
		button.text = _get_palette_button_text(part)
		if not unlocked:
			button.text = "LOCKED\n%s" % str(part.get("name", "Unknown"))
			button.tooltip_text = "Discover creatures to unlock this part."
			button.disabled = true
		else:
			button.tooltip_text = str(part.get("description", ""))
			button.pressed.connect(
				Callable(self, "_on_part_button_pressed").bind(part_id)
			)
		_part_grid.add_child(button)


func _on_part_button_pressed(part_id: String) -> void:
	var progression := get_node_or_null("/root/ProgressionService")
	if progression != null and progression.has_method("is_part_unlocked"):
		if not bool(progression.call("is_part_unlocked", part_id)):
			_set_builder_status("This part has not been discovered yet.")
			return
	super._on_part_button_pressed(part_id)


func _save_blueprint() -> void:
	_sync_progression_into_blueprint()
	super._save_blueprint()
	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("save_now"):
		if not bool(save_service.call("save_now")):
			_set_builder_status("Design written, but the campaign snapshot could not be saved.")


func _refresh_stats_panel() -> void:
	super._refresh_stats_panel()
	if _stats_label == null:
		return
	var progression := get_node_or_null("/root/ProgressionService")
	if progression == null:
		return
	_stats_label.text += (
		"\n\nDISCOVERY\n"
		+ "Insight: %d\n"
		+ "Known species: %d\n"
		+ "Unlocked parts: %d"
	) % [
		int(progression.get("discovery_points")),
		int(progression.call("get_discovered_species_count")),
		int(progression.call("get_unlocked_count")),
	]


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
