extends RefCounted
## Presentation only. Stable node/phase identities stay in the real catalogs.
const Text = preload("res://core/localization/ui_text.gd")
const Behavior = preload("res://core/progression/behavior_catalog.gd")
const Tribal = preload("res://core/progression/tribal_progression.gd")
const Phases = preload("res://core/progression/phase_progression_plan.gd")

static func node_text(id: String, field: String) -> String:
	var key := "SKILLS_NODE_" + id.replace(".", "_").to_upper() + "_" + field.to_upper()
	var translated := Text.text(key)
	if translated != key: return translated
	var definition: Dictionary = Behavior.NODES.get(id, Tribal.NODES.get(id, {}))
	return str(definition.get(field, id))

static func phase_name(index: int) -> String:
	return phase_text(clampi(index, 0, Phases.PHASES.size() - 1), "name")

static func phase_text(index: int, field: String) -> String:
	var key := "SKILLS_PHASE_%d_%s" % [index, field.to_upper()]
	var translated := Text.text(key)
	return str(Phases.phase(index).get(field, "")) if translated == key else translated

static func phase_loop(index: int) -> String:
	var steps: PackedStringArray = []
	for i in range(Phases.PHASES[index].loop.size()):
		steps.append(phase_text(index, "loop_%d" % i))
	return " → ".join(steps)
