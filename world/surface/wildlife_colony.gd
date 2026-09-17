extends RefCounted
## Additive, deterministic families. The original resident and its frozen body,
## encounter/needs records and location are never replaced during an upgrade.
const Ids = preload("res://core/campaign/campaign_ids.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Encoding = preload("res://world/fauna/domestication/domestication_contract.gd")
const MAX_MEMBERS: int = 4

static func ensure(host: Node, region: Dictionary, original: Dictionary) -> void:
	if region.has("colony") or original.is_empty() or original.has("catalog_species_id"): return
	var anchor: Dictionary = original.get("home", original.location).duplicate(true)
	var colony_id: String = Ids.scoped("group", host.descriptor.id, region.key + ":nest")
	var members: Array = [original.id]
	var count: int = 3 + posmod(int(original.individual_seed), 2)
	for index in range(1, count):
		var id: String = Ids.scoped("object", colony_id, str(index))
		# Indexed lookup includes residents that have crossed the region border.
		if not host.storage.record(id).is_empty():
			members.append(id)
			continue
		var angle: float = index * TAU / count + float(posmod(original.individual_seed, 17))
		var frame: Basis = host.adapter.frame_at(anchor)
		var point: Dictionary = host.adapter.offset(anchor, (frame.x * cos(angle) + frame.z * sin(angle)) * 3.8)
		point.height = host.adapter.sample(point).height
		point.radius = host.descriptor.radius
		if not Planner.dry(host.adapter.terrain.surface, point): continue
		var resident: Dictionary = original.duplicate(true)
		# An old resident's injuries, friendships or meals belong only to it.
		for field in ["encounter", "foraging", "drinking"]: resident.erase(field)
		resident.id = id
		resident.identity.object_id = id
		resident.individual_seed = int(id.sha256_text().left(7).hex_to_int())
		resident.location = point
		resident.home = anchor.duplicate(true)
		resident.colony_id = colony_id
		if not host.storage.put(resident): return
		members.append(id)
	# Commit marker last: partial storage failures are retryable by stable ID.
	original.colony_id = colony_id
	var design: Dictionary = Encoding.decode(original.blueprint)
	region.colony = {"schema": 1, "id": colony_id, "anchor": anchor,
		"species_id": original.identity.species_id, "members": members,
		"name": str(design.get("species", {}).get("display_name", design.get("name", ""))),
		"seed": int(original.species_seed), "role": original.role}

static func problem(value: Variant, body: Dictionary) -> String:
	if not value is Dictionary or value.get("schema") != 1: return "Ungültige Nestversion."
	if not value.get("id") is String or value.id.is_empty() or not value.get("species_id") is String or value.species_id.is_empty(): return "Ungültige Nestidentität."
	if not preload("res://world/home_group/home_group_state.gd").place_valid(value.get("anchor"), preload("res://world/space/cube_sphere.gd").MODE, body.id) or value.anchor.radius != body.radius: return "Ungültiger Neststandort."
	if not value.get("members") is Array or value.members.is_empty() or value.members.size() > MAX_MEMBERS: return "Ungültige Nestbewohner."
	var seen: Dictionary = {}
	for id: Variant in value.members:
		if not id is String or id.is_empty() or seen.has(id): return "Doppelte Nestbewohner."
		seen[id] = true
	if not value.get("name") is String or not value.get("seed") is int and not value.get("seed") is float or value.get("role") not in ["grazer", "predator", "scavenger"]: return "Ungültige Nestbeschreibung."
	return ""
