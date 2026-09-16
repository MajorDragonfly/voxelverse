extends Node
const Model = preload("res://world/tribe/transport/site_transport_state.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Text = preload("res://core/localization/ui_text.gd")
var controller: Node
var message: String = ""

func reason(destination: String) -> String:
	if not controller.is_active() or not controller.navigation.is_ready(): return "SITE_FREIGHT_NOT_READY"
	var body: Dictionary = controller.body()
	if body.get("settlements", {}).get("entries", {}).size() != 2 or destination == controller.village().id: return "SITE_FREIGHT_DESTINATION"
	if Model.active(body): return "SITE_FREIGHT_BUSY"
	if controller.selected.size() != 1 or not Model.available(body, controller.village().id, controller.selected[0], controller._state.campaign.data.player_object_id): return "SITE_FREIGHT_CARRIER"
	return ""

func send(destination: String, kind: String, amount: int) -> bool:
	message = reason(destination)
	if not message.is_empty(): return false
	var body: Dictionary = controller.body()
	var source: String = controller.village().id
	var start: Vector3 = controller.anchor()
	var end: Vector3 = Space.resolve(self, Model.village(body, destination).anchor)
	var points: PackedVector3Array = controller.navigation.route(start, end)
	if points.is_empty(): message = "SITE_FREIGHT_ROUTE"; return false
	var path: Array = [controller.village().anchor.duplicate(true)]
	for point: Vector3 in points:
		var place: Dictionary = Space.encode(self, point)
		if Model.Home.distance(path.back(), place) > 0.1: path.append(place)
	if Model.Home.distance(path.back(), Model.village(body, destination).anchor) < 0.1: path.pop_back()
	path.append(Model.village(body, destination).anchor.duplicate(true))
	var network: Dictionary = Model.graph(body, source, destination, path)
	if network.is_empty(): message = "SITE_FREIGHT_ROUTE"; return false
	controller.domestication._flush("")
	var before: Dictionary = body.duplicate(true)
	var result: Dictionary = Model.reserve(body, controller._state.campaign.data, source, destination, controller.selected[0], kind, amount, network)
	if not result.ok:
		body.clear(); body.merge(before)
		message = "SITE_FREIGHT_CAPACITY" if result.code == "capacity" else ("SITE_FREIGHT_STOCK" if result.code == "stock" else "SITE_FREIGHT_ROUTE")
		return false
	return _save(before, "SITE_FREIGHT_SENT")

func cancel() -> bool:
	if not controller.is_active() or not Model.active(controller.body()): return false
	controller.domestication._flush("")
	var before: Dictionary = controller.body().duplicate(true)
	if not Model.cancel(controller.body()): return false
	return _save(before, "SITE_FREIGHT_RETURN_REQUESTED")

func _save(before: Dictionary, success: String) -> bool:
	controller._transaction = true
	var saved: bool = controller._saves.save_now()
	controller._transaction = false
	if not saved:
		var body: Dictionary = controller.body()
		body.clear(); body.merge(before)
	message = success if saved else "SITE_FREIGHT_SAVE_FAILED"
	controller._routes.clear()
	controller._goals.clear()
	controller.panel.refresh()
	return saved

func tick(member: Dictionary, actor: CharacterBody3D, delta: float, simulation_delta: float) -> void:
	var body: Dictionary = controller.body()
	if not Model.handoff(body, "near"): return
	var value: Dictionary = Model.job(body)
	if value.status == "reserved": Model.depart(body); value = Model.job(body)
	if value.status != "moving": Model.settle(body); return
	member.hunger = maxf(0, float(member.hunger) - simulation_delta * 0.08)
	member.hydration = maxf(0, float(member.hydration) - simulation_delta * 0.06)
	var target: Vector3 = Space.resolve(self, value.route.nodes[int(value.leg) + 1].place)
	var arrived: bool = controller._walk(actor, member.id, target, delta, minf(member.hunger, member.hydration))
	member.position = Space.encode(self, actor.global_position)
	# A 0.5 m stair is measured tangentially by _walk. The regional observer
	# still checks its physical position and rejects a different endpoint.
	Model.observe(body, member.position, controller._state.campaign.data.elapsed_seconds, arrived, bool(member.blocked))
	controller._saves.schedule_autosave(1.0)

func occupies(position: Vector3) -> bool:
	if not Model.active(controller.body()): return false
	for point: Dictionary in Model.job(controller.body()).route.nodes:
		if position.distance_to(Space.resolve(self, point.place)) < 2.0: return true
	return false
