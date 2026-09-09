extends RefCounted
## Workshop and wildlife pose sampler. Authoring data is never changed.
const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
const LimbRig = preload("res://creatures/runtime/creature_limb_rig.gd")
const Gait = preload("res://creatures/runtime/creature_gait_profile.gd")
var _preview: Node3D
var _base_position := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _parts: Array[Dictionary] = []
var _legs: Array[Dictionary] = []
var _profile: Dictionary = {}
var _course: Node3D
var course_finished: bool = false


func bind(preview: Node3D) -> void:
	_preview = preview
	_base_position = preview.position
	_base_rotation = preview.rotation
	_parts.clear()
	_legs.clear()
	for child in preview.get_children():
		if child is Node3D and child.has_meta("creature_part_category"):
			_parts.append({"node": child, "position": child.position, "rotation": child.rotation})
	var legs: Array[Node3D] = []
	for part in _parts:
		if str(part["node"].get_meta("creature_part_category")) == "legs":
			legs.append(part["node"])
	legs.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.z < b.position.z)
	var animator := Animator.new()
	var ranks: Dictionary = {1: 0, -1: 0}
	for leg in legs:
		var side: int = 1 if float(leg.get_meta("creature_part_side", 1.0)) > 0.0 else -1
		var record: Dictionary = animator._create_runtime_leg_rig(leg)
		record["phase"] = Gait.phase_offset(legs.size(), int(ranks[side]), side)
		ranks[side] += 1
		_legs.append(record)
	animator.free()
	_profile = Gait.build(_legs)


func set_course(course: Node3D) -> void:
	_course = course
	course_finished = false


func unbind() -> void:
	reset()
	_preview = null
	_course = null
	_parts.clear()
	_legs.clear()
	course_finished = false


func reset() -> void:
	if is_instance_valid(_preview):
		_preview.position = _base_position
		_preview.rotation = _base_rotation
	for part in _parts:
		if is_instance_valid(part["node"]):
			part["node"].position = part["position"]
			part["node"].rotation = part["rotation"]
	for leg in _legs:
		if is_instance_valid(leg.get("knee")):
			leg["knee"].rotation = leg.get("knee_base_rotation", Vector3.ZERO)
		if bool(leg.get("sculpt_rig", false)) and is_instance_valid(leg.get("root")) and leg["root"].is_inside_tree() and is_instance_valid(_preview) and _preview.is_inside_tree():
			LimbRig.pose(leg, _preview.to_global(leg["rest_ankle_preview"]))


