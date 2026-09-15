extends RefCounted
## One bounded shipment per body, sharing the campaign's villages and snapshot.
## The regional reducer owns movement; this adapter commits its stock effects.
const Transport = preload("res://world/tribe/transport/regional_transport.gd")
const Routes = Transport.Routes
const Economy = Routes.Economy
const Home = Routes.Home
const Ledger = Economy.Freight
const Ids = Transport.Ids
const FIELD: String = "site_transport"
const CAPACITY: int = 4
const ACTIVE: Array[String] = ["reserved", "moving", "arrived"]

static func village(body: Dictionary, id: String) -> Dictionary:
	return body.get("settlements", {}).get("entries", {}).get(id, {}).get("village", {})

static func job(body: Dictionary) -> Dictionary:
	return body.get(FIELD, {}).get("job", {})

static func active(body: Dictionary) -> bool:
	return job(body).get("status", "") in ACTIVE

static func bound(body: Dictionary, id: String) -> bool:
	return active(body) and job(body).carrier_id == id

static func member(body: Dictionary) -> Dictionary:
	var shipment: Dictionary = job(body)
	if shipment.is_empty(): return {}
	for resident: Dictionary in village(body, shipment.source.settlement_id).get("members", []):
		if resident.id == shipment.carrier_id: return resident
	return {}

static func available(body: Dictionary, source: String, carrier: String, player: String) -> bool:
	if active(body) or carrier == player: return false
	for animal: Dictionary in body.get("domesticated_animals", {}).get("registry", {}).get("animals", {}).values():
		if animal.get("handler_id") == carrier or animal.get("pending", {}).get("actor_id") == carrier: return false
	if carrier in body.get("tribal_neighbor", {}).get("aid", {}).get("carriers", []): return false
	for resident: Dictionary in village(body, source).get("members", []):
		if resident.id == carrier:
			return resident.order == "wait" and resident.paused_order == "" and resident.cargo == "" and resident.construction_id == "" and resident.care_pen_id == "" and Home.distance(resident.position, village(body, source).anchor) <= 1.0
	return false

## The caller certifies each segment using loaded navigation before this call.
static func graph(body: Dictionary, source: String, destination: String, path: Array) -> Dictionary:
	var result: Dictionary = {"schema": 1, "id": Ids.scoped("routes", body.id, "sites"), "body_id": body.id, "nodes": {}, "edges": {}}
	if path.size() < 2 or path.size() > Routes.MAX_LEGS + 1: return {}
	var faction: String = village(body, source).faction_id
	for i: int in path.size():
		var id: String = "site_gate_%d" % i
		result.nodes[id] = {"id": id, "region_id": Ids.scoped("region", body.id, "site-corridor"), "settlement_id": source if i == 0 else (destination if i == path.size() - 1 else ""), "faction_id": faction, "place": path[i].duplicate(true)}
		if i == 0: continue
		var seconds: float = maxf(0.01, Home.distance(path[i - 1], path[i]) / 2.28)
		for reverse: bool in [false, true]:
			var edge_id: String = "site_edge_%d_%s" % [i, "back" if reverse else "out"]
			result.edges[edge_id] = {"id": edge_id, "from": id if reverse else "site_gate_%d" % (i - 1), "to": "site_gate_%d" % (i - 1) if reverse else id, "mode": "foot", "seconds": seconds, "capacity": CAPACITY, "revision": 1, "blocked": false}
	return result if Routes.validate(result).is_empty() else {}

