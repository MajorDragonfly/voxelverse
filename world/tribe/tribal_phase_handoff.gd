extends RefCounted
## The existing home/controller proves placement, paths and explicit confirmation.
## This adapter only adds its validated village to a detached campaign snapshot.
const Model = preload("res://world/tribe/tribe_state.gd")
const FROM: int = 0
const TO: int = 1


static func blockers(state: Node) -> Array[String]:
	var runtime: Node = state.get_tree().get_first_node_in_group(&"tribe_controller")
	if runtime == null:
		return ["The gameplay and handoff for this phase are not implemented yet."]
	return runtime.blockers()


static func confirmed_handoff(state: Node, token: String) -> Dictionary:
	var runtime: Node = state.get_tree().get_first_node_in_group(&"tribe_controller")
	return runtime.confirmed_handoff(token) if runtime != null else {}


static func install(campaign: Dictionary, body_id: String, handoff: Dictionary) -> String:
	var body: Dictionary = campaign["bodies"].get(body_id, {})
	if body.is_empty():
		return "Dem Epochenwechsel fehlt sein aktiver Körper."
	if body.has("tribe"):
		return "Ein vorhandener Stamm darf beim Epochenwechsel nicht ersetzt werden."
	var problem: String = Model.validate(handoff, body, campaign)
	if not problem.is_empty():
		return problem
	body["tribe"] = handoff.duplicate(true)
	return ""


static func receipt(handoff: Dictionary) -> Dictionary:
	# Keep the released receipt shape and scoped transition identity unchanged.
	return {"tribe_id": handoff["id"], "body_id": handoff["body_id"]}
