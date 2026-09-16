extends RefCounted
## Optional campaign participant. Immutable designs live with owned instances,
## not in loose author files. This milestone exposes an explicit trial only.
const Contract = preload("res://space/fleet/expedition_contract.gd")
const Ship = preload("res://space/ships/ship_blueprint.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const FIELD: String = "expedition_fleet"
const SCHEMA: int = 1
const MAX_SHIPS: int = 16
const MAX_DISTANCE: float = 100.0

static func context(campaign: Dictionary) -> Dictionary:
	var bodies: Dictionary = {}
	var systems: Array = []
	if not campaign.get("bodies") is Dictionary: return {}
	for body in campaign.bodies.values():
		if not body is Dictionary or not Contract._id(body.get("id")) or not Contract._id(body.get("system_id")): return {}
		bodies[body.id] = body.system_id
		if not systems.has(body.system_id): systems.append(body.system_id)
	return {"campaign_id": campaign.get("id", ""), "species_id": campaign.get("player_species_id", ""),
		"faction_id": campaign.get("player_faction_id", ""), "systems": systems, "bodies": bodies}

static func design_key(reference: Dictionary) -> String:
	return str(reference.design_id) + "@" + str(int(reference.revision))

static func validate(campaign: Dictionary) -> String:
	if not campaign.has(FIELD): return ""
	var value: Variant = campaign[FIELD]
	if not Contract._json(value, [200000]): return "fleet.unbounded"
	if not Contract._keys(value, ["schema", "mode", "snapshot", "designs"]): return "fleet.fields"
	if not Contract._version(value.schema) or not Contract._tag(value.mode, "shipyard_trial"): return "fleet.unsupported"
	var problem: String = Contract.validate(value.snapshot, context(campaign))
	if not problem.is_empty(): return problem
	if value.snapshot.ships.size() > MAX_SHIPS or not value.designs is Dictionary or value.designs.size() > MAX_SHIPS: return "fleet.limit"
	var used: Dictionary = {}
	var evaluated: Dictionary = {}
	for ship: Dictionary in value.snapshot.ships.values():
		var key: String = design_key(ship.blueprint)
		used[key] = true
		if not value.designs.get(key) is Dictionary: return "fleet.missing_pin"
		var design: Dictionary = value.designs[key]
		if not Ship.inspect(design).ok: return "fleet.invalid_pin"
		if not evaluated.has(key): evaluated[key] = Ship.pin(design)
		var pinned: Dictionary = evaluated[key]
		if not pinned.ok or not same_json(pinned.blueprint, ship.blueprint) or not same_json(pinned.capabilities, ship.capabilities) or design.ship.role != ship.role: return "fleet.capability_mismatch"
	if used.size() != value.designs.size(): return "fleet.unreferenced_pin"
	# The trial's sole operator remains the real campaign player on the surface.
	# No second player controller, invented passengers or live economy receipts.
	var snapshot: Dictionary = value.snapshot
	if not Contract._id(campaign.get("player_object_id")) or snapshot.people.size() != 1 or not snapshot.people.has(campaign.player_object_id): return "fleet.player"
	if snapshot.control != {"person_id": campaign.player_object_id, "kind": "person", "target_id": campaign.player_object_id}: return "fleet.control"
	for asset: Dictionary in snapshot.assets.values():
		if asset.owner_module != "shipyard_trial": return "fleet.foreign_receipt"
	return ""

static func unsupported(campaign: Dictionary) -> bool:
	# An unreadable fleet is protected as a whole, including nested versions,
	# pins and receipt references. Never silently replace it with an older backup.
	return not validate(campaign).is_empty()

static func trial(campaign: Dictionary, body: Dictionary) -> Dictionary:
	if campaign.has(FIELD) or body.get("surface_mode") != Contract.Cube.MODE: return Contract._failure("fleet.trial_context")
	var host: Dictionary = Ship.template("expedition")
	var guest: Dictionary = Ship.template("lander")
	host.revision = 1
	guest.revision = 1
	var a: Dictionary = instance(host, system_place(body.system_id, [0.0, 0.0, 0.0]))
	var b: Dictionary = instance(guest, system_place(body.system_id, [0.0, 0.0, 60.0]))
	var player: String = campaign.player_object_id
	var snapshot: Dictionary = {"schema": 1, "revision": 0, "campaign_id": campaign.id,
		"species_id": campaign.player_species_id, "faction_id": campaign.player_faction_id,
		"ships": {a.id: a, b.id: b}, "assets": {},
		"people": {player: {"id": player, "place": {"kind": "surface", "system_id": body.system_id,
			"address": body.surface_context.spawn.duplicate(true), "orientation": [0, 0, 0, 1]}}},
		"control": {"person_id": player, "kind": "person", "target_id": player}}
	for kind: String in ["cargo", "sample"]:
		var id: String = Ids.create("transport")
		snapshot.assets[id] = {"id": id, "kind": kind, "owner_module": "shipyard_trial", "record_id": Ids.create(kind), "space": 2, "ship_id": b.id}
	var value: Dictionary = {"schema": SCHEMA, "mode": "shipyard_trial", "snapshot": snapshot,
		"designs": {design_key(a.blueprint): payload(host), design_key(b.blueprint): payload(guest)}}
	return _checked(campaign, value)

static func payload(design: Dictionary) -> Dictionary:
	# Authoring uses StringName keys; campaign snapshots use plain JSON keys.
	return Ship.Store.Atomic.parse_dictionary(Ship.Store.Atomic.stringify(Ship.Assembly.serialize(design)))

static func same_json(a: Dictionary, b: Dictionary) -> bool:
	return Ship.Store.Atomic.parse_dictionary(Ship.Store.Atomic.stringify(a)) == Ship.Store.Atomic.parse_dictionary(Ship.Store.Atomic.stringify(b))

static func instance(design: Dictionary, place: Dictionary) -> Dictionary:
	var pin: Dictionary = Ship.pin(design)
	if not pin.ok: return {}
	return {"id": Ids.create("ship"), "role": design.ship.role, "blueprint": pin.blueprint,
		"capabilities": pin.capabilities, "energy": pin.capabilities.energy_capacity, "place": place.duplicate(true)}

static func system_place(system_id: String, position: Array) -> Dictionary:
	return {"kind": "system", "system_id": system_id, "position": position.duplicate(), "orientation": [0, 0, 0, 1]}

static func apply(campaign: Dictionary, command: Dictionary, expected_revision: int, saved_design: Dictionary = {}) -> Dictionary:
	if command.size() > 4: return Contract._failure("fleet.command")
	for key in command:
		if not key is String or not command[key] is String or command[key].is_empty() or command[key].length() > 4096: return Contract._failure("fleet.command")
	var problem: String = validate(campaign)
	if not problem.is_empty(): return Contract._failure(problem)
	if not campaign.has(FIELD): return Contract._failure("fleet.missing")
	var before: Dictionary = campaign[FIELD].snapshot
	if expected_revision != before.revision: return Contract._failure("fleet.stale")
	var value: Dictionary = campaign[FIELD].duplicate(true)
	var snapshot: Dictionary = value.snapshot
	var kind: Variant = command.get("kind")
	match kind:
		"dock":
			if not Contract._keys(command, ["kind", "ship_id", "host_id", "bay_id"]): return Contract._failure("fleet.command")
			var guest: Dictionary = snapshot.ships.get(command.ship_id, {})
			var host: Dictionary = snapshot.ships.get(command.host_id, {})
			if guest.is_empty() or host.is_empty() or guest.id == host.id: return Contract._failure("fleet.ship")
			if guest.role != "lander" or host.role != "expedition": return Contract._failure("fleet.roles")
			if guest.place.kind != "system" or host.place.kind != "system" or not _near(guest.place, host.place): return Contract._failure("fleet.too_far")
			var fit: Dictionary = Ship.hangar_fit(value.designs[design_key(host.blueprint)], value.designs[design_key(guest.blueprint)], str(command.bay_id))
			if not fit.ok: fit = Ship.hangar_fit(value.designs[design_key(host.blueprint)], value.designs[design_key(guest.blueprint)], str(command.bay_id), 90)
			if not fit.ok: return fit
			var yaw: float = deg_to_rad(float(fit.yaw)) * 0.5
			guest.place = {"kind": "dock", "host_ship_id": host.id, "bay_id": fit.bay_id, "offset": [0, 0, 0], "orientation": [0, sin(yaw), 0, cos(yaw)]}
		"undock":
			if not Contract._keys(command, ["kind", "ship_id"]): return Contract._failure("fleet.command")
			var guest: Dictionary = snapshot.ships.get(command.ship_id, {})
			if guest.is_empty() or guest.place.kind != "dock": return Contract._failure("fleet.not_docked")
			var host: Dictionary = snapshot.ships[guest.place.host_ship_id]
			if host.place.kind != "system": return Contract._failure("fleet.host_location")
			# Trial staging berth, not a flight/physical launch clearance.
			var position: Array = host.place.position.duplicate()
			position[2] += 60.0
			guest.place = system_place(host.place.system_id, position)
		"cargo":
			if not Contract._keys(command, ["kind", "asset_id", "target_id"]): return Contract._failure("fleet.command")
			var asset: Dictionary = snapshot.assets.get(command.asset_id, {})
			if asset.is_empty() or not snapshot.ships.has(command.target_id): return Contract._failure("fleet.asset")
			if not connected(snapshot, asset.ship_id, command.target_id): return Contract._failure("fleet.not_connected")
			asset.ship_id = command.target_id
		"instantiate":
			if not Contract._keys(command, ["kind", "path", "host_id"]) or not snapshot.ships.has(command.host_id): return Contract._failure("fleet.command")
			if snapshot.ships.size() >= MAX_SHIPS: return Contract._failure("fleet.limit")
			var pin: Dictionary = Ship.pin(saved_design)
			if not pin.ok: return pin
			var host: Dictionary = snapshot.ships[command.host_id]
			if host.place.kind != "system": return Contract._failure("fleet.host_location")
			var key: String = design_key(pin.blueprint)
			var stored: Dictionary = payload(saved_design)
			if value.designs.has(key) and value.designs[key] != stored: return Contract._failure("fleet.pin_conflict")
			var position: Array = host.place.position.duplicate()
			position[2] += 60.0
			var ship: Dictionary = instance(saved_design, system_place(host.place.system_id, position))
			snapshot.ships[ship.id] = ship
			value.designs[key] = stored
		_:
			return Contract._failure("fleet.command")
	snapshot.revision += 1
	var checked: Dictionary = _checked(campaign, value)
	if not checked.ok: return checked
	if kind != "instantiate":
		var staged: Dictionary = Contract.stage(before, snapshot, context(campaign), 0)
		if not staged.ok: return staged
	return checked

static func connected(snapshot: Dictionary, a: String, b: String) -> bool:
	if a == b or not snapshot.ships.has(a) or not snapshot.ships.has(b): return false
	var pa: Dictionary = snapshot.ships[a].place
	var pb: Dictionary = snapshot.ships[b].place
	return (pa.kind == "dock" and pa.host_ship_id == b) or (pb.kind == "dock" and pb.host_ship_id == a)

static func _near(a: Dictionary, b: Dictionary) -> bool:
	if a.system_id != b.system_id: return false
	# Subtract Double components BEFORE any single-precision Vector conversion.
	var squared: float = 0
	for i in range(3): squared += pow(float(a.position[i]) - float(b.position[i]), 2)
	return squared <= MAX_DISTANCE * MAX_DISTANCE

static func _checked(campaign: Dictionary, value: Dictionary) -> Dictionary:
	var candidate: Dictionary = campaign.duplicate()
	candidate[FIELD] = value
	var problem: String = validate(candidate)
	if not problem.is_empty(): return Contract._failure(problem)
	return {"ok": true, "code": "", "data": value}
