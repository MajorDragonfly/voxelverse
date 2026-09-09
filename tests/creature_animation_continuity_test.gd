extends SceneTree
## Exercise live transitions and actual articulated feet, not just curve values.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Gait = preload("res://creatures/runtime/creature_gait_profile.gd")
const Animator = preload("res://creatures/runtime/adaptive_locomotion_animator.gd")
var failures: Array[String] = []
var evidence: Array[Dictionary] = []

class Actor extends CharacterBody3D:
	var move_speed: float = 2.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_contacts()
	for pairs in [1, 2, 3]:
		var endpoints: Array[Vector3] = []
		for fps in [30, 60, 144]:
			endpoints.append(_check_live(pairs, fps))
		_expect(endpoints[0].distance_to(endpoints[2]) < 0.025, "Frame rate changed the settled pose")
	await _check_ground(Vector3.ZERO)
	await _check_ground(Vector3(0.4, 0.0, 1.2))
	for failure in failures:
		push_error(failure)
	print("CREATURE_ANIMATION_CONTINUITY " + JSON.stringify(evidence))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _design(pairs: int) -> Dictionary:
	var design: Dictionary = Assembly.create_default()
	for index in range(pairs - 1):
		Assembly.BaseBlueprint.add_part(design, "legs_walker")
	Assembly.BaseBlueprint.add_part(design, "tail_balance")
	Anatomy.reset_all_anchors(design)
	return design


func _preview(pairs: int, parent: Node) -> Preview:
	var preview := Preview.new()
	preview.name = "BlueprintCreatureVisual"
	parent.add_child(preview)
	preview.set_editor_state(_design(pairs), -1, -1, false)
	for collider in preview.find_children("*", "CollisionObject3D", true, false):
		collider.collision_layer = 0
		collider.collision_mask = 0
	return preview


func _check_contacts() -> void:
	for count in [2, 4, 6]:
		var profile := {"count": count, "stride": 0.3, "lift": 0.12, "cadence": 5.0}
		for run in [0.0, 0.5, 1.0]:
			var settings: Dictionary = Gait.blended_parameters(profile, run)
			for boundary in [float(settings["duty"]), 1.0]:
				var h: float = 0.00001
				var before: Vector3 = Gait.sample(settings, (boundary - h) * TAU)["offset"]
				var at: Vector3 = Gait.sample(settings, boundary * TAU)["offset"]
				var after: Vector3 = Gait.sample(settings, (boundary + h) * TAU)["offset"]
				_expect(((at - before) / h).distance_to((after - at) / h) < 0.02, "Foot velocity jumps at contact")


func _check_live(pairs: int, fps: int) -> Vector3:
	var preview := _preview(pairs, root)
	var authored: String = var_to_str(preview.blueprint)
	preview.set_motion("idle")
	preview.set_process(false)
	var foot: Node3D = preview._motion._legs[0]["foot"]
	var previous: Vector3 = foot.global_position
	var maximum_step: float = 0.0
	var maximum_switch: float = 0.0
	for frame in range(fps * 6):
		var time: float = float(frame) / fps
		var mode: String = "idle" if time < 0.5 or time >= 4.0 else "walk" if time < 2.0 else "run"
		# Repeated requests are intentional: they must not reset any animation.
		var before: Vector3 = foot.global_position
		var clock: float = preview._motion_time
		preview.set_motion(mode)
		preview.set_process(false)
		maximum_switch = maxf(maximum_switch, before.distance_to(foot.global_position))
		_expect(preview._motion_time == clock, "Locomotion request reset the live clock")
		preview._process(1.0 / fps)
		maximum_step = maxf(maximum_step, previous.distance_to(foot.global_position))
		_expect(foot.global_position.is_finite(), "Non-finite articulated foot")
		previous = foot.global_position
	_expect(maximum_switch < 0.00001, "Mode change snapped the pose before the next frame")
	_expect(maximum_step < 0.16, "Live foot moved more than 16 cm in one frame")
	_expect(preview._motion._live_blend < 0.0001, "Stopped creature keeps stepping")
	_expect(var_to_str(preview.blueprint) == authored, "Live motion mutated the blueprint")
	var endpoint: Vector3 = foot.global_position
	preview.set_motion("edit")
	_expect(not preview.is_processing(), "Authoring mode keeps animating")
	evidence.append({"pairs": pairs, "fps": fps, "max_foot_delta": maximum_step, "switch_delta": maximum_switch})
	preview.free()
	return endpoint


func _check_ground(angles: Vector3) -> void:
	var world := Node3D.new()
	world.rotation = angles
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.2, 30)
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	var actor := Actor.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = 0.6
	actor.add_child(collider)
	actor.floor_snap_length = 0.3
	actor.position.y = 0.03
	world.add_child(actor)
	actor.up_direction = world.global_basis.y
	var visual := Node3D.new()
	visual.name = "CreatureRuntimeVisual"
	actor.add_child(visual)
	var preview := _preview(2, visual)
	preview.position.y = -float(preview.get_meta("ground_y"))
	var animator := Animator.new()
	actor.add_child(animator)
	animator.set_physics_process(false)
	await process_frame
	animator._bind_runtime_visual()
	var max_delta: float = 0.0
	var max_frame: Dictionary = {}
	var previous: Array[Vector3] = []
	for frame in range(150):
		await physics_frame
		var speed: float = 1.2 if frame >= 10 and frame < 90 else 0.0
		actor.velocity = actor.global_basis * Vector3(0, -0.5, -speed)
		actor.move_and_slide()
		actor.apply_floor_snap()
		animator._physics_process(1.0 / 60.0)
		for index in range(animator._leg_records.size()):
			var foot: Node3D = animator._leg_records[index]["foot"]
			var point: Vector3 = world.to_local(foot.global_position)
			_expect(point.is_finite() and point.y > -0.025, "Grounded foot penetrated radial floor")
			if frame > 0:
				if point.distance_to(previous[index]) > max_delta:
					max_frame = {"frame": frame, "leg": index, "from": str(previous[index]), "to": str(point), "phase": animator._phase, "swing": animator._leg_records[index].get("swing"), "grounded": actor.is_on_floor()}
				max_delta = maxf(max_delta, point.distance_to(previous[index]))
			else:
				previous.append(point)
			previous[index] = point
		if frame == 75:
			# Local origin correction must preserve cached contacts exactly.
			var shift := Vector3(40, -20, 30)
			world.position += shift
			animator.surface_origin_shifted(shift)
	_expect(max_delta < 0.18, "Planted foot snapped on release or origin shift")
	# A gait wrap must not reset independent breathing/tail/head oscillators.
	animator._phase = TAU - 0.00001
	animator._animate_non_leg_parts()
	var rotations: Array[Vector3] = []
	for part in animator._part_roots:
		rotations.append(part.rotation)
	animator._phase = 0.00001
	animator._animate_non_leg_parts()
	for index in range(rotations.size()):
		_expect(rotations[index].distance_to(animator._part_roots[index].rotation) < 0.0001, "Body part snapped at cycle wrap")
	evidence.append({"radial_angles": str(angles), "max_ground_foot_delta": max_delta, "maximum": max_frame})
	world.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
