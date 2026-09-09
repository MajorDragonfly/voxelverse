extends Node
## Explicit success-only API. Never guesses actions from stat changes or UI text.

signal action_played(action: StringName, source_id: int)

const COOLDOWNS := {&"eat": 650, &"drink": 650, &"gather": 250, &"evolve": 1500}
const MAX_COOLDOWNS := 128
const MAX_RECEIPTS := 256
var _last: Dictionary = {}
var _receipts: Dictionary = {}


func play(action: StringName, source: Node3D = null, receipt_id: String = "") -> bool:
	if not COOLDOWNS.has(action):
		return false
	var source_id := 0
	if is_instance_valid(source):
		if source.is_queued_for_deletion() or not source.is_inside_tree() or source.get_meta(&"audio_disabled", false):
			return false
		if source.get("is_dead") == true:
			return false
		source_id = source.get_instance_id()
	elif action != &"evolve":
		return false
	if action != &"evolve" and get_tree().paused:
		return false
	if receipt_id.length() > 128:
		return false
	var key := "%s:%d" % [action, source_id]
	var receipt := "%s:%s" % [key, receipt_id]
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -100000)) < int(COOLDOWNS[action]):
		return false
	if not receipt_id.is_empty() and _receipts.has(receipt):
		return false
	var audio := get_parent()
	var event := StringName("action_" + String(action))
	var played: bool
	if action == &"evolve":
		# Evolution confirms an editor/progression operation, including paused UI.
		played = audio.play_ui(event)
	else:
		played = audio.play_world(event, source.global_position, -5.0, 1.0, source_id, 1)
	if not played:
		return false
	if _last.size() >= MAX_COOLDOWNS:
		_last.erase(_last.keys()[0])
	_last[key] = now
	if not receipt_id.is_empty():
		if _receipts.size() >= MAX_RECEIPTS:
			_receipts.erase(_receipts.keys()[0])
		_receipts[receipt] = true
	action_played.emit(action, source_id)
	return true


func reset() -> void:
	_last.clear()
	_receipts.clear()
