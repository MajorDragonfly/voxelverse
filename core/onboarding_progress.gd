extends RefCounted

## Optional UI progress, independent of gameplay rewards and campaign events.
const SCHEMA: int = 1
const STEPS: Array[String] = ["look", "move", "jump", "inspect"]
const GOALS: Dictionary = {"look": 0.55, "move": 4.0, "jump": 1.0, "inspect": 1.0}
var data: Dictionary = {"schema": SCHEMA, "skipped": true, "progress": {"look": 0.0, "move": 0.0, "jump": 0.0, "inspect": 0.0}}

func reset(enabled: bool = false) -> void:
	data = {"schema": SCHEMA, "skipped": not enabled, "progress": {"look": 0.0, "move": 0.0, "jump": 0.0, "inspect": 0.0}}

func import_state(value: Variant) -> void:
	reset()
	if not value is Dictionary:
		return
	var version: Variant = value.get("schema")
	if not (version is float or version is int) or not is_finite(float(version)):
		return
	# Preserve optional data from a later guide version without changing it.
	if int(version) > SCHEMA:
		data = value.duplicate(true)
		return
	if float(version) != float(SCHEMA) or not value.get("progress") is Dictionary:
		return
	data.skipped = bool(value.get("skipped", true))
	for step in STEPS:
		var amount: Variant = value.progress.get(step, 0.0)
		if (amount is float or amount is int) and is_finite(float(amount)):
			data.progress[step] = clampf(float(amount), 0.0, GOALS[step])

func export_state() -> Dictionary:
	return data.duplicate(true)

func supported() -> bool:
	return int(data.schema) == SCHEMA

func amount(step: String) -> float:
	return float(data.progress.get(step, 0.0)) if supported() and step in STEPS else 0.0

func done(step: String) -> bool:
	return step in STEPS and amount(step) >= float(GOALS[step])

func completed_count() -> int:
	var count: int = 0
	for step in STEPS:
		count += int(done(step))
	return count

func current_step() -> String:
	if supported() and not bool(data.skipped):
		for step in STEPS:
			if not done(step):
				return step
	return ""

func record(step: String, value: float = 1.0) -> bool:
	if current_step().is_empty() or step not in STEPS or not is_finite(value) or value <= 0.0 or done(step):
		return false
	data.progress[step] = minf(amount(step) + value, GOALS[step])
	return true

func skip() -> void:
	if supported():
		data.skipped = true
