extends RefCounted
## Ship authoring uses the existing Assembly, history, codec and DesignStore.
## These are local designs, not owned ships or campaign save participants.
const Assembly = preload("res://assembly/core/modular_assembly.gd")
const Contract = preload("res://assembly/core/blueprint_contract.gd")
const Catalog = preload("res://space/ships/ship_module_catalog.gd")
const Store = preload("res://core/persistence/design_store.gd")
const MAX_MODULES: int = 128
const DIRECTORY: String = "user://ship_designs"
const LIMITS: Dictionary = {"lander": Vector3(16, 12, 24), "expedition": Vector3(96, 48, 160)}

static func template(role: String) -> Dictionary:
	if not LIMITS.has(role): return {}
	var data: Dictionary = Assembly.create("ship", "Pionier" if role == "expedition" else "Späher")
	data.ship = {"schema": 1, "role": role, "catalog_revision": Catalog.REVISION}
	data.grid_size = 1.0
	var layout: Array = [
		["hull_s", Vector3.ZERO], ["cockpit", Vector3(0, 0, -4)],
		["drive_s", Vector3(0, 0, 4)], ["reactor_s", Vector3(-1, 2, 0)],
		["battery_s", Vector3(1, 2, 0)], ["cargo_s", Vector3(0, -2, 0)],
		["landing_gear", Vector3(0, -2, -3)],
	] if role == "lander" else [
		["hull_l", Vector3.ZERO], ["bridge", Vector3(0, 5, -6)],
		["reactor_l", Vector3(0, 5, 0)], ["laboratory", Vector3(0, 5, 6)],
		["cargo_l", Vector3(0, 0, 18)], ["drive_l", Vector3(0, 0, 27)],
		["hangar", Vector3(14, 0, 0)], ["habitat", Vector3(-10, 0, 0)],
	]
	for row: Array in layout:
		var index: int = Assembly.add_part(data, row[0], row[1])
		data.parts[index].part_revision = Catalog.REVISION
	return data

## Structural/compatibility checks allow unfinished but safely editable drafts.
static func inspect(data: Dictionary) -> Dictionary:
	var generic: Dictionary = Contract.inspect(data, "modular")
	if not generic.ok: return generic
	if not data.get("assembly_type") is String or data.assembly_type != "ship": return _result("ship.type")
	if not data.get("schema") is float and not data.get("schema") is int: return _result("ship.schema")
	if data.schema != 1: return _result("ship.schema")
	if not data.get("ship") is Dictionary: return _result("ship.schema")
	if not data.get("parts") is Array: return _result("ship.parts")
	var ship: Dictionary = data.ship
	for key in ["schema", "catalog_revision"]:
		if not _integer(ship.get(key)) or int(ship[key]) != 1: return _result("ship.unsupported_version")
	if not ship.get("role") is String or not LIMITS.has(ship.role): return _result("ship.role")
	for key in ["design_id", "name"]:
		if not data.get(key) is String or data[key].strip_edges().is_empty() or data[key].length() > 120: return _result("ship.identity")
	if data.parts.size() > MAX_MODULES: return _result("ship.module_limit")
	var definitions: Dictionary = Catalog.all()
	for part: Dictionary in data.parts:
		if not part.get("uid") is String or part.uid.is_empty() or part.uid.length() > 120: return _result("ship.module_identity")
		if not definitions.has(part.get("part_id", "")): return _result("ship.unknown_module")
		if not _integer(part.get("part_revision")) or int(part.part_revision) != Catalog.REVISION: return _result("ship.unsupported_module")
		for field in ["position", "rotation", "scale"]:
			if not part.has(field): return _result("ship.transform")
		var position: Vector3 = vector(part.position)
		var rotation: Vector3 = vector(part.rotation)
		if absf(position.x) > 200 or absf(position.y) > 200 or absf(position.z) > 200: return _result("ship.position")
		if not position.is_equal_approx(position.snapped(Vector3.ONE)): return _result("ship.grid")
		if not is_zero_approx(rotation.x) or not is_zero_approx(rotation.z) or rotation.y not in [0.0, 90.0, 180.0, 270.0]: return _result("ship.rotation")
		if not vector(part.scale).is_equal_approx(Vector3.ONE): return _result("ship.scale")
	return _result("")

