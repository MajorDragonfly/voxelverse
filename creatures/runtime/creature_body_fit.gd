extends RefCounted
## Read-only, on-demand evidence. Never a species suitability decision.
const Contract = preload("res://creatures/runtime/creature_body_contract.gd")
const Shapes = preload("res://creatures/runtime/creature_body_fit_shapes.gd")
const Overlap = preload("res://creatures/runtime/creature_voxel_overlap.gd")
const Joints = preload("res://creatures/editor/creature_joint_profile.gd")
const SCHEMA: int = 1
const STRETCH_NOTICE: float = 1.2
const SCAN_BUDGET: int = 200000


static func inspect(preview: Node3D) -> Dictionary:
	var report: Dictionary = {"schema": SCHEMA, "profile": Shapes.PROFILE, "frame": "preview_local",
		"pose": "rest" if preview.get("motion_mode") == "edit" else "single_motion_sample",
		"complete": true, "checked_sockets": [], "collisions": [], "errors": [], "cells_tested": 0,
		"rest_stretch_notice": STRETCH_NOTICE, "stretched_legs": [], "suitability_owner": "D1"}
	var profile: Dictionary = Shapes.Rider.read(preview.get("blueprint"))
	report["rider_profile"] = profile
	if Contract.Data.read(preview.get("blueprint")).has(Shapes.Rider.KEY):
		report["profile"] = Shapes.ADJUSTABLE_PROFILE
	report["errors"] = Shapes.Rider.validate(profile)
	if not report["errors"].is_empty():
		report["complete"] = false
		return report
	var body: Node3D = preview.get_node_or_null("BodyV4")
	var skin: MeshInstance3D = preview.get_node_or_null("BodyV4/SculptedSkin")
	if body == null or skin == null:
		report["complete"] = false
		report["errors"].append("sculpted_skin_missing")
		return report
	var resolved: Dictionary = Contract.resolve(preview.get("blueprint"), skin.mesh)
	report["errors"] = resolved["errors"].duplicate()
	report["complete"] = report["errors"].is_empty()
	var geometry: Array = collect(preview)
	var scale: float = Contract.Surface.Blueprint.get_body_scale(preview.get("blueprint"))
	for id in resolved["sockets"]:
		var sample: Dictionary = inspect_socket(geometry, id, body.transform * resolved["sockets"][id], scale, SCAN_BUDGET - int(report["cells_tested"]), profile)
		report["checked_sockets"].append(id)
		report["collisions"].append_array(sample["collisions"])
		report["cells_tested"] += sample["cells_tested"]
		report["complete"] = report["complete"] and sample["complete"]
	# Rest lengths are retained in the rig even while pose/foot locations move.
	for child in preview.get_children():
		if child.get_meta("creature_part_category", "") != "legs" or not child.has_meta("sculpt_limb_rig"):
			continue
		var rig: Dictionary = child.get_meta("sculpt_limb_rig")
		var stretch: float = float(rig["upper_length"]) / float(rig["authored_upper_length"])
		if stretch > STRETCH_NOTICE:
			report["stretched_legs"].append({"part_uid": str(child.get_meta("creature_part_uid", "")),
				"side": child.get_meta("creature_part_side", 1.0), "stretch": stretch,
				"position": Contract._array(child.position)})
	return report


static func collect(preview: Node3D) -> Array:
	var geometry: Array = []
	for child in preview.get_children():
		if child is Node3D and (child.name == "BodyV4" or child.has_meta("creature_part_uid")):
			_collect(child, Transform3D.IDENTITY, str(child.get_meta("creature_part_uid", "body")),
				str(child.get_meta("creature_part_category", "body")), float(child.get_meta("creature_part_side", 0)), geometry)
	return geometry


static func _collect(node: Node3D, parent: Transform3D, uid: String, category: String, side: float, geometry: Array) -> void:
	if node is CollisionObject3D or node.get_meta("editor_guide", false):
		return
	var local: Transform3D = parent * node.transform
	if node is MeshInstance3D and node.mesh != null:
		geometry.append({"mesh": node.mesh, "transform": local, "part_uid": uid, "category": category, "side": side})
	elif node is MultiMeshInstance3D:
		# A legacy batched surface has no exact voxel occupancy for this query.
		geometry.append({"mesh": null, "part_uid": uid})
	for child in node.get_children():
		if child is Node3D:
			_collect(child, local, uid, category, side, geometry)


