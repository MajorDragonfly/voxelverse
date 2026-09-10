extends RefCounted
## ARCH-30 executable DESIGN fixture. No runtime consumer, writer or save schema.
## See docs/SPACE_EXPEDITION_CONTRACT.md before using this reference model.
const Cube = preload("res://world/space/cube_sphere.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const MAX_COUNT: int = 4096
const MAX_VALUE: int = 1000000000

static func validate(value: Variant, context: Dictionary) -> String:
	if not _json(value, [100000]) or not _json(context, [100000]): return "data.non_json_or_unbounded"
	if not value is Dictionary or not _version(value.get("schema")): return "schema.unsupported"
	if not _keys(value, ["schema", "revision", "campaign_id", "faction_id", "species_id", "ships", "people", "assets", "control"]): return "snapshot.fields"
	for key in ["campaign_id", "faction_id", "species_id"]:
		if not _id(value[key]) or not _id(context.get(key)) or value[key] != context[key]: return "owner.mismatch"
	if not context.get("systems") is Array or not context.get("bodies") is Dictionary: return "context.invalid"
	if not _integer(value.revision): return "revision.invalid"
	if not _map(value.ships, 64) or value.ships.is_empty() or not _map(value.people, MAX_COUNT) or not _map(value.assets, MAX_COUNT): return "snapshot.collections"
	var occupied: Dictionary = {}
	var cargo_space: Dictionary = {}
	var seats: Dictionary = {}
	for id in value.ships:
		var ship: Variant = value.ships[id]
		if not _id(id) or not _keys(ship, ["id", "role", "blueprint", "capabilities", "place", "energy"]) or not _id(ship.id) or ship.id != id: return "ship.identity"
		if not _tag(ship.role, "expedition") and not _tag(ship.role, "lander"): return "ship.role"
		if not _keys(ship.blueprint, ["design_id", "revision", "payload_schema"]) or not _id(ship.blueprint.design_id) or not _integer(ship.blueprint.revision, 1) or not _version(ship.blueprint.payload_schema): return "blueprint.reference"
		var cap: Variant = ship.capabilities
		if not _keys(cap, ["design_revision", "catalog_revision", "hull_size", "cargo_space", "seats", "energy_capacity", "bays"]): return "capabilities.fields"
		if not _integer(cap.design_revision, 1) or cap.design_revision != ship.blueprint.revision or not _version(cap.catalog_revision): return "capabilities.revision"
		if not _vector(cap.hull_size, 3, true) or not _integer(cap.cargo_space) or not _integer(cap.seats) or not _integer(cap.energy_capacity) or not _map(cap.bays, 64): return "capabilities.invalid"
		for bay in cap.bays:
			if not _id(bay) or not _vector(cap.bays[bay], 3, true): return "bay.invalid"
		if not _integer(ship.energy) or ship.energy > cap.energy_capacity: return "energy.capacity"
		var problem: String = _place(ship.place, context, true)
		if not problem.is_empty(): return problem
		cargo_space[id] = 0
		seats[id] = 0
	# Resolve references only after every ship's local shape has passed validation.
	for id in value.ships:
		var ship: Dictionary = value.ships[id]
		if ship.place.kind != "dock": continue
		var place: Dictionary = ship.place
		if not value.ships.has(place.host_ship_id) or place.host_ship_id == id: return "dock.host"
		var host: Dictionary = value.ships[place.host_ship_id]
		if not host.capabilities.bays.has(place.bay_id): return "dock.bay_missing"
		var key: String = JSON.stringify([place.host_ship_id, place.bay_id])
		if occupied.has(key): return "dock.occupied"
		occupied[key] = id
		if not _fits(ship.capabilities.hull_size, place, host.capabilities.bays[place.bay_id]): return "dock.does_not_fit"
		var visited: Dictionary = {id: true}
		var cursor: String = place.host_ship_id
		while true:
			if visited.has(cursor): return "dock.cycle"
			visited[cursor] = true
			var parent: Dictionary = value.ships[cursor].place
			if parent.kind != "dock": break
			if not value.ships.has(parent.host_ship_id): return "dock.host"
			cursor = parent.host_ship_id
	var references: Dictionary = {}
	for id in value.assets:
		var asset: Variant = value.assets[id]
		if not _id(id) or not _keys(asset, ["id", "kind", "owner_module", "record_id", "space", "ship_id"]) or not _id(asset.id) or asset.id != id: return "asset.identity"
		if not _tag(asset.kind, "cargo") and not _tag(asset.kind, "sample"): return "asset.kind"
		if not _id(asset.owner_module) or not _id(asset.record_id) or not _integer(asset.space, 1) or not value.ships.has(asset.ship_id): return "asset.reference"
		# A copied sample/lot cannot acquire a second transport ID to occupy two holds.
		var key: String = JSON.stringify([asset.owner_module, asset.record_id])
		if references.has(key): return "asset.duplicate_record"
		references[key] = true
		cargo_space[asset.ship_id] += asset.space
	for id in value.people:
		var person: Variant = value.people[id]
		if not _id(id) or not _keys(person, ["id", "place"]) or not _id(person.id) or person.id != id: return "person.identity"
		if not person.place is Dictionary: return "person.place"
		if _tag(person.place.get("kind"), "aboard"):
			if not _keys(person.place, ["kind", "ship_id"]) or not value.ships.has(person.place.ship_id): return "person.ship"
			seats[person.place.ship_id] += 1
		else:
			var problem: String = _place(person.place, context, false)
			if not problem.is_empty(): return problem
	for id in value.ships:
		if cargo_space[id] > value.ships[id].capabilities.cargo_space: return "cargo.capacity"
		if seats[id] > value.ships[id].capabilities.seats: return "passengers.capacity"
	var control: Variant = value.control
	if not _keys(control, ["person_id", "kind", "target_id"]) or not _id(control.person_id) or not _id(control.target_id) or not value.people.has(control.person_id): return "control.person"
	var place: Dictionary = value.people[control.person_id].place
	if _tag(control.kind, "ship"):
		if place.kind != "aboard" or control.target_id != place.ship_id: return "control.ship"
	elif _tag(control.kind, "person"):
		if control.target_id != control.person_id or place.kind != "surface": return "control.surface"
	else: return "control.kind"
	return ""

static func stage(before: Dictionary, after: Dictionary, context: Dictionary, energy_spent: int) -> Dictionary:
	# Proposal proof only. Arrival, authority, costs and module receipts are supplied
	# by future gameplay owners, never inferred from a structurally valid place.
	for snapshot in [before, after]:
		var problem: String = validate(snapshot, context)
		if not problem.is_empty(): return _failure(problem)
	if after.revision != before.revision + 1: return _failure("transfer.revision")
	if before.control.person_id != after.control.person_id: return _failure("transfer.controller_changed")
	if energy_spent < 0 or energy_spent > MAX_VALUE: return _failure("transfer.energy_spent")
	for id in before.ships:
		if after.ships.has(id) and _system(before, id) != _system(after, id): return _failure("transfer.system_changed")
	var old: Dictionary = before.duplicate(true)
	var next: Dictionary = after.duplicate(true)
	old.erase("revision")
	next.erase("revision")
	old.erase("control")
	next.erase("control")
	var old_energy: int = _energy(before)
	var next_energy: int = _energy(after)
	for snapshot in [old, next]:
		for ship: Dictionary in snapshot.ships.values():
			ship.erase("place")
			ship.erase("energy")
		for person: Dictionary in snapshot.people.values(): person.erase("place")
		for asset: Dictionary in snapshot.assets.values(): asset.erase("ship_id")
	if old != next: return _failure("transfer.identity_or_payload_changed")
	if old_energy - next_energy != energy_spent: return _failure("transfer.energy_balance")
	return {"ok": true, "code": "", "before": before.duplicate(true), "after": after.duplicate(true), "energy_spent": energy_spent}

static func admit(current: Dictionary, staged: Dictionary, context: Dictionary) -> Dictionary:
	# A future shared Save owner must durably write the admitted whole candidate
	# BEFORE publishing it. This helper deliberately has no I/O or mutation.
	var problem: String = validate(current, context)
	if not problem.is_empty(): return _failure(problem)
	if not _keys(staged, ["ok", "code", "before", "after", "energy_spent"]) or not staged.ok is bool or not staged.ok or not staged.before is Dictionary or not staged.after is Dictionary or not _integer(staged.energy_spent): return _failure("transfer.invalid_proposal")
	var checked: Dictionary = stage(staged.before, staged.after, context, int(staged.energy_spent))
	if not checked.ok: return checked
	if current == staged.after: return {"ok": true, "code": "transfer.replay", "data": current.duplicate(true)}
	if current != staged.before: return _failure("transfer.stale")
	return {"ok": true, "code": "", "data": staged.after.duplicate(true)}

static func _energy(snapshot: Dictionary) -> int:
	var result: int = 0
	for ship: Dictionary in snapshot.ships.values(): result += int(ship.energy)
	return result

static func _system(snapshot: Dictionary, id: String) -> String:
	# Called only on validated, acyclic snapshots.
	var place: Dictionary = snapshot.ships[id].place
	while place.kind == "dock": place = snapshot.ships[place.host_ship_id].place
	return place.system_id

static func _place(place: Variant, context: Dictionary, ship: bool) -> String:
	if not place is Dictionary: return "place.invalid"
	match place.get("kind"):
		"surface":
			if not _keys(place, ["kind", "system_id", "address", "orientation"]) or not _rotation(place.orientation): return "place.surface_fields"
			if not _keys(place.address, ["mode", "body_id", "face", "u", "v", "height"]) or not _tag(place.address.mode, Cube.MODE) or not Cube.valid(place.address) or not Surface.location(place.address, str(place.address.get("body_id", ""))): return "place.surface_address"
			if not _id(place.system_id) or not context.systems.has(place.system_id) or not _id(context.bodies.get(place.address.body_id)) or context.bodies[place.address.body_id] != place.system_id: return "place.body_system"
		"system":
			if not ship or not _keys(place, ["kind", "system_id", "position", "orientation"]) or not _id(place.system_id) or not context.systems.has(place.system_id) or not _vector(place.position, 3) or not _rotation(place.orientation): return "place.system"
		"dock":
			if not ship or not _keys(place, ["kind", "host_ship_id", "bay_id", "offset", "orientation"]) or not _id(place.host_ship_id) or not _id(place.bay_id) or not _vector(place.offset, 3) or not _rotation(place.orientation): return "place.dock"
		_: return "place.kind"
	return ""

static func _fits(size: Array, place: Dictionary, bay: Array) -> bool:
	var q: Array = place.orientation
	var frame := Basis(Quaternion(q[0], q[1], q[2], q[3]))
	var extent: Vector3 = (frame.x.abs() * float(size[0]) + frame.y.abs() * float(size[1]) + frame.z.abs() * float(size[2])) * 0.5
	for axis in range(3):
		if absf(float(place.offset[axis])) + extent[axis] > float(bay[axis]) * 0.5 + 0.00001: return false
	return true

static func _keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

static func _id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128 and value == value.strip_edges()

static func _tag(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _version(value: Variant) -> bool:
	return _integer(value, 1) and value == 1

static func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= MAX_VALUE and float(value) == floor(float(value))

static func _map(value: Variant, maximum: int) -> bool:
	return value is Dictionary and value.size() <= maximum

static func _vector(value: Variant, length: int, positive: bool = false) -> bool:
	if not value is Array or value.size() != length: return false
	for item in value:
		if not (item is int or item is float) or not is_finite(float(item)) or absf(float(item)) > 1.0e15 or (positive and item <= 0): return false
	return true

static func _rotation(value: Variant) -> bool:
	if not _vector(value, 4): return false
	var length_squared: float = 0.0
	for component in value: length_squared += float(component) * float(component)
	return absf(length_squared - 1.0) < 0.000001

static func _json(value: Variant, budget: Array, depth: int = 0) -> bool:
	budget[0] -= 1
	if budget[0] < 0 or depth > 16: return false
	if value is Dictionary:
		if value.size() > 100000: return false
		for key in value:
			if not key is String or key.length() > 128 or not _json(value[key], budget, depth + 1): return false
	elif value is Array:
		if value.size() > 100000: return false
		for item in value:
			if not _json(item, budget, depth + 1): return false
	elif value is float: return is_finite(value)
	elif value is String: return value.length() <= 4096
	elif not (value == null or value is int or value is bool): return false
	return true

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}
