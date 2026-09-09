extends RefCounted
class_name CampaignGameEvent

enum Kind { DISCOVERY, INTERACTION, CONFLICT_RESULT, PHASE_TRANSITION }

var kind: int = Kind.DISCOVERY
var campaign_id: String = ""
var source_id: String = ""
var target_id: String = ""
var phase: int = 0
var sequence: int = 0
var outcome: String = ""
## Optional M2 completion evidence; older events remain valid but earn no points.
var encounter_id: String = ""
var behavior_context: Dictionary = {}


func is_valid() -> bool:
	return kind in Kind.values() and not campaign_id.is_empty() and not source_id.is_empty() and not target_id.is_empty() and phase >= 0 and phase <= 5 and sequence > 0 and outcome in ["discovered", "helped", "befriended", "won", "lost", "completed"] and (
		(kind == Kind.DISCOVERY and outcome == "discovered")
		or (kind == Kind.INTERACTION and outcome in ["helped", "befriended"])
		or (kind == Kind.CONFLICT_RESULT and outcome in ["won", "lost"])
		or (kind == Kind.PHASE_TRANSITION and outcome == "completed")
	)


func channel() -> String:
	return "%s:%d" % [source_id, kind]


func to_dict() -> Dictionary:
	return {"kind": kind, "campaign_id": campaign_id, "source_id": source_id,
		"target_id": target_id, "phase": phase, "sequence": sequence, "outcome": outcome,
		"encounter_id": encounter_id, "behavior_context": behavior_context.duplicate(true)}
