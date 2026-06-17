extends RefCounted
class_name CreaturePartLibrary


const CATEGORY_BODY: String = "body"
const CATEGORY_MOUTH: String = "mouth"
const CATEGORY_EYES: String = "eyes"
const CATEGORY_LEGS: String = "legs"
const CATEGORY_ARMS: String = "arms"
const CATEGORY_TAIL: String = "tail"
const CATEGORY_HORNS: String = "horns"
const CATEGORY_PLATES: String = "plates"
const CATEGORY_SPIKES: String = "spikes"
const CATEGORY_DECOR: String = "decor"
const CATEGORY_PAINT: String = "paint"


static func get_categories() -> Array:
	return [
		{
			"id": CATEGORY_BODY,
			"name": "Body",
			"icon": "⬢",
		},
		{
			"id": CATEGORY_MOUTH,
			"name": "Mouth",
			"icon": "▸",
		},
		{
			"id": CATEGORY_EYES,
			"name": "Eyes",
			"icon": "●",
		},
		{
			"id": CATEGORY_LEGS,
			"name": "Legs",
			"icon": "╫",
		},
		{
			"id": CATEGORY_ARMS,
			"name": "Arms",
			"icon": "╋",
		},
		{
			"id": CATEGORY_TAIL,
			"name": "Tail",
			"icon": "↝",
		},
		{
			"id": CATEGORY_HORNS,
			"name": "Horns",
			"icon": "⌃",
		},
		{
			"id": CATEGORY_PLATES,
			"name": "Plates",
			"icon": "▰",
		},
		{
			"id": CATEGORY_SPIKES,
			"name": "Spikes",
			"icon": "▲",
		},
		{
			"id": CATEGORY_DECOR,
			"name": "Decor",
			"icon": "✦",
		},
		{
			"id": CATEGORY_PAINT,
			"name": "Paint",
			"icon": "▣",
		},
	]


static func get_category_name(category_id: String) -> String:
	for category in get_categories():
		if category.get("id", "") == category_id:
			return category.get("name", category_id.capitalize())

	return category_id.capitalize()


static func get_body_parts() -> Array:
	return [
		{
			"id": "body_balanced_core",
			"name": "Balanced Core",
			"description": "Middle-sized creature body.",
			"shape": Vector3(1.35, 1.0, 2.1),
			"color": Color(0.70, 0.55, 0.38, 1.0),
			"complexity": 8,
			"stats": {
				"health": 100.0,
				"speed": 5.0,
				"jump": 6.0,
				"attack": 1.0,
				"defense": 1.0,
				"perception": 1.0,
				"grip": 0.0,
				"hunger_drain": 0.20,
			},
		},
		{
			"id": "body_long_grazer",
			"name": "Long Grazer Core",
			"description": "Long body for stable herbivores.",
			"shape": Vector3(1.15, 0.9, 2.9),
			"color": Color(0.62, 0.73, 0.38, 1.0),
			"complexity": 10,
			"stats": {
				"health": 110.0,
				"speed": 4.8,
				"jump": 5.3,
				"attack": 0.6,
				"defense": 1.1,
				"perception": 1.0,
				"grip": 0.0,
				"hunger_drain": 0.22,
			},
		},
		{
			"id": "body_heavy_shell",
			"name": "Heavy Shell",
			"description": "Wide protected body.",
			"shape": Vector3(1.75, 1.05, 2.0),
			"color": Color(0.55, 0.48, 0.35, 1.0),
			"complexity": 12,
			"stats": {
				"health": 145.0,
				"speed": 3.5,
				"jump": 4.3,
				"attack": 0.8,
				"defense": 3.0,
				"perception": 0.8,
				"grip": 0.0,
				"hunger_drain": 0.28,
			},
		},
		{
			"id": "body_insectoid",
			"name": "Insectoid Thorax",
			"description": "Segmented body for many legs.",
			"shape": Vector3(1.25, 0.85, 2.45),
			"color": Color(0.25, 0.46, 0.34, 1.0),
			"complexity": 13,
			"stats": {
				"health": 90.0,
				"speed": 5.4,
				"jump": 6.1,
				"attack": 1.1,
				"defense": 1.4,
				"perception": 1.2,
				"grip": 0.0,
				"hunger_drain": 0.24,
			},
		},
		{
			"id": "body_serpent_base",
			"name": "Serpent Base",
			"description": "Flexible stretched body.",
			"shape": Vector3(0.9, 0.75, 3.25),
			"color": Color(0.52, 0.40, 0.64, 1.0),
			"complexity": 13,
			"stats": {
				"health": 95.0,
				"speed": 5.2,
				"jump": 4.6,
				"attack": 1.3,
				"defense": 0.9,
				"perception": 1.2,
				"grip": 0.0,
				"hunger_drain": 0.21,
			},
		},
	]


