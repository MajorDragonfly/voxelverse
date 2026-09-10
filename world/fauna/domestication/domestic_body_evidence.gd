extends RefCounted
## D1 owns suitability. B1 supplies geometry and actual runtime foot contacts.
const Contract = preload("res://world/fauna/domestication/domestication_contract.gd")
const Body = preload("res://creatures/runtime/creature_body_contract.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const SCHEMA: int = 1
const POLICY: String = "domestic_body_v1"
const EGG_POLICY: String = "domestic_egg_body_v1"
const SOCKETS: Array[String] = ["saddle.primary", "harness.left", "harness.right"]
const MAX_GAP: float = 0.002

static func fingerprint(entry: Dictionary) -> String:
	# JSON numbers must have the same representation before and after a cold load.
	return JSON.stringify(JSON.parse_string(JSON.stringify(entry["blueprint"]))).sha256_text()

static func inspect(entry: Dictionary, parent: Node, ready_preview: Node3D = null) -> Dictionary:
	var blueprint: Dictionary = Contract.decode(entry["blueprint"])
	# The spawner supplies the freshly built body before its first simulation tick.
	var preview: Node3D = ready_preview
	var previous_motion: String = "edit"
	if preview == null:
		preview = Preview.new()
		preview.visible = false
		parent.add_child(preview)
		preview.set_editor_state(blueprint.duplicate(true), -1, -1, false)
	else:
		previous_motion = preview.motion_mode
		preview.set_motion("edit")
	var skin: MeshInstance3D = preview.get_node_or_null("BodyV4/SculptedSkin")
	var body: Dictionary = Body.describe(blueprint, skin.mesh if skin != null else null)
	var rest: Dictionary = Body.inspect_rest(preview)
	if ready_preview == null: preview.free()
	else: preview.set_motion(previous_motion)
	var errors: Array[String] = assess(body, rest, str(entry["group"]))
	return {"schema": SCHEMA, "policy_version": EGG_POLICY if entry.group == "eggs" else POLICY, "source_sha256": fingerprint(entry),
		"status": "passed" if errors.is_empty() else "rejected", "errors": errors,
		"body": body, "rest": rest}

static func confirm(entry: Dictionary, parent: Node, ready_preview: Node3D = null) -> bool:
	if entry.has("body_evidence"): return false
	entry["body_evidence"] = inspect(entry, parent, ready_preview)
	return true

static func approved(entry: Dictionary) -> bool:
	return entry.get("body_evidence") is Dictionary and entry["body_evidence"].get("status") == "passed" and validate(entry).is_empty()

static func unsupported(entry: Dictionary) -> bool:
	var blueprint: Variant = entry.get("blueprint")
	var assembly: Variant = blueprint.get("assembly", {}) if blueprint is Dictionary else {}
	if assembly is Dictionary and assembly.get("body_attachments") is Dictionary:
		if not Contract.integer(assembly["body_attachments"].get("schema"), 1, 1): return true
	if not entry.get("body_evidence") is Dictionary: return false
	var value: Dictionary = entry["body_evidence"]
	if not Contract.integer(value.get("schema"), SCHEMA, SCHEMA) or value.get("policy_version") != (EGG_POLICY if entry.get("group") == "eggs" else POLICY): return true
	for key in ["body", "rest"]:
		if value.get(key) is Dictionary and not Contract.integer(value[key].get("schema"), 1, 1): return true
	if value.get("body") is Dictionary and not Contract.integer(value["body"].get("attachment_schema"), 1, 1): return true
	return false

static func validate(entry: Dictionary) -> String:
	if not entry.has("body_evidence"): return ""
	var value: Variant = entry["body_evidence"]
	if not value is Dictionary or unsupported(entry): return "Unsupported domestic body evidence."
	if value.get("source_sha256") != fingerprint(entry): return "Domestic body evidence belongs to another blueprint."
	if not value.get("body") is Dictionary or not value.get("rest") is Dictionary or not value.get("errors") is Array:
		return "Incomplete domestic body evidence."
	var errors: Array[String] = assess(value["body"], value["rest"], str(entry["group"]))
	if value["errors"] != errors or value.get("status") != ("passed" if errors.is_empty() else "rejected"):
		return "Domestic body evidence and verdict disagree."
	return ""

static func assess(body: Dictionary, rest: Dictionary, group: String) -> Array[String]:
	var errors: Array[String] = []
	if body.get("schema") != 1 or body.get("frame") != "BodyV4" or body.get("units") != "design_units" or body.get("forward") != "-Z" or body.get("up") != "+Y" or not body.get("errors") is Array or not body.get("sockets") is Dictionary:
		return ["invalid_body_descriptor"]
	if not body["errors"].is_empty(): errors.append("body_geometry_errors")
	var minimum_legs: int = 2 if group == "eggs" else 4
	if not Contract.integer(body.get("authored_leg_count"), minimum_legs, 12): errors.append("insufficient_authored_legs")
	if group == "work":
		for id in SOCKETS:
			if not body["sockets"].has(id): errors.append("missing_socket:" + id)
	for socket in body["sockets"].values():
		if not socket is Dictionary or not vec(socket.get("position")) or not vec(socket.get("basis_x")) or not vec(socket.get("basis_y")) or not vec(socket.get("basis_z")):
			errors.append("invalid_socket_geometry")
			break
	if rest.get("schema") != 1 or rest.get("pose") != "rest_only" or not rest.get("feet") is Array or not Contract.integer(rest.get("leg_count"), 0, 12) or rest["leg_count"] != rest["feet"].size():
		errors.append("invalid_rest_descriptor")
		return errors
	if int(rest["leg_count"]) < minimum_legs or rest["leg_count"] != body.get("authored_leg_count"): errors.append("insufficient_runtime_legs")
	if not Contract.number(rest.get("max_contact_error"), 0, MAX_GAP) or rest.get("all_feet_on_plane") != true: errors.append("missing_rest_contact")
	if not Contract.number(rest.get("max_rest_stretch"), 1, 1.20 if group == "work" else 1.35): errors.append("excessive_rest_stretch")
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var feet: Dictionary = {}
	for foot in rest["feet"]:
		if not foot is Dictionary or not vec(foot.get("position")) or not foot.get("part_uid") is String or foot["part_uid"].is_empty() or not Contract.number(foot.get("side"), -1, 1) or absf(float(foot["side"])) != 1.0 or not Contract.number(foot.get("gap"), 0, MAX_GAP):
			errors.append("invalid_support_foot")
			return errors
		var identity: String = str(foot["part_uid"]) + ":" + str(int(foot["side"]))
		if feet.has(identity): errors.append("duplicate_support_foot")
		feet[identity] = true
		minimum = minimum.min(vector(foot["position"]))
		maximum = maximum.max(vector(foot["position"]))
	var bounds: Variant = body.get("body_bounds")
	if not bounds is Dictionary or not vec(bounds.get("position")) or not vec(bounds.get("size")):
		errors.append("invalid_body_bounds")
		return errors
	var size: Vector3 = vector(bounds["size"])
	var center: Vector3 = vector(bounds["position"]) + size * 0.5
	if group == "eggs" and rest.leg_count == 2:
		# Two feet cannot form the four-point load-bearing footprint required
		# for mounts. Check lateral stance and a centered leg pair instead.
		# This is geometric rest evidence, not a physical balance simulation.
		if size.x <= 0 or size.y <= 0 or size.z <= 0 or maximum.x - minimum.x < size.x * 0.25:
			errors.append("insufficient_support_span")
		if center.x <= minimum.x + 0.02 or center.x >= maximum.x - 0.02 or absf((minimum.z + maximum.z) * 0.5 - center.z) > size.z * 0.2:
			errors.append("body_outside_support")
		return errors
	if size.x <= 0 or size.y <= 0 or size.z <= 0 or maximum.x - minimum.x < size.x * 0.25 or maximum.z - minimum.z < size.z * 0.30:
		errors.append("insufficient_support_span")
	if center.x <= minimum.x + 0.02 or center.x >= maximum.x - 0.02 or center.z <= minimum.z + 0.02 or center.z >= maximum.z - 0.02:
		errors.append("body_outside_support")
	return errors

static func vec(value: Variant) -> bool:
	return value is Array and value.size() == 3 and Contract.number(value[0], -1e6, 1e6) and Contract.number(value[1], -1e6, 1e6) and Contract.number(value[2], -1e6, 1e6)

static func vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
