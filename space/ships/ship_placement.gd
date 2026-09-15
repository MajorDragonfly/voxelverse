extends RefCounted
## Pure, bounded placement planning. Previews never allocate persistent IDs.
const Ship = preload("res://space/ships/ship_blueprint.gd")
const DIRECTIONS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
static var _definitions: Dictionary = Ship.Catalog.all()

static func plan(data: Dictionary, anchor: int, id: String, side: int = 0, yaw: int = 0, symmetric: bool = false) -> Dictionary:
	var inspection: Dictionary = Ship.inspect(data)
	if not inspection.ok: return {"ok": false, "code": inspection.code, "placements": []}
	var definitions: Dictionary = _definitions
	if not definitions.has(id) or side < 0 or side >= DIRECTIONS.size() or yaw not in [0, 90, 180, 270]:
		return {"ok": false, "code": "ship.placement_input", "placements": []}
	if definitions[id].role not in ["both", data.ship.role]: return {"ok": false, "code": "ship.module_role", "placements": []}
	if not data.parts.is_empty() and (anchor < 0 or anchor >= data.parts.size()): return {"ok": false, "code": "ship.select_anchor", "placements": []}
	var module: Dictionary = {"uid": "preview_primary", "part_id": id, "part_revision": Ship.Catalog.REVISION,
		"position": Vector3.ZERO, "rotation": Vector3(0, yaw, 0), "scale": Vector3.ONE}
	if not data.parts.is_empty():
		var target: Dictionary = data.parts[anchor]
		var target_box: AABB = Ship.module_box(target, definitions[target.part_id])
		var size: Vector3 = Ship.module_box(module, definitions[id]).size
		module.position = target_box.get_center() + DIRECTIONS[side] * (target_box.size + size) * 0.5
	var placements: Array[Dictionary] = [module]
	if symmetric and not is_zero_approx(module.position.x):
		var mirror: Dictionary = module.duplicate(true)
		mirror.uid = "preview_mirror"
		mirror.position.x = -mirror.position.x
		mirror.rotation.y = fposmod(-mirror.rotation.y, 360)
		placements.append(mirror)
	return validate(data, placements)

## Placement rejects new intersections/disconnections, but permits an unfinished
## source (e.g. no reactor yet). Economy/readiness still belongs to Ship.evaluate.
static func validate(data: Dictionary, placements: Array[Dictionary]) -> Dictionary:
	var check: Dictionary = Ship.inspect(data)
	if not check.ok: return {"ok": false, "code": check.code, "placements": []}
	var definitions: Dictionary = _definitions
	var result: Dictionary = {"ok": false, "code": "", "placements": placements.duplicate(true), "boxes": []}
	if placements.is_empty() or placements.size() > 2:
		result.code = "ship.placement_input"
		return result
	var candidate: Dictionary = data.duplicate(true)
	for part: Dictionary in placements: candidate.parts.append(part.duplicate(true))
	check = Ship.inspect(candidate)
	if not check.ok:
		result.code = check.code
		return result
	var existing: Array[AABB] = []
	var bounds := AABB()
	var first: bool = true
	for part: Dictionary in data.parts:
		var box: AABB = Ship.module_box(part, definitions[part.part_id])
		existing.append(box)
		bounds = box if first else bounds.merge(box)
		first = false
	for part: Dictionary in placements:
		if definitions[part.part_id].role not in ["both", data.ship.role]: result.code = "ship.module_role"
		var box: AABB = Ship.module_box(part, definitions[part.part_id])
		var connected: bool = existing.is_empty()
		for other: AABB in existing:
			var extent: Vector3 = box.end.min(other.end) - box.position.max(other.position)
			if extent.x > 0.001 and extent.y > 0.001 and extent.z > 0.001: result.code = "ship.overlap"
			if Ship._face_contact(extent): connected = true
		if not connected and result.code.is_empty(): result.code = "ship.disconnected"
		existing.append(box)
		result.boxes.append(box)
		bounds = box if first else bounds.merge(box)
		first = false
	var limit: Vector3 = Ship.LIMITS[data.ship.role]
	if bounds.size.x > limit.x or bounds.size.y > limit.y or bounds.size.z > limit.z:
		if result.code.is_empty(): result.code = "ship.size_limit"
	result.ok = result.code.is_empty()
	return result

static func add_attached(data: Dictionary, anchor: int, id: String, side: int = 0, yaw: int = 0, symmetric: bool = false) -> Dictionary:
	# Recompute at the command boundary; an old green preview is no authority.
	return commit(data, plan(data, anchor, id, side, yaw, symmetric))

static func mirror(data: Dictionary, index: int) -> Dictionary:
	if not Ship.inspect(data).ok or index < 0 or index >= data.parts.size(): return {"ok": false, "code": "ship.select_anchor"}
	var part: Dictionary = data.parts[index].duplicate(true)
	if is_zero_approx(Ship.vector(part.position).x): return {"ok": false, "code": "ship.mirror_center"}
	part.uid = "preview_mirror"
	part.position = Ship.vector(part.position) * Vector3(-1, 1, 1)
	part.rotation = Vector3(0, fposmod(-Ship.vector(part.rotation).y, 360), 0)
	return commit(data, validate(data, [part]))

static func commit(data: Dictionary, proposal: Dictionary) -> Dictionary:
	if not proposal.get("ok", false): return proposal
	var check: Dictionary = validate(data, proposal.placements)
	if not check.ok: return check
	var candidate: Dictionary = data.duplicate(true)
	var added: Array[int] = []
	for part: Dictionary in check.placements:
		var index: int = Ship.Assembly.add_part(candidate, part.part_id, part.position, part.rotation)
		var placed: Dictionary = part.duplicate(true)
		placed.uid = candidate.parts[index].uid
		placed.mirror_group = ""
		candidate.parts[index] = Ship.Assembly.normalize_part(placed)
		added.append(index)
	return {"ok": true, "code": "", "blueprint": candidate, "added": added}
