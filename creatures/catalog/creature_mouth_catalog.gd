extends RefCounted
## Shared mouth/head model provider. Legacy identities and species stay frozen.
const REVISION: int = 1
const LEGACY_IDS: Array[String] = ["mouth_grazer", "mouth_broad_beak", "mouth_predator_jaws", "mouth_filter_snout"]
const DEFINITIONS: Array = [
	{"id": "mouth_canine_snout", "name": "Hundeschnauze",
		"description": "Spitze Schnauze mit Nasenspiegel und Fangzähnen. Werte und Freischaltung wie Raubkiefer.",
		"features": ["tapered_muzzle", "nose", "canines"]},
	{"id": "mouth_crocodile_snout", "name": "Krokodilschnauze",
		"description": "Lange, flache Schnauze mit zwei Zahnreihen. Werte und Freischaltung wie Raubkiefer.",
		"features": ["flat_snout", "nostrils", "upper_teeth", "lower_teeth"]},
	{"id": "mouth_octopus_beak", "name": "Oktopusmund",
		"description": "Runde Mundöffnung mit innenliegendem Schnabel. Werte und Freischaltung wie Raubkiefer.",
		"features": ["oral_ring", "mouth_cavity", "inner_beak"]},
	{"id": "head_elephant_trunk", "name": "Elefantenrüssel",
		"description": "Gebogener Rüssel über dem separat wählbaren Mund. Freischaltung mit der Filterschnauze; reines Gestaltungsteil.",
		"category": "head", "stats_source": "", "stats": {},
		"complexity": 9, "default_scale": 1.0,
		"unlock_source": "mouth_filter_snout",
		"features": ["tapered_trunk", "curled_tip", "nostrils", "separate_mouth"]},
]


static func get_profile(part_id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id == part_id:
			var result: Dictionary = entry.duplicate(true)
			result.merge({"category": "mouth", "revision": REVISION,
				"geometry_id": part_id, "geometry_revision": REVISION,
				"stats_source": "mouth_predator_jaws", "unlock_source": "mouth_predator_jaws",
				"attachment": "body_surface", "forward": "-Z",
				"capabilities": [], "supported_actions": []})
			return result
	return {}


static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
