extends RefCounted
## Explicit playable handoffs. Enum values, saved flags and points are not releases.
## Preparation is read-only; SaveGameService owns the atomic commit and signals.
const Campaign = preload("res://core/campaign/campaign_state.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const Civilization = preload("res://core/progression/civilization_contract.gd")
const ADAPTERS: Dictionary = {
	1: preload("res://world/tribe/tribal_phase_handoff.gd"),
}


static func blockers(state: Node, target: int) -> Array[String]:
	if target != int(state.current_phase) + 1:
		return ["Only the next supported phase can be entered."]
	if not state.campaign.data["pending_transition"].is_empty():
		return ["Ein anderer Übergang wird noch abgeschlossen."]
	var adapter: Script = _adapter(int(state.current_phase), target)
	if adapter != null:
		return adapter.blockers(state)
	if target in [2, 3]:
		var epoch: Dictionary = Civilization.describe(state.campaign.data, state.active_body_id, state.current_phase, target)
		var reasons: Array[String] = []
		reasons.assign(epoch["blockers"])
		return reasons
	return ["The gameplay and handoff for this phase are not implemented yet."]


static func prepare(state: Node, target: int, confirmation_token: String) -> Dictionary:
	var reasons: Array[String] = blockers(state, target)
	if not reasons.is_empty():
		return _failure("phase_blocked", reasons[0])
	var adapter: Script = _adapter(int(state.current_phase), target)
	var handoff: Dictionary = adapter.confirmed_handoff(state, confirmation_token)
	if handoff.is_empty():
		return _failure("confirmation_required", "Bestätige den Wechsel im Fenster für das Stammeszeitalter erneut.")
	var before: Dictionary = state.campaign.export_state()
	var transition_id: String = Ids.scoped("transition", before["id"], "%d:%d" % [state.current_phase, target])
	if before["completed_transitions"].has(transition_id):
		return _failure("already_completed", "Dieser Epochenwechsel wurde bereits abgeschlossen.")
	var candidate := Campaign.new()
	if not candidate.import_state(before):
		return _failure("invalid_campaign", candidate.last_error)
	var problem: String = adapter.install(candidate.data, state.active_body_id, handoff)
	if not problem.is_empty():
		return _failure("invalid_handoff", problem)
	problem = Civilization.validate_retention(before, candidate.data)
	if not problem.is_empty():
		return _failure("retention_failed", problem)
	var event = candidate.next_event(GameEvent.Kind.PHASE_TRANSITION, before["player_faction_id"], target, "completed")
	if not candidate.accept_event(event, target):
		return _failure("invalid_event", "Der Abschluss des Epochenwechsels konnte nicht bestätigt werden.")
	var receipt: Dictionary = adapter.receipt(handoff)
	receipt.merge({"id": transition_id, "from": int(state.current_phase), "to": target, "confirmed": true})
	candidate.data["completed_transitions"][transition_id] = receipt
	return {"ok": true, "code": "prepared", "from": int(state.current_phase), "to": target,
		"campaign": candidate.export_state(), "event": event.to_dict()}


static func _adapter(from: int, target: int) -> Script:
	var adapter: Script = ADAPTERS.get(target)
	return adapter if adapter != null and adapter.FROM == from and adapter.TO == target else null


static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
