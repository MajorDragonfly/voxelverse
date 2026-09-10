extends RefCounted
## Translation belongs here; faction names and command parameters remain literal.
const Text = preload("res://core/localization/ui_text.gd")
const RESULT_KEYS := {
	"neighbor.unavailable": "NEIGHBOR_UNAVAILABLE",
	"neighbor.already_known": "NEIGHBOR_ALREADY_KNOWN",
	"neighbor.not_known": "NEIGHBOR_NOT_KNOWN",
	"neighbor.no_site": "NEIGHBOR_NO_SITE",
	"neighbor.contact_save_failed": "NEIGHBOR_CONTACT_SAVE_FAILED",
	"neighbor.contacted": "NEIGHBOR_CONTACTED",
	"neighbor.route_blocked": "NEIGHBOR_ROUTE_BLOCKED",
	"neighbor.aid_finished": "NEIGHBOR_AID_FINISHED",
	"neighbor.selection_required": "NEIGHBOR_SELECTION_REQUIRED",
	"neighbor.carriers_busy": "NEIGHBOR_CARRIERS_BUSY",
	"neighbor.aid_started": "NEIGHBOR_AID_STARTED",
	"neighbor.aid_save_failed": "NEIGHBOR_AID_SAVE_FAILED",
	"neighbor.shelter_completed": "NEIGHBOR_SHELTER_COMPLETED",
}
const STATUS_KEYS := {"offered": "NEIGHBOR_OFFERED", "active": "NEIGHBOR_ACTIVE",
	"building": "NEIGHBOR_BUILDING", "completed": "NEIGHBOR_COMPLETED"}

static func result_text(outcome: Dictionary) -> String:
	return Text.format_text(RESULT_KEYS.get(outcome.get("code", ""), "NEIGHBOR_UNKNOWN_RESULT"), outcome.get("params", {}))

static func detail_text(facts: Dictionary) -> String:
	if not facts.get("known", false):
		return Text.text("NEIGHBOR_EMPTY")
	return Text.format_text("NEIGHBOR_DETAIL", {
		"name": facts.name, "residents": facts.residents,
		"status": Text.text(STATUS_KEYS.get(facts.status, "NEIGHBOR_UNKNOWN_RESULT")),
		"food": int(facts.received.food), "food_required": int(facts.required.food),
		"wood": int(facts.received.wood), "wood_required": int(facts.required.wood),
		"contributors": facts.contributors, "shelter": facts.shelter_percent})
