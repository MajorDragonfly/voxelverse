extends RefCounted

## Optional UI progress only. Never grants rewards or changes the campaign phase.
const SCHEMA: int = 3
const CHAPTERS: Array[String] = ["explore", "survive", "home", "tribe"]
const CHAPTER_STEPS: Dictionary = {
	"explore": ["look", "move", "jump", "inspect"],
	"survive": ["eat", "drink"], "home": ["home", "command"], "tribe": ["tribe"],
}
const STEPS: Array[String] = ["look", "move", "jump", "inspect", "eat", "drink", "home", "command", "tribe"]
const GOALS: Dictionary = {"look": 0.55, "move": 4.0, "jump": 1.0, "inspect": 1.0,
	"eat": 1.0, "drink": 1.0, "home": 1.0, "command": 1.0, "tribe": 1.0}
# The tribe is another chapter family in the same optional save participant.
const TRIBE_CHAPTERS: Array[String] = ["tribe_view", "tribe_work", "tribe_build"]
const TRIBE_CHAPTER_STEPS := {
	"tribe_view": ["tribe_camera", "tribe_single", "tribe_group"],
	"tribe_work": ["tribe_order", "tribe_delivery", "tribe_supply"],
	"tribe_build": ["tribe_tool", "tribe_place", "tribe_finish", "tribe_profession", "tribe_workplace"],
}
const TRIBE_STEPS: Array[String] = ["tribe_camera", "tribe_single", "tribe_group", "tribe_order", "tribe_delivery", "tribe_supply", "tribe_tool", "tribe_place", "tribe_finish", "tribe_profession", "tribe_workplace"]
var data: Dictionary

func _init() -> void:
	reset()

func reset(enabled: bool = false) -> void:
	data = {"schema": SCHEMA, "skipped": not enabled, "focus": "explore", "progress": {}}
	for step in STEPS:
		data.progress[step] = 0.0
	_reset_tribal(enabled)

func import_state(value: Variant) -> void:
	reset()
	if not value is Dictionary:
		return
	var version: Variant = value.get("schema")
	if not (version is float or version is int) or not is_finite(float(version)):
		return
	# Do not round unknown fractional versions down to a supported contract.
	if float(version) not in [1.0, 2.0, float(SCHEMA)] and float(version) > 1.0:
		data = value.duplicate(true)
		return
	if float(version) not in [1.0, 2.0, float(SCHEMA)] or not value.get("progress") is Dictionary:
		return
	data.skipped = value.get("skipped", true) != false
	if value.get("focus") is String and value.focus in CHAPTERS:
		data.focus = value.focus
	var available: Array = CHAPTER_STEPS.explore if float(version) == 1.0 else STEPS
	for step: String in available:
		var amount_value: Variant = value.progress.get(step, 0.0)
		if (amount_value is float or amount_value is int) and is_finite(float(amount_value)):
			data.progress[step] = clampf(float(amount_value), 0.0, GOALS[step])
	# An old finished introduction stays quiet. Expanded help is opt-in there.
	if float(version) == 1.0 and chapter_completed("explore") == 4:
		data.skipped = true

	if float(version) == SCHEMA and value.get("tribal") is Dictionary:
		var tribal: Dictionary = value.tribal
		data.tribal.skipped = tribal.get("skipped", true) != false
		if tribal.get("focus") in TRIBE_CHAPTERS: data.tribal.focus = tribal.focus
		if tribal.get("progress") is Dictionary:
			for step: String in TRIBE_STEPS:
				var amount_value: Variant = tribal.progress.get(step, 0.0)
				if (amount_value is float or amount_value is int) and is_finite(float(amount_value)):
					data.tribal.progress[step] = clampf(float(amount_value), 0.0, tribal_goal(step))

func export_state() -> Dictionary:
	return data.duplicate(true)

func supported() -> bool:
	return data.get("schema") == SCHEMA

func amount(step: String) -> float:
	return float(data.progress.get(step, 0.0)) if supported() and step in STEPS else 0.0

func done(step: String) -> bool:
	return step in STEPS and amount(step) >= float(GOALS[step])

func completed_count() -> int:
	var count: int = 0
	for step in STEPS:
		count += int(done(step))
	return count

func chapter_completed(chapter: String) -> int:
	var count: int = 0
	for step: String in CHAPTER_STEPS.get(chapter, []):
		count += int(done(step))
	return count

func chapter_for(step: String) -> String:
	for chapter in CHAPTERS:
		if step in CHAPTER_STEPS[chapter]:
			return chapter
	return ""

func current_step() -> String:
	# Reaching the tribe ends the introduction, even if optional exercises remain.
	if not supported() or bool(data.skipped) or done("tribe"):
		return ""
	var ordered: Array = CHAPTER_STEPS[data.focus].duplicate()
	ordered.append_array(STEPS)
	for step: String in ordered:
		if not done(step):
			return step
	return ""

func select_chapter(chapter: String) -> bool:
	if not supported() or chapter not in CHAPTERS or done("tribe"):
		return false
	data.focus = chapter
	data.skipped = false
	return true

func record(step: String, value: float = 1.0) -> bool:
	if current_step().is_empty() or step not in STEPS or not is_finite(value) or value <= 0.0 or done(step):
		return false
	data.progress[step] = minf(amount(step) + value, GOALS[step])
	return true

func skip() -> void:
	if supported():
		data.skipped = true

func _reset_tribal(enabled: bool) -> void:
	data["tribal"] = {"skipped": not enabled, "focus": "tribe_view", "progress": {}}
	for step: String in TRIBE_STEPS: data.tribal.progress[step] = 0.0

static func tribal_goal(step: String) -> float:
	return 4.0 if step == "tribe_camera" else 1.0

func tribal_amount(step: String) -> float:
	return float(data.tribal.progress.get(step, 0.0)) if supported() and step in TRIBE_STEPS else 0.0

func tribal_done(step: String) -> bool:
	return step in TRIBE_STEPS and tribal_amount(step) >= tribal_goal(step)

func tribal_completed(chapter: String = "") -> int:
	var count: int = 0
	for step: String in TRIBE_CHAPTER_STEPS.get(chapter, TRIBE_STEPS): count += int(tribal_done(step))
	return count

func tribal_step() -> String:
	if not supported() or bool(data.tribal.skipped): return ""
	var ordered: Array = TRIBE_CHAPTER_STEPS[data.tribal.focus].duplicate()
	ordered.append_array(TRIBE_STEPS)
	for step: String in ordered:
		if not tribal_done(step): return step
	return ""

func select_tribal(chapter: String) -> bool:
	if not supported() or chapter not in TRIBE_CHAPTERS: return false
	data.tribal.focus = chapter
	data.tribal.skipped = false
	return true

func record_tribal(step: String, value: float = 1.0) -> bool:
	if tribal_step().is_empty() or step not in TRIBE_STEPS or not is_finite(value) or value <= 0.0 or tribal_done(step): return false
	data.tribal.progress[step] = minf(tribal_amount(step) + value, tribal_goal(step))
	return true

func skip_tribal() -> void:
	if supported(): data.tribal.skipped = true

func restart_tribal() -> void:
	if supported(): _reset_tribal(true)
