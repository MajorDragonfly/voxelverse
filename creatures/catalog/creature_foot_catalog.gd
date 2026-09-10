extends RefCounted
## Anatomical metadata only. Geometry, live sole contact and D1 roles have
## separate owners. Revision 1 is the shipped shape; no save schema changes.
const REVISION: int = 1
const DEFINITIONS: Array = [
	{"id": "feet_pads", "name": "Ballenfüße", "domestic_support": true},
	{"id": "feet_claws", "name": "Krallenfüße", "domestic_support": false},
	{"id": "feet_hooves", "name": "Spalthufe", "domestic_support": true},
	{"id": "feet_webbed", "name": "Schwimmfüße", "domestic_support": false},
]


static func get_profile(part_id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id != part_id: continue
		var capabilities: Array[String] = ["ground_contact"]
		if entry.domestic_support: capabilities.append("domestic_support")
		return {"id": part_id, "name": entry.name, "category": "feet",
			"description": "Am passenden Bein oder Arm befestigen. Größe und Drehung separat einstellen.",
			"complexity": 2, "default_scale": 1.0, "stats": {},
			"revision": REVISION, "geometry_id": part_id, "geometry_revision": REVISION,
			"attachment": "leg_end", "capabilities": capabilities,
			# These existing actions require an attached leg and its locomotion rig.
			# Webbing is a shape, never permission to swim, fly or climb.
			"supported_limb_actions": ["walk", "run"],
			"contact": {"method": "rendered_bounds", "marker": "RuntimeFootContact"}}
	return {}


static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS:
		result.append(get_profile(entry.id))
	return result


static func supports(part_id: String, capability: String, revision: int = REVISION) -> bool:
	return capability in get_profile(part_id, revision).get("capabilities", [])
