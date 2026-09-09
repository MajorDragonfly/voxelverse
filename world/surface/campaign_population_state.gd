extends RefCounted
## Regional placement and frozen bodies. Health, friendship, needs and ownership
## remain in their existing campaign services, keyed by the same object IDs.
const Cube = preload("res://world/space/cube_sphere.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Values = preload("res://world/fauna/domestication/domestication_contract.gd")
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Cells = preload("res://world/surface/surface_population_job.gd")
const SCHEMA: int = 1
const PAGED_SCHEMA: int = 2
const MAX_REGIONS: int = 32768
const MAX_OBJECTS_PER_REGION: int = 128

static func create(body_id: String) -> Dictionary:
	return {"schema": SCHEMA, "body_id": body_id, "regions": {}}

static func cell(body: Dictionary, point: Dictionary) -> Dictionary:
	var level: int = Cells.level_for(float(body.radius))
	var count: int = 1 << level
	var step: float = 2.0 / count
	var x: int = clampi(floori((point.u + 1.0) / step), 0, count - 1)
	var y: int = clampi(floori((point.v + 1.0) / step), 0, count - 1)
	return {"id": "%s:land1:%d:%d:%d:%d" % [body.id, level, int(point.face), x, y],
		"level": level, "face": int(point.face), "x": x, "y": y, "step": step}

static func ensure_region(data: Dictionary, key: String) -> Dictionary:
	if not data.regions.has(key):
		if data.regions.size() >= MAX_REGIONS: return {}
		data.regions[key] = {"schema": 1, "key": key, "objects": {}, "plants": {}, "generated": false}
	return data.regions[key]

static func put(data: Dictionary, body: Dictionary, record: Dictionary, plant: bool = false) -> bool:
	var region: Dictionary = ensure_region(data, cell(body, record.location).id)
	if region.is_empty(): return false
	var collection: Dictionary = region.plants if plant else region.objects
	if not collection.has(record.id) and collection.size() >= MAX_OBJECTS_PER_REGION: return false
	collection[record.id] = record
	return true

static func validate(value: Variant, body: Dictionary) -> String:
	if value is Dictionary and value.get("schema") == PAGED_SCHEMA:
		if value.get("body_id") != body.id: return "Körperfremder Regionsspeicher."
		return preload("res://core/persistence/region_store.gd").manifest_problem(value.get("storage"))
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("body_id") != body.id or not value.get("regions") is Dictionary or value.regions.size() > MAX_REGIONS:
		return "Ungültiger regionaler Kugelbestand."
	var seen: Dictionary = {}
	for key in value.regions:
		var region: Variant = value.regions[key]
		if not region is Dictionary or region.get("schema") != 1 or region.get("key") != key or not region.get("generated") is bool: return "Ungültige Kugelregion."
		for section in ["objects", "plants"]:
			if not region.get(section) is Dictionary or region[section].size() > MAX_OBJECTS_PER_REGION: return "Kugelregion überschreitet ihr Objektbudget."
			for id in region[section]:
				var entry: Variant = region[section][id]
				if not entry is Dictionary or entry.get("id") != id or seen.has(id) or not Home.place_valid(entry.get("location"), Cube.MODE, body.id) or entry.location.radius != body.radius:
					return "Ungültiges, doppeltes oder körperfremdes Oberflächenobjekt."
				seen[id] = true
				if section == "plants":
					if not entry.get("food_key") is String or entry.food_key.is_empty(): return "Nahrungsquelle ohne stabile Identität."
					continue
				var identity: Variant = entry.get("identity")
				if not identity is Dictionary or identity.get("object_id") != id or identity.get("body_id") != body.id or not identity.get("species_id") is String or identity.species_id.is_empty() or not identity.get("region_id") is String or identity.region_id.is_empty(): return "Ungültige Individuenidentität."
				if not Values.integer(entry.get("species_seed"), 1, 9007199254740991) or not Values.integer(entry.get("individual_seed"), 0, 2147483647): return "Ungültiger Individuenseed."
				if entry.get("role") not in ["grazer", "forager", "climber", "predator", "scavenger", "swimmer"] or not entry.get("blueprint") is Dictionary or not Catalog.snapshot_value(entry.blueprint): return "Ungültiger eingefrorener Tierkörper."
	return ""

static func validate_region(region: Dictionary, body: Dictionary) -> String:
	var envelope: Dictionary = create(body.id)
	envelope.regions[region.get("key", "")] = region
	return validate(envelope, body)