static func get_paint_parts() -> Array:
	return [
		{
			"id": "paint_plain",
			"name": "Plain Skin",
			"description": "Natural base color.",
			"base_tint": Color(1.0, 1.0, 1.0, 1.0),
			"accent": Color(0.18, 0.22, 0.12, 1.0),
			"pattern": "plain",
			"complexity": 0,
		},
		{
			"id": "paint_forest_spots",
			"name": "Forest Spots",
			"description": "Green camouflage spots.",
			"base_tint": Color(0.75, 1.00, 0.70, 1.0),
			"accent": Color(0.07, 0.34, 0.11, 1.0),
			"pattern": "spots",
			"complexity": 4,
		},
		{
			"id": "paint_sand_stripes",
			"name": "Sand Stripes",
			"description": "Dry biome stripes.",
			"base_tint": Color(1.12, 0.95, 0.66, 1.0),
			"accent": Color(0.45, 0.28, 0.13, 1.0),
			"pattern": "stripes",
			"complexity": 4,
		},
		{
			"id": "paint_warning_marks",
			"name": "Warning Marks",
			"description": "Bright poisonous markings.",
			"base_tint": Color(0.92, 0.78, 0.56, 1.0),
			"accent": Color(1.0, 0.10, 0.12, 1.0),
			"pattern": "warning",
			"complexity": 6,
		},
		{
			"id": "paint_crystal_bloom",
			"name": "Crystal Bloom",
			"description": "Colorful alien plates.",
			"base_tint": Color(0.70, 0.92, 1.05, 1.0),
			"accent": Color(0.95, 0.10, 0.85, 1.0),
			"pattern": "crystal",
			"complexity": 7,
		},
	]


static func get_parts_for_category(category_id: String) -> Array:
	if category_id == CATEGORY_BODY:
		return get_body_parts()

	if category_id == CATEGORY_PAINT:
		return get_paint_parts()

	var all_parts: Array = _get_placeable_parts()
	var result: Array = []

	for part in all_parts:
		if part.get("category", "") == category_id:
			result.append(part)

	return result


static func get_part(part_id: String) -> Dictionary:
	for body_part in get_body_parts():
		if body_part.get("id", "") == part_id:
			return body_part.duplicate(true)

	for paint_part in get_paint_parts():
		if paint_part.get("id", "") == part_id:
			return paint_part.duplicate(true)

	for part in _get_placeable_parts():
		if part.get("id", "") == part_id:
			return part.duplicate(true)

	return {}


static func get_first_part_id_for_category(category_id: String) -> String:
	var parts: Array = get_parts_for_category(category_id)

	if parts.is_empty():
		return ""

	return parts[0].get("id", "")


static func get_default_body_part_id() -> String:
	return "body_balanced_core"


static func get_default_paint_id() -> String:
	return "paint_plain"


