extends RefCounted
class_name BuildingPartLibrary

const CATEGORY_MASS: String = "mass"
const CATEGORY_ROOF: String = "roof"
const CATEGORY_TOWER: String = "tower"
const CATEGORY_OPENING: String = "opening"
const CATEGORY_BALCONY: String = "balcony"
const CATEGORY_SUPPORT: String = "support"
const CATEGORY_UTILITY: String = "utility"
const CATEGORY_DECOR: String = "decor"

const STONE := Color(0.56, 0.54, 0.49, 1.0)
const LIGHT_STONE := Color(0.72, 0.69, 0.61, 1.0)
const DARK_STONE := Color(0.34, 0.35, 0.34, 1.0)
const TIMBER := Color(0.34, 0.20, 0.11, 1.0)
const PLASTER := Color(0.82, 0.75, 0.62, 1.0)
const ROOF_RED := Color(0.50, 0.20, 0.12, 1.0)
const ROOF_DARK := Color(0.18, 0.22, 0.23, 1.0)
const METAL := Color(0.32, 0.38, 0.39, 1.0)
const GLASS := Color(0.28, 0.58, 0.70, 1.0)
const ACCENT := Color(0.72, 0.48, 0.18, 1.0)


static func get_categories() -> Array:
	return [
		{"id": CATEGORY_MASS, "name": "Structure"},
		{"id": CATEGORY_ROOF, "name": "Roofs"},
		{"id": CATEGORY_TOWER, "name": "Towers"},
		{"id": CATEGORY_OPENING, "name": "Doors / Windows"},
		{"id": CATEGORY_BALCONY, "name": "Balconies"},
		{"id": CATEGORY_SUPPORT, "name": "Supports"},
		{"id": CATEGORY_UTILITY, "name": "Utility"},
		{"id": CATEGORY_DECOR, "name": "Decor"},
	]


