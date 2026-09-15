extends RefCounted
## Copy reducers for ARCH-27. The caller owns the common stock/reservation/save
## transaction. Effects are intents, never independent stock or file writes.
const Routes = preload("res://world/tribe/transport/regional_routes.gd")
const Resources = preload("res://world/tribe/resource_catalog.gd")
const Ids = preload("res://core/campaign/campaign_ids.gd")
const STEP: float = 0.25
const MAX_CLOCK: float = 1000000000000.0
const STATUSES: Array[String] = ["reserved", "moving", "arrived", "delivered", "returned", "cancelled", "lost"]
const BLOCKS: Array[String] = ["", "route.network_unavailable", "route.network_mismatch", "route.connection_missing", "route.blocked", "route.recertification_required", "route.endpoint_changed"]

static func validate(value: Variant) -> String:
	if not Routes.fields(value, ["schema", "id", "faction_id", "carrier_id", "reservation_id", "resource_id", "resource_revision", "amount", "source", "destination", "route", "leg", "elapsed", "cursor", "owner", "epoch", "status", "returning", "blocked", "at_gateway"]): return "transport.fields"
	if not Routes.Economy.integer(value.schema, 1, 1): return "transport.schema"
	for field: String in ["id", "faction_id", "carrier_id", "reservation_id"]:
		if not Routes.identity(value[field]): return "transport.identity"
	if not value.resource_id is String or Resources.definition(value.resource_id).is_empty() or not Routes.Economy.integer(value.resource_revision, Resources.REVISION, Resources.REVISION): return "transport.resource"
	if not Routes.Economy.integer(value.amount, 1, 48): return "transport.capacity"
	var problem: String = Routes.validate_route(value.route, int(value.amount))
	if not problem.is_empty(): return problem
	for field: String in ["source", "destination"]:
		if not Routes.node_valid(value[field], value.route.body_id) or value[field].settlement_id.is_empty() or value[field].faction_id != value.faction_id: return "transport.ownership"
	if value.source.id == value.destination.id or value.source.settlement_id == value.destination.settlement_id: return "transport.endpoints"
	if not value.owner is String or value.owner not in ["near", "far"] or not Routes.Economy.integer(value.epoch, 1, 1000000000): return "transport.owner"
	if not value.status is String or value.status not in STATUSES or not value.returning is bool or not value.at_gateway is bool or not value.blocked is String or value.blocked not in BLOCKS: return "transport.status"
	if not Routes.Economy.number(value.cursor, 0, MAX_CLOCK) or not Routes.Economy.integer(value.leg, 0, value.route.legs.size()) or not Routes.Economy.number(value.elapsed, 0, Routes.MAX_DURATION): return "transport.cursor"
	var last: Dictionary = value.source if value.returning else value.destination
	if value.route.nodes.back() != last: return "transport.route_target"
	if not value.returning and value.route.nodes.front() != value.source: return "transport.route_source"
	if value.at_gateway and value.elapsed != 0: return "transport.gateway_progress"
	if value.owner == "far" and value.status == "moving" and value.at_gateway != (value.elapsed == 0): return "transport.gateway_progress"
	var finished: bool = int(value.leg) == value.route.legs.size()
	if finished and (value.elapsed != 0 or not value.at_gateway): return "transport.finished_progress"
	if not finished and value.elapsed >= value.route.legs[int(value.leg)].seconds: return "transport.leg_progress"
	if value.status in ["reserved", "cancelled"] and (value.leg != 0 or value.elapsed != 0 or value.returning or not value.at_gateway): return "transport.reservation_progress"
	if value.status == "moving" and finished: return "transport.moving_finished"
	if value.status in ["arrived", "delivered", "returned"] and not finished: return "transport.arrival_missing"
	if value.status == "delivered" and value.returning or value.status == "returned" and not value.returning: return "transport.wrong_receipt"
	if value.status != "moving" and not value.blocked.is_empty(): return "transport.blocked_status"
	return ""

static func create(id: String, faction_id: String, carrier_id: String, reservation_id: String, resource_id: String, amount: int, route: Dictionary, clock: float) -> Dictionary:
	var problem: String = Routes.validate_route(route, amount)
	if not problem.is_empty(): return _failure(problem)
	var data: Dictionary = {"schema": 1, "id": id, "faction_id": faction_id, "carrier_id": carrier_id, "reservation_id": reservation_id, "resource_id": resource_id, "resource_revision": Resources.REVISION, "amount": amount, "source": route.nodes.front().duplicate(true), "destination": route.nodes.back().duplicate(true), "route": route.duplicate(true), "leg": 0, "elapsed": 0.0, "cursor": clock, "owner": "near", "epoch": 1, "status": "reserved", "returning": false, "blocked": "", "at_gateway": true}
	return _result(data, "reserve")

static func depart(value: Dictionary, epoch: int, clock: float) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	if value.status != "reserved": return _failure("transport.not_reserved")
	var data: Dictionary = value.duplicate(true)
	data.status = "moving"
	data.cursor = clock
	return _result(data, "pickup", value)

static func handoff(value: Dictionary, epoch: int, owner: String, clock: float) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	if owner not in ["near", "far"] or owner == value.owner: return _failure("transport.handoff_owner")
	# Catch up the current owner first. Never silently drop pending travel time.
	if clock != value.cursor: return _failure("transport.handoff_pending_time")
	if not value.at_gateway: return _failure("transport.handoff_at_gateway_only")
	var data: Dictionary = value.duplicate(true)
	data.owner = owner
	data.epoch += 1
	return _result(data, "", value)

