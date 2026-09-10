extends RefCounted
class_name BuildingBlueprint

const Assembly = preload("res://assembly/core/modular_assembly.gd")
const Contract = preload("res://assembly/core/blueprint_contract.gd")
const Parts = preload("res://civilization/buildings/building_part_library.gd")

const Compatibility = preload("res://core/persistence/design_compatibility.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Store = preload("res://core/persistence/design_store.gd")

const SAVE_VERSION: int = 1
const DESIGN_DIR: String = "user://building_designs"
const AUTOSAVE_PATH: String = "user://building_builder_autosave.json"

const BUILDING_TYPES: Array[String] = [
	"residential",
	"commercial",
	"industrial",
	"civic",
	"military",
	"harbor",
]


static func create_default() -> Dictionary:
	var blueprint: Dictionary = Assembly.create("building", "New Building")
	blueprint["building"] = {
		"schema": SAVE_VERSION,
		"type": "residential",
		"style_name": "Player Architecture",
	}
	Assembly.set_grid_size(blueprint, 0.25)
	Assembly.add_part(blueprint, "mass_house_core", Vector3.ZERO)
	Assembly.add_part(blueprint, "roof_gable_red", Vector3(0, 3.45, 0))
	Assembly.add_part(blueprint, "opening_door_wood", Vector3(0, 0.35, -2.12))
	Assembly.add_part(blueprint, "opening_window_small", Vector3(-1.15, 1.65, -2.12))
	Assembly.add_part(blueprint, "opening_window_small", Vector3(1.15, 1.65, -2.12))
	normalize(blueprint)
	return blueprint


static func normalize(blueprint: Dictionary) -> Dictionary:
	if not Contract.version_error(blueprint, "building").is_empty(): return blueprint
	Ids.ensure_design(blueprint)
	Assembly.normalize(blueprint, "building")
	blueprint["assembly_type"] = "building"
	Compatibility.resolve_building(blueprint)
	var building: Dictionary = blueprint.get("building", {})
	building["schema"] = SAVE_VERSION
	var type_name: String = str(building.get("type", "residential"))
	if type_name not in BUILDING_TYPES:
		type_name = "residential"
	building["type"] = type_name
	building["style_name"] = str(
		building.get("style_name", "Player Architecture")
	)
	blueprint["building"] = building
	return blueprint


static func set_building_type(blueprint: Dictionary, type_name: String) -> void:
	if not Contract.version_error(blueprint, "building").is_empty(): return
	normalize(blueprint)
	if type_name not in BUILDING_TYPES:
		return
	var building: Dictionary = blueprint.get("building", {})
	building["type"] = type_name
	blueprint["building"] = building


static func get_building_type(blueprint: Dictionary) -> String:
	var building: Dictionary = blueprint.get("building", {})
	return str(building.get("type", "residential"))


static func calculate_stats(blueprint: Dictionary) -> Dictionary:
	var totals: Dictionary = Assembly.calculate_stats(blueprint, Parts.get_all_parts())
	for stat_name in [
		"cost",
		"housing",
		"commerce",
		"industry",
		"defense",
		"prestige",
		"energy",
		"pollution",
	]:
		totals[stat_name] = float(totals.get(stat_name, 0.0))
	return totals


static func save_autosave(blueprint: Dictionary) -> Error:
	return save_to_file(blueprint, AUTOSAVE_PATH, false)


static func load_autosave() -> Dictionary:
	var blueprint: Dictionary = load_from_file(AUTOSAVE_PATH)
	if blueprint.is_empty():
		return create_default()
	return blueprint


static func save_design(
	blueprint: Dictionary,
	design_name: String = ""
) -> String:
	if not Contract.inspect(blueprint, "building").ok: return ""
	var safe_name: String = design_name.strip_edges()
	if safe_name.is_empty():
		safe_name = str(blueprint.get("name", "building"))
	var candidate: Dictionary = blueprint.duplicate(true)
	candidate["name"] = safe_name
	_ensure_design_directory()
	var filename: String = _slugify(safe_name) + ".json"
	var path: String = "%s/%s" % [DESIGN_DIR, filename]
	var error: Error = save_to_file(candidate, path, true)
	if error == OK:
		blueprint.clear()
		blueprint.merge(candidate, true)
	return path if error == OK else ""


static func save_to_file(
	blueprint: Dictionary,
	path: String,
	increment_revision: bool = false
) -> Error:
	if not Contract.inspect(blueprint, "building").ok: return ERR_INVALID_DATA
	var candidate: Dictionary = blueprint.duplicate(true)
	normalize(candidate)
	if increment_revision:
		var previous: Dictionary = Store.Atomic.parse_dictionary(Store.read_text(path))
		if previous is Dictionary and previous.get("design_id") == candidate.get("design_id") and Contract.inspect(previous, "building").ok:
			candidate["revision"] = maxi(int(candidate.get("revision", 0)), int(previous.get("revision", 0)))
		Assembly.increment_revision(candidate)
	var data: Dictionary = Assembly.serialize(candidate)
	var error: Error = Store.write(path, data)
	if error == OK:
		blueprint.clear()
		blueprint.merge(candidate, true)
	return error


static func load_from_file(path: String) -> Dictionary:
	var text: String = Store.read_text(path)
	if text.is_empty():
		return {}
	if not Contract.inspect_text(text, "building").ok: return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	Ids.ensure_design(parsed, path)
	var blueprint: Dictionary = Assembly.deserialize(parsed)
	blueprint["building"] = parsed.get("building", {}).duplicate(true)
	normalize(blueprint)
	return blueprint


static func list_designs() -> Array[String]:
	_ensure_design_directory()
	return Store.list_buildings()


static func get_design_path(filename: String) -> String:
	return "%s/%s" % [DESIGN_DIR, filename]


static func validate(blueprint: Dictionary) -> Array[String]:
	var errors: Array[String] = Assembly.validate(blueprint, Parts.get_all_parts())
	if blueprint.get("parts", []).is_empty():
		errors.append("Building contains no parts.")
	var has_structure: bool = false
	for part_value in blueprint.get("parts", []):
		if not (part_value is Dictionary):
			continue
		var definition: Dictionary = Parts.get_part(str(part_value.get("part_id", "")))
		if str(definition.get("category", "")) == Parts.CATEGORY_MASS:
			has_structure = true
			break
	if not has_structure:
		errors.append("Building needs at least one structural mass.")
	return errors


static func _ensure_design_directory() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(DESIGN_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_path)


static func _slugify(value: String) -> String:
	var result: String = value.to_lower().strip_edges()
	for character in [" ", "/", "\\", ":", ";", ".", ",", "?", "!", "\t"]:
		result = result.replace(character, "_")
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.trim_prefix("_").trim_suffix("_")
	return result if not result.is_empty() else "building"
