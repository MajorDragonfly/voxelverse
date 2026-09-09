extends RefCounted
## Incremental, disposable review of authored geometry on the workshop course.
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Course = preload("res://creatures/editor/creature_test_course.gd")
const Fit = preload("res://creatures/runtime/creature_body_fit.gd")
const Support = preload("res://creatures/runtime/creature_saddle_support.gd")
const SAMPLES_PER_CYCLE: int = 32
const MAX_SCENARIO_SAMPLES: int = 512
var report: Dictionary = {}
var _lab: Node3D
var _preview: Node3D
var _course: Node3D
var _design: Dictionary
var _scenario: int = 0
var _sample: int = 0
var _count: int = 0
var _duration: float = 0.0
var _current: Dictionary = {}
var _all_complete: bool = true


func start(parent: Node, blueprint: Dictionary) -> void:
	dispose()
	_design = blueprint.duplicate(true)
	report = {"schema": 1, "design_id": str(blueprint.get("design_id", "")),
		"geometry_profile": Fit.Shapes.ADJUSTABLE_PROFILE, "checked_sockets": [],
		"source_fingerprint": var_to_str(blueprint).sha256_text(), "rider_profile": Fit.Shapes.Rider.read(blueprint),
		"status": "running", "complete": false, "coverage": "sampled_poses", "continuous_clearance": false,
		"samples_per_cycle": SAMPLES_PER_CYCLE, "samples_checked": 0, "scenarios": [],
		"support": Support.inspect(blueprint), "errors": [], "suitability_owner": "D1"}
	var validation: Array[String] = Fit.Contract.Data.validate(Fit.Contract.Data.read(blueprint))
	validation.append_array(Fit.Shapes.Rider.validate(report["rider_profile"]))
	if not validation.is_empty():
		report["errors"] = validation
		report["status"] = "invalid"
		return
	_lab = Node3D.new()
	_lab.name = "IsolatedFitReview"
	_lab.visible = false
	parent.add_child(_lab)
	_preview = Preview.new()
	_lab.add_child(_preview)
	_course = Course.new()
	_lab.add_child(_course)
	_scenario = 0
	_all_complete = true
	_begin_scenario()


func _begin_scenario() -> void:
	var kind: String = ["flat", "slope", "steps"][_scenario / 2]
	var mode: String = "walk" if _scenario % 2 == 0 else "run"
	_preview.set_motion("edit")
	_preview.set_editor_state(_design.duplicate(true), -1, -1, false)
	_course.configure(kind, _preview.get_meta("ground_y"), Fit.Contract.LimbRig.bounds(_preview).size)
	# Hidden geometry must not intercept editor picking or world physics.
	# Review uses the same analytic course surface as the existing animator.
	for collider in _lab.find_children("*", "CollisionObject3D", true, false):
		collider.collision_layer = 0
		collider.collision_mask = 0
		collider.input_ray_pickable = false
	_preview.set_motion(mode)
	_preview.set_process(false)
	var motion: RefCounted = _preview.get("_motion")
	motion.set_course(_course)
	var parameters: Dictionary = motion.Gait.parameters(motion.get("_profile"), mode == "run")
	var period: float = TAU / float(parameters["cadence"])
	_duration = period * 2 if kind == "flat" else maxf(period, _course.duration(parameters["speed"]))
	var requested: int = ceili(_duration / period * SAMPLES_PER_CYCLE) + 1
	_count = mini(requested, MAX_SCENARIO_SAMPLES)
	_sample = 0
	_current = {"course": kind, "mode": mode, "duration": _duration, "sample_count": _count,
		"requested_samples": requested, "time_step": _duration / float(_count - 1),
		"complete": requested <= MAX_SCENARIO_SAMPLES, "collision_samples": 0, "first_collision": {},
		"findings": [], "findings_truncated": false,
		"minimum_supporting_feet": -1, "max_foot_penetration": 0.0, "max_total_stretch": 1.0}


func step(max_poses: int = 8) -> bool:
	if report.get("status") != "running":
		return true
	if not is_instance_valid(_lab) or not is_instance_valid(_preview):
		cancel()
		return true
	var deadline: int = Time.get_ticks_usec() + 8000
	for iteration in range(max_poses):
		var time: float = _duration * float(_sample) / float(_count - 1)
		_preview.get("_motion").sample(_current["mode"], time)
		var sample: Dictionary = Fit.inspect(_preview)
		report["checked_sockets"] = sample["checked_sockets"].duplicate()
		_current["complete"] = _current["complete"] and sample["complete"]
		if not sample["collisions"].is_empty():
			_current["collision_samples"] += 1
			if _current["first_collision"].is_empty():
				_current["first_collision"] = {"time": time, "collisions": sample["collisions"]}
			for hit: Dictionary in sample["collisions"]:
				var known: bool = false
				for finding: Dictionary in _current["findings"]:
					var old: Dictionary = finding["collision"]
					known = known or (old["socket_id"] == hit["socket_id"] and old["shape_id"] == hit["shape_id"] and old["part_uid"] == hit["part_uid"] and old["side"] == hit["side"])
				if not known:
					if _current["findings"].size() < 128:
						_current["findings"].append({"time": time, "collision": hit})
					else:
						_current["findings_truncated"] = true
						_current["complete"] = false
		_measure_feet()
		report["samples_checked"] += 1
		_sample += 1
		if _sample >= _count:
			_all_complete = _all_complete and _current["complete"]
			report["scenarios"].append(_current)
			_scenario += 1
			if _scenario >= 6:
				report["complete"] = _all_complete
				report["status"] = "completed"
				dispose()
				return true
			_begin_scenario()
		if Time.get_ticks_usec() >= deadline:
			break
	return false


func _measure_feet() -> void:
	var grounded: int = 0
	for child in _preview.get_children():
		if child.get_meta("creature_part_category", "") != "legs" or not child.has_meta("sculpt_limb_rig"):
			continue
		var rig: Dictionary = child.get_meta("sculpt_limb_rig")
		var foot: Vector3 = _lab.to_local(rig["foot"].global_position)
		var gap: float = foot.y - float(_course.surface(foot)["height"])
		grounded += 1 if absf(gap) <= 0.002 else 0
		_current["max_foot_penetration"] = maxf(float(_current["max_foot_penetration"]), -gap)
		var stretch: float = float(rig["upper_length"]) / float(rig["authored_upper_length"]) * rig["upper"].scale.y
		_current["max_total_stretch"] = maxf(float(_current["max_total_stretch"]), stretch)
	_current["minimum_supporting_feet"] = grounded if int(_current["minimum_supporting_feet"]) < 0 else mini(grounded, _current["minimum_supporting_feet"])


func cancel() -> void:
	if report.get("status") == "running":
		report["status"] = "cancelled"
		report["complete"] = false
	dispose()


func dispose() -> void:
	if is_instance_valid(_lab):
		_lab.free()
	_lab = null
	_preview = null
	_course = null