static func advance_far(value: Dictionary, epoch: int, clock: float, graph: Dictionary) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	if value.owner != "far": return _failure("transport.wrong_owner")
	if value.status != "moving": return _failure("transport.not_moving")
	var data: Dictionary = value.duplicate(true)
	data.blocked = Routes.availability(data.route, int(data.leg), graph)
	if not data.blocked.is_empty():
		data.cursor = clock # Suspended time cannot become travel credit on reopening.
		return _result(data, "", value)
	var duration: float = data.route.legs[int(data.leg)].seconds
	var delta: float = minf(STEP, minf(clock - float(data.cursor), duration - float(data.elapsed)))
	data.cursor += delta
	data.elapsed += delta
	data.at_gateway = data.elapsed == 0
	if data.elapsed >= duration: _next_leg(data)
	return _result(data, "", value)

static func observe_near(value: Dictionary, epoch: int, clock: float, place: Dictionary, graph: Dictionary) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	if value.owner != "near": return _failure("transport.wrong_owner")
	if value.status != "moving": return _failure("transport.not_moving")
	if not Routes.node_valid({"id": "observation", "region_id": "observation", "settlement_id": "", "faction_id": value.faction_id, "place": place}, value.route.body_id): return _failure("transport.observation")
	var data: Dictionary = value.duplicate(true)
	var target: Dictionary = data.route.nodes[int(data.leg) + 1].place
	if place.radius != target.radius: return _failure("transport.observation")
	data.cursor = clock # Near travel advances only through physical observations.
	data.blocked = Routes.availability(data.route, int(data.leg), graph)
	if data.blocked.is_empty() and Routes.Home.distance(place, target) <= 1.0:
		_next_leg(data)
	else:
		data.at_gateway = Routes.Home.distance(place, data.route.nodes[int(data.leg)].place) <= 1.0
	return _result(data, "", value)

static func return_to_source(value: Dictionary, epoch: int, clock: float, route: Dictionary) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	if value.status not in ["moving", "arrived"] or not value.at_gateway or value.returning: return _failure("transport.return_at_gateway_only")
	problem = Routes.validate_route(route, int(value.amount))
	if not problem.is_empty(): return _failure(problem)
	if route.body_id != value.route.body_id or route.graph_id != value.route.graph_id or route.nodes.front() != value.route.nodes[int(value.leg)] or route.nodes.back() != value.source: return _failure("transport.return_route")
	var data: Dictionary = value.duplicate(true)
	data.route = route.duplicate(true)
	data.leg = 0
	data.elapsed = 0.0
	data.cursor = clock
	data.returning = true
	data.status = "arrived" if route.legs.is_empty() else "moving"
	data.blocked = ""
	return _result(data, "", value)

static func finish(value: Dictionary, epoch: int, clock: float, action: String) -> Dictionary:
	var problem: String = _guard(value, epoch, clock)
	if not problem.is_empty(): return _failure(problem)
	var data: Dictionary = value.duplicate(true)
	match action:
		"cancel":
			if data.status != "reserved": return _failure("transport.loaded_cargo_requires_return")
			data.status = "cancelled"
		"deliver":
			if data.status != "arrived": return _failure("transport.arrival_missing")
			data.status = "returned" if data.returning else "delivered"
		"lose":
			if data.status not in ["moving", "arrived"]: return _failure("transport.no_carried_cargo")
			data.status = "lost"
		_: return _failure("transport.action")
	data.cursor = clock
	data.blocked = ""
	return _result(data, data.status, value)

static func _next_leg(data: Dictionary) -> void:
	data.leg += 1
	data.elapsed = 0.0
	data.at_gateway = true
	if data.leg == data.route.legs.size(): data.status = "arrived"

static func _guard(value: Dictionary, epoch: int, clock: float) -> String:
	var problem: String = validate(value)
	if not problem.is_empty(): return problem
	if value.epoch != epoch: return "transport.stale_owner"
	if not Routes.Economy.number(clock, float(value.cursor), MAX_CLOCK): return "transport.clock"
	return ""

static func _failure(code: String) -> Dictionary:
	return {"ok": false, "code": code}

static func _result(data: Dictionary, action: String = "", expected: Dictionary = {}) -> Dictionary:
	var problem: String = validate(data)
	if not problem.is_empty(): return _failure(problem)
	var effects: Array = []
	if not action.is_empty():
		var endpoint: Dictionary = data.destination if action == "delivered" else data.source
		effects.append({"id": Ids.scoped("transport_effect", data.id, action), "action": action, "transport_id": data.id, "reservation_id": data.reservation_id, "settlement_id": endpoint.settlement_id, "endpoint_id": endpoint.id, "resource_id": data.resource_id, "amount": data.amount})
	return {"ok": true, "code": "", "data": data, "effects": effects, "expected": expected.duplicate(true)}

static func admit(current: Dictionary, proposal: Dictionary) -> Dictionary:
	# Call synchronously inside the single campaign owner, then save data and
	# effects together. The proposal is a local reducer result, not an import API.
	if not proposal.get("ok", false) or not proposal.get("expected") is Dictionary or not proposal.get("data") is Dictionary or not proposal.get("effects") is Array: return _failure("transport.proposal")
	if current != proposal.expected: return _failure("transport.stale_proposal")
	var problem: String = validate(proposal.data)
	if not problem.is_empty(): return _failure(problem)
	return {"ok": true, "code": "", "data": proposal.data.duplicate(true), "effects": proposal.effects.duplicate(true)}
