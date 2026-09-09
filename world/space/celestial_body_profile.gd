extends RefCounted
class_name CelestialBodyProfile

## One versioned source for catalog and live terrain. The sphere is a new
## surface model, never an implicit migration of a legacy plane.
const TerrainProfile = preload("res://world/generation/planet_profile_v9.gd")
const VERSION: int = 1
const SPHERE_VERSION: String = "cube_sphere_m1_v1"


static func terrain_profile(seed_value: int) -> Dictionary:
	return TerrainProfile.create(clampi(seed_value, 1, 2_147_483_647))


static func create(id: String, kind: String, seed_value: int, radius: float,
		parent_id: String = "", surface_mode: String = SPHERE_VERSION) -> Dictionary:
	return {"schema": VERSION, "id": id, "kind": kind, "parent_id": parent_id,
		"seed": seed_value, "generator_version": "planetary_v9", "surface_mode": surface_mode,
		"radius": radius, "gravity": 12.0, "rotation_period": 240.0, "axial_tilt": 0.2,
		"orbit_radius": 0.0, "orbit_period": 600.0, "orbit_phase": 0.0,
		"atmosphere": "temperate" if kind == "planet" else "none"}
