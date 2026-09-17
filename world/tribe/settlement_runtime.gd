extends Node
## The only live founding/selection transaction. Physical preflight runs while
## paused; one existing save commits collection, freight and progress together.
const Text = preload("res://core/localization/ui_text.gd")
const Collection = preload("res://world/tribe/settlement_collection.gd")
const Navigation = preload("res://world/tribe/village_navigation.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Visuals = preload("res://world/tribe/village_visuals.gd")
const Shelters = preload("res://world/tribe/village_shelters.gd")
var controller: Node
var busy: bool = false
var far_visuals: Dictionary = {}
var _timer: float = 0.0

func _ready() -> void:
	controller.panel.add_settlements(self)

func founding_reason() -> String:
	if busy or not controller.is_active(): return Text.text("SETTLEMENT_NOT_READY")
	if controller.body().get("surface_mode") != Collection.Home.Cube.MODE: return Text.text("SETTLEMENT_SPHERE_REQUIRED")
	if Collection.ids(controller.body()).size() >= Collection.MAX_SETTLEMENTS: return Text.text("SETTLEMENT_LIMIT")
	if controller.selected.size() != 1: return Text.text("SETTLEMENT_SELECT_FOUNDER")
	var member: Dictionary = controller.member_record(controller.selected[0])
	if member.is_empty() or member.id == controller._state.campaign.data.player_object_id: return Text.text("SETTLEMENT_KEEP_PLAYER")
	if member.order != "wait" or member.cargo != "" or member.construction_id != "" or member.care_pen_id != "" or member.paused_order != "": return Text.text("SETTLEMENT_FOUNDER_BUSY")
	var distance: float = Collection.Home.distance(member.position, controller.village().anchor)
	if distance < 14.0 or distance > 20.0: return Text.text("SETTLEMENT_WALK_FIRST")
	return ""

func found() -> bool:
	var reason: String = founding_reason()
	if not reason.is_empty(): return _message(reason)
	var member_id: String = controller.selected[0]
	var anchor: Dictionary = controller.member_record(member_id).position.duplicate(true)
	if controller.navigation.route(controller.anchor(), Space.resolve(self, anchor)).is_empty(): return _message(Text.text("SETTLEMENT_ROUTE_MISSING"))
	busy = true
	get_tree().paused = true
	var body: Dictionary = controller.body()
	var id: String = body.id
	var nav := Navigation.new()
	nav.begin(controller.home, Space.resolve(self, anchor))
	if not await _navigation(nav, id): return _end(Text.text("SETTLEMENT_GROUND_MISSING"))
	var sites: Dictionary = nav.sites()
	if sites.is_empty() or not _clear_sites(body, anchor, sites): return _end(Text.text("SETTLEMENT_OVERLAP"))
	if not await controller.finish_navigation_for_departure(): return _end(Text.text("SETTLEMENT_ROUTES_BUSY"))
	var simulation: Dictionary = await controller.prepare_far_simulation()
	if simulation.is_empty(): return _end(Text.text("SETTLEMENT_CERTIFY_FAILED"))
	controller.domestication._flush("")
	var before: Dictionary = body.duplicate(true)
	var result: Dictionary = Collection.found(body, controller._state.campaign.data, member_id, anchor, sites)
	if not result.ok: return _end(Text.text("SETTLEMENT_FOUND_FAILED"))
	body.clear()
	body.merge(result.body)
	simulation.owner = "near"
	simulation.legs.erase(member_id)
	Collection.set_simulation(body, simulation)
	controller._transaction = true
	var saved: bool = controller._saves.save_now()
	controller._transaction = false
	if not saved:
		body.clear()
		body.merge(before)
		return _end(Text.text("SETTLEMENT_FOUND_SAVE_FAILED"))
	# Retire the old actor before the second settlement can spawn this identity.
	var actor: Node3D = controller.actors.get(member_id)
	if is_instance_valid(actor):
		Space.untrack(actor)
		actor.get_parent().remove_child(actor)
		actor.queue_free()
	controller.actors.erase(member_id)
	controller.selected.clear()
	controller._state.far_scheduler.rebuild(controller._state.campaign.data)
	refresh_visuals()
	_end(Text.text("SETTLEMENT_FOUNDED"))
	return true

func select(id: String) -> bool:
	if busy or not controller.is_active(): return false
	var body: Dictionary = controller.body()
	if not body.has("settlements") or id not in Collection.ids(body): return false
	if id == Collection.selected_id(body): return true
	busy = true
	get_tree().paused = true
	if not await controller.finish_navigation_for_departure(): return _end(Text.text("SETTLEMENT_ROUTES_PENDING"))
	var simulation: Dictionary = await controller.prepare_far_simulation()
	if simulation.is_empty(): return _end(Text.text("SETTLEMENT_WORK_CHECKPOINT"))
	controller.domestication._flush("")
	var before: Dictionary = body.duplicate(true)
	var progression: Node = get_node("/root/ProgressionService")
	var progress_before: Dictionary = progression.export_state()
	if Collection.SiteTransport.active(body) and not Collection.SiteTransport.handoff(body, "far"):
		return _end(Text.text("SITE_FREIGHT_ROUTE"))
	Collection.set_simulation(body, simulation)
	var target: Dictionary = Collection.view(body, id)
	# Only already accrued, bounded campaign time; no wall-clock production.
	while target.village_simulation.get("owner") == "far" and float(target.village_simulation.cursor) + 0.000001 < float(controller._state.campaign.data.elapsed_seconds):
		var started: int = Time.get_ticks_usec()
		for index in range(32):
			if not Collection.Simulation.advance(target, float(controller._state.campaign.data.elapsed_seconds), float(progression.get_behavior_effect("group_cooperation", 1).value), progression.record_far_work.bind(controller._state), true): break
			if Collection.SiteTransport.active(body): Collection.SiteTransport.advance(body, float(controller._state.campaign.data.elapsed_seconds))
			if Time.get_ticks_usec() - started >= 2000: break
		await get_tree().process_frame
	while Collection.SiteTransport.active(body) and Collection.SiteTransport.advance(body, float(controller._state.campaign.data.elapsed_seconds)):
		await get_tree().process_frame
	var nav := Navigation.new()
	nav.begin(controller.home, Space.resolve(self, target.tribe.anchor), target.tribe, 20)
	if not await _navigation(nav, str(body.id)):
		_restore(body, before, progress_before)
		return _end(Text.text("SETTLEMENT_TARGET_ROUTES"))
	Collection.select(body, id)
	if target.village_simulation.is_empty():
		Collection.set_simulation(body, Collection.Simulation.create(body.id, controller._state.campaign.data.elapsed_seconds, {}, [], controller._state.campaign.data.player_object_id))
	var owner: Dictionary = Collection.view(body).village_simulation
	owner.owner = "near"
	owner.cursor = controller._state.campaign.data.elapsed_seconds
	owner.legs.clear()
	controller._transaction = true
	var saved: bool = controller._saves.save_now()
	controller._transaction = false
	if not saved:
		_restore(body, before, progress_before)
		return _end(Text.text("SETTLEMENT_SWITCH_FAILED"))
	_clear_visuals()
	controller.domestication._invalidate(null)
	controller._deactivate()
	controller.navigation = nav
	controller._activate()
	controller._state.far_scheduler.rebuild(controller._state.campaign.data)
	refresh_visuals()
	_end(Text.text("SETTLEMENT_SWITCHED"))
	return true

func _restore(body: Dictionary, before: Dictionary, progression: Dictionary) -> void:
	body.clear()
	body.merge(before)
	get_node("/root/ProgressionService").import_state(progression)

func _navigation(nav: RefCounted, body_id: String) -> bool:
	# A fresh 20 m graph needs thousands of collision samples. At 2 FPS the
	# return graph can exceed 120 s even while every slice makes progress.
	# Retain the 2 ms / 128-cell slice and a bounded transaction watchdog.
	var deadline: int = Time.get_ticks_msec() + 240000
	while nav.pending:
		if Time.get_ticks_msec() > deadline or controller._state.active_body_id != body_id:
			nav.cancel()
			return false
		nav.advance()
		if nav.pending: await get_tree().physics_frame
	return nav.is_ready()

func _clear_sites(body: Dictionary, anchor: Dictionary, sites: Dictionary) -> bool:
	var fresh: Array = [anchor, sites.wood, sites.stone, sites.food]
	fresh.append_array(sites.huts)
	for id: String in Collection.ids(body):
		var data: Dictionary = Collection.village(body, id)
		var occupied: Array = [data.anchor]
		for deposit: Dictionary in data.deposits.values(): occupied.append(deposit.position)
		for building: Dictionary in Collection.Tribe.Housing.obstacles(data) + data.husbandry.pens + data.economy.stations.values(): occupied.append(building.position)
		if body.has("tribal_neighbor"): occupied.append(body.tribal_neighbor.anchor)
		for point: Dictionary in fresh:
			for previous: Dictionary in occupied:
				if Collection.Home.distance(point, previous) < 4.0: return false
	return true

func _message(text: String) -> bool:
	controller.status = text
	controller.panel.refresh()
	return false

func _end(text: String) -> bool:
	busy = false
	get_tree().paused = false
	return _message(text)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0: return
	_timer = 0.5
	if not controller._active:
		_clear_visuals()
		return
	refresh_visuals()

func refresh_visuals() -> void:
	var body: Dictionary = controller.body()
	var wanted: Array = Collection.ids(body)
	wanted.erase(Collection.selected_id(body))
	for id: String in far_visuals.keys():
		if id not in wanted: _remove_visual(id)
	for id: String in wanted:
		var data: Dictionary = Collection.village(body, id)
		if not far_visuals.has(id):
			var props := Visuals.new()
			var buildings := Shelters.new()
			get_tree().current_scene.add_child(props)
			get_tree().current_scene.add_child(buildings)
			far_visuals[id] = {"props": props, "buildings": buildings, "signature": ""}
		var visible: Dictionary = far_visuals[id]
		var stations: Array = []
		for key: String in data.economy.stations:
			var site: Dictionary = data.economy.stations[key]
			stations.append([site.id, site.position, Collection.Economy.station_source(data, key).remaining])
		# Partial production clocks are not visible geometry. Only publish changes
		# to location, identity or the actual ready amount for either instance.
		var signature: String = JSON.stringify([data.stock, data.project, stations, data.housing.homes, data.husbandry.pens])
		if signature != visible.signature:
			visible.signature = signature
			visible.props.rebuild(data)
			visible.buildings.sync(data, {})

func _remove_visual(id: String) -> void:
	for key: String in ["props", "buildings"]:
		var node: Node3D = far_visuals[id][key]
		if is_instance_valid(node):
			Space.untrack(node)
			node.get_parent().remove_child(node)
			node.queue_free()
	far_visuals.erase(id)

func _clear_visuals() -> void:
	for id: String in far_visuals.keys(): _remove_visual(id)

func _exit_tree() -> void:
	# These siblings leave with the scene; its child list is locked here.
	for entry: Dictionary in far_visuals.values():
		for key: String in ["props", "buildings"]:
			if is_instance_valid(entry[key]):
				Space.untrack(entry[key])
				entry[key].queue_free()
	far_visuals.clear()
	if busy: get_tree().paused = false

## Keep both sites' structures and already certified freight corridors free.
## This is a placement preflight, not another per-frame navigation graph.
func occupies(position: Vector3) -> bool:
	if controller.site_transport.occupies(position): return true
	var body: Dictionary = controller.body()
	for id: String in Collection.ids(body):
		if id == Collection.selected_id(body): continue
		var data: Dictionary = Collection.village(body, id)
		var places: Array = [data.anchor]
		for place: Dictionary in data.deposits.values(): places.append(place.position)
		for member: Dictionary in data.members: places.append(member.position)
		for place: Dictionary in Collection.Tribe.Housing.obstacles(data) + data.husbandry.pens + data.economy.stations.values(): places.append(place.position)
		for place: Dictionary in places:
			if position.distance_to(Space.resolve(self, place)) < 4.0: return true
		for path: Array in Collection.view(body, id).get("village_simulation", {}).get("roads", {}).values():
			for point: Dictionary in path:
				if position.distance_to(Space.resolve(self, point)) < 2.0: return true
	return false
