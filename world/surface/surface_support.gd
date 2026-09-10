extends RefCounted
## Read-only admission for the existing adaptive terrain, not a catalog filter.
## Limits do not alter stored radii, seeds, IDs or terrain generations.
const Cube = preload("res://world/space/cube_sphere.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const SCHEMA: int = 1
const MIN_TEST_RADIUS: float = 64.0
const MIN_CAMPAIGN_RADIUS: float = 50000.0
const MAX_RADIUS: float = 100000000.0
const MAX_GROUND_CELL_METERS: float = 4.0

static func radius_support(value: Variant, campaign: bool = false) -> Dictionary:
	if not (value is int or value is float) or not is_finite(float(value)):
		return failure("invalid_radius")
	var radius: float = float(value)
	var minimum: float = MIN_CAMPAIGN_RADIUS if campaign else MIN_TEST_RADIUS
	if radius < minimum: return failure("radius_too_small", {"minimum_m": minimum, "radius_m": radius})
	if radius > MAX_RADIUS: return failure("radius_too_large", {"maximum_m": MAX_RADIUS, "radius_m": radius})
	var layout := Layout.new(radius)
	var cell: float = cell_width(2.0 / (1 << layout.max_level), radius)
	if cell > MAX_GROUND_CELL_METERS:
		return failure("ground_resolution_unavailable", {"cell_m": cell, "max_level": Layout.MAX_LEVEL})
	return {"ok": true, "code": "supported", "schema": SCHEMA, "parameters": {},
		"surface_class": "campaign" if radius >= MIN_CAMPAIGN_RADIUS else "test",
		"radius_m": radius, "lod_level": layout.max_level, "max_lod_level": Layout.MAX_LEVEL,
		"finest_cell_m": cell, "ground_cell_limit_m": MAX_GROUND_CELL_METERS}

static func inspect(body: Dictionary, campaign: bool = false) -> Dictionary:
	if body.get("kind") not in ["planet", "moon"]: return failure("catalog_only")
	if body.get("schema") != 1 or body.get("surface_mode") != Cube.MODE or body.get("generator_version") != "planetary_v9":
		return failure("unsupported_surface_version")
	if not body.get("id") is String or body.id.is_empty(): return failure("invalid_body_identity")
	var seed_value: Variant = body.get("seed")
	if not (seed_value is int or seed_value is float) or not is_finite(float(seed_value)) or float(seed_value) != floor(float(seed_value)) or seed_value < 1 or seed_value > 2147483647:
		return failure("invalid_body_identity")
	var generation: Variant = body.get("surface_generation", "")
	var revision: Variant = body.get("terrain_revision", 1)
	if not ((generation == "" and revision in [1, 2, 3]) or
			(generation == "living_planet_v1" and revision == 3) or
			(generation == "living_planet_v2" and revision == 4)):
		return failure("unsupported_surface_version")
	return radius_support(body.get("radius"), campaign)

static func cell_width(uv_width: float, radius: float) -> float:
	return uv_width * radius / Patch.CELLS

static func failure(code: String, parameters: Dictionary = {}) -> Dictionary:
	return {"ok": false, "code": code, "schema": SCHEMA, "parameters": parameters}

static func error_text(result: Dictionary) -> String:
	if result.ok: return ""
	match result.code:
		"radius_too_large": return "Dieser Körper ist für die derzeitige Bodenkollision zu groß; seine Daten bleiben unverändert."
		"radius_too_small": return "Dieser Körper ist für diese Spieloberfläche zu klein; sein Radius bleibt unverändert."
		"invalid_radius": return "Der Planetenradius ist ungültig."
		"catalog_only": return "Dieser Himmelskörper kann angezeigt, aber nicht betreten werden."
		"ground_resolution_unavailable": return "Die benötigte Bodenkollision ist für diesen Planeten nicht verfügbar."
		_: return "Unbekannter Oberflächenvertrag; Spielstand bleibt geschützt."
