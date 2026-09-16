extends RefCounted
## Authored tail identities. New silhouettes reuse existing earned profiles.
const REVISION: int = 1
const LEGACY_IDS: Array[String] = ["tail_balance", "tail_club", "tail_fin", "tail_stinger"]
const DEFINITIONS: Array = [
	{"id": "tail_stump", "name": "Stummelschwanz",
		"description": "Kurzer, runder Schwanz. Werte und Freischaltung wie Balanceschwanz.",
		"stats_source": "tail_balance", "features": ["short_root", "rounded_tip"]},
	{"id": "tail_reptile", "name": "Reptilienschwanz",
		"description": "Kräftiger Ansatz mit langem, gebogenem Ende und Rückenschuppen. Werte und Freischaltung wie Balanceschwanz.",
		"stats_source": "tail_balance", "features": ["thick_root", "tapered_curve", "dorsal_scales"]},
	{"id": "tail_beaver_paddle", "name": "Biberpaddel",
		"description": "Breiter, flacher Paddelschwanz mit Schuppen. Werte und Freischaltung wie Flossenschwanz.",
		"stats_source": "tail_fin", "features": ["narrow_root", "flat_paddle", "surface_scales"]},
	{"id": "tail_horizontal_fluke", "name": "Horizontale Schwanzflosse",
		"description": "Zwei seitliche Flossenlappen mit schmalem Ansatz. Werte und Freischaltung wie Flossenschwanz.",
		"stats_source": "tail_fin", "features": ["narrow_root", "paired_lobes", "central_notch"]},
]


static func get_profile(part_id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	var result: Dictionary = {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id == part_id:
			result = entry.duplicate(true)
			result["unlock_source"] = result.stats_source
			break
	if result.is_empty() and part_id not in LEGACY_IDS: return {}
	result.merge({"id": part_id, "category": "tail", "revision": REVISION,
		"geometry_id": part_id, "geometry_revision": REVISION,
		"attachment": "body_surface", "forward": "+Z",
		"capabilities": [], "supported_actions": []})
	return result


static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
