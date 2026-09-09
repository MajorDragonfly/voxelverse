extends RefCounted
## Map scale is presentation only; it never unlocks or changes a phase.
const PROFILES := [
	{"name": "Umgebung", "radius_m": 64.0},
	{"name": "Stammesgebiet", "radius_m": 160.0},
	{"name": "Region", "radius_m": 640.0},
	{"name": "Land", "radius_m": 2560.0},
	{"name": "Planetenoberfläche", "radius_m": 12800.0},
]
const ZOOMS := [0.5, 1.0, 2.0]

static func for_phase(phase: int, zoom_index: int = 1, body_radius: float = 0.0) -> Dictionary:
	var result: Dictionary = PROFILES[clampi(phase, 0, PROFILES.size() - 1)].duplicate()
	result["radius_m"] *= ZOOMS[clampi(zoom_index, 0, ZOOMS.size() - 1)]
	# A local sphere chart must not wrap through the antipode on test planets.
	if body_radius > 0.0:
		result["radius_m"] = minf(result["radius_m"], body_radius * 0.65)
	return result

static func distance_text(meters: float) -> String:
	return "%d m" % roundi(meters) if meters < 1000.0 else "%.1f km" % (meters / 1000.0)