static func reserve(body: Dictionary, campaign: Dictionary, source: String, destination: String, carrier: String, kind: String, amount: int, network: Dictionary) -> Dictionary:
	if not available(body, source, carrier, campaign.player_object_id): return {"ok": false, "code": "carrier"}
	var a: Dictionary = village(body, source)
	var b: Dictionary = village(body, destination)
	if a.is_empty() or b.is_empty() or a.id == b.id or a.faction_id != b.faction_id or kind not in Ledger.KINDS or amount < 1 or amount > CAPACITY: return {"ok": false, "code": "request"}
	if int(a.stock.get(kind, 0)) < amount: return {"ok": false, "code": "stock"}
	if Economy.reserve(b, kind) + Economy.pending(b, kind) + amount > 48: return {"ok": false, "code": "capacity"}
	var plan: Dictionary = Routes.plan(network, "site_gate_0", "site_gate_%d" % (network.get("nodes", {}).size() - 1), amount)
	if not plan.ok: return {"ok": false, "code": "route"}
	if plan.route.nodes.front().place != a.anchor or plan.route.nodes.back().place != b.anchor or plan.route.nodes.front().settlement_id != source or plan.route.nodes.back().settlement_id != destination: return {"ok": false, "code": "route"}
	var sequence: int = int(body.get(FIELD, {}).get("sequence", 0)) + 1
	if sequence > 1000000000: return {"ok": false, "code": "limit"}
	var identity: String = Ids.scoped("site_transport", body.id, str(sequence))
	var proposal: Dictionary = Transport.create(identity, a.faction_id, carrier, Ids.scoped("reservation", identity, "stock"), kind, amount, plan.route, campaign.elapsed_seconds)
	if not proposal.ok: return proposal
	if Ledger.amount(a, "exports", kind) + amount > 1000000000 or Ledger.amount(b, "imports", kind) + amount > 1000000000: return {"ok": false, "code": "limit"}
	for data: Dictionary in [a, b]:
		if not data.economy.has("freight"): data.economy.freight = Ledger.create()
	# Escrow removes spendable stock; source capacity is held for a possible
	# return, destination capacity for arrival. Neither is a second goods copy.
	a.stock[kind] -= amount
	a.economy.freight.exports[kind] += amount
	a.economy.freight.held[kind] += amount
	b.economy.freight.held[kind] += amount
	body[FIELD] = {"schema": 1, "body_id": body.id, "sequence": sequence, "graph": network.duplicate(true), "job": proposal.data, "cancel_requested": false}
	return {"ok": true, "code": ""}

static func _apply(body: Dictionary, proposal: Dictionary) -> bool:
	var accepted: Dictionary = Transport.admit(job(body), proposal)
	if not accepted.ok: return false
	body[FIELD].job = accepted.data
	return true

static func depart(body: Dictionary) -> bool:
	var value: Dictionary = job(body)
	return _apply(body, Transport.depart(value, int(value.epoch), float(value.cursor)))

static func cancel(body: Dictionary) -> bool:
	if not active(body): return false
	body[FIELD].cancel_requested = true
	if job(body).status == "reserved": return _finish(body, "cancel")
	_turn_back(body)
	return true

static func _turn_back(body: Dictionary) -> void:
	var value: Dictionary = job(body)
	if not body[FIELD].cancel_requested or value.returning or not value.at_gateway: return
	var route: Dictionary = Routes.plan(body[FIELD].graph, value.route.nodes[int(value.leg)].id, value.source.id, int(value.amount))
	if route.ok: _apply(body, Transport.return_to_source(value, int(value.epoch), float(value.cursor), route.route))

static func _finish(body: Dictionary, action: String) -> bool:
	var value: Dictionary = job(body)
	var proposal: Dictionary = Transport.finish(value, int(value.epoch), float(value.cursor), action)
	if not proposal.ok: return false
	var a: Dictionary = village(body, value.source.settlement_id)
	var b: Dictionary = village(body, value.destination.settlement_id)
	var returning: bool = action == "cancel" or value.returning
	var target: Dictionary = a if returning else b
	var kind: String = value.resource_id
	var amount: int = int(value.amount)
	if not _apply(body, proposal): return false
	a.economy.freight.held[kind] -= amount
	b.economy.freight.held[kind] -= amount
	target.stock[kind] += amount
	if returning: a.economy.freight.exports[kind] -= amount
	else: b.economy.freight.imports[kind] += amount
	member(body).blocked = false
	return true