## Recomputed from the pinned local catalogue; no saved/downloaded totals read.
static func evaluate(data: Dictionary) -> Dictionary:
	var inspection: Dictionary = inspect(data)
	if not inspection.ok: return {"ok": false, "code": inspection.code, "issues": [{"code": inspection.code, "parts": []}], "stats": {}, "bounds": AABB()}
	var definitions: Dictionary = Catalog.all()
	var stats: Dictionary = {}
	for key in ["mass", "cost", "cargo", "seats", "energy", "power", "draw", "thrust", "structure", "command", "landing", "research"]: stats[key] = 0
	var boxes: Array[AABB] = []
	var issues: Array[Dictionary] = []
	var bays: Dictionary = {}
	var bounds := AABB()
	var roots: Array[int] = []
	for index in range(data.parts.size()):
		var part: Dictionary = data.parts[index]
		var definition: Dictionary = definitions[part.part_id]
		var box: AABB = module_box(part, definition)
		boxes.append(box)
		bounds = box if index == 0 else bounds.merge(box)
		for key in definition.stats: stats[key] += int(definition.stats[key])
		if definition.stats.get("structure", 0) > 0: roots.append(index)
		if definition.role not in ["both", data.ship.role]: issues.append(_issue("ship.module_role", [index]))
		if definition.has("bay_size"):
			bays[part.uid] = {"size": definition.bay_size, "position": vector(part.position), "yaw": vector(part.rotation).y}
	# Bounded pairwise checks: 128 modules maximum, no scene/physics dependency.
	var adjacency: Array = []
	for index in range(boxes.size()): adjacency.append([])
	for a in range(boxes.size()):
		for b in range(a + 1, boxes.size()):
			var extent: Vector3 = boxes[a].end.min(boxes[b].end) - boxes[a].position.max(boxes[b].position)
			if extent.x > 0.001 and extent.y > 0.001 and extent.z > 0.001:
				issues.append(_issue("ship.overlap", [a, b]))
			elif _face_contact(extent):
				adjacency[a].append(b)
				adjacency[b].append(a)
	var reached: Dictionary = {}
	var queue: Array[int] = []
	if not roots.is_empty(): queue.append(roots[0])
	while not queue.is_empty():
		var current: int = queue.pop_back()
		if reached.has(current): continue
		reached[current] = true
		for neighbor: int in adjacency[current]:
			if not reached.has(neighbor): queue.append(neighbor)
	for index in range(boxes.size()):
		if not reached.has(index): issues.append(_issue("ship.disconnected", [index]))
	if roots.is_empty(): issues.append(_issue("ship.no_hull"))
	if stats.command != 1: issues.append(_issue("ship.command_count"))
	if stats.power < stats.draw: issues.append(_issue("ship.power_deficit"))
	if stats.energy <= 0: issues.append(_issue("ship.no_energy"))
	if stats.thrust < stats.mass: issues.append(_issue("ship.thrust_deficit"))
	if stats.cargo <= 0: issues.append(_issue("ship.no_cargo"))
	if data.ship.role == "lander" and stats.landing < 1: issues.append(_issue("ship.no_landing_gear"))
	if data.ship.role == "expedition" and bays.is_empty(): issues.append(_issue("ship.no_hangar"))
	var limit: Vector3 = LIMITS[data.ship.role]
	if bounds.size.x > limit.x or bounds.size.y > limit.y or bounds.size.z > limit.z: issues.append(_issue("ship.size_limit"))
	return {"ok": issues.is_empty(), "code": "" if issues.is_empty() else issues[0].code,
		"issues": issues, "stats": stats, "bounds": bounds, "bays": bays, "boxes": boxes}

static func hangar_fit(host: Dictionary, guest: Dictionary, bay_id: String = "", yaw: int = 0, offset: Vector3 = Vector3.ZERO) -> Dictionary:
	var a: Dictionary = evaluate(host)
	var b: Dictionary = evaluate(guest)
	if not a.ok or not b.ok: return _result("ship.invalid_design")
	if host.ship.role != "expedition" or guest.ship.role != "lander": return _result("ship.docking_roles")
	if yaw not in [0, 90, 180, 270] or not offset.is_finite(): return _result("ship.dock_transform")
	var size: Vector3 = b.bounds.size
	if yaw in [90, 270]: size = Vector3(size.z, size.y, size.x)
	for key in a.bays:
		if not bay_id.is_empty() and key != bay_id: continue
		var available: Vector3 = a.bays[key].size
		var occupied: Vector3 = size + offset.abs() * 2.0
		if occupied.x <= available.x and occupied.y <= available.y and occupied.z <= available.z:
			return {"ok": true, "code": "", "bay_id": key, "yaw": yaw, "clearance": (available - occupied) * 0.5}
	return _result("ship.hangar_too_small")

