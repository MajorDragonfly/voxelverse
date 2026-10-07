extends RefCounted
## Opt-in QA overlay only; never invoked from a worker thread.
const Atomic = preload("res://core/persistence/atomic_json.gd")
const MAX_SAMPLES: int = 262144
const MAX_SLOW_FRAMES: int = 2048
static var enabled: bool = false
static var phase: String = "prepare"
static var values: Dictionary = {}
static var totals: Dictionary = {}
static var slow: Array = []
static var count: int = 0
static var dropped: int = 0
static var writes: int = 0
static var write_ms: float = 0.0
static var write_errors: int = 0

static func reset() -> void:
	enabled = true
	phase = "prepare"
	values.clear()
	totals.clear()
	slow.clear()
	count = 0
	dropped = 0
	writes = 0
	write_ms = 0.0
	write_errors = 0

static func sample(operation: String, milliseconds: float) -> void:
	if not enabled: return
	var key: String = phase + "|" + operation
	var row: Dictionary = totals.get(key, {"count": 0, "sum_ms": 0.0, "max_ms": 0.0,
		"over_33_ms": 0, "over_50_ms": 0, "over_100_ms": 0})
	row.count += 1
	row.sum_ms += milliseconds
	row.max_ms = maxf(row.max_ms, milliseconds)
	if milliseconds > 33.0: row.over_33_ms += 1
	if milliseconds > 50.0: row.over_50_ms += 1
	if milliseconds > 100.0: row.over_100_ms += 1
	totals[key] = row
	if count < MAX_SAMPLES:
		if not values.has(key): values[key] = []
		values[key].append(milliseconds)
		count += 1
	else: dropped += 1
	if milliseconds > 33.0 and slow.size() < MAX_SLOW_FRAMES:
		slow.append({"phase": phase, "operation": operation, "ms": milliseconds,
			"process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(),
			"wall_us": Time.get_ticks_usec()})

static func summary() -> Dictionary:
	return {"totals": totals.duplicate(true), "sample_count": count, "dropped": dropped,
		"writes": writes, "write_ms": write_ms, "write_errors": write_errors,
		"note": "Nested wall spans overlap; callback time includes renderer API synchronization. No CPU/GPU attribution."}

static func checkpoint() -> void:
	var began: int = Time.get_ticks_usec()
	var code: Error = Atomic.write("user://int30-collision-spans.json",
		{"schema": 1, "summary": summary(), "samples": values, "slow": slow}, false)
	writes += 1
	write_ms += (Time.get_ticks_usec() - began) / 1000.0
	if code != OK:
		write_errors += 1
		push_error("R33 span checkpoint failed: " + error_string(code))