static func settle(body: Dictionary) -> bool:
	if not active(body): return false
	_turn_back(body)
	var value: Dictionary = job(body)
	if value.status != "arrived" or (body[FIELD].cancel_requested and not value.returning): return false
	var target: String = value.source.settlement_id if value.returning else value.destination.settlement_id
	# Do not let a lagging village consume a newly arrived load retroactively.
	if float(body.settlements.entries[target].simulation.get("cursor", 0)) + 0.000001 < float(value.cursor): return false
	return _finish(body, "deliver")

## Physical observations can hand off within a certified straight segment.
## Projection is bounded to the corridor; time never supplies near arrival.
static func handoff(body: Dictionary, owner: String) -> bool:
	var value: Dictionary = job(body)
	if value.owner == owner: return true
	if value.at_gateway: return _apply(body, Transport.handoff(value, int(value.epoch), owner, float(value.cursor)))
	var changed: Dictionary = value.duplicate(true)
	if owner == "far":
		var a: Dictionary = value.route.nodes[int(value.leg)].place
		var b: Dictionary = value.route.nodes[int(value.leg) + 1].place
		var position: Dictionary = member(body).position
		var length: float = Home.distance(a, b)
		var start: float = Home.distance(a, position)
		var end: float = Home.distance(b, position)
		var fraction: float = clampf((start * start + length * length - end * end) / maxf(0.000001, 2 * length * length), 0.0, 0.999999)
		if start * start - pow(fraction * length, 2) > 0.36: return false
		changed.elapsed = fraction * float(value.route.legs[int(value.leg)].seconds)
		changed.at_gateway = changed.elapsed == 0
	if owner == "near": changed.elapsed = 0.0
	changed.owner = owner
	changed.epoch += 1
	if not Transport.validate(changed).is_empty(): return false
	body[FIELD].job = changed
	return true

static func observe(body: Dictionary, place: Dictionary, clock: float, arrived: bool, blocked: bool) -> bool:
	if not active(body): return false
	var value: Dictionary = job(body)
	if value.status == "reserved": depart(body); value = job(body)
	if value.status != "moving" or not handoff(body, "near"): return settle(body)
	value = job(body)
	var network: Dictionary = body[FIELD].graph
	var edge: Dictionary = network.get("edges", {}).get(value.route.legs[int(value.leg)].id, {})
	if not edge.is_empty(): edge.blocked = blocked
	# Only pass a target observation after the physical host reports arrival.
	# RegionalTransport's generic one-metre threshold must not skip waypoints.
	if arrived or blocked:
		_apply(body, Transport.observe_near(value, int(value.epoch), clock, place, network))
	else:
		value.cursor = clock
		value.at_gateway = Home.distance(place, value.route.nodes[int(value.leg)].place) <= 0.05
		value.blocked = ""
		if value.at_gateway: value.elapsed = 0.0
	_turn_back(body)
	settle(body)
	return true

static func advance(body: Dictionary, clock: float) -> bool:
	if not active(body): return false
	var value: Dictionary = job(body)
	var limit: float = clock
	for id: String in [value.source.settlement_id, value.destination.settlement_id]:
		limit = minf(limit, float(body.settlements.entries[id].simulation.get("cursor", 0)))
	if limit <= float(value.cursor) + 0.000001: return settle(body)
	if not handoff(body, "far"): return false
	if value.status == "reserved": depart(body)
	_turn_back(body)
	value = job(body)
	if value.status == "moving":
		if not _apply(body, Transport.advance_far(value, int(value.epoch), limit, body[FIELD].graph)): return false
		value = job(body)
		var a: Dictionary = value.route.nodes[int(value.leg)].place
		var position: Dictionary = a
		if value.status == "moving" and value.elapsed > 0:
			var b: Dictionary = value.route.nodes[int(value.leg) + 1].place
			var first: Array = Home.Cube.cartesian(a, a.radius)
			var last: Array = Home.Cube.cartesian(b, b.radius)
			var t: float = float(value.elapsed) / float(value.route.legs[int(value.leg)].seconds)
			position = Home.Cube.from_cartesian(a.body_id, [lerpf(first[0], last[0], t), lerpf(first[1], last[1], t), lerpf(first[2], last[2], t)], a.radius)
			position.radius = a.radius
		member(body).position = position.duplicate(true)
		member(body).blocked = not value.blocked.is_empty()
	settle(body)
	return true

