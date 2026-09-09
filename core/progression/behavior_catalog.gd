extends RefCounted
class_name BehaviorCatalog

## M2A prototype values. Change RULES_VERSION when persisted costs/rules change.
const RULES_VERSION: int = 1
const TRACKS: Array[String] = ["social", "aggression"]
const PHASE_COUNT: int = 6
const PHASE_POINT_CAP: int = 24
const NODES: Dictionary = {
	"creature.social.approach": {
		"name": "Offenheit", "phase": 0, "track": "social", "cost": 2,
		"requires": [], "effects": {"befriend_efficiency": 0.15}, "legacy": {},
		"description": "Befreunden wird um 15 % wirksamer.",
	},
	"creature.social.support": {
		"name": "Zusammenhalt", "phase": 0, "track": "social", "cost": 3,
		"requires": ["creature.social.approach"],
		"effects": {"ally_support_efficiency": 0.15}, "legacy": {},
		"description": "Unterstützung verbündeter Kreaturen wird um 15 % wirksamer.",
	},
	"creature.social.legacy": {
		"name": "Gemeinsinn", "phase": 0, "track": "social", "cost": 4,
		"requires": ["creature.social.support"], "effects": {},
		"legacy": {"group_cooperation": 0.10},
		"description": "Ab der Stammesphase: 10 % bessere Gruppenkoordination.",
	},
	"creature.aggression.hunter": {
		"name": "Jagdinstinkt", "phase": 0, "track": "aggression", "cost": 2,
		"requires": [], "effects": {"attack_efficiency": 0.10}, "legacy": {},
		"description": "Angriffe werden um 10 % wirksamer.",
	},
	"creature.aggression.endurance": {
		"name": "Ausdauer", "phase": 0, "track": "aggression", "cost": 3,
		"requires": ["creature.aggression.hunter"],
		"effects": {"stamina_recovery": 0.15}, "legacy": {},
		"description": "Ausdauer erholt sich um 15 % schneller.",
	},
	"creature.aggression.legacy": {
		"name": "Wehrhaftigkeit", "phase": 0, "track": "aggression", "cost": 4,
		"requires": ["creature.aggression.endurance"], "effects": {},
		"legacy": {"group_defense": 0.10},
		"description": "Ab der Stammesphase: 10 % bessere gemeinsame Verteidigung.",
	},
}
const EFFECTS: Array[String] = ["befriend_efficiency", "ally_support_efficiency",
	"attack_efficiency", "stamina_recovery", "group_cooperation", "group_defense"]


static func node(node_id: String) -> Dictionary:
	return NODES.get(node_id, {}).duplicate(true)


static func is_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


static func is_newer_version(value: Variant, supported: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > supported
