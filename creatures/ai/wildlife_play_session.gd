extends RefCounted
## One transient session shared by two live actors. Weak handles avoid retaining
## streamed scenes. Only the leader advances the clock; either animal can cancel.
const APPROACH_LIMIT: float = 5.0
const GREETING_SECONDS: float = 1.3
const PLAY_SECONDS: float = 4.8
const REST_SECONDS: float = 1.2
const MAX_DISTANCE: float = 10.0

var first: WeakRef
var second: WeakRef
var stage: String = "approach"
var elapsed: float = 0.0
var stage_elapsed: float = 0.0
var spacing: float = 2.4
var reason: String = ""
var _blocked: float = 0.0
var _last_frame: int = -1

func configure(a: Node3D, b: Node3D, personal_space: float) -> void:
	first = weakref(a)
	second = weakref(b)
	spacing = personal_space

func partner(actor: Node) -> Node3D:
	return second.get_ref() if first.get_ref() == actor else first.get_ref()

func active() -> bool:
	return reason.is_empty()

func cancel(why: String) -> void:
	if not active(): return
	reason = why
	for handle: WeakRef in [first, second]:
		var actor: Node = handle.get_ref()
		if is_instance_valid(actor): actor.play_session_ended(self, why)

func valid() -> bool:
	if not active(): return false
	var a: Node3D = first.get_ref()
	var b: Node3D = second.get_ref()
	if not is_instance_valid(a) or not is_instance_valid(b):
		cancel("removed")
		return false
	if not a.play_available() or not b.play_available():
		cancel("priority")
		return false
	if a.get_world_3d() != b.get_world_3d() or a.global_position.distance_to(b.global_position) > MAX_DISTANCE:
		cancel("separated")
		return false
	return true

func advance(actor: Node, delta: float, frame: int) -> void:
	if not is_finite(delta) or delta <= 0.0 or not valid(): return
	if first.get_ref() != actor or frame == _last_frame: return
	_last_frame = frame
	elapsed += delta
	stage_elapsed += delta
	var a: Node3D = first.get_ref()
	var b: Node3D = second.get_ref()
	var distance: float = a.global_position.distance_to(b.global_position)
	_blocked = _blocked + delta if a.ai_state == "blocked" or b.ai_state == "blocked" else 0.0
	if _blocked > 1.5:
		cancel("blocked")
		return
	if stage == "approach":
		if distance <= spacing + 0.35 and distance >= spacing * 0.65:
			_set_stage("greet")
		elif stage_elapsed >= APPROACH_LIMIT:
			cancel("approach_timeout")
	elif distance > spacing + 2.0:
		cancel("separated")
	elif stage == "greet" and stage_elapsed >= GREETING_SECONDS:
		_set_stage("play")
	elif stage == "play" and stage_elapsed >= PLAY_SECONDS:
		_set_stage("rest")
	elif stage == "rest" and stage_elapsed >= REST_SECONDS:
		cancel("complete")

func _set_stage(value: String) -> void:
	stage = value
	stage_elapsed = 0.0
	for handle: WeakRef in [first, second]:
		var actor: Node = handle.get_ref()
		if is_instance_valid(actor):
			actor._sense_remaining = 0.0
			actor._steer_remaining = 0.0
			# Existing bounded audio observes this event; no new voice owner.
			if value == "greet": actor.audio_event.emit(&"friend")

func heading(actor: Node3D) -> Vector3:
	var other: Node3D = partner(actor)
	if not is_instance_valid(other): return Vector3.ZERO
	var toward: Vector3 = (other.global_position - actor.global_position).slide(actor.up_direction)
	var distance: float = toward.length()
	if distance < 0.01: return Vector3.ZERO
	var forward: Vector3 = toward / distance
	if stage == "approach":
		if distance < spacing * 0.75: return -forward
		return forward if distance > spacing + 0.15 else Vector3.ZERO
	if stage != "play": return Vector3.ZERO
	# Alternate invitation and response. This is a short sideways play step,
	# never a combat chase or a physics impulse; ordinary steering owns travel.
	var turn: int = int(stage_elapsed / 1.2) % 2
	var mover: bool = (first.get_ref() == actor) == (turn == 0)
	var correction: float = clampf((distance - spacing) * 0.8, -1.0, 1.0)
	if not mover: return forward * correction if absf(correction) > 0.25 else Vector3.ZERO
	var side: float = -1.0 if int(stage_elapsed / 2.4) % 2 == 0 else 1.0
	return (actor.up_direction.cross(forward) * side * 0.6 + forward * correction).normalized()
