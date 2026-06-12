extends Node


enum Phase {
	CREATURE,
	TRIBE,
	ANCIENT_MEDIEVAL,
	NATION,
	SPACE,
	MULTIVERSE,
}


const PHASE_ABILITIES: Dictionary = {
	Phase.CREATURE: [
		&"bite",
		&"eat",
		&"drink",
		&"socialize",
		&"mate",
	],

	Phase.TRIBE: [
		&"bite",
		&"eat",
		&"drink",
		&"socialize",
		&"mate",
		&"gather",
		&"chop",
		&"mine",
		&"build",
	],

	Phase.ANCIENT_MEDIEVAL: [
		&"gather",
		&"chop",
		&"mine",
		&"build",
		&"farm",
		&"trade",
	],

	Phase.NATION: [
		&"gather",
		&"chop",
		&"mine",
		&"build",
		&"farm",
		&"trade",
		&"industrialize",
	],

	Phase.SPACE: [
		&"build",
		&"trade",
		&"industrialize",
		&"colonize",
		&"terraform",
	],

	Phase.MULTIVERSE: [
		&"build",
		&"trade",
		&"industrialize",
		&"colonize",
		&"terraform",
		&"travel_multiverse",
	],
}


# Jeder neue Durchlauf beginnt in der Kreaturenphase.
var current_phase: int = Phase.CREATURE

# Derselbe Seed erzeugt immer dieselbe Ausgangswelt.
var world_seed: int = 12345


func has_ability(ability: StringName) -> bool:
	var available_abilities: Array = PHASE_ABILITIES.get(
		current_phase,
		[]
	)

	return ability in available_abilities


func set_phase(new_phase: int) -> void:
	if not PHASE_ABILITIES.has(new_phase):
		push_warning("Unknown game phase: %s" % new_phase)
		return

	current_phase = new_phase
	print("Game phase changed to: ", get_phase_name())


func get_phase_name() -> String:
	match current_phase:
		Phase.CREATURE:
			return "Creature"

		Phase.TRIBE:
			return "Tribe"

		Phase.ANCIENT_MEDIEVAL:
			return "Ancient / Medieval"

		Phase.NATION:
			return "Nation"

		Phase.SPACE:
			return "Space"

		Phase.MULTIVERSE:
			return "Multiverse"

		_:
			return "Unknown"
