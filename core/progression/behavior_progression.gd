extends RefCounted
class_name BehaviorProgression

const Catalog = preload("res://core/progression/behavior_catalog.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const SCHEMA: int = 1

var _state: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	_state = {"schema": SCHEMA, "rules_version": Catalog.RULES_VERSION,
		"phases": {}, "purchased_nodes": {}}
	for phase in range(Catalog.PHASE_COUNT):
		_state["phases"][str(phase)] = {"earned": {"social": 0, "aggression": 0},
			"spent": {"social": 0, "aggression": 0}, "rewards": {}}


func export_state() -> Dictionary:
	return _state.duplicate(true)


func import_state(value: Dictionary) -> bool:
	if not validate_state(value).is_empty():
		return false
	_state = value.duplicate(true)
	# JSON numbers arrive as floats; the public point contract stays integer-only.
	_state["schema"] = SCHEMA
	_state["rules_version"] = Catalog.RULES_VERSION
	for phase_state in _state["phases"].values():
		for track in Catalog.TRACKS:
			phase_state["earned"][track] = int(phase_state["earned"][track])
			phase_state["spent"][track] = int(phase_state["spent"][track])
		for reward in phase_state["rewards"].values():
			reward["amount"] = int(reward["amount"])
	return true


func wallet(phase: int) -> Dictionary:
	if phase not in range(Catalog.PHASE_COUNT):
		return {}
	var result: Dictionary = _state["phases"][str(phase)].duplicate(true)
	result.erase("rewards")
	result["available"] = {}
	for track in Catalog.TRACKS:
		result["available"][track] = int(result["earned"][track]) - int(result["spent"][track])
	result["earning_cap"] = Catalog.PHASE_POINT_CAP
	return result


## Called synchronously by GameState after accepting the event, before observers.
## Scene producers must supply stable IDs and pre-action relationship/cause facts.
func apply_event(event: GameEvent, campaign_id: String, player_id: String, current_phase: int) -> Dictionary:
	if not event.is_valid() or event.campaign_id != campaign_id or event.source_id != player_id or event.phase != current_phase:
		return _rejected("invalid_event")
	if current_phase != 0:
		return _rejected("phase_not_implemented")
	if event.encounter_id.is_empty() or event.encounter_id.length() > 256 or event.target_id.length() > 256:
		return _rejected("missing_stable_encounter")
	if event.target_id == player_id:
		return _rejected("self_interaction")
	var reward: Dictionary = _reward_rule(event)
	if reward.is_empty():
		return _rejected("not_rewardable")
	var phase_state: Dictionary = _state["phases"][str(current_phase)]
	var target_key: String = event.target_id.sha256_text()
	var encounter_key: String = event.encounter_id.sha256_text()
	var rewards: Dictionary = phase_state["rewards"]
	if rewards.has(target_key):
		return _rejected("target_already_rewarded")
	for previous in rewards.values():
		if previous["encounter"] == encounter_key:
			return _rejected("encounter_already_rewarded")
	var track: String = reward["track"]
	var amount: int = mini(int(reward["amount"]), Catalog.PHASE_POINT_CAP - int(phase_state["earned"][track]))
	if amount <= 0:
		return _rejected("phase_earning_cap")
	phase_state["earned"][track] = int(phase_state["earned"][track]) + amount
	# Never evict paid targets. Two capped wallets bound this ledger to 48 entries.
	rewards[target_key] = {"encounter": encounter_key, "track": track,
		"amount": amount, "outcome": event.outcome}
	return {"ok": true, "phase": current_phase, "track": track, "amount": amount,
		"outcome": event.outcome, "available": wallet(current_phase)["available"][track]}


static func _reward_rule(event: GameEvent) -> Dictionary:
	var relation: Variant = event.behavior_context.get("target_relation", "")
	if event.kind == GameEvent.Kind.INTERACTION:
		if event.outcome == "befriended" and relation in ["neutral", "wild"]:
			return {"track": "social", "amount": 3}
		if event.outcome == "helped" and relation in ["neutral", "wild", "ally"] and event.behavior_context.get("need_origin", "") in ["environment", "third_party"]:
			return {"track": "social", "amount": 2}
	if event.kind == GameEvent.Kind.CONFLICT_RESULT and event.outcome == "won" and relation in ["prey", "hostile"] and event.behavior_context.get("conflict_reason", "") in ["hunt", "territory", "self_defense"]:
		return {"track": "aggression", "amount": 3}
	return {}


func can_purchase(node_id: String, current_phase: int) -> Dictionary:
	var definition: Dictionary = Catalog.node(node_id)
	if definition.is_empty():
		return _rejected("unknown_node")
	if current_phase not in range(Catalog.PHASE_COUNT) or int(definition["phase"]) > current_phase:
		return _rejected("future_phase")
	if _state["purchased_nodes"].has(node_id):
		return _rejected("already_purchased")
	for required in definition["requires"]:
		if not _state["purchased_nodes"].has(required):
			return _rejected("prerequisite_missing")
	var phase: int = definition["phase"]
	var track: String = definition["track"]
	if int(wallet(phase)["available"][track]) < int(definition["cost"]):
		return _rejected("insufficient_points")
	return {"ok": true, "node_id": node_id, "phase": phase,
		"track": track, "cost": definition["cost"]}


func purchase(node_id: String, current_phase: int) -> Dictionary:
	var result: Dictionary = can_purchase(node_id, current_phase)
	if not result["ok"]:
		return result
	var phase_state: Dictionary = _state["phases"][str(result["phase"])]
	var track: String = result["track"]
	phase_state["spent"][track] = int(phase_state["spent"][track]) + int(result["cost"])
	_state["purchased_nodes"][node_id] = true
	return result


func nodes_for_phase(phase: int, current_phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node_id in Catalog.NODES:
		var definition: Dictionary = Catalog.node(node_id)
		if int(definition["phase"]) != phase:
			continue
		definition["id"] = node_id
		definition["purchased"] = _state["purchased_nodes"].has(node_id)
		definition["purchase_status"] = can_purchase(node_id, current_phase)
		result.append(definition)
	return result


## Always recompute from raw body/technology inputs, never from the previous result.
func calculate_effect(effect_id: String, phase: int, body_value: float = 1.0, technology_bonus: float = 0.0) -> Dictionary:
	if effect_id not in Catalog.EFFECTS or phase not in range(Catalog.PHASE_COUNT) or not is_finite(body_value) or not is_finite(technology_bonus):
		return _rejected("invalid_effect_input")
	var contributions: Array[Dictionary] = []
	var total: float = body_value + technology_bonus
	for node_id in _state["purchased_nodes"]:
		var definition: Dictionary = Catalog.node(node_id)
		var node_phase: int = definition["phase"]
		var effects: Dictionary = definition["effects"] if phase == node_phase else definition["legacy"] if phase > node_phase else {}
		if effects.has(effect_id):
			var amount: float = effects[effect_id]
			total += amount
			contributions.append({"node_id": node_id, "amount": amount, "legacy": phase > node_phase})
	return {"ok": true, "value": clampf(total, 0.5, 2.0), "body_value": body_value,
		"technology_bonus": technology_bonus, "contributions": contributions,
		"unclamped_value": total, "minimum": 0.5, "maximum": 2.0}


static func has_unsupported_contract(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	return (Catalog.is_newer_version(value.get("schema"), SCHEMA)
		or Catalog.is_newer_version(value.get("rules_version"), Catalog.RULES_VERSION))


static func validate_state(value: Variant) -> String:
	if not value is Dictionary or not Catalog.is_integer(value.get("schema"), SCHEMA, SCHEMA) or not Catalog.is_integer(value.get("rules_version"), Catalog.RULES_VERSION, Catalog.RULES_VERSION):
		return "Unsupported behavior schema or rules version."
	if not value.get("phases") is Dictionary or value["phases"].size() != Catalog.PHASE_COUNT or not value.get("purchased_nodes") is Dictionary:
		return "Invalid behavior wallets or purchases."
	var purchases: Dictionary = value["purchased_nodes"]
	if purchases.size() > Catalog.NODES.size():
		return "Too many purchased nodes."
	var expected_spent: Dictionary = {}
	for phase in range(Catalog.PHASE_COUNT):
		expected_spent[str(phase)] = {"social": 0, "aggression": 0}
	for node_id in purchases:
		var definition: Dictionary = Catalog.node(str(node_id))
		if definition.is_empty() or not purchases[node_id] is bool or not purchases[node_id]:
			return "Unknown or invalid purchased node."
		for required in definition["requires"]:
			if not purchases.has(required):
				return "Purchased node lacks its prerequisite."
		expected_spent[str(definition["phase"])][definition["track"]] += int(definition["cost"])
	for phase in range(Catalog.PHASE_COUNT):
		var state: Variant = value["phases"].get(str(phase))
		if not state is Dictionary or not state.get("earned") is Dictionary or not state.get("spent") is Dictionary or not state.get("rewards") is Dictionary:
			return "Invalid phase wallet."
		if state["earned"].size() != 2 or state["spent"].size() != 2 or state["rewards"].size() > Catalog.PHASE_POINT_CAP * 2:
			return "Invalid wallet size or reward history limit."
		var totals: Dictionary = {"social": 0, "aggression": 0}
		var encounters: Dictionary = {}
		for target_key in state["rewards"]:
			var reward: Variant = state["rewards"][target_key]
			if not _is_hash(target_key) or not reward is Dictionary or not _is_hash(reward.get("encounter")):
				return "Invalid reward identity."
			var track: Variant = reward.get("track")
			var outcome: Variant = reward.get("outcome")
			if phase != 0 or track not in Catalog.TRACKS or outcome not in ["befriended", "helped", "won"]:
				return "Unsupported behavior reward."
			if (track == "aggression") != (outcome == "won") or not Catalog.is_integer(reward.get("amount"), 1, 2 if outcome == "helped" else 3):
				return "Invalid behavior reward amount/type."
			if encounters.has(reward["encounter"]):
				return "Encounter paid more than once."
			encounters[reward["encounter"]] = true
			totals[track] += int(reward["amount"])
		for track in Catalog.TRACKS:
			if not Catalog.is_integer(state["earned"].get(track), 0, Catalog.PHASE_POINT_CAP) or not Catalog.is_integer(state["spent"].get(track), 0, Catalog.PHASE_POINT_CAP):
				return "Invalid point balance."
			if int(state["earned"][track]) != totals[track] or int(state["spent"][track]) != expected_spent[str(phase)][track] or int(state["spent"][track]) > int(state["earned"][track]):
				return "Point balances do not match rewards and purchases."
	return ""


static func _is_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _rejected(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
