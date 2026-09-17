extends RefCounted
## Ephemeral wall-clock observations; no world construction or persistent state.

var _started: int = 0
var _ended: int = 0
var _phase_started: int = 0
var _phase: String = ""
var _status: String = "idle"
var _error: String = ""
var _sequence: int = 0
var _segments: Array[Dictionary] = []
var _context: Dictionary = {}


func begin(now: int = -1) -> void:
	if now < 0: now = Time.get_ticks_usec()
	_sequence += 1
	_started = now
	_ended = 0
	_phase_started = now
	_phase = "prepare_state"
	_status = "loading"
	_error = ""
	_segments.clear()
	_context.clear()


func set_context(context: Dictionary) -> void:
	_context = context.duplicate(true)


func phase(id: String, now: int = -1) -> void:
	if _status != "loading" or id == _phase or id.is_empty(): return
	if now < 0: now = Time.get_ticks_usec()
	_close(now)
	_phase = id
	_phase_started = now


func finish(status: String, error: String = "", now: int = -1) -> void:
	if _status != "loading": return
	if now < 0: now = Time.get_ticks_usec()
	_close(now)
	_ended = now
	_status = status
	_error = error


func snapshot(now: int = -1) -> Dictionary:
	if now < 0: now = Time.get_ticks_usec()
	var result: Dictionary = {"schema": 1, "sequence": _sequence, "status": _status,
		"last_phase": _phase, "error": _error, "context": _context.duplicate(true),
		"total_ms": 0.0, "segments": _segments.duplicate(true)}
	if _status == "idle": return result
	result.total_ms = (now - _started if _status == "loading" else _ended - _started) / 1000.0
	if _status == "loading":
		result.segments.append(_segment(now, false))
	return result


func _segment(now: int, completed: bool) -> Dictionary:
	return {"phase": _phase, "start_ms": (_phase_started - _started) / 1000.0,
		"duration_ms": (now - _phase_started) / 1000.0, "completed": completed}


func _close(now: int) -> void:
	_segments.append(_segment(now, true))
