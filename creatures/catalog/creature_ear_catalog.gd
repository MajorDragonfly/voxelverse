extends RefCounted
## Model identities and existing gameplay source. Shapes do not grant new movement/senses.
const REVISION: int = 1
const DEFINITIONS: Array = [
  {
    "id": "ears_cat_pointed",
    "name": "Spitzes Katzenohr",
    "description": "Spitzes, leicht nach außen gestelltes Ohr mit sichtbarer Innenmuschel.",
    "layout": "ear"
  },
  {
    "id": "ears_bear_round",
    "name": "Rundes Bärenohr",
    "description": "Kompaktes, rundes Ohr mit breitem Rand und vertiefter Innenfläche.",
    "layout": "ear"
  },
  {
    "id": "ears_rabbit_long",
    "name": "Langes Hasenohr",
    "description": "Lange, schmale Ohrmuschel mit abgerundeter Spitze.",
    "layout": "ear"
  },
  {
    "id": "ears_dog_floppy",
    "name": "Hängendes Hundeohr",
    "description": "Weiches, nach außen gewölbtes Hängeohr mit rundem Ende.",
    "layout": "ear"
  },
  {
    "id": "ears_elephant_broad",
    "name": "Breites Elefantenohr",
    "description": "Breite, fächerförmige Ohrmuschel mit gewelltem Außenrand.",
    "layout": "ear"
  },
  {
    "id": "ears_bat_large",
    "name": "Großes Fledermausohr",
    "description": "Hohe, weit geöffnete Ohrmuschel mit spitzer Kontur und breitem Innenraum.",
    "layout": "ear"
  }
]

static func get_profile(id: String, revision: int = REVISION) -> Dictionary:
	if revision != REVISION: return {}
	for entry: Dictionary in DEFINITIONS:
		if entry.id != id: continue
		var result: Dictionary = entry.duplicate(true)
		result.merge({"category": "ears", "revision": REVISION, "geometry_id": id, "geometry_revision": REVISION,
			"attachment": entry.layout, "forward": "+X" if entry.layout == "side" else "+Y",
			"default_mirrored": entry.layout != "dorsal", "stats_source": "decor_feathers", "unlock_source": "decor_feathers",
			"capabilities": [], "supported_actions": [], "features": [entry.layout, "inner_cup"]})
		return result
	return {}

static func get_parts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in DEFINITIONS: result.append(get_profile(entry.id))
	return result
