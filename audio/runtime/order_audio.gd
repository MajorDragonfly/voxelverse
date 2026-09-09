extends Node
## One confirmation per group command receipt; never per selected member.

signal feedback_played(order: StringName, command_id: String, accepted: bool)
const ORDERS := {&"move": &"move", &"gather": &"gather", &"wood": &"gather",
	&"stone": &"gather", &"food": &"gather", &"attack": &"attack",
	&"build": &"build", &"tool": &"build", &"hut": &"build", &"wait": &"wait", &"feed": &"feed", &"garden": &"build", &"supply": &"gather",
	&"follow": &"move", &"home": &"move", &"tame": &"tame"}
const MAX_RECEIPTS := 256
var automatic_binding := true
var _sources: Array[Node] = []
var _receipts: Dictionary = {}
var _last_feedback := -1000
var _clock := 0.0
var _last_rejection := -1000


func play_result(order: StringName, command_id: String, accepted: bool) -> bool:
	if not ORDERS.has(order) or command_id.is_empty() or command_id.length() > 128 or get_tree().paused:
		return false
	if _receipts.has(command_id):
		return false
	# Consume even suppressed receipts: a delayed duplicate must never sound later.
	if _receipts.size() >= MAX_RECEIPTS:
		_receipts.erase(_receipts.keys()[0])
	_receipts[command_id] = true
	var now := Time.get_ticks_msec()
	# A rejected command immediately following success must remain audible.
	if now - (_last_feedback if accepted else _last_rejection) < 180:
		return false
	var kind: StringName = ORDERS[order] if accepted else &"reject"
	if not get_parent().play_ui(StringName("order_" + String(kind))):
		return false
	_last_feedback = now
	if not accepted:
		_last_rejection = now
	feedback_played.emit(order, command_id, accepted)
	return true


func bind_source(source: Node) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree() or not source.has_signal("order_resolved"):
		return false
	if source in _sources:
		return true
	if _sources.size() >= 8:
		return false
	source.connect("order_resolved", _on_result)
	_sources.append(source)
	return true


func _on_result(order: StringName, command_id: String, accepted: bool) -> void:
	play_result(order, command_id, accepted)


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = 0.5
	_sources = _sources.filter(func(source): return is_instance_valid(source))
	if automatic_binding:
		for source in get_tree().get_nodes_in_group(&"tribe_controller"):
			bind_source(source)


func reset_scene() -> void:
	for source in _sources:
		if is_instance_valid(source) and source.is_connected("order_resolved", _on_result):
			source.disconnect("order_resolved", _on_result)
	_sources.clear()
	_receipts.clear()
	_last_feedback = -1000
	_last_rejection = -1000
	_clock = 0.0


func _exit_tree() -> void:
	reset_scene()