static func inspect_socket(geometry: Array, id: String, socket: Transform3D, scale: float, budget: int = SCAN_BUDGET, profile: Dictionary = Shapes.Rider.DEFAULT) -> Dictionary:
	var result: Dictionary = {"complete": true, "collisions": [], "cells_tested": 0}
	if not Shapes.Rider.validate(profile).is_empty():
		result["complete"] = false
		return result
	var pose: Transform3D = socket * Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO)
	for shape: Dictionary in Shapes.boxes(id, profile):
		var found: Dictionary = {}
		for piece: Dictionary in geometry:
			if piece["mesh"] == null:
				result["complete"] = false
				continue
			var key: String = "%s:%s" % [piece["part_uid"], piece["side"]]
			if found.has(key):
				continue
			var check: Dictionary = Overlap.query(piece["mesh"], pose.affine_inverse() * piece["transform"], shape["bounds"], mini(Overlap.LIMIT, maxi(0, budget - int(result["cells_tested"]))))
			result["cells_tested"] += check["cells_tested"]
			result["complete"] = result["complete"] and check["complete"]
			if check["hit"]:
				found[key] = true
				result["collisions"].append({"socket_id": id, "shape_id": shape["id"], "part_uid": piece["part_uid"],
					"category": piece["category"], "side": piece["side"], "position": Contract._array(pose * check["point"])})
	return result


static func socket_proposal(preview: Node3D, id: String) -> Dictionary:
	if preview.get("motion_mode") != "edit" or id not in Contract.Data.IDS:
		return {}
	var blueprint: Dictionary = preview.get("blueprint")
	var profile: Dictionary = Shapes.Rider.read(blueprint)
	if not Shapes.Rider.validate(profile).is_empty():
		return {}
	var data: Dictionary = Contract.Data.read(blueprint)
	if not Contract.Data.validate(data).is_empty() or not data["sockets"][id]["enabled"]:
		return {}
	var skin: MeshInstance3D = preview.get_node_or_null("BodyV4/SculptedSkin")
	if skin == null:
		return {}
	var original: Dictionary = data["sockets"][id]
	var candidates: Array = []
	# First try another location on the skin. Then propose a visibly stated
	# outward offset. This is clearance only, not proof of saddle support.
	for shift in [-0.08, 0.08, -0.16, 0.16, -0.24, 0.24]:
		var socket: Dictionary = original.duplicate(true)
		socket["t"] = clampf(float(socket["t"]) + shift, 0.12, 0.88)
		candidates.append(socket)
	for step in range(1, 11):
		var socket: Dictionary = original.duplicate(true)
		var axis: int = 1 if id == "saddle.primary" else 0
		var direction: float = -1.0 if id == "harness.left" else 1.0
		socket["offset"][axis] = clampf(float(original["offset"][axis]) + step * 0.05 * direction, -0.5, 0.5)
		candidates.append(socket)
	var geometry: Array = collect(preview)
	for socket: Dictionary in candidates:
		var candidate: Dictionary = blueprint.duplicate(true)
		Contract.Data.set_socket(candidate, id, socket)
		var resolved: Dictionary = Contract.resolve(candidate, skin.mesh)
		if not resolved["sockets"].has(id):
			continue
		var sample: Dictionary = inspect_socket(geometry, id, preview.get_node("BodyV4").transform * resolved["sockets"][id], Contract.Surface.Blueprint.get_body_scale(candidate), SCAN_BUDGET, profile)
		if sample["complete"] and sample["collisions"].is_empty():
			return {"socket_id": id, "socket": socket, "profile": Shapes.PROFILE}
	return {}


static func leg_candidate(blueprint: Dictionary, report: Dictionary, uid: String) -> Dictionary:
	var factor: float = 1.0
	for leg: Dictionary in report["stretched_legs"]:
		if leg["part_uid"] == uid:
			factor = maxf(factor, float(leg["stretch"]) * 1.02)
	if factor <= 1.0:
		return {}
	var candidate: Dictionary = blueprint.duplicate(true)
	for part: Dictionary in candidate.get("parts", []):
		if part.get("uid", "") == uid and part.get("category", "") == "legs":
			var joint: Dictionary = Joints.read(part.get("joint", {}))
			if is_equal_approx(float(joint["upper"]), 2.2) and is_equal_approx(float(joint["lower"]), 2.2):
				return {}
			joint["upper"] = minf(float(joint["upper"]) * factor, 2.2)
			joint["lower"] = minf(float(joint["lower"]) * factor, 2.2)
			part["joint"] = joint
			return candidate
	return {}
