extends RefCounted
## A fresh, read-only view of one canonical village member. No saved UI state,
## copied ledger, speculative equipment, or retained member/actor reference.
const Economy = preload("res://world/tribe/village_economy.gd")

static func snapshot(data: Dictionary, selected: Array, actors: Dictionary = {}) -> Dictionary:
	if selected.size() != 1 or not selected[0] is String:
		return {}
	var member: Dictionary = {}
	for candidate: Dictionary in data.get("members", []):
		if candidate.get("id") == selected[0]:
			if not member.is_empty(): return {} # Ambiguous identity is not a detail target.
			member = candidate
	if member.is_empty(): return {}
	var workplace_id: String = str(member.get("workplace_id", ""))
	var workplace_key: String = Economy.station_key(data, workplace_id)
	return {"id": str(member.id), "name": str(member.name),
		"profession": str(member.profession), "order": str(member.order),
		"stage": str(member.stage), "blocked": bool(member.blocked),
		"food": float(member.hunger), "water": float(member.hydration),
		"cargo": str(member.cargo), "construction_id": str(member.get("construction_id", "")),
		"workplace_id": workplace_id, "workplace_key": workplace_key,
		"workplace_kind": Economy.station_kind(workplace_key),
		"health_percent": _health(actors.get(member.id), str(member.id)),
		# The village schema has no personal inventory contract. In particular,
		# data.tools/stock and unknown extra member keys prove no personal ownership.
		"personal_equipment_available": false}

static func _health(actor: Variant, identity: String) -> Variant:
	if not is_instance_valid(actor) or not actor is Node or actor.is_queued_for_deletion(): return null
	var properties: Dictionary = {}
	for field: Dictionary in actor.get_property_list(): properties[field.name] = true
	if properties.has("member_id") and actor.get("member_id") != identity: return null
	if not properties.has("current_health") or not properties.has("maximum_health"): return null
	var current: Variant = actor.get("current_health")
	var maximum: Variant = actor.get("maximum_health")
	if not (current is float or current is int) or not (maximum is float or maximum is int): return null
	if not is_finite(float(current)) or not is_finite(float(maximum)) or float(maximum) <= 0: return null
	# Health is a loaded-actor observation. Companion health currently has no
	# persisted village field; absence of an actor must not become a fabricated 100%.
	return clampf(float(current) / float(maximum) * 100.0, 0.0, 100.0)
