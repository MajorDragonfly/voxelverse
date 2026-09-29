extends RefCounted
## Short, unsaved world cues driven by the existing expression state. Repeated
## samples of the same state never turn a cue into a permanent AI status label.
const CUES := {
	"curious": {"symbol": "?", "color": Color(0.80, 0.94, 0.88), "seconds": 1.45},
	"angry": {"symbol": "!", "color": Color(1.0, 0.68, 0.42), "seconds": 1.8},
	"afraid": {"symbol": "!!", "color": Color(1.0, 0.80, 0.57), "seconds": 1.8},
	"hurt": {"symbol": "✚", "color": Color(1.0, 0.62, 0.58), "seconds": 1.5},
	"affectionate": {"symbol": "♥", "color": Color(0.96, 0.74, 0.82), "seconds": 1.7},
	"playful": {"symbol": "♪", "color": Color(0.75, 0.91, 0.72), "seconds": 1.5},
}
const REPEAT_DELAY := 2.4
const FADE_SECONDS := 0.4

var _state := "calm"
var _remaining := 0.0
var _repeat_remaining := 0.0


func reset() -> void:
	_state = "calm"
	_remaining = 0.0
	_repeat_remaining = 0.0


func advance(delta: float, state: String) -> Dictionary:
	if not is_finite(delta) or delta < 0.0:
		return {}
	_remaining = maxf(0.0, _remaining - delta)
	_repeat_remaining = maxf(0.0, _repeat_remaining - delta)
	if state != _state:
		_state = state
		# Danger, pain and genuine social reactions can interrupt a cue. Routine
		# curiosity bouncing among nearby animals does not flood the screen.
		if not CUES.has(state):
			_remaining = 0.0
		elif state in ["angry", "afraid", "hurt", "affectionate", "playful"] or _repeat_remaining <= 0.0:
			_remaining = float(CUES[state].seconds)
			_repeat_remaining = REPEAT_DELAY
		else:
			_remaining = 0.0
	if _remaining <= 0.0 or not CUES.has(_state):
		return {}
	return {"symbol": CUES[_state].symbol, "color": CUES[_state].color,
		"alpha": minf(1.0, _remaining / FADE_SECONDS), "state": _state}
