extends RefCounted
## Body-local geometric evidence for D1. This is not an animal suitability model.
const Data = preload("res://assembly/core/creature_body_attachments.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const LimbRig = preload("res://creatures/runtime/creature_limb_rig.gd")
const SCHEMA: int = 1


static func resolve(blueprint: Dictionary, skin: ArrayMesh = null) -> Dictionary:
	var data: Dictionary = Data.read(blueprint)
	var errors: Array[String] = Data.validate(data)
	var result: Dictionary = {"schema": SCHEMA, "frame": "BodyV4", "forward": "-Z", "up": "+Y",
		"source": "saved" if blueprint.get("assembly", {}).has(Data.KEY) else "legacy_default",
		"sockets": {}, "errors": errors}
	if not errors.is_empty():
		return result
	# Legacy reads are pure, including Spine.ensure_profile inside the mesher.
	var design: Dictionary = blueprint.duplicate(true)
	if skin == null:
		skin = Surface.build_skin(design)
	result["body_bounds"] = {"position": _array(skin.get_aabb().position), "size": _array(skin.get_aabb().size)}
	for id in Data.IDS:
		var socket: Dictionary = data["sockets"][id]
		if not socket["enabled"]:
			continue
		var t: float = socket["t"]
		var cross: Dictionary = Surface.section(design, t)
		var outward: Vector3 = Vector3.UP if id == "saddle.primary" else (Vector3.LEFT if id == "harness.left" else Vector3.RIGHT)
		var ray_origin: Vector3 = cross["center"] + outward * (skin.get_aabb().size.length() + 1.0)
		var hit: Dictionary = Surface.Voxels.raycast(skin, ray_origin, -outward)
		if hit.is_empty():
			errors.append("surface_missing:" + id)
			continue
		var front: Vector3 = _dorsal(design, t - 0.025)
		var back: Vector3 = _dorsal(design, t + 0.025)
		var z_axis: Vector3 = (back - front).normalized()
		var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
		var frame := Basis(x_axis, z_axis.cross(x_axis).normalized(), z_axis)
		var scale: float = Surface.Blueprint.get_body_scale(design)
		var position: Vector3 = hit["position"] + outward * (0.04 * scale) + frame * _vector(socket["offset"]) * scale
		var cell_size: float = skin.get_meta("voxel_size")
		if skin.get_meta("voxel_cells", {}).has(Vector3i((position / cell_size).floor())):
			errors.append("socket_inside_skin:" + id)
			continue
		var rotation: Vector3 = _vector(socket["rotation_degrees"]) * (PI / 180.0)
		result["sockets"][id] = Transform3D(frame * Basis.from_euler(rotation), position)
	return result


static func describe(blueprint: Dictionary) -> Dictionary:
	var resolved: Dictionary = resolve(blueprint)
	var sockets: Dictionary = {}
	for id in resolved["sockets"]:
		sockets[id] = encode_transform(resolved["sockets"][id])
	var legs: int = 0
	for value in blueprint.get("parts", []):
		if value is Dictionary and str(value.get("category", "")) == "legs":
			var point: Vector3 = Surface.Blueprint._as_vector3(value.get("position", Vector3.ZERO))
			legs += 2 if bool(value.get("mirrored", false)) and not bool(value.get("center_locked", false)) and absf(point.x) >= 0.005 else 1
	return {"schema": SCHEMA, "design_id": str(blueprint.get("design_id", "")),
		"frame": resolved["frame"], "forward": "-Z", "up": "+Y", "units": "design_units",
		"attachment_source": resolved["source"], "attachment_schema": Data.SCHEMA,
		"sockets": sockets, "errors": resolved["errors"], "authored_leg_count": legs,
		"body_bounds": resolved.get("body_bounds", {}),
		"requires_runtime_contact_check": true, "suitability_owner": "D1"}


static func inspect_rest(preview: Node3D) -> Dictionary:
	var feet: Array = []
	var max_gap: float = 0.0
	var max_stretch: float = 1.0
	var ground: float = preview.get_meta("ground_y", 0.0)
	for child in preview.get_children():
		if not child is Node3D or child.get_meta("creature_part_category", "") != "legs" or not child.has_meta("sculpt_limb_rig"):
			continue
		var rig: Dictionary = child.get_meta("sculpt_limb_rig")
		var point: Vector3 = preview.to_local(rig["foot"].global_position)
		var gap: float = absf(point.y - ground)
		max_gap = maxf(max_gap, gap)
		max_stretch = maxf(max_stretch, float(rig["upper_length"]) / float(rig["authored_upper_length"]))
		feet.append({"part_uid": str(child.get_meta("creature_part_uid", "")), "side": child.get_meta("creature_part_side", 1.0),
			"position": _array(point), "gap": gap,
			"rest_stretch": float(rig["upper_length"]) / float(rig["authored_upper_length"])})
	return {"schema": SCHEMA, "pose": "rest_only", "leg_count": feet.size(), "feet": feet,
		"max_contact_error": max_gap, "max_rest_stretch": max_stretch,
		"all_feet_on_plane": not feet.is_empty() and max_gap <= 0.002}


static func encode_transform(value: Transform3D) -> Dictionary:
	return {"position": _array(value.origin), "basis_x": _array(value.basis.x),
		"basis_y": _array(value.basis.y), "basis_z": _array(value.basis.z)}


static func _dorsal(blueprint: Dictionary, t: float) -> Vector3:
	var cross: Dictionary = Surface.section(blueprint, t)
	return cross["center"] + Vector3.UP * float(cross["radius"].y)


static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


static func _array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
