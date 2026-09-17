extends RefCounted
## Model identities and existing gameplay source. Shapes do not grant new movement/senses.
const REVISION: int = 1
const DEFINITIONS: Array = [
  {
    "id": "fins_broad_paddle",
    "name": "Breite Paddelflosse",
    "description": "Breite, abgerundete Seitenflosse mit kräftigem Ansatz und feinen Flossenstrahlen.",
    "layout": "side"
  },
  {
    "id": "fins_slender_steering",
    "name": "Schmale Steuerflosse",
    "description": "Lange, nach hinten gezogene Seitenflosse mit schmal zulaufender Spitze.",
    "layout": "side"
  },
  {
    "id": "fins_round_side",
    "name": "Kleine Rundflosse",
    "description": "Kompakte, fächerförmige Seitenflosse mit rundem Rand.",
    "layout": "side"
  },
  {
    "id": "fins_tall_dorsal",
    "name": "Hohe Rückenflosse",
    "description": "Hohe dreieckige Rückenflosse mit breitem Ansatz und sichtbaren Stützstrahlen.",
    "layout": "dorsal"
  },
  {
    "id": "fins_long_fringe",
    "name": "Langer Flossensaum",
    "description": "Flacher, langgezogener Flossensaum mit weicher Wellenkontur.",
    "layout": "dorsal"
  },
  {
    "id": "fins_small_stabilizer",
    "name": "Kleine Stabilisatorflosse",
    "description": "Kurze, nach hinten geneigte Flosse für Rücken- oder Bauchplatzierung.",
    "layout": "dorsal"
  }
]

static func get_profile(id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id != id: continue
		var result: Dictionary = entry.duplicate(true)
		result.merge({"category": "fins", "revision": REVISION, "geometry_id": id, "geometry_revision": REVISION,
			"attachment": entry.layout, "forward": "+X" if entry.layout == "side" else "+Y",
			"default_mirrored": entry.layout != "dorsal", "stats_source": "tail_fin", "unlock_source": "tail_fin",
			"capabilities": [], "supported_actions": [], "features": [entry.layout, "fin_rays"]})
		return result
	return {}

static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