static func get_default_position(
	category_id: String,
	body_shape: Vector3
) -> Vector3:
	match category_id:
		CATEGORY_MOUTH:
			return Vector3(0.0, 0.08, -body_shape.z * 0.56)
		CATEGORY_EYES:
			return Vector3(0.34, body_shape.y * 0.35, -body_shape.z * 0.42)
		CATEGORY_LEGS:
			return Vector3(0.48, -body_shape.y * 0.56, 0.18)
		CATEGORY_ARMS:
			return Vector3(0.72, -0.05, -body_shape.z * 0.18)
		CATEGORY_TAIL:
			return Vector3(0.0, -0.05, body_shape.z * 0.58)
		CATEGORY_HORNS:
			return Vector3(0.35, body_shape.y * 0.54, -body_shape.z * 0.38)
		CATEGORY_PLATES:
			return Vector3(0.0, body_shape.y * 0.55, 0.0)
		CATEGORY_SPIKES:
			return Vector3(0.0, body_shape.y * 0.68, -body_shape.z * 0.12)
		CATEGORY_DECOR:
			return Vector3(0.0, body_shape.y * 0.56, -body_shape.z * 0.08)
		_:
			return Vector3.ZERO


static func is_default_mirrored(category_id: String) -> bool:
	return (
		category_id == CATEGORY_EYES
		or category_id == CATEGORY_LEGS
		or category_id == CATEGORY_ARMS
		or category_id == CATEGORY_HORNS
	)