func sample(mode: String, time: float) -> void:
	if not is_instance_valid(_preview):
		return
	var moving: float = 1.0 if mode in ["walk", "run"] else 0.0
	var settings: Dictionary = Gait.parameters(_profile, mode == "run")
	var phase: float = time * float(settings["cadence"])
	var training: bool = is_instance_valid(_course) and str(_course.get("kind")) != "flat"
	var route := Vector3.ZERO
	var floor_rise: float = 0.0
	var terrain_pitch: float = 0.0
	course_finished = false
	if training:
		route = _course.call("route", time if moving > 0 else 0.0, settings["speed"])
		course_finished = moving > 0 and time >= float(_course.call("duration", settings["speed"]))
		if course_finished:
			moving = 0.0
		var ground: Dictionary = _course.call("surface", route)
		floor_rise = float(ground["height"]) - float(_preview.get_meta("ground_y", 0.0))
		# Smooth body pitch samples a wider footprint; feet still use each
		# exact tread and ramp normal.
		var front: Dictionary = _course.call("surface", route + Vector3.FORWARD * 0.45)
		var back: Dictionary = _course.call("surface", route + Vector3.BACK * 0.45)
		terrain_pitch = clampf(atan2(float(front["height"]) - float(back["height"]), 0.9), -0.32, 0.32)
	var rest_basis := Basis.from_euler(_base_rotation).scaled(_preview.scale)
	var reference := Transform3D(rest_basis, _base_position + route + Vector3.UP * floor_rise)
	var parent: Node3D = _preview.get_parent() as Node3D
	var parent_frame: Transform3D = parent.global_transform if parent != null else Transform3D.IDENTITY
	var world_reference: Transform3D = parent_frame * reference
	_preview.position = reference.origin + Vector3(sin(phase) * float(_profile.get("sway", 0.02)) * moving, sin(time * 2.0) * 0.012 + absf(sin(phase)) * float(_profile.get("bob", 0.02)) * moving, 0)
	_preview.rotation = _base_rotation + Vector3(terrain_pitch, 0, sin(phase) * 0.018 * moving)
	for part in _parts:
		var node: Node3D = part["node"]
		if not is_instance_valid(node):
			continue
		node.position = part["position"]
		node.rotation = part["rotation"]
		var category: String = str(node.get_meta("creature_part_category", ""))
		var side: float = float(node.get_meta("creature_part_side", 1.0))
		if category == "tail":
			node.rotation.y += sin(time * 2.5) * 0.20
		elif category == "arms":
			node.rotation.x += sin(phase + side * PI * 0.5) * 0.32 * moving
		elif category in ["mouth", "eyes"]:
			node.rotation.x += sin(time * 1.8) * 0.025
	for leg in _legs:
		if not is_instance_valid(leg["root"]):
			continue
		var stride: float = phase + float(leg["phase"])
		if bool(leg.get("sculpt_rig", false)):
			var step: Dictionary = Gait.sample(settings, stride, moving)
			var target: Vector3 = leg["rest_contact_preview"] + step["offset"]
			var contact_world: Vector3 = world_reference * target
			var normal_world: Vector3 = world_reference.basis.y.normalized()
			if training:
				var foot: Dictionary = _course_foot(leg, step, settings, time, moving, route, rest_basis)
				contact_world = parent_frame * foot["point"]
				normal_world = (parent_frame.basis * foot["normal"]).normalized()
			LimbRig.plant(leg, contact_world, normal_world, world_reference.basis)
			continue
		leg["root"].rotation.x += cos(stride) * (0.50 if mode == "run" else 0.32) * moving
		if is_instance_valid(leg.get("knee")):
			leg["knee"].rotation = leg.get("knee_base_rotation", Vector3.ZERO)
			leg["knee"].rotation.x += maxf(0.0, sin(stride)) * 0.55 * moving


func _course_foot(leg: Dictionary, step: Dictionary, settings: Dictionary, time: float, moving: float, route: Vector3, rest_basis: Basis) -> Dictionary:
	var rest: Vector3 = rest_basis * leg["rest_contact_preview"] + _base_position
	var target: Vector3 = rest + route
	var swing_height: float = -INF
	if moving > 0:
		var period: float = TAU / float(settings["cadence"])
		var landing_time: float = time - float(step["u"]) * period
		var from: Vector3 = rest + _course.call("route", landing_time, settings["speed"]) + Vector3.FORWARD * float(settings["stride"])
		target = from
		if bool(step["swing"]):
			var to: Vector3 = rest + _course.call("route", landing_time + period, settings["speed"]) + Vector3.FORWARD * float(settings["stride"])
			var swing_time: float = (float(step["u"]) - float(settings["duty"])) / (1.0 - float(settings["duty"]))
			target = from.lerp(to, smoothstep(0, 1, swing_time))
			var origin_surface: Dictionary = _course.call("surface", from)
			var landing_surface: Dictionary = _course.call("surface", to)
			# Clear a riser before crossing it, including one between the
			# endpoints; the collider is checked independently in acceptance.
			var highest: float = maxf(float(origin_surface["height"]), float(landing_surface["height"]))
			for sample_index in range(1, 5):
				var surface: Dictionary = _course.call("surface", from.lerp(to, float(sample_index) / 5.0))
				highest = maxf(highest, surface["height"])
			var baseline: float = lerpf(float(origin_surface["height"]), float(landing_surface["height"]), smoothstep(0, 1, swing_time))
			swing_height = baseline + sin(PI * swing_time) * (float(settings["lift"]) + highest - minf(float(origin_surface["height"]), float(landing_surface["height"])))
	var floor: Dictionary = _course.call("surface", target)
	target.y = maxf(float(floor["height"]), swing_height)
	return {"point": target, "normal": floor["normal"]}
