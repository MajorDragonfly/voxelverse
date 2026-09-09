extends RefCounted

const DURATION: float = 2.5
var target_id: int = 0
var elapsed: float = 0.0

func reset() -> void:
	target_id = 0
	elapsed = 0.0

func advance(instance_id: int, delta: float) -> bool:
	if instance_id == 0:
		reset()
		return false
	if instance_id != target_id:
		target_id = instance_id
		elapsed = 0.0
	if not is_finite(delta) or delta <= 0.0:
		return false
	# A stalled frame or focus change cannot finish a scan in one update.
	elapsed = minf(DURATION, elapsed + minf(delta, 0.1))
	return elapsed >= DURATION

func ratio() -> float:
	return elapsed / DURATION
