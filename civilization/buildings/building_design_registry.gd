extends RefCounted
class_name BuildingDesignRegistry

const Blueprint = preload(
	"res://civilization/buildings/building_blueprint.gd"
)
const BuildingVisual = preload(
	"res://civilization/buildings/building_runtime_visual.gd"
)


static func load_all_designs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for filename in Blueprint.list_designs():
		var design: Dictionary = Blueprint.load_from_file(
			Blueprint.get_design_path(filename)
		)
		if design.is_empty():
			continue
		design["_design_filename"] = filename
		result.append(design)
	return result


static func get_designs_for_type(type_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for design in load_all_designs():
		if Blueprint.get_building_type(design) == type_name:
			result.append(design)
	return result


static func choose_design(
	type_name: String,
	selection_seed: int
) -> Dictionary:
	var designs: Array[Dictionary] = get_designs_for_type(type_name)
	if designs.is_empty():
		var fallback: Dictionary = Blueprint.create_default()
		Blueprint.set_building_type(fallback, type_name)
		fallback["name"] = "%s Prototype" % type_name.capitalize()
		return fallback
	var index: int = posmod(selection_seed, designs.size())
	return designs[index].duplicate(true)


static func instantiate_design(
	design: Dictionary,
	with_collision: bool = false
) -> Node3D:
	var visual := BuildingVisual.new()
	visual.name = "Building_%s" % _safe_node_name(str(design.get("name", "Design")))
	visual.set("build_collision", with_collision)
	visual.set_blueprint(design)
	return visual


static func create_city_design_set(city_seed: int) -> Dictionary:
	var result: Dictionary = {}
	for index in range(Blueprint.BUILDING_TYPES.size()):
		var type_name: String = Blueprint.BUILDING_TYPES[index]
		result[type_name] = choose_design(
			type_name,
			city_seed + index * 83_492_791
		)
	return result


static func get_design_summary() -> Dictionary:
	var summary: Dictionary = {"total": 0}
	for type_name in Blueprint.BUILDING_TYPES:
		summary[type_name] = 0
	for design in load_all_designs():
		var type_name: String = Blueprint.get_building_type(design)
		summary[type_name] = int(summary.get(type_name, 0)) + 1
		summary["total"] = int(summary.get("total", 0)) + 1
	return summary


static func _safe_node_name(value: String) -> String:
	var result: String = value.strip_edges()
	for character in ["/", "\\", ":", "@", "\"", "%"]:
		result = result.replace(character, "_")
	return result if not result.is_empty() else "Design"