static func validate(body: Dictionary, campaign: Dictionary) -> String:
	var data: Variant = body.get(FIELD, {})
	if not data is Dictionary: return "site_transport.fields"
	var collection: Variant = body.get("settlements", {})
	if not collection is Dictionary or not collection.get("entries", {}) is Dictionary: return "site_transport.settlements"
	var entries: Dictionary = collection.get("entries", {})
	if not data.is_empty():
		if not Routes.fields(data, ["schema", "body_id", "sequence", "graph", "job", "cancel_requested"]) or not Economy.integer(data.schema, 1, 1): return "site_transport.schema"
		if data.body_id != body.id or not Economy.integer(data.sequence, 1, 1000000000) or not data.cancel_requested is bool: return "site_transport.identity"
		if not Transport.validate(data.job).is_empty(): return "site_transport.job"
		if data.job.id != Ids.scoped("site_transport", body.id, str(int(data.sequence))) or data.job.reservation_id != Ids.scoped("reservation", data.job.id, "stock") or data.job.amount > CAPACITY or data.job.status == "lost": return "site_transport.identity"
		if not data.graph is Dictionary or (not data.graph.is_empty() and not Routes.validate(data.graph).is_empty()): return "site_transport.graph"
		if data.job.cursor > float(campaign.elapsed_seconds) + 0.000001 or data.job.route.body_id != body.id: return "site_transport.clock"
		for endpoint: Dictionary in [data.job.source, data.job.destination]:
			var place: Dictionary = village(body, endpoint.settlement_id)
			if place.is_empty() or place.anchor != endpoint.place or place.faction_id != data.job.faction_id: return "site_transport.endpoint"
		var resident: Dictionary = member(body)
		if resident.is_empty() or resident.id == campaign.player_object_id: return "site_transport.carrier"
		if active(body) and (resident.order != "wait" or resident.cargo != "" or resident.construction_id != "" or resident.care_pen_id != "" or resident.paused_order != ""): return "site_transport.carrier_busy"
	for kind: String in Ledger.KINDS:
		var balance: int = 0
		for id: String in entries:
			var place: Dictionary = village(body, id)
			var ledger: Variant = place.economy.get("freight", {})
			if not ledger is Dictionary or (not ledger.is_empty() and not Ledger.valid(ledger)): return "site_transport.ledger"
			balance += Ledger.amount(place, "exports", kind) - Ledger.amount(place, "imports", kind)
			var held: int = int(data.job.amount) if active(body) and data.job.resource_id == kind and id in [data.job.source.settlement_id, data.job.destination.settlement_id] else 0
			if Ledger.amount(place, "held", kind) != held: return "site_transport.reservation"
		var cargo: int = int(data.job.amount) if active(body) and data.job.resource_id == kind else 0
		if balance != cargo: return "site_transport.balance"
	return ""

static func unsupported(body: Dictionary) -> bool:
	var data: Variant = body.get(FIELD)
	if not data is Dictionary: return false
	if data.get("schema") != 1: return true
	var shipment: Variant = data.get("job")
	if shipment is Dictionary:
		if shipment.get("resource_revision") != Transport.Resources.REVISION: return true
		if shipment.get("route") is Dictionary and shipment.route.get("schema") != 1: return true
	for key: String in ["job", "graph"]:
		var value: Variant = data.get(key)
		if value is Dictionary and not value.is_empty() and value.get("schema") != 1: return true
	return false
