extends RefCounted
## Nine underside witnesses on the actual skin; geometric evidence, not load.
const Fit = preload("res://creatures/runtime/creature_body_fit.gd")
const Contract = Fit.Contract
const Rider = Fit.Shapes.Rider
const MAX_GAP: float = 0.085
const MAX_SEAT_GAP: float = 0.035
const EPSILON: float = 0.001
const MAX_TILT: float = 35.0


static func inspect(blueprint: Dictionary, skin: ArrayMesh = null) -> Dictionary:
	var profile: Dictionary = Rider.read(blueprint)
	var report: Dictionary = {"schema": 1, "frame": "BodyV4", "active": false, "complete": false,
		"supported": false, "rider_seated": false, "samples": [], "errors": Rider.validate(profile)}
	if not report["errors"].is_empty():
		return report
	if skin == null:
		skin = Contract.Surface.build_skin(blueprint.duplicate(true))
	var resolved: Dictionary = Contract.resolve(blueprint, skin)
	report["errors"] = resolved["errors"]
	if not report["errors"].is_empty():
		return report
	if not resolved["sockets"].has("saddle.primary"):
		report["complete"] = true
		return report
	return inspect_socket(skin, resolved["sockets"]["saddle.primary"], Contract.Surface.Blueprint.get_body_scale(blueprint), profile)


static func inspect_socket(skin: ArrayMesh, socket: Transform3D, scale: float, profile: Dictionary) -> Dictionary:
	if skin == null or not skin.has_meta("voxel_cells") or scale <= 0.0 or not Rider.validate(profile).is_empty():
		return {"schema": 1, "frame": "BodyV4", "active": true, "complete": false, "supported": false,
			"rider_seated": false, "samples": [], "errors": ["unsupported_seat_query"]}
	var up: Vector3 = socket.basis.y.normalized()
	var report: Dictionary = {"schema": 1, "frame": "BodyV4", "active": true, "complete": true, "errors": [],
		"samples": [], "supported_samples": 0, "max_allowed_gap": MAX_GAP, "min_gap": 0.0, "max_gap": 0.0,
		"tilt_degrees": rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1, 1))),
		"supported": false, "rider_seated": false}
	var seat_gap: float = float(profile["seat_height"]) - 0.08 * float(profile["rider_scale"]) - 0.11
	report["rider_seat_gap"] = seat_gap
	report["rider_seated"] = seat_gap >= -EPSILON and seat_gap <= MAX_SEAT_GAP
	var reach: float = skin.get_aabb().size.length() + scale
	var gaps: Array[float] = []
	for z in [-0.22, 0.0, 0.22]:
		for x in [-0.16, 0.0, 0.16]:
			var underside: Vector3 = socket * Vector3(x * scale, 0, z * scale)
			var hit: Dictionary = Contract.Surface.Voxels.raycast(skin, underside + up * reach, -up)
			var sample: Dictionary = {"underside": Contract._array(underside), "supported": false}
			if not hit.is_empty():
				var gap: float = (underside - Vector3(hit["position"])).dot(up) / scale
				sample["skin"] = Contract._array(hit["position"])
				sample["gap"] = gap
				sample["supported"] = gap >= -EPSILON and gap <= MAX_GAP
				gaps.append(gap)
				if sample["supported"]:
					report["supported_samples"] += 1
			report["samples"].append(sample)
	if not gaps.is_empty():
		gaps.sort()
		report["min_gap"] = gaps[0]
		report["max_gap"] = gaps[-1]
	report["supported"] = report["supported_samples"] == 9 and float(report["tilt_degrees"]) <= MAX_TILT
	return report


static func proposal(preview: Node3D) -> Dictionary:
	if preview.get("motion_mode") != "edit":
		return {}
	var blueprint: Dictionary = preview.get("blueprint")
	var profile: Dictionary = Rider.read(blueprint)
	var data: Dictionary = Contract.Data.read(blueprint)
	if not Rider.validate(profile).is_empty() or not Contract.Data.validate(data).is_empty() or not data["sockets"]["saddle.primary"]["enabled"]:
		return {}
	var skin: MeshInstance3D = preview.get_node_or_null("BodyV4/SculptedSkin")
	if skin == null:
		return {}
	var scale: float = Contract.Surface.Blueprint.get_body_scale(blueprint)
	var geometry: Array = Fit.collect(preview)
	profile["seat_height"] = 0.12 + 0.08 * float(profile["rider_scale"])
	for shift in [0.0, -0.08, 0.08, -0.16, 0.16, -0.24, 0.24]:
		var candidate: Dictionary = blueprint.duplicate(true)
		var socket: Dictionary = data["sockets"]["saddle.primary"].duplicate(true)
		socket["t"] = clampf(float(socket["t"]) + shift, 0.12, 0.88)
		socket["offset"][1] = 0.0
		Contract.Data.set_socket(candidate, "saddle.primary", socket)
		var resolved: Dictionary = Contract.resolve(candidate, skin.mesh)
		if not resolved["sockets"].has("saddle.primary"):
			continue
		var pose: Transform3D = resolved["sockets"]["saddle.primary"]
		var support: Dictionary = inspect_socket(skin.mesh, pose, scale, profile)
		if float(support["tilt_degrees"]) > MAX_TILT:
			continue
		var frame: Basis = pose.basis * Basis.from_euler(Contract._vector(socket["rotation_degrees"]) * PI / 180.0).inverse()
		socket["offset"][1] = clampf((0.025 - float(support["min_gap"])) / maxf(frame.y.dot(pose.basis.y), 0.25), -0.5, 0.5)
		Contract.Data.set_socket(candidate, "saddle.primary", socket)
		resolved = Contract.resolve(candidate, skin.mesh)
		if not resolved["sockets"].has("saddle.primary"):
			continue
		pose = resolved["sockets"]["saddle.primary"]
		support = inspect_socket(skin.mesh, pose, scale, profile)
		if not support["supported"]:
			continue
		for increment in range(21):
			var fitted: Dictionary = profile.duplicate(true)
			fitted["leg_spacing"] = minf(float(profile["leg_spacing"]) + increment * 0.1, 2.4)
			var check: Dictionary = Fit.inspect_socket(geometry, "saddle.primary", preview.get_node("BodyV4").transform * pose, scale, Fit.SCAN_BUDGET, fitted)
			if check["complete"] and check["collisions"].is_empty():
				return {"socket": socket, "rider_profile": fitted, "support": support}
	return {}
