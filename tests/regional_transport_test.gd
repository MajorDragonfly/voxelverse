extends SceneTree
## ARCH-27 model acceptance. Fixture stocks exercise the future atomic owner
## boundary; this does not claim two playable settlements or terrain routing.
const Routes = preload("res://world/tribe/transport/regional_routes.gd")
const Transport = preload("res://world/tribe/transport/regional_transport.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const PATH: String = "user://arch27_snapshot.json"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_cmdline_user_args().has("--arch27-restart"):
		_restart()
	else:
		_routes()
		_journey()
		_far_delivery()
		_returns()
		_validation()
	print(JSON.stringify({"test": "regional_transport", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _graph() -> Dictionary:
	var nodes: Dictionary = {}
	for id: String in ["a", "gate", "b", "detour"]:
		var u: float = {"a": 0.0, "gate": 0.0001, "b": 0.0002, "detour": 0.0003}[id]
		var place: Dictionary = Routes.Home.Cube.address("body", 2, u, 0)
		place.radius = 6371000.0
		nodes[id] = {"id": id, "region_id": "region_" + id, "settlement_id": "settlement_" + id if id in ["a", "b"] else "", "faction_id": "ours", "place": place}
	var edges: Dictionary = {}
	for row: Array in [["a", "gate", 0.5, 4], ["gate", "b", 0.5, 4], ["a", "detour", 2.0, 8], ["detour", "b", 2.0, 8], ["gate", "a", 0.5, 4], ["b", "gate", 0.5, 4]]:
		var id: String = row[0] + "_" + row[1]
		edges[id] = {"id": id, "from": row[0], "to": row[1], "mode": "foot", "seconds": row[2], "capacity": row[3], "revision": 1, "blocked": false}
	return {"schema": 1, "id": "network", "body_id": "body", "nodes": nodes, "edges": edges}

func _order(graph: Dictionary, id: String = "shipment") -> Dictionary:
	return Transport.create(id, "ours", "carrier", "reservation_" + id, "wood", 3, Routes.plan(graph, "a", "b", 3).route, 0).data

func _routes() -> void:
	var graph: Dictionary = _graph()
	_expect(Routes.validate(graph).is_empty(), "valid bounded network")
	var route: Dictionary = Routes.plan(graph, "a", "b", 3).route
	_expect(route.legs.size() == 2 and route.legs[0].id == "a_gate", "fastest certified path")
	_expect(Routes.plan(graph, "a", "b", 5).route.legs[0].id == "a_detour", "capacity selects wider connection")
	_expect(not Routes.plan(graph, "a", "b", 9).ok, "capacity cannot invent route")
	graph.edges.a_gate.blocked = true
	_expect(Routes.plan(graph, "a", "b", 3).route.legs[0].id == "a_detour", "blocked route uses available detour")
	graph.edges.a_detour.blocked = true
	_expect(not Routes.plan(graph, "a", "b", 3).ok, "disconnected endpoints remain unreachable")
	_expect(route.legs[0].blocked == false, "planned route does not alias graph")
	graph = _graph()
	graph.edges.gate_b.revision += 1
	_expect(Routes.availability(route, 1, graph) == "route.recertification_required", "changed certificate suspends old route")
	graph = _graph()
	graph.nodes.b.region_id = "moved"
	_expect(Routes.availability(route, 1, graph) == "route.endpoint_changed", "relocated receiving endpoint invalidates route")
	graph = _graph()
	var reversed: Dictionary = graph.duplicate(true)
	reversed.edges = {}
	var keys: Array = graph.edges.keys()
	keys.reverse()
	for key: String in keys: reversed.edges[key] = graph.edges[key]
	_expect(Routes.plan(graph, "a", "b", 3) == Routes.plan(reversed, "a", "b", 3), "route independent of insertion order")
	# Persisted gateways can cross a cube face boundary without local XYZ.
	graph.nodes.a.place = Routes.Home.Cube.address("body", 0, 0.9999, 0)
	graph.nodes.gate.place = Routes.Home.Cube.address("body", 5, -0.9999, 0)
	graph.nodes.a.place.radius = 6371000.0
	graph.nodes.gate.place.radius = 6371000.0
	_expect(Routes.plan(graph, "a", "b", 3).ok, "body fixed gateways across cube seam")
	var large: Dictionary = {"schema": 1, "id": "large", "body_id": "body", "nodes": {}, "edges": {}}
	for i: int in 66:
		var node: Dictionary = graph.nodes.a.duplicate(true)
		node.id = "node_%03d" % i
		large.nodes[node.id] = node
		if i == 0: continue
		var edge: Dictionary = graph.edges.a_gate.duplicate(true)
		edge.id = "edge_%03d" % i
		edge.from = "node_%03d" % (i - 1)
		edge.to = node.id
		large.edges[edge.id] = edge
	_expect(Routes.plan(large, "node_000", "node_065").code == "routes.leg_budget", "route length bounded independently of world size")

func _journey() -> void:
	var graph: Dictionary = _graph()
	var reserved: Dictionary = _order(graph)
	_expect(Transport.validate(reserved).is_empty(), "reserved order valid")
	_expect(not Transport.finish(reserved, 1, 0, "deliver").ok, "reservation cannot credit destination")
	var departure: Dictionary = Transport.depart(reserved, 1, 0)
	var order: Dictionary = Transport.admit(reserved, departure).data
	_expect(reserved.status == "reserved" and order.status == "moving", "proposal leaves live state untouched")
	_expect(not Transport.admit(order, departure).ok, "pickup replay rejected")
	order = Transport.handoff(order, 1, "far", 0).data
	_expect(not Transport.advance_far(order, 1, 1, graph).ok, "old simulation owner rejected")
	order = Transport.advance_far(order, 2, 1, graph).data
	_expect(order.elapsed == 0.25 and order.cursor == 0.25 and order.leg == 0, "far work limited to one quarter second")
	_expect(Transport.advance_far(order, 2, 0.25, graph).data == order, "paused campaign clock does not travel")
	_expect(not Transport.handoff(order, 2, "near", 0.25).ok, "handoff cannot teleport from middle of connection")
	_expect(not Transport.finish(order, 2, 1, "deliver").ok, "moving cargo not credited")
	graph.edges.a_gate.blocked = true
	order = Transport.advance_far(order, 2, 10, graph).data
	_expect(order.elapsed == 0.25 and order.cursor == 10 and order.blocked == "route.blocked", "road closure preserves cargo and progress")
	graph.edges.a_gate.blocked = false
	order = Transport.advance_far(order, 2, 10, graph).data
	_expect(order.elapsed == 0.25, "suspended time cannot be replayed")
	order = Transport.advance_far(order, 2, 11, {}).data
	_expect(order.cursor == 11 and order.elapsed == 0.25 and order.blocked == "route.network_unavailable", "region eviction suspends route")
	var snapshot: Dictionary = {"graph": graph, "order": order, "stock_a": 7, "stock_b": 0, "carried": 3, "clock": 11}
	_expect(Atomic.write(PATH, snapshot) == OK, "save in transit")
	_child()
	var before_text: String = FileAccess.get_file_as_string(PATH)
	order = Transport.advance_far(order, 2, 11.25, graph).data
	_expect(order.leg == 1 and order.elapsed == 0 and order.at_gateway, "next certified gateway reached")
	_expect(not Transport.handoff(order, 2, "near", 12).ok, "handoff must account for pending time")
	order = Transport.handoff(order, 2, "near", 11.25).data
	_expect(not Transport.advance_far(order, 2, 12, graph).ok, "previous far worker invalidated")
	order = Transport.observe_near(order, 3, 20, graph.nodes.a.place, graph).data
	_expect(order.status == "moving" and order.leg == 1, "near elapsed time alone is not arrival")
	_expect(not Transport.handoff(order, 3, "far", 20).ok, "near actor must reach gateway before handoff")
	order = Transport.observe_near(order, 3, 21, graph.nodes.b.place, graph).data
	_expect(order.status == "arrived", "physical target observation allows arrival")
	var delivered: Dictionary = Transport.finish(order, 3, 21, "deliver")
	_expect(delivered.ok and delivered.effects.size() == 1 and delivered.effects[0].settlement_id == "settlement_b", "single destination effect after arrival")
	var candidate: Dictionary = snapshot.duplicate(true)
	candidate.order = Transport.admit(order, delivered).data
	candidate.stock_b += delivered.effects[0].amount
	candidate.carried = 0
	candidate.clock = 21
	_expect(DirAccess.make_dir_absolute(PATH + ".tmp") == OK, "inject writer failure")
	_expect(Atomic.write(PATH, candidate) != OK and FileAccess.get_file_as_string(PATH) == before_text, "failed common commit retains old cargo and stocks")
	_expect(DirAccess.remove_absolute(PATH + ".tmp") == OK, "remove writer failure")
	_expect(Atomic.write(PATH, candidate) == OK, "commit destination and transport together")
	_expect(candidate.stock_a + candidate.stock_b + candidate.carried == 10, "delivery conserves material")
	_expect(not Transport.admit(candidate.order, delivered).ok and not Transport.finish(candidate.order, 3, 21, "deliver").ok, "acknowledgement replay cannot duplicate freight")
	_child()

func _returns() -> void:
	var graph: Dictionary = _graph()
	var reserved: Dictionary = _order(graph, "cancel")
	var cancelled: Dictionary = Transport.finish(reserved, 1, 0, "cancel")
	_expect(cancelled.ok and cancelled.effects[0].action == "cancelled" and cancelled.effects[0].amount == 3, "unloaded cancellation releases reservation")
	_expect(not Transport.finish(cancelled.data, 1, 0, "cancel").ok, "reservation released once")
	var order: Dictionary = Transport.depart(reserved, 1, 0).data
	_expect(not Transport.finish(order, 1, 0, "cancel").ok, "loaded cancellation cannot teleport stock home")
	var local_return: Dictionary = Transport.return_to_source(order, 1, 0, Routes.plan(graph, "a", "a", 3).route)
	_expect(local_return.ok and Transport.finish(local_return.data, 1, 0, "deliver").data.status == "returned", "loaded but unmoved cargo can be unloaded at source")
	order = Transport.observe_near(order, 1, 1, graph.nodes.gate.place, graph).data
	var reverse_route: Dictionary = Routes.plan(graph, "gate", "a", 3).route
	order = Transport.return_to_source(order, 1, 1, reverse_route).data
	_expect(order.returning and order.status == "moving" and not Transport.finish(order, 1, 1, "deliver").ok, "return requires a real route home")
	graph.edges.gate_a.blocked = true
	order = Transport.observe_near(order, 1, 2, graph.nodes.a.place, graph).data
	_expect(order.status == "moving", "blocked return cannot credit source")
	graph.edges.gate_a.blocked = false
	order = Transport.observe_near(order, 1, 3, graph.nodes.a.place, graph).data
	var returned: Dictionary = Transport.finish(order, 1, 3, "deliver")
	_expect(returned.ok and returned.data.status == "returned" and returned.effects[0].settlement_id == "settlement_a", "return credits source only")
	var lost: Dictionary = Transport.finish(Transport.depart(reserved, 1, 0).data, 1, 2, "lose")
	_expect(lost.ok and lost.data.status == "lost" and lost.effects[0].action == "lost", "loss is terminal balance event")
	_expect(not Transport.finish(lost.data, 1, 2, "deliver").ok and not Transport.finish(lost.data, 1, 2, "lose").ok, "lost cargo cannot be delivered or lost twice")

func _far_delivery() -> void:
	var graph: Dictionary = _graph()
	var order: Dictionary = Transport.depart(_order(graph, "far"), 1, 0).data
	order = Transport.handoff(order, 1, "far", 0).data
	for i: int in 4:
		var result: Dictionary = Transport.advance_far(order, 2, 100, graph)
		_expect(result.ok and result.effects.is_empty(), "travel alone cannot apply stock effect")
		order = result.data
	_expect(order.status == "arrived" and order.cursor == 1, "far arrival consumes exactly certified travel time")
	_expect(Transport.finish(order, 2, 100, "deliver").data.status == "delivered", "far arrival permits settlement receipt")
	order = Transport.return_to_source(order, 2, 100, Routes.plan(graph, "b", "a", 3).route).data
	for i: int in 4: order = Transport.advance_far(order, 2, 101, graph).data
	_expect(order.status == "arrived" and order.cursor == 101, "far return traverses reverse connections")
	_expect(Transport.finish(order, 2, 101, "deliver").data.status == "returned", "far return conserves original source")

func _validation() -> void:
	var graph: Dictionary = _graph()
	var valid: Dictionary = _order(graph)
	for field: String in valid:
		for wrong: Variant in [null, [], {}, true, "unexpected", NAN]:
			var bad: Dictionary = valid.duplicate(true)
			bad[field] = wrong
			if field in ["returning", "at_gateway"] and wrong is bool: continue
			if field in ["id", "faction_id", "carrier_id", "reservation_id"] and wrong is String: continue
			_expect(not Transport.validate(bad).is_empty(), "reject malformed order " + field)
	for path: Array in [["schema"], ["nodes", "a", "place", "mode"], ["nodes", "a", "place", "face"], ["nodes", "a", "place", "body_id"], ["edges", "a_gate", "seconds"], ["edges", "a_gate", "revision"], ["edges", "a_gate", "capacity"], ["edges", "a_gate", "from"]]:
		for wrong: Variant in [null, [], {}, true, "unexpected", NAN]:
			var bad: Dictionary = graph.duplicate(true)
			var target: Dictionary = bad
			for i: int in path.size() - 1: target = target[path[i]]
			target[path.back()] = wrong
			_expect(not Routes.validate(bad).is_empty(), "reject malformed network " + str(path))
	var foreign: Dictionary = graph.duplicate(true)
	foreign.nodes.b.faction_id = "foreign"
	_expect(not Transport.create("foreign", "ours", "carrier", "reservation", "wood", 3, Routes.plan(foreign, "a", "b", 3).route, 0).ok, "foreign storage never implicitly authorized")
	var newer: Dictionary = valid.duplicate(true)
	newer.schema = 2
	var original: Dictionary = newer.duplicate(true)
	_expect(not Transport.depart(newer, 1, 0).ok and newer == original, "future schema preserved without normalization")
	var broken: Dictionary = valid.duplicate(true)
	broken.status = "delivered"
	_expect(not Transport.validate(broken).is_empty(), "forged early completion rejected")
	broken = valid.duplicate(true)
	broken.route.legs[1].from = "a"
	_expect(not Transport.validate(broken).is_empty(), "disconnected route rejected")
	_expect(not Transport.depart(valid, 1, -1).ok, "backward clock rejected")

func _restart() -> void:
	var snapshot: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(PATH))
	_expect(not snapshot.is_empty(), "fresh process reads snapshot")
	if snapshot.is_empty(): return
	var order: Dictionary = snapshot.order
	_expect(Transport.validate(order).is_empty() and Routes.validate(snapshot.graph).is_empty(), "fresh process preserves contracts")
	_expect(snapshot.stock_a + snapshot.stock_b + snapshot.carried == 10, "fresh process retains material balance")
	if order.status == "moving":
		_expect(order.elapsed == 0.25 and order.leg == 0 and snapshot.carried == 3, "resume same region leg and cargo")
		var resumed: Dictionary = Transport.advance_far(order, int(order.epoch), snapshot.clock, snapshot.graph).data
		_expect(resumed.elapsed == order.elapsed and resumed.leg == order.leg, "closed application does not travel")
	else:
		_expect(order.status == "delivered" and snapshot.stock_b == 3 and snapshot.carried == 0, "restart after commit retains one delivery")
		_expect(not Transport.finish(order, int(order.epoch), snapshot.clock, "deliver").ok, "restart before acknowledgement does not duplicate delivery")

func _child() -> void:
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/regional_transport_test.gd", "--", "--arch27-restart"], output, true)
	_expect(code == 0, "fresh process successful: " + str(output))

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