static func find_hangar_fit(host: Dictionary, guest: Dictionary) -> Dictionary:
	var result: Dictionary = hangar_fit(host, guest)
	if result.ok or result.code != "ship.hangar_too_small": return result
	return hangar_fit(host, guest, "", 90)

## Exact capability shape from ARCH-30, with a centre offset for scene adapters.
## Only saved, ready designs can be pinned by future ship instances.
static func pin_saved(path: String) -> Dictionary:
	var loaded: Dictionary = load_design(path)
	if not loaded.ok: return loaded
	var data: Dictionary = loaded.blueprint
	var result: Dictionary = evaluate(data)
	if not result.ok or int(data.get("revision", 0)) < 1: return _result("ship.not_ready_to_pin")
	var bays: Dictionary = {}
	for id in result.bays: bays[id] = array(result.bays[id].size)
	return {"ok": true, "code": "", "blueprint": {"design_id": data.design_id, "revision": data.revision, "payload_schema": 1},
		"capabilities": {"design_revision": data.revision, "catalog_revision": Catalog.REVISION,
			"hull_size": array(result.bounds.size), "cargo_space": result.stats.cargo, "seats": result.stats.seats,
			"energy_capacity": result.stats.energy, "bays": bays}, "design_center": result.bounds.get_center(),
		"bay_frames": result.bays.duplicate(true)}

static func save_design(data: Dictionary, path: String = "") -> Dictionary:
	var check: Dictionary = inspect(data)
	if not check.ok: return check
	if path.is_empty(): path = DIRECTORY + "/" + data.design_id.sha256_text().left(32) + ".json"
	# Full ship validation on the original before using the generic writer.
	# Corruption and newer schemas never fall back to an older backup.
	var previous: Dictionary = {}
	if FileAccess.file_exists(path):
		var loaded: Dictionary = load_design(path)
		if not loaded.ok: return _result("ship.protected_original")
		previous = loaded.blueprint
		if previous.design_id != data.design_id: return _result("ship.different_design")
	var candidate: Dictionary = data.duplicate(true)
	candidate.revision = maxi(int(candidate.revision), int(previous.get("revision", 0))) + 1
	if not inspect(candidate).ok: return _result("ship.revision_limit")
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK: return _result("ship.write_failed")
	var error: Error = Store.write(path, Assembly.serialize(candidate))
	if error != OK: return _result("ship.write_failed")
	data.clear()
	data.merge(candidate, true)
	return {"ok": true, "code": "", "path": path}

static func load_design(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return _result("ship.file_missing")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _result("ship.read_failed")
	if file.get_length() > Contract.MAX_BYTES:
		file.close()
		return _result("blueprint_too_large")
	var text: String = file.get_as_text()
	file.close()
	var check: Dictionary = Contract.inspect_text(text, "modular")
	if not check.ok: return check
	var parsed: Dictionary = Store.Atomic.parse_dictionary(text)
	check = inspect(parsed)
	if not check.ok: return check
	return {"ok": true, "code": "", "blueprint": Assembly.deserialize(parsed)}

static func list_designs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(DIRECTORY): return result
	for filename in DirAccess.get_files_at(DIRECTORY):
		if not filename.ends_with(".json"): continue
		# List metadata only for the bounded selected authoring library.
		var loaded: Dictionary = load_design(DIRECTORY + "/" + filename)
		result.append({"path": DIRECTORY + "/" + filename, "name": loaded.blueprint.name if loaded.ok else filename,
			"ok": loaded.ok, "code": loaded.code})
	return result

static func module_box(part: Dictionary, definition: Dictionary) -> AABB:
	var size: Vector3 = definition.size
	if int(vector(part.rotation).y) in [90, 270]: size = Vector3(size.z, size.y, size.x)
	return AABB(vector(part.position) - size * 0.5, size)

static func vector(value: Variant) -> Vector3:
	return Assembly._as_vector3(value)

static func array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value)) == float(value)

static func _face_contact(extent: Vector3) -> bool:
	return (absf(extent.x) <= 0.001 and extent.y > 0.001 and extent.z > 0.001) or (absf(extent.y) <= 0.001 and extent.x > 0.001 and extent.z > 0.001) or (absf(extent.z) <= 0.001 and extent.x > 0.001 and extent.y > 0.001)

static func _issue(code: String, parts: Array = []) -> Dictionary:
	return {"code": code, "parts": parts}

static func _result(code: String) -> Dictionary:
	return {"ok": code.is_empty(), "code": code}
