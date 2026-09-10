extends RefCounted
## One read-only local search. No threads, Nodes, persistence or global sampler.
const PROBES_PER_TICK: int = 2
const PROBE_COUNT: int = 25
const MAX_OBSERVER_DRIFT: float = 8.0
var listener: Vector3
var frame: Basis
var generation: int
var cursor: int = 0
var nearest: float = INF
var nearest_position: Vector3 = Vector3.ZERO
var queries_last_step: int = 0

func _init(position: Vector3, tangent_frame: Basis, epoch: int) -> void:
	listener = position
	frame = tangent_frame
	generation = epoch

func step(sample: Callable) -> void:
	queries_last_step = 0
	while cursor < PROBE_COUNT and queries_last_step < PROBES_PER_TICK:
		var radius: float = 0.0
		var angle: float = 0.0
		if cursor > 0:
			radius = [7.0, 18.0, 30.0][(cursor - 1) / 8]
			angle = ((cursor - 1) % 8) * TAU / 8.0
		var point: Vector3 = listener + frame * Vector3(cos(angle), 0, sin(angle)) * radius
		cursor += 1
		queries_last_step += 1
		var probe: Dictionary = sample.call(point)
		if not bool(probe.get("water_present", false)): continue
		if probe.has("water_point"):
			point = probe.water_point
		elif probe.has("water_height"):
			# Only the explicit legacy planar port returns an absolute Y level.
			point.y = float(probe.water_height)
		else: continue
		if not point.is_finite(): continue
		var distance: float = point.distance_to(listener)
		if distance < nearest:
			nearest = distance
			nearest_position = point

func complete() -> bool:
	return cursor == PROBE_COUNT

func rebase(shift: Vector3) -> void:
	listener += shift
	nearest_position += shift