static func _get_placeable_parts() -> Array:
	return [
		# Mouths
		{
			"id": "mouth_grazer",
			"name": "Grazer Mouth",
			"category": CATEGORY_MOUTH,
			"description": "Good for plant food.",
			"complexity": 5,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.3,
				"perception": 0.0,
				"hunger_drain": -0.02,
				"diet_plant": 3.0,
				"diet_meat": 0.0,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, -0.06), Vector3(0.52, 0.25, 0.28), Color(0.72, 0.48, 0.32, 1.0)),
				_voxel(Vector3(0.0, -0.09, -0.23), Vector3(0.44, 0.10, 0.18), Color(0.45, 0.24, 0.14, 1.0)),
			],
		},
		{
			"id": "mouth_broad_beak",
			"name": "Broad Beak",
			"category": CATEGORY_MOUTH,
			"description": "Simple hard beak.",
			"complexity": 6,
			"default_scale": 1.0,
			"stats": {
				"attack": 1.1,
				"perception": 0.0,
				"hunger_drain": 0.01,
				"diet_plant": 1.5,
				"diet_meat": 1.0,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, -0.12), Vector3(0.58, 0.20, 0.35), Color(0.88, 0.72, 0.34, 1.0)),
				_voxel(Vector3(0.0, -0.08, -0.30), Vector3(0.44, 0.10, 0.18), Color(0.42, 0.28, 0.16, 1.0)),
			],
		},
		{
			"id": "mouth_predator_jaws",
			"name": "Predator Jaws",
			"category": CATEGORY_MOUTH,
			"description": "Strong biting jaws.",
			"complexity": 8,
			"default_scale": 1.05,
			"stats": {
				"attack": 2.7,
				"perception": 0.0,
				"hunger_drain": 0.05,
				"diet_plant": 0.0,
				"diet_meat": 3.0,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.07, -0.10), Vector3(0.62, 0.18, 0.36), Color(0.50, 0.38, 0.34, 1.0)),
				_voxel(Vector3(0.0, -0.12, -0.12), Vector3(0.62, 0.16, 0.34), Color(0.42, 0.30, 0.25, 1.0)),
				_voxel(Vector3(-0.22, -0.02, -0.34), Vector3(0.08, 0.22, 0.10), Color(0.96, 0.92, 0.78, 1.0)),
				_voxel(Vector3(0.22, -0.02, -0.34), Vector3(0.08, 0.22, 0.10), Color(0.96, 0.92, 0.78, 1.0)),
			],
		},
		{
			"id": "mouth_filter_snout",
			"name": "Filter Snout",
			"category": CATEGORY_MOUTH,
			"description": "Long snout for shallow water feeding.",
			"complexity": 7,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.4,
				"perception": 0.2,
				"hunger_drain": -0.01,
				"diet_plant": 2.0,
				"diet_meat": 0.4,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, -0.24), Vector3(0.34, 0.22, 0.62), Color(0.54, 0.40, 0.33, 1.0)),
				_voxel(Vector3(0.0, -0.11, -0.56), Vector3(0.44, 0.10, 0.16), Color(0.30, 0.22, 0.18, 1.0)),
			],
		},

		# Eyes
		{
			"id": "eyes_beady",
			"name": "Beady Eyes",
			"category": CATEGORY_EYES,
			"description": "Cheap basic vision.",
			"complexity": 4,
			"default_scale": 1.0,
			"stats": {
				"perception": 1.0,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.0), Vector3(0.18, 0.18, 0.18), Color(0.05, 0.05, 0.05, 1.0)),
				_voxel(Vector3(0.0, 0.0, -0.05), Vector3(0.08, 0.08, 0.05), Color(0.70, 0.95, 1.0, 1.0)),
			],
		},
		{
			"id": "eyes_wide",
			"name": "Wide Watchers",
			"category": CATEGORY_EYES,
			"description": "Large expressive eyes.",
			"complexity": 6,
			"default_scale": 1.05,
			"stats": {
				"perception": 1.8,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.0), Vector3(0.28, 0.25, 0.18), Color(0.08, 0.08, 0.08, 1.0)),
				_voxel(Vector3(0.0, 0.0, -0.06), Vector3(0.14, 0.13, 0.05), Color(0.66, 0.96, 1.0, 1.0)),
			],
		},
		{
			"id": "eyes_stalks",
			"name": "Eye Stalks",
			"category": CATEGORY_EYES,
			"description": "Raised eyes for safer scanning.",
			"complexity": 9,
			"default_scale": 1.0,
			"stats": {
				"perception": 2.2,
				"defense": -0.2,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.20, 0.0), Vector3(0.08, 0.38, 0.08), Color(0.48, 0.36, 0.28, 1.0)),
				_voxel(Vector3(0.0, 0.03, -0.02), Vector3(0.24, 0.22, 0.18), Color(0.07, 0.07, 0.07, 1.0)),
				_voxel(Vector3(0.0, 0.03, -0.08), Vector3(0.11, 0.10, 0.05), Color(0.60, 0.95, 1.0, 1.0)),
			],
		},
		{
			"id": "eyes_cluster",
			"name": "Cluster Eyes",
			"category": CATEGORY_EYES,
			"description": "Multiple small sensor eyes.",
			"complexity": 10,
			"default_scale": 1.0,
			"stats": {
				"perception": 2.5,
			},
			"voxels": [
				_voxel(Vector3(-0.08, 0.06, 0.0), Vector3(0.12, 0.12, 0.12), Color(0.04, 0.04, 0.04, 1.0)),
				_voxel(Vector3(0.08, 0.06, 0.0), Vector3(0.12, 0.12, 0.12), Color(0.04, 0.04, 0.04, 1.0)),
				_voxel(Vector3(0.0, -0.08, 0.0), Vector3(0.12, 0.12, 0.12), Color(0.04, 0.04, 0.04, 1.0)),
				_voxel(Vector3(0.0, 0.02, -0.05), Vector3(0.07, 0.07, 0.04), Color(0.67, 1.0, 0.85, 1.0)),
			],
		},

		# Legs
		{
			"id": "legs_stubby",
			"name": "Stubby Legs",
			"category": CATEGORY_LEGS,
			"description": "Stable but slow.",
			"complexity": 7,
			"default_scale": 1.0,
			"stats": {
				"speed": -0.4,
				"jump": -0.5,
				"defense": 0.3,
				"hunger_drain": -0.01,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.16, 0.0), Vector3(0.22, 0.42, 0.22), Color(0.36, 0.28, 0.20, 1.0)),
				_voxel(Vector3(0.0, -0.40, -0.02), Vector3(0.34, 0.14, 0.30), Color(0.28, 0.22, 0.17, 1.0)),
			],
		},
		{
			"id": "legs_walker",
			"name": "Walker Legs",
			"category": CATEGORY_LEGS,
			"description": "Balanced movement.",
			"complexity": 8,
			"default_scale": 1.0,
			"stats": {
				"speed": 0.5,
				"jump": 0.2,
				"hunger_drain": 0.02,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.24, 0.0), Vector3(0.18, 0.62, 0.18), Color(0.42, 0.30, 0.22, 1.0)),
				_voxel(Vector3(0.0, -0.60, -0.04), Vector3(0.34, 0.14, 0.34), Color(0.30, 0.24, 0.18, 1.0)),
			],
		},
		{
			"id": "legs_sprinter",
			"name": "Sprinter Legs",
			"category": CATEGORY_LEGS,
			"description": "Fast but hungry.",
			"complexity": 10,
			"default_scale": 1.05,
			"stats": {
				"speed": 1.4,
				"jump": 0.8,
				"defense": -0.2,
				"hunger_drain": 0.05,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.30, 0.0), Vector3(0.16, 0.72, 0.16), Color(0.45, 0.31, 0.21, 1.0)),
				_voxel(Vector3(0.0, -0.72, -0.10), Vector3(0.40, 0.12, 0.44), Color(0.26, 0.20, 0.15, 1.0)),
			],
		},
		{
			"id": "legs_spider",
			"name": "Spider Legs",
			"category": CATEGORY_LEGS,
			"description": "Many-jointed side legs.",
			"complexity": 13,
			"default_scale": 1.0,
			"stats": {
				"speed": 0.9,
				"jump": 0.4,
				"grip": 1.5,
				"hunger_drain": 0.04,
			},
			"voxels": [
				_voxel(Vector3(0.08, -0.15, 0.0), Vector3(0.38, 0.14, 0.14), Color(0.18, 0.14, 0.12, 1.0)),
				_voxel(Vector3(0.28, -0.42, 0.0), Vector3(0.14, 0.52, 0.14), Color(0.16, 0.12, 0.10, 1.0)),
				_voxel(Vector3(0.36, -0.72, -0.05), Vector3(0.34, 0.11, 0.28), Color(0.10, 0.08, 0.07, 1.0)),
			],
		},
		{
			"id": "legs_hoof",
			"name": "Hoof Legs",
			"category": CATEGORY_LEGS,
			"description": "Fast steppe legs.",
			"complexity": 10,
			"default_scale": 1.0,
			"stats": {
				"speed": 1.1,
				"jump": 0.5,
				"hunger_drain": 0.03,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.28, 0.0), Vector3(0.18, 0.66, 0.18), Color(0.62, 0.47, 0.32, 1.0)),
				_voxel(Vector3(0.0, -0.68, 0.0), Vector3(0.28, 0.12, 0.26), Color(0.08, 0.07, 0.06, 1.0)),
			],
		},

		# Arms
		{
			"id": "arms_grasping",
			"name": "Grasping Arms",
			"category": CATEGORY_ARMS,
			"description": "Basic manipulation.",
			"complexity": 10,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.4,
				"grip": 2.0,
				"hunger_drain": 0.03,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.18, 0.0), Vector3(0.16, 0.54, 0.16), Color(0.44, 0.31, 0.23, 1.0)),
				_voxel(Vector3(0.0, -0.50, -0.04), Vector3(0.28, 0.16, 0.22), Color(0.35, 0.25, 0.18, 1.0)),
				_voxel(Vector3(-0.11, -0.62, -0.06), Vector3(0.08, 0.16, 0.08), Color(0.24, 0.18, 0.14, 1.0)),
				_voxel(Vector3(0.11, -0.62, -0.06), Vector3(0.08, 0.16, 0.08), Color(0.24, 0.18, 0.14, 1.0)),
			],
		},
		{
			"id": "arms_climber",
			"name": "Climber Arms",
			"category": CATEGORY_ARMS,
			"description": "Long arms with strong grip.",
			"complexity": 12,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.5,
				"grip": 3.0,
				"speed": -0.2,
				"hunger_drain": 0.04,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.28, 0.0), Vector3(0.15, 0.78, 0.15), Color(0.42, 0.30, 0.22, 1.0)),
				_voxel(Vector3(0.0, -0.74, -0.02), Vector3(0.36, 0.15, 0.26), Color(0.28, 0.20, 0.15, 1.0)),
			],
		},
		{
			"id": "arms_claws",
			"name": "Claw Arms",
			"category": CATEGORY_ARMS,
			"description": "Offensive clawed arms.",
			"complexity": 14,
			"default_scale": 1.0,
			"stats": {
				"attack": 2.0,
				"grip": 1.1,
				"hunger_drain": 0.06,
			},
			"voxels": [
				_voxel(Vector3(0.0, -0.20, 0.0), Vector3(0.17, 0.58, 0.17), Color(0.36, 0.23, 0.18, 1.0)),
				_voxel(Vector3(0.0, -0.56, -0.08), Vector3(0.28, 0.15, 0.20), Color(0.24, 0.16, 0.12, 1.0)),
				_voxel(Vector3(-0.12, -0.66, -0.18), Vector3(0.06, 0.20, 0.06), Color(0.96, 0.90, 0.76, 1.0)),
				_voxel(Vector3(0.0, -0.70, -0.20), Vector3(0.06, 0.22, 0.06), Color(0.96, 0.90, 0.76, 1.0)),
				_voxel(Vector3(0.12, -0.66, -0.18), Vector3(0.06, 0.20, 0.06), Color(0.96, 0.90, 0.76, 1.0)),
			],
		},

		# Tail
		{
			"id": "tail_balance",
			"name": "Balance Tail",
			"category": CATEGORY_TAIL,
			"description": "Helps with movement.",
			"complexity": 7,
			"default_scale": 1.0,
			"stats": {
				"speed": 0.3,
				"jump": 0.2,
				"hunger_drain": 0.01,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.18), Vector3(0.24, 0.22, 0.62), Color(0.40, 0.30, 0.22, 1.0)),
				_voxel(Vector3(0.0, -0.02, 0.60), Vector3(0.18, 0.16, 0.44), Color(0.34, 0.24, 0.18, 1.0)),
			],
		},
		{
			"id": "tail_club",
			"name": "Club Tail",
			"category": CATEGORY_TAIL,
			"description": "Heavy defensive tail.",
			"complexity": 11,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.9,
				"defense": 1.0,
				"speed": -0.3,
				"hunger_drain": 0.04,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.20), Vector3(0.22, 0.20, 0.60), Color(0.42, 0.30, 0.22, 1.0)),
				_voxel(Vector3(0.0, 0.0, 0.72), Vector3(0.50, 0.42, 0.50), Color(0.30, 0.26, 0.20, 1.0)),
			],
		},
		{
			"id": "tail_fin",
			"name": "Fin Tail",
			"category": CATEGORY_TAIL,
			"description": "Water movement helper.",
			"complexity": 10,
			"default_scale": 1.0,
			"stats": {
				"speed": 0.1,
				"swim": 2.0,
				"hunger_drain": 0.02,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.25), Vector3(0.20, 0.18, 0.60), Color(0.25, 0.45, 0.58, 1.0)),
				_voxel(Vector3(0.0, 0.14, 0.60), Vector3(0.12, 0.58, 0.42), Color(0.16, 0.62, 0.78, 1.0)),
			],
		},
		{
			"id": "tail_stinger",
			"name": "Stinger Tail",
			"category": CATEGORY_TAIL,
			"description": "Dangerous pointed tail.",
			"complexity": 13,
			"default_scale": 1.0,
			"stats": {
				"attack": 1.8,
				"defense": 0.2,
				"hunger_drain": 0.04,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.0, 0.24), Vector3(0.18, 0.18, 0.66), Color(0.36, 0.25, 0.20, 1.0)),
				_voxel(Vector3(0.0, 0.0, 0.72), Vector3(0.30, 0.30, 0.30), Color(0.20, 0.12, 0.18, 1.0)),
				_voxel(Vector3(0.0, 0.06, 0.94), Vector3(0.12, 0.20, 0.28), Color(0.94, 0.88, 0.72, 1.0)),
			],
		},

		# Horns
		{
			"id": "horns_small",
			"name": "Small Horns",
			"category": CATEGORY_HORNS,
			"description": "Small defensive horns.",
			"complexity": 6,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.7,
				"defense": 0.2,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.10, -0.02), Vector3(0.16, 0.34, 0.16), Color(0.88, 0.80, 0.58, 1.0)),
				_voxel(Vector3(0.0, 0.32, -0.05), Vector3(0.10, 0.16, 0.10), Color(0.96, 0.90, 0.72, 1.0)),
			],
		},
		{
			"id": "horns_crest",
			"name": "Crest Horns",
			"category": CATEGORY_HORNS,
			"description": "Visual display and defense.",
			"complexity": 9,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.5,
				"defense": 0.7,
				"perception": 0.2,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.06, 0.0), Vector3(0.20, 0.34, 0.14), Color(0.80, 0.65, 0.42, 1.0)),
				_voxel(Vector3(0.0, 0.26, -0.04), Vector3(0.16, 0.24, 0.12), Color(0.92, 0.78, 0.50, 1.0)),
				_voxel(Vector3(0.0, 0.42, -0.07), Vector3(0.10, 0.16, 0.08), Color(0.98, 0.90, 0.65, 1.0)),
			],
		},
		{
			"id": "horns_antlers",
			"name": "Branch Antlers",
			"category": CATEGORY_HORNS,
			"description": "Large branching display horns.",
			"complexity": 15,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.8,
				"defense": 0.5,
				"perception": 0.4,
				"speed": -0.2,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.20, 0.0), Vector3(0.12, 0.52, 0.12), Color(0.76, 0.62, 0.38, 1.0)),
				_voxel(Vector3(0.12, 0.46, -0.02), Vector3(0.30, 0.10, 0.10), Color(0.84, 0.72, 0.48, 1.0)),
				_voxel(Vector3(0.20, 0.62, -0.06), Vector3(0.10, 0.26, 0.10), Color(0.90, 0.80, 0.56, 1.0)),
			],
		},

		# Plates
		{
			"id": "plates_dorsal",
			"name": "Dorsal Plates",
			"category": CATEGORY_PLATES,
			"description": "Back armor plates.",
			"complexity": 13,
			"default_scale": 1.0,
			"stats": {
				"defense": 1.8,
				"speed": -0.3,
				"hunger_drain": 0.03,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.10, -0.40), Vector3(0.16, 0.42, 0.26), Color(0.28, 0.36, 0.32, 1.0)),
				_voxel(Vector3(0.0, 0.16, 0.0), Vector3(0.18, 0.54, 0.30), Color(0.24, 0.34, 0.30, 1.0)),
				_voxel(Vector3(0.0, 0.10, 0.42), Vector3(0.16, 0.42, 0.26), Color(0.28, 0.36, 0.32, 1.0)),
			],
		},
		{
			"id": "plates_shell",
			"name": "Shell Plates",
			"category": CATEGORY_PLATES,
			"description": "Layered shell armor.",
			"complexity": 16,
			"default_scale": 1.0,
			"stats": {
				"defense": 2.6,
				"speed": -0.6,
				"hunger_drain": 0.05,
			},
			"voxels": [
				_voxel(Vector3(-0.24, 0.06, -0.20), Vector3(0.38, 0.24, 0.44), Color(0.34, 0.32, 0.25, 1.0)),
				_voxel(Vector3(0.24, 0.06, -0.20), Vector3(0.38, 0.24, 0.44), Color(0.34, 0.32, 0.25, 1.0)),
				_voxel(Vector3(-0.24, 0.06, 0.26), Vector3(0.38, 0.24, 0.44), Color(0.30, 0.28, 0.22, 1.0)),
				_voxel(Vector3(0.24, 0.06, 0.26), Vector3(0.38, 0.24, 0.44), Color(0.30, 0.28, 0.22, 1.0)),
			],
		},

		# Spikes
		{
			"id": "spikes_back",
			"name": "Back Spikes",
			"category": CATEGORY_SPIKES,
			"description": "Simple defensive spikes.",
			"complexity": 12,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.4,
				"defense": 1.2,
			},
			"voxels": [
				_voxel(Vector3(0.0, 0.14, -0.34), Vector3(0.14, 0.34, 0.14), Color(0.90, 0.82, 0.62, 1.0)),
				_voxel(Vector3(0.0, 0.22, 0.0), Vector3(0.16, 0.46, 0.16), Color(0.94, 0.86, 0.64, 1.0)),
				_voxel(Vector3(0.0, 0.14, 0.38), Vector3(0.14, 0.34, 0.14), Color(0.90, 0.82, 0.62, 1.0)),
			],
		},
		{
			"id": "spikes_side",
			"name": "Side Spikes",
			"category": CATEGORY_SPIKES,
			"description": "Side protection.",
			"complexity": 10,
			"default_scale": 1.0,
			"stats": {
				"attack": 0.3,
				"defense": 1.0,
			},
			"voxels": [
				_voxel(Vector3(0.08, 0.02, -0.12), Vector3(0.42, 0.14, 0.14), Color(0.88, 0.80, 0.64, 1.0)),
				_voxel(Vector3(0.20, 0.02, 0.22), Vector3(0.34, 0.12, 0.12), Color(0.88, 0.80, 0.64, 1.0)),
			],
		},

		# Decor
		{
			"id": "decor_feathers",
			"name": "Feather Crest",
			"category": CATEGORY_DECOR,
			"description": "Colorful social display.",
			"complexity": 9,
			"default_scale": 1.0,
			"stats": {
				"perception": 0.3,
				"defense": -0.1,
			},
			"voxels": [
				_voxel(Vector3(-0.16, 0.16, 0.0), Vector3(0.10, 0.46, 0.10), Color(0.95, 0.20, 0.45, 1.0)),
				_voxel(Vector3(0.0, 0.22, -0.02), Vector3(0.10, 0.54, 0.10), Color(0.10, 0.85, 0.80, 1.0)),
				_voxel(Vector3(0.16, 0.16, 0.0), Vector3(0.10, 0.46, 0.10), Color(0.24, 0.40, 1.0, 1.0)),
			],
		},
		{
			"id": "decor_crystals",
			"name": "Crystal Growths",
			"category": CATEGORY_DECOR,
			"description": "Bright alien decoration.",
			"complexity": 12,
			"default_scale": 1.0,
			"stats": {
				"defense": 0.2,
				"perception": 0.2,
			},
			"voxels": [
				_voxel(Vector3(-0.16, 0.10, 0.0), Vector3(0.18, 0.36, 0.18), Color(0.05, 0.95, 1.0, 1.0)),
				_voxel(Vector3(0.12, 0.18, -0.05), Vector3(0.20, 0.48, 0.20), Color(0.94, 0.18, 1.0, 1.0)),
				_voxel(Vector3(0.0, 0.02, 0.16), Vector3(0.15, 0.30, 0.15), Color(0.20, 0.48, 1.0, 1.0)),
			],
		},
	]


static func _voxel(
	local_position: Vector3,
	size: Vector3,
	color: Color
) -> Dictionary:
	return {
		"position": local_position,
		"size": size,
		"color": color,
	}
