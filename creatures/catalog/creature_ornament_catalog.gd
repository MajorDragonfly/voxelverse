extends RefCounted
## Independent antler and crest model families using existing earned profiles.
const REVISION: int = 1
const DEFINITIONS: Array = [
	{"id": "horns_stag_antlers", "name": "Hirschgeweih", "description": "Verzweigte Geweihstange mit mehreren nach oben gerichteten Sprossen. Werte und Freischaltung wie Geweih.", "stats_source": "horns_antlers", "unlock_source": "horns_antlers", "category": "horns", "attachment": "upper_front", "default_mirrored": true},
	{"id": "horns_moose_antlers", "name": "Schaufelgeweih", "description": "Breite Geweihschaufel mit abgesetzten Randspitzen. Werte und Freischaltung wie Geweih.", "stats_source": "horns_antlers", "unlock_source": "horns_antlers", "category": "horns", "attachment": "upper_front", "default_mirrored": true},
	{"id": "decor_low_crest", "name": "Flacher Rückenkamm", "description": "Niedriger durchgehender Kamm entlang des Rückens. Werte und Freischaltung wie Federkamm.", "stats_source": "decor_feathers", "unlock_source": "decor_feathers", "category": "decor", "attachment": "upper_spine", "default_mirrored": false},
	{"id": "decor_saw_crest", "name": "Gezackter Rückenkamm", "description": "Hoher Rückenkamm mit vier deutlich getrennten Zacken. Werte und Freischaltung wie Federkamm.", "stats_source": "decor_feathers", "unlock_source": "decor_feathers", "category": "decor", "attachment": "upper_spine", "default_mirrored": false},
	{"id": "decor_head_crest", "name": "Kopfkamm", "description": "Kompakter nach hinten auslaufender Kamm auf dem Kopf. Werte und Freischaltung wie Federkamm.", "stats_source": "decor_feathers", "unlock_source": "decor_feathers", "category": "decor", "attachment": "upper_front", "default_mirrored": false},
	{"id": "decor_frill", "name": "Nackenschild", "description": "Breiter fächerförmiger Nackenschild mit kräftigem Mittelansatz. Werte und Freischaltung wie Federkamm.", "stats_source": "decor_feathers", "unlock_source": "decor_feathers", "category": "decor", "attachment": "neck", "default_mirrored": false},
]

static func get_profile(id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id != id: continue
		var result: Dictionary = entry.duplicate(true)
		result.merge({"revision": 1, "geometry_id": id, "geometry_revision": 1,
			"capabilities": [], "supported_actions": []})
		return result
	return {}

static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