static func get_parts_for_category(category_id: String) -> Array:
	var result: Array = []
	for definition in get_all_parts().values():
		if str(definition.get("category", "")) == category_id:
			result.append(definition.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return result


static func get_part(part_id: String) -> Dictionary:
	return get_all_parts().get(part_id, {}).duplicate(true)


static func get_all_parts() -> Dictionary:
	var parts: Dictionary = {}
	for definition in _definitions():
		parts[str(definition.get("id", ""))] = definition
	return parts


static func get_default_part_id() -> String:
	return "mass_house_core"


static func _definitions() -> Array:
	return [
		_part("mass_house_core", "House Core", CATEGORY_MASS, "Balanced residential volume.", [
			_box(Vector3(0, 1.5, 0), Vector3(4.0, 3.0, 4.0), PLASTER),
			_box(Vector3(0, 0.35, 0), Vector3(4.3, 0.7, 4.3), STONE),
		], {"cost": 18, "housing": 8, "defense": 2, "prestige": 1}),
		_part("mass_long_hall", "Long Hall", CATEGORY_MASS, "Wide civic or residential hall.", [
			_box(Vector3(0, 1.6, 0), Vector3(7.0, 3.2, 3.5), PLASTER),
			_box(Vector3(0, 0.35, 0), Vector3(7.3, 0.7, 3.8), STONE),
		], {"cost": 28, "housing": 12, "commerce": 2, "prestige": 2}),
		_part("mass_tall_block", "Tall Block", CATEGORY_MASS, "Vertical urban building mass.", [
			_box(Vector3(0, 2.8, 0), Vector3(3.5, 5.6, 3.5), LIGHT_STONE),
			_box(Vector3(0, 0.4, 0), Vector3(3.8, 0.8, 3.8), DARK_STONE),
		], {"cost": 30, "housing": 14, "defense": 3, "prestige": 2}),
		_part("mass_market_wing", "Market Wing", CATEGORY_MASS, "Open commercial side wing.", [
			_box(Vector3(0, 1.4, 0), Vector3(5.0, 2.8, 2.5), TIMBER),
			_box(Vector3(0, 2.55, 0), Vector3(5.3, 0.5, 2.8), PLASTER),
		], {"cost": 20, "commerce": 8, "housing": 2, "prestige": 1}),
		_part("mass_workshop", "Workshop", CATEGORY_MASS, "Industrial production volume.", [
			_box(Vector3(0, 1.6, 0), Vector3(5.5, 3.2, 4.0), DARK_STONE),
			_box(Vector3(0, 3.0, 0), Vector3(5.8, 0.35, 4.3), METAL),
		], {"cost": 27, "industry": 9, "energy": -2, "pollution": 2}),

		_part("roof_gable_red", "Red Gable Roof", CATEGORY_ROOF, "Stepped warm tiled roof.", _gable_roof(4.5, 4.5, ROOF_RED), {"cost": 8, "prestige": 2}),
		_part("roof_gable_dark", "Dark Gable Roof", CATEGORY_ROOF, "Stepped slate-like roof.", _gable_roof(4.5, 4.5, ROOF_DARK), {"cost": 9, "defense": 1, "prestige": 2}),
		_part("roof_flat_garden", "Garden Roof", CATEGORY_ROOF, "Flat planted roof platform.", [
			_box(Vector3(0, 0.12, 0), Vector3(4.5, 0.24, 4.5), DARK_STONE),
			_box(Vector3(0, 0.30, 0), Vector3(4.0, 0.18, 4.0), Color(0.30, 0.52, 0.18, 1.0)),
		], {"cost": 10, "prestige": 3, "housing": 1}),
		_part("roof_pyramid", "Pyramid Roof", CATEGORY_ROOF, "Four-sided stepped roof.", _pyramid_roof(4.2, ROOF_RED), {"cost": 10, "prestige": 3}),
		_part("roof_dome", "Voxel Dome", CATEGORY_ROOF, "Rounded ceremonial roof.", _dome(3.8, LIGHT_STONE), {"cost": 15, "prestige": 7, "defense": 1}),

		_part("tower_square", "Square Tower", CATEGORY_TOWER, "Tall defensive tower.", [
			_box(Vector3(0, 2.8, 0), Vector3(2.5, 5.6, 2.5), STONE),
			_box(Vector3(0, 5.55, 0), Vector3(2.9, 0.45, 2.9), DARK_STONE),
		], {"cost": 26, "defense": 8, "prestige": 4}),
		_part("tower_timber", "Timber Lookout", CATEGORY_TOWER, "Light wooden lookout tower.", [
			_box(Vector3(-0.75, 2.2, -0.75), Vector3(0.3, 4.4, 0.3), TIMBER),
			_box(Vector3(0.75, 2.2, -0.75), Vector3(0.3, 4.4, 0.3), TIMBER),
			_box(Vector3(-0.75, 2.2, 0.75), Vector3(0.3, 4.4, 0.3), TIMBER),
			_box(Vector3(0.75, 2.2, 0.75), Vector3(0.3, 4.4, 0.3), TIMBER),
			_box(Vector3(0, 4.4, 0), Vector3(2.4, 0.5, 2.4), TIMBER),
		], {"cost": 18, "defense": 4, "prestige": 2}),
		_part("tower_roundish", "Octagonal Tower", CATEGORY_TOWER, "Voxel approximation of a round tower.", _roundish_tower(), {"cost": 34, "defense": 9, "prestige": 6}),

		_part("opening_door_wood", "Wood Door", CATEGORY_OPENING, "Heavy wooden entrance.", [
			_box(Vector3(0, 1.0, 0), Vector3(1.25, 2.0, 0.22), TIMBER),
			_box(Vector3(0.4, 1.0, -0.13), Vector3(0.10, 0.10, 0.10), ACCENT),
		], {"cost": 2, "housing": 1}),
		_part("opening_gate", "City Gate", CATEGORY_OPENING, "Large reinforced gateway.", [
			_box(Vector3(-1.15, 1.7, 0), Vector3(0.45, 3.4, 0.5), STONE),
			_box(Vector3(1.15, 1.7, 0), Vector3(0.45, 3.4, 0.5), STONE),
			_box(Vector3(0, 3.2, 0), Vector3(2.7, 0.5, 0.5), STONE),
		], {"cost": 12, "defense": 5, "prestige": 2}),
		_part("opening_window_small", "Small Window", CATEGORY_OPENING, "Simple glass window.", [
			_box(Vector3(0, 0, 0), Vector3(0.8, 0.95, 0.16), GLASS),
			_box(Vector3(0, 0, 0.05), Vector3(0.10, 1.15, 0.22), TIMBER),
		], {"cost": 2, "housing": 1, "prestige": 1}),
		_part("opening_window_wide", "Wide Window", CATEGORY_OPENING, "Commercial glass opening.", [
			_box(Vector3(0, 0, 0), Vector3(1.8, 1.15, 0.14), GLASS),
			_box(Vector3(0, 0, 0.04), Vector3(0.10, 1.35, 0.20), METAL),
		], {"cost": 4, "commerce": 2, "prestige": 1}),

		_part("balcony_wood", "Wood Balcony", CATEGORY_BALCONY, "Projected timber balcony.", [
			_box(Vector3(0, 0, -0.65), Vector3(2.4, 0.22, 1.3), TIMBER),
			_box(Vector3(-1.05, 0.55, -1.2), Vector3(0.18, 1.1, 0.18), TIMBER),
			_box(Vector3(1.05, 0.55, -1.2), Vector3(0.18, 1.1, 0.18), TIMBER),
			_box(Vector3(0, 1.0, -1.2), Vector3(2.3, 0.16, 0.16), TIMBER),
		], {"cost": 6, "housing": 2, "prestige": 2}),
		_part("balcony_stone", "Stone Balcony", CATEGORY_BALCONY, "Heavy civic balcony.", [
			_box(Vector3(0, 0, -0.65), Vector3(2.6, 0.28, 1.3), LIGHT_STONE),
			_box(Vector3(0, 0.62, -1.2), Vector3(2.6, 0.75, 0.18), STONE),
		], {"cost": 9, "defense": 1, "prestige": 4}),

		_part("support_column_stone", "Stone Column", CATEGORY_SUPPORT, "Vertical stone support.", [
			_box(Vector3(0, 1.5, 0), Vector3(0.55, 3.0, 0.55), LIGHT_STONE),
			_box(Vector3(0, 0.12, 0), Vector3(0.8, 0.24, 0.8), STONE),
			_box(Vector3(0, 2.88, 0), Vector3(0.8, 0.24, 0.8), STONE),
		], {"cost": 4, "defense": 2, "prestige": 1}),
		_part("support_buttress", "Buttress", CATEGORY_SUPPORT, "Stepped exterior support.", [
			_box(Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.2), STONE),
			_box(Vector3(0, 1.5, 0.22), Vector3(0.75, 0.8, 0.75), STONE),
			_box(Vector3(0, 2.2, 0.42), Vector3(0.5, 0.7, 0.5), LIGHT_STONE),
		], {"cost": 5, "defense": 3}),
		_part("support_arch", "Arch", CATEGORY_SUPPORT, "Voxel arch for arcades.", _arch(), {"cost": 7, "commerce": 1, "prestige": 2}),

		_part("utility_chimney", "Chimney", CATEGORY_UTILITY, "Production chimney stack.", [
			_box(Vector3(0, 1.8, 0), Vector3(0.8, 3.6, 0.8), Color(0.42, 0.24, 0.15, 1.0)),
			_box(Vector3(0, 3.65, 0), Vector3(1.0, 0.35, 1.0), DARK_STONE),
		], {"cost": 6, "industry": 3, "pollution": 2}),
		_part("utility_water_tank", "Water Tank", CATEGORY_UTILITY, "Elevated utility tank.", [
			_box(Vector3(0, 1.0, 0), Vector3(0.25, 2.0, 0.25), METAL),
			_box(Vector3(0, 2.4, 0), Vector3(1.8, 1.2, 1.8), METAL),
		], {"cost": 8, "housing": 1, "industry": 2}),
		_part("utility_antenna", "Antenna", CATEGORY_UTILITY, "Future communication mast.", [
			_box(Vector3(0, 1.6, 0), Vector3(0.16, 3.2, 0.16), METAL),
			_box(Vector3(0, 2.8, 0), Vector3(1.2, 0.12, 0.12), ACCENT),
		], {"cost": 7, "energy": -1, "prestige": 1}),

		_part("decor_sign", "Hanging Sign", CATEGORY_DECOR, "Commercial hanging sign.", [
			_box(Vector3(0, 0.55, 0), Vector3(1.3, 0.9, 0.18), ACCENT),
			_box(Vector3(-0.72, 1.05, 0), Vector3(0.12, 0.9, 0.12), TIMBER),
		], {"cost": 2, "commerce": 2, "prestige": 1}),
		_part("decor_awning", "Market Awning", CATEGORY_DECOR, "Bright market canopy.", [
			_box(Vector3(0, 0, -0.6), Vector3(2.6, 0.16, 1.2), Color(0.72, 0.22, 0.16, 1.0)),
			_box(Vector3(-0.75, -0.12, -0.62), Vector3(0.3, 0.18, 1.25), Color(0.90, 0.72, 0.30, 1.0)),
			_box(Vector3(0.75, -0.12, -0.62), Vector3(0.3, 0.18, 1.25), Color(0.90, 0.72, 0.30, 1.0)),
		], {"cost": 3, "commerce": 3, "prestige": 1}),
		_part("decor_banner", "Banner", CATEGORY_DECOR, "Civic color banner.", [
			_box(Vector3(0, 0.8, 0), Vector3(0.75, 1.6, 0.10), Color(0.22, 0.38, 0.68, 1.0)),
			_box(Vector3(0, 1.65, 0), Vector3(1.0, 0.10, 0.10), METAL),
		], {"cost": 2, "prestige": 3}),
	]


