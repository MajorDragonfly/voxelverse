extends Node
## Transient recovery. Health == 0 in the existing player snapshot is the durable
## pending marker; loading starts a new attempt, never an old timer callback.
const Space = preload("res://world/surface/gameplay_space.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const PROTECTION_SECONDS: float = 5.0
const CANDIDATES_PER_FRAME: int = 3
var stage: String = "inactive"
var remaining: float = 0.0
var player: CharacterBody3D
var _anchor: Dictionary = {}
var _planar_anchor: Vector3
var _candidate: int = 0
var _earliest_physics_frame: int = 0
var _fallback: bool = false

func _ready() -> void:
	player = get_parent()
	var view := preload("res://ui/player_recovery_hud.gd").new()
	add_child(view)

func reset() -> void:
	stage = "inactive"
	remaining = 0.0
	_anchor.clear()
	_candidate = 0
	_fallback = false

func begin() -> void:
	reset()
	stage = "countdown"
	remaining = player.respawn_delay

func protected() -> bool:
	return stage == "protected" and remaining > 0.0

func end_protection() -> void:
	if protected(): reset()

func advance(delta: float) -> void:
	if stage == "inactive" or not _active(): return
	if stage == "protected":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0: reset()
		return
	if not player.is_dead:
		reset()
		return
	if stage in ["countdown", "blocked"]:
		remaining = maxf(0.0, remaining - delta)
		if remaining > 0.0: return
		if stage == "countdown":
			if not _prepare(false):
				_blocked()
				return
		else:
			if _anchor.is_empty():
				if not _prepare(_fallback):
					_blocked()
					return
			_candidate = 0
			stage = "preparing"
	if Engine.get_physics_frames() < _earliest_physics_frame: return
	# Only a few ground/shape queries per frame, independent of world size.
	for _index in range(CANDIDATES_PER_FRAME):
		if _candidate >= 25:
			if not _fallback and Space.adapter(player) != null and _prepare(true): return
			_blocked()
			return
		var point: Vector3 = _point(_candidate)
		if not Space.ground_ready(player, point): return
		_candidate += 1
		var safe: Dictionary = _landing(point)
		if safe.is_empty(): continue
		var before: Vector3 = player.global_position
		player.global_transform = safe.transform
		player.up_direction = safe.up
		player.surface_origin_shifted(player.global_position - before)
		stage = "protected"
		remaining = PROTECTION_SECONDS
		player._finish_recovery()
		return

func _active() -> bool:
	if get_tree().paused or not player.is_processing() or not player.is_physics_processing(): return false
	var flow := get_node_or_null("/root/SessionFlow")
	return flow == null or not flow.loading

func _blocked() -> void:
	stage = "blocked"
	remaining = 1.0

func _prepare(fallback: bool) -> bool:
	var surface: RefCounted = Space.adapter(player)
	if surface == null:
		var nest: Node3D = get_tree().get_first_node_in_group(&"player_nest")
		if nest == null or not nest.has_method("get_respawn_position"): return false
		_planar_anchor = nest.get_respawn_position()
	else:
		var body: Dictionary = get_node("/root/GameState").get_current_body_record()
		var spawn: Dictionary = body.get("surface_context", {}).get("spawn", {})
		var target: Dictionary = spawn if fallback else body.get("home_group", {}).get("anchor", spawn)
		if not Cube.valid(target, str(surface.terrain.surface.body.id)): return false
		_anchor = target.duplicate(true)
		_anchor.height = surface.sample(_anchor).height + 0.1
		# Rebase canonical double coordinates before creating local Vector3s.
		# Request ordinary budgeted streaming; no synchronous whole-cover build.
		surface.terrain.rebase(Cube.cartesian(_anchor, surface.terrain.surface.body.radius))
		var before: Vector3 = player.global_position
		player.global_position = Vector3.ZERO
		player.surface_origin_shifted(-before)
		player.global_basis = surface.frame_at(_anchor)
		player.up_direction = surface.up_at(_anchor)
		surface.terrain.set_motion_hint(player.up_direction, Vector3.ZERO)
		surface.terrain.stream_at(player.up_direction)
	_fallback = fallback
	_candidate = 0
	_earliest_physics_frame = Engine.get_physics_frames() + 2
	stage = "preparing"
	return true

func _point(index: int) -> Vector3:
	var offset := Vector3.ZERO
	if index > 0:
		var radius: float = 2.0 * (1 + int((index - 1) / 8))
		var angle: float = ((index - 1) % 8) * TAU / 8.0
		offset = Vector3(cos(angle), 0, sin(angle)) * radius
	var surface: RefCounted = Space.adapter(player)
	if surface == null: return _planar_anchor + offset
	var address: Dictionary = surface.offset(_anchor, surface.frame_at(_anchor) * offset, 0.1)
	return surface.to_local(address)

func _landing(point: Vector3) -> Dictionary:
	var hit: Dictionary = Space.floor_hit(player, point, 2.0, 4.0)
	if hit.is_empty(): return {}
	var up: Vector3 = Space.up(player, hit.position)
	if hit.normal.dot(up) < cos(player.floor_max_angle): return {}
	if not Space.dry(player, hit.position + up * 0.1, 0.05): return {}
	var pose := Transform3D(Space.frame(player, hit.position), hit.position + up * 0.08)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player.collision_shape.shape
	query.transform = pose * player.collision_shape.transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.margin = 0.02
	if not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): return {}
	return {"transform": pose, "up": up}
