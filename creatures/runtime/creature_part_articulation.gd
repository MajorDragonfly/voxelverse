extends RefCounted
## Cosmetic local joints. Bind once per rebuild, then touch only cached meshes.
## Geometry providers own pivots/limits; no mesh rebuild, reparent or save writes.
var _joints: Array[Dictionary] = []
var _action: String = ""
var _time: float = 0.0
var _duration: float = 0.0
var _mouth: float = 0.0
var _grip: float = 0.0
var _wing: float = 0.0
var _manual: bool = false


func bind(root: Node) -> void:
	unbind()
	_collect(root)


func _collect(root: Node) -> void:
	if root is Node3D and root.has_meta("part_articulation"):
		var shape: Vector3 = root.get_meta("part_shape", Vector3.ONE)
		var side: float = -1.0 if float(root.get_meta("creature_part_side", 1.0)) < 0.0 else 1.0
		for profile: Dictionary in root.get_meta("part_articulation"):
			var members: Array[Dictionary] = []
			for child: Node in root.get_children():
				if not child is MeshInstance3D: continue
				for prefix: String in profile.prefixes:
					if str(child.name).begins_with(prefix):
						members.append({"node": child, "rest": child.transform})
						break
			if members.is_empty(): continue
			# Axes are pseudovectors: reflecting X reverses rotations about Y/Z.
			_joints.append({"members": members, "channel": profile.channel,
				"pivot": profile.pivot * shape * Vector3(side, 1, 1),
				"axis": profile.axis * Vector3(1, side, side),
				"angle": deg_to_rad(float(profile.degrees))})
	for child: Node in root.get_children(): _collect(child)


func unbind() -> void:
	reset()
	_joints.clear()


func reset() -> void:
	_action = ""
	_time = 0.0
	_duration = 0.0
	_manual = false
	_mouth = 0.0
	_grip = 0.0
	_wing = 0.0
	_apply()


func play(action: String, duration: float = -1.0) -> bool:
	if action not in ["bite", "eat", "grip", "wing_stretch"]: return false
	if action == "wing_stretch" and not _joints.any(func(j: Dictionary) -> bool: return j.channel == "wing"): return false
	if not is_finite(duration): return false
	# A successful bite may interrupt chewing, never the other way round.
	if _action == "bite" and action == "eat": return false
	_action = action
	_time = 0.0
	_duration = clampf(duration, 0.08, 3.0) if duration > 0.0 else (0.9 if action == "eat" else 0.32)
	_manual = false
	return true


func set_pose(mouth: float, grip: float) -> void:
	_action = ""
	_manual = true
	_mouth = clampf(mouth, 0.0, 1.0) if is_finite(mouth) else 0.0
	_grip = clampf(grip, 0.0, 1.0) if is_finite(grip) else 0.0
	_apply()


func set_wing_pose(amount: float) -> void:
	_action = ""
	_manual = true
	_wing = clampf(amount, 0, 1) if is_finite(amount) else 0.0
	_apply()


func advance(delta: float, idle_time: float = -1.0) -> void:
	if _manual or not is_finite(delta) or delta <= 0.0: return
	var mouth_target: float = 0.0
	var grip_target: float = 0.0
	var wing_target: float = 0.0
	if not _action.is_empty():
		_time = minf(_time + delta, _duration)
		var progress: float = _time / _duration
		var wave: float = pow(sin(PI * progress), 2.0)
		if _action == "eat":
			mouth_target = pow(sin(PI * progress * 3.0), 2.0) * 0.55
		elif _action == "bite":
			mouth_target = wave
			grip_target = wave
		elif _action == "wing_stretch":
			wing_target = wave
		else:
			grip_target = wave
		if _time >= _duration: _action = ""
	elif idle_time >= 0.0 and is_finite(idle_time):
		# A quiet breathing/flex pose shared by the existing Stand preview and AI.
		mouth_target = (0.5 - 0.5 * cos(idle_time * 1.6)) * 0.055
		grip_target = (0.5 - 0.5 * cos(idle_time * 1.1)) * 0.14
		wing_target = (0.5 - 0.5 * cos(idle_time * 1.25)) * 0.12
	var blend: float = 1.0 - exp(-26.0 * delta)
	_mouth = lerpf(_mouth, mouth_target, blend)
	_grip = lerpf(_grip, grip_target, blend)
	_wing = lerpf(_wing, wing_target, blend)
	if wing_target == 0.0 and _wing < 0.00001: _wing = 0.0
	if mouth_target == 0.0 and _mouth < 0.00001: _mouth = 0.0
	if grip_target == 0.0 and _grip < 0.00001: _grip = 0.0
	_apply()


func is_active() -> bool:
	return not _action.is_empty() or (not _manual and (_mouth > 0.0 or _grip > 0.0 or _wing > 0.0))


func debug_state() -> Dictionary:
	return {"joints": _joints.size(), "action": _action, "time": _time,
		"mouth": _mouth, "grip": _grip, "wing": _wing, "manual": _manual}


func _apply() -> void:
	for joint: Dictionary in _joints:
		var amount: float = {"mouth": _mouth, "grip": _grip, "wing": _wing}.get(joint.channel, 0.0)
		var rotation := Basis(joint.axis, float(joint.angle) * amount)
		var pivot: Vector3 = joint.pivot
		for member: Dictionary in joint.members:
			if not is_instance_valid(member.node): continue
			var rest: Transform3D = member.rest
			member.node.transform = rest if amount == 0.0 else Transform3D(
				rotation * rest.basis, pivot + rotation * (rest.origin - pivot))