static func _part(
	id: String,
	name: String,
	category: String,
	description: String,
	geometry: Array,
	stats: Dictionary
) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"category": category,
		"description": description,
		"geometry": geometry,
		"stats": stats,
		"default_scale": Vector3.ONE,
	}


static func _box(position: Vector3, size: Vector3, color: Color) -> Dictionary:
	return {"position": position, "size": size, "color": color}


static func _gable_roof(width: float, depth: float, color: Color) -> Array:
	var boxes: Array = []
	for level in range(5):
		var factor: float = 1.0 - float(level) * 0.17
		boxes.append(_box(
			Vector3(0, float(level) * 0.32, 0),
			Vector3(width * factor, 0.30, depth),
			color.lightened(float(level) * 0.025)
		))
	return boxes


static func _pyramid_roof(size: float, color: Color) -> Array:
	var boxes: Array = []
	for level in range(6):
		var factor: float = 1.0 - float(level) * 0.15
		boxes.append(_box(
			Vector3(0, float(level) * 0.30, 0),
			Vector3(size * factor, 0.28, size * factor),
			color.lightened(float(level) * 0.02)
		))
	return boxes


static func _dome(size: float, color: Color) -> Array:
	return [
		_box(Vector3(0, 0.15, 0), Vector3(size, 0.30, size), color),
		_box(Vector3(0, 0.50, 0), Vector3(size * 0.84, 0.40, size * 0.84), color.lightened(0.04)),
		_box(Vector3(0, 0.90, 0), Vector3(size * 0.62, 0.40, size * 0.62), color.lightened(0.08)),
		_box(Vector3(0, 1.25, 0), Vector3(size * 0.35, 0.30, size * 0.35), color.lightened(0.10)),
	]


static func _roundish_tower() -> Array:
	var boxes: Array = []
	boxes.append(_box(Vector3(0, 2.5, 0), Vector3(2.2, 5.0, 2.8), STONE))
	boxes.append(_box(Vector3(0, 2.5, 0), Vector3(2.8, 5.0, 2.2), STONE))
	boxes.append(_box(Vector3(0, 5.1, 0), Vector3(3.0, 0.35, 3.0), DARK_STONE))
	return boxes


static func _arch() -> Array:
	return [
		_box(Vector3(-1.0, 1.5, 0), Vector3(0.45, 3.0, 0.55), STONE),
		_box(Vector3(1.0, 1.5, 0), Vector3(0.45, 3.0, 0.55), STONE),
		_box(Vector3(-0.65, 2.8, 0), Vector3(0.55, 0.45, 0.55), STONE),
		_box(Vector3(0.65, 2.8, 0), Vector3(0.55, 0.45, 0.55), STONE),
		_box(Vector3(0, 3.1, 0), Vector3(0.9, 0.45, 0.55), LIGHT_STONE),
	]
