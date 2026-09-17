extends RefCounted
## Visual wing families. Flight needs its own movement contract.
const REVISION: int = 1
const DEFINITIONS: Array = [
	{"id": "wings_broad_feather", "name": "Breiter Federflügel", "description": "Gerundete Schwingen mit breitem Federfächer und sichtbaren Federlagen.", "features": ["rounded_fan", "layered_feathers"]},
	{"id": "wings_slender_feather", "name": "Schmaler Federflügel", "description": "Lange, schmale Schwingen mit zurückgezogenen Schwungfedern.", "features": ["long_span", "swept_feathers"]},
	{"id": "wings_bat_membrane", "name": "Fledermausflügel", "description": "Ausgespannte Haut zwischen vier sichtbaren Trägern mit gebuchtetem Rand.", "features": ["finger_struts", "scalloped_membrane"]},
	{"id": "wings_long_insect", "name": "Langer Insektenflügel", "description": "Schmale, gerundete Flügelfläche mit verzweigten Adern und hellem Saum.", "features": ["rounded_blade", "branching_veins"]},
]

static func get_profile(id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id != id: continue
		var result: Dictionary = entry.duplicate(true)
		result.merge({"category": "wings", "revision": REVISION, "geometry_id": id, "geometry_revision": REVISION,
			"attachment": "upper_side", "forward": "+X", "default_mirrored": true,
			"stats_source": "decor_feathers", "unlock_source": "decor_feathers", "capabilities": [], "supported_actions": []})
		return result
	return {}

static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
