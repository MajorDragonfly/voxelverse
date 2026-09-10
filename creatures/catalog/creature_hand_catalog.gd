extends RefCounted
## Hand identity and anatomy, separate from geometry and gameplay systems.
const REVISION: int = 1
const DEFINITIONS: Array = [
	{"id": "hands_grasp", "name": "Greifhände", "features": ["palm", "fingers", "thumb"]},
	{"id": "hands_claws", "name": "Krallenhände", "features": ["palm", "fingers", "thumb", "claws"]},
	{"id": "hands_pincers", "name": "Scherenhände", "features": ["palm", "pincers"]},
	{"id": "hands_crab_claws", "name": "Krebsscheren", "features": ["carapace", "fixed_finger", "opposing_finger", "teeth"]},
]


static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS:
		# Keep the existing catalog definition fields and values unchanged.
		result.append({"id": entry.id, "name": entry.name, "category": "hands",
			"description": "Am passenden Bein oder Arm befestigen. Größe und Drehung separat einstellen.",
			"complexity": 2, "default_scale": 1.0, "stats": {}})
	return result


static func get_profile(part_id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id == part_id:
			return {"id": part_id, "name": entry.name, "category": "hands",
				"revision": REVISION, "geometry_id": part_id, "geometry_revision": REVISION,
				"attachment": "arm_end", "features": entry.features.duplicate(),
				# Anatomy does not grant grip, attacks, climbing or supporting feet.
				"capabilities": [], "supported_limb_actions": []}
	return {}
