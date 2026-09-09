extends Node
## Host adapter for the existing tribe, SaveGameService and live D1 fauna.
const State = preload("res://world/domestication/animal_state.gd")
const Saved = preload("res://world/domestication/campaign_animal_state.gd")
const Controller = preload("res://world/domestication/domestication_controller.gd")
const Policy = preload("res://world/domestication/d1_taming_policy.gd")
const Animal = preload("res://world/domestication/campaign_animal.gd")
const AnimalControls = preload("res://world/domestication/domestication_controls.gd")
const Steering = preload("res://creatures/ai/wildlife_steering.gd")
var tribe: Node
var controller = Controller.new()
var animals: Dictionary = {}
var sources: Dictionary = {}
var controls: Control
var status: String = ""
var _state: Node
var _saves: Node
var _campaign: String = ""
var _body: String = ""
var _ready_runtime: bool = false
var _committing: bool = false
var _timer: float = 0
var _policy: RefCounted
var _routes: Dictionary = {}
var _goals: Dictionary = {}

func _ready() -> void:
	tribe = get_parent()
	_state = get_node("/root/GameState")
	_saves = get_node("/root/SaveGameService")
	_policy = Policy.new(resolve_suitability, {"food": "plant"})
	add_to_group(&"domestication_runtime")
	_saves.save_started.connect(_flush)
	_saves.game_loaded.connect(_invalidate)
	_state.world_seed_changed.connect(_invalidate)
	_state.phase_changed.connect(_invalidate)
	controller.animal_changed.connect(_changed)
	controls = AnimalControls.new()
	controls.runtime = self
	tribe.panel.add_extension(controls)

func _process(delta: float) -> void:
	if _ready_runtime and (_campaign != _state.campaign.data["id"] or _body != _state.get_current_body()["id"]):
		_invalidate(null)
	if not _ready_runtime and tribe.is_active(): _activate()
	if not is_active(): return
	for id: String in controller.registry.get("animals", {}):
		var a: Dictionary = controller.record(id)
		if not a["pending"].is_empty():
			var handler_id: String = a["pending"]["actor_id"]
			var result: Dictionary = controller.advance_offer(id, minf(_state.simulation_delta(delta), 0.25), context(id, handler_id))
			if not result["ok"] or str(result["code"]).begins_with("interrupted:"): _show(result)
	_timer -= delta
	if _timer <= 0:
		_timer = 0.25
		controls.refresh()

func _activate() -> void:
	var body: Dictionary = tribe.body()
	var problem: String = Saved.validate_body(body, _state.campaign.data)
	if not problem.is_empty():
		status = problem
		return
	var envelope: Dictionary = body.get(Saved.FIELD, Saved.create(_state.campaign.data, body))
	sources = envelope["sources"].duplicate(true)
	controller.configure(envelope["registry"], _persist, _policy.for_species)
	_campaign = _state.campaign.data["id"]
	_body = body["id"]
	_ready_runtime = true
	# Animals stand outside the original 12 m work grid. Expand only the
	# loaded collision graph, keeping all member positions inside the 22 m save contract.
	tribe.navigation.rebuild(tribe.home, tribe.anchor(), 20)
	for id: String in controller.registry["animals"]:
		_spawn(id)
	controls.refresh()

func _invalidate(_value: Variant) -> void:
	_ready_runtime = false
	for actor: Node in animals.values():
		if is_instance_valid(actor):
			actor.set_physics_process(false)
			actor.queue_free()
	animals.clear()
	sources.clear()
	controller.registry.clear()
	_routes.clear()
	_goals.clear()
	if is_instance_valid(controls): controls.hide()

func _exit_tree() -> void:
	_invalidate(null)

func is_active() -> bool:
	return _ready_runtime and is_instance_valid(tribe) and tribe.is_active() and _state.simulation_delta(1.0) > 0

func handler_actor(id: String) -> Node3D:
	var actor: Node3D = tribe.actors.get(id)
	if not is_instance_valid(actor) or bool(actor.get("is_dead")): return null
	return actor

func chosen_handler() -> String:
	return str(tribe.selected[0]) if tribe.selected.size() == 1 else ""

func visible_animals() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"wildlife"):
		if not node is Node3D or node.is_queued_for_deletion() or not node.has_method("get_campaign_identity"): continue
		var identity: Dictionary = node.get_campaign_identity()
		if identity.get("body_id") != _body or node.global_position.distance_to(tribe.anchor()) > 45: continue
		result.append(node)
	return result

func actor_for(id: String) -> Node3D:
	if animals.has(id) and is_instance_valid(animals[id]): return animals[id]
	for actor: Node3D in visible_animals():
		if actor.get_campaign_identity().get("object_id") == id: return actor
	return null

func resolve_suitability(species_id: String) -> Variant:
	for source: Dictionary in sources.values():
		if source["identity"]["species_id"] == species_id: return source["blueprint"]["species"].get("domestication", {}).duplicate(true)
	for actor: Node3D in visible_animals():
		if actor.get_campaign_identity().get("species_id") == species_id:
			return actor.blueprint.get("species", {}).get("domestication", {}).duplicate(true)
	return {}

func context(id: String, handler_id: String) -> Dictionary:
	var handler: Node3D = handler_actor(handler_id)
	var target: Node3D = actor_for(id)
	var campaign: Dictionary = _state.campaign.data
	return {"campaign_id": campaign["id"], "body_id": _state.get_current_body()["id"], "phase": _state.current_phase,
		"player_species_id": campaign["player_species_id"], "faction_id": campaign["player_faction_id"],
		"actor_id": handler_id, "actor_alive": handler != null, "paused": not is_active(),
		"handler_available": tribe.member_record(handler_id).get("order") == "wait" and tribe.member_record(handler_id).get("cargo") == "",
		"actor_position": handler.global_position if handler != null else Vector3.INF, "home": tribe.anchor(),
		"capacity": Saved.CAPACITY, "stock": tribe.village()["stock"].duplicate(),
		"line_of_sight": handler != null and target != null and Steering.clear_sight(handler, target),
		"threatened": frightened(id) or (target != null and not animals.has(id) and float(target.get("_threat_timer")) > 0.0)}

func offer(id: String) -> Dictionary:
	if not is_active(): return _show({"ok": false, "code": "tribal_age_required"})
	var handler_id: String = chosen_handler()
	var member: Dictionary = tribe.member_record(handler_id)
	if member.is_empty(): return _show({"ok": false, "code": "choose_one_handler"})
	if member["order"] != "wait" or member["cargo"] != "": return _show({"ok": false, "code": "handler_busy"})
	var target: Node3D = actor_for(id)
	if target == null: return _show({"ok": false, "code": "unknown_animal"})
	var fresh: bool = not controller.registry["animals"].has(id)
	var before_registry: Dictionary = controller.registry.duplicate(true)
	if fresh:
		var identity: Dictionary = target.get_campaign_identity()
		var source: Dictionary = Saved.source_from(target)
		if source["blueprint"].get("design_id", "") == "": return _show({"ok": false, "code": "unsuitable"})
		sources[id] = source
		var record: Dictionary = State.individual(id, identity["species_id"], identity["body_id"],
			{"id": source["blueprint"]["design_id"], "revision": int(identity.get("design_ref", {}).get("revision", 0))}, target.global_position)
		record["health"] = target.get_health_ratio() * 100.0
		if target.is_dead: record["status"] = "dead"
		controller.registry["animals"][id] = record
	var result: Dictionary = controller.begin_offer(id, "food", context(id, handler_id))
	if fresh:
		if result["ok"]: _spawn(id)
		else:
			controller.registry = before_registry
			sources.erase(id)
	return _show(result)

func approach(id: String) -> bool:
	if not is_active() or chosen_handler().is_empty():
		_show({"ok": false, "code": "choose_one_handler"})
		return false
	var actor: Node3D = actor_for(id)
	if actor == null: return false
	var handler: Node3D = handler_actor(chosen_handler())
	if handler == null:
		_show({"ok": false, "code": "choose_one_handler"})
		return false
	var best := Vector3.INF
	var length: float = INF
	for point_id: int in tribe.navigation.graph.get_point_ids():
		var point: Vector3 = tribe.navigation.graph.get_point_position(point_id)
		if point.distance_to(actor.global_position) > Controller.REACH - 0.25 or point.distance_to(tribe.anchor()) > 20: continue
		var route: PackedVector3Array = tribe.navigation.route(handler.global_position, point)
		if route.is_empty(): continue
		if point.distance_to(handler.global_position) < length:
			best = point
			length = point.distance_to(handler.global_position)
	if not best.is_finite():
		status = "Das Tier liegt außerhalb der erreichbaren Dorfumgebung."
		return false
	return tribe.issue_order("move", best, 20.0)

func issue_command(id: String, order: String) -> Dictionary:
	if not is_active(): return _show({"ok": false, "code": "tribal_age_required"})
	return _show(controller.command(id, order, context(id, chosen_handler())))

func cancel(id: String) -> Dictionary:
	if not is_active(): return _show({"ok": false, "code": "tribal_age_required"})
	return _show(controller.interrupt_offer(id))

func abandon(id: String) -> Dictionary:
	if not is_active(): return _show({"ok": false, "code": "tribal_age_required"})
	return _show(controller.abandon_claim(id, context(id, chosen_handler())))

func damage_animal(id: String, amount: float) -> bool:
	if not is_active() or not sources.has(id): return false
	var before: float = sources[id]["fear_until"]
	sources[id]["fear_until"] = simulation_time() + 6.0
	var result: Dictionary = controller.damage(id, amount)
	if not result["ok"]: sources[id]["fear_until"] = before
	return result["ok"]

func frightened(id: String) -> bool:
	return sources.has(id) and float(sources[id]["fear_until"]) > simulation_time()

func simulation_time() -> float:
	return float(_state.campaign.data["elapsed_seconds"])

func heading(actor: Node3D, target: Vector3) -> Vector3:
	var id: String = actor.object_id
	if not _goals.has(id) or _goals[id].distance_to(target) > 0.5:
		_routes[id] = tribe.navigation.route(actor.global_position, target)
		# A moving handler causes frequent replans. Do not send the animal
		# backwards to the nearest starting cell on every such refresh.
		if controller.record(id).get("order") == "follow" and _routes[id].size() > 1:
			_routes[id].remove_at(0)
		_goals[id] = target
	var route: PackedVector3Array = _routes.get(id, PackedVector3Array())
	while not route.is_empty():
		var offset := Vector3(route[0].x - actor.global_position.x, 0, route[0].z - actor.global_position.z)
		if offset.length() > 0.25:
			# Do not probe beyond a turn or the final waypoint into the next wall.
			actor.steer_distance = minf(1.1, offset.length())
			_routes[id] = route
			return offset.normalized()
		route.remove_at(0)
	_routes[id] = route
	var final_offset := Vector3(target.x - actor.global_position.x, 0, target.z - actor.global_position.z)
	actor.steer_distance = minf(1.1, final_offset.length())
	return final_offset.normalized()

func _spawn(id: String) -> void:
	# Remove the streamed representative before instantiating its held body.
	for actor: Node in get_tree().get_nodes_in_group(&"wildlife"):
		if not actor.has_method("get_campaign_identity") or actor.get_campaign_identity().get("object_id") != id: continue
		var parent: Node = actor.get_parent()
		if parent != null and parent.get("_active_fauna") is Array: parent._active_fauna.erase(actor)
		actor.set_physics_process(false)
		actor.remove_from_group(&"wildlife")
		actor.queue_free()
	var creature = Animal.new()
	creature.setup(self, controller.record(id), sources[id])
	add_child(creature)
	creature.global_position = State.vector(controller.record(id)["position"])
	animals[id] = creature

func _flush(_path: String) -> void:
	if not _ready_runtime or _committing or _campaign != _state.campaign.data["id"] or _body != _state.get_current_body()["id"]: return
	if controller.registry["animals"].is_empty(): return
	for id: String in animals:
		if is_instance_valid(animals[id]): controller.record_position(id, animals[id].global_position)
	tribe.body()[Saved.FIELD] = {"schema": Saved.SCHEMA, "registry": controller.registry.duplicate(true), "sources": sources.duplicate(true)}

func _persist(registry: Dictionary, cost: Dictionary) -> bool:
	if not is_active() or _committing: return false
	var body: Dictionary = tribe.body()
	var had: bool = body.has(Saved.FIELD)
	var previous: Dictionary = body.get(Saved.FIELD, {}).duplicate(true)
	var before_stock: Dictionary = tribe.village()["stock"].duplicate()
	for food: String in cost:
		if food != "food" or not State.integer(cost[food], 0, 1000) or int(before_stock.get(food, 0)) < int(cost[food]): return false
	body[Saved.FIELD] = {"schema": Saved.SCHEMA, "registry": registry.duplicate(true), "sources": sources.duplicate(true)}
	for food: String in cost: tribe.village()["stock"][food] -= int(cost[food])
	var progression: Node = get_node("/root/ProgressionService")
	var previous_health: Dictionary = {}
	for id: String in registry["animals"]:
		var a: Dictionary = registry["animals"][id]
		var previous_entry: Dictionary = progression.get_saved_creature_encounter(id)
		if not previous_entry.is_empty() and (float(previous_entry["health_ratio"]) != float(a["health"]) / 100.0 or bool(previous_entry["dead"]) != (a["status"] == "dead")):
			previous_health[id] = previous_entry
			progression.store_fauna_health(id, float(a["health"]) / 100.0, a["status"] == "dead", 0.0)
	_committing = true
	var ok: bool = _saves.save_now()
	_committing = false
	if not ok:
		for id: String in previous_health: progression._restore_encounter_entry(id, previous_health[id])
		if had: body[Saved.FIELD] = previous
		else: body.erase(Saved.FIELD)
		tribe.village()["stock"] = before_stock
	return ok

func _changed(id: String, code: String) -> void:
	_routes.erase(id)
	_goals.erase(id)
	if animals.has(id) and is_instance_valid(animals[id]): animals[id].apply_record(controller.record(id))
	_saves.schedule_autosave(2.0)
	_show({"ok": true, "code": code})

func _show(result: Dictionary) -> Dictionary:
	var texts: Dictionary = {"tribal_age_required": "Tierhaltung ist erst im aktiven Stammeszeitalter möglich.", "choose_one_handler": "Wähle genau einen Stammesbewohner als Betreuer.", "handler_busy": "Der Betreuer muss ohne Ladung warten. Lass ihn seine Lieferung abschließen und halte ihn an.",
		"unknown_animal": "Das Tier ist nicht in der geladenen Dorfumgebung.", "unsuitable": "Diese Art besitzt keine geprüfte Zähmeignung.", "wrong_food": "Im Dorf fehlt passendes Futter für diese Art.", "insufficient_food": "Lagere zuerst weitere Wurzeln als Nahrung ein.",
		"out_of_range": "Der Betreuer muss höchstens 4,5 m vom Tier entfernt stehen.", "no_line_of_sight": "Der Betreuer braucht freien Sichtkontakt zum Tier.", "fleeing": "Das Tier ist noch verängstigt.", "capacity_full": "Alle sechs Tierplätze sind belegt oder reserviert.",
		"offer_started": "Futter angeboten. Der Betreuer muss zwei Sekunden beim Tier bleiben.", "trust_gained": "Futter angenommen; Vertrauen und Nahrung gemeinsam gespeichert.", "tamed": "Gezähmt. Das Tier gehört deinem Stamm und bleibt eine fremde Art.",
		"order_follow": "Tier folgt dem ausgewählten Betreuer.", "order_wait": "Tier wartet am gespeicherten Ort.", "order_home": "Tier kehrt zum Heimatplatz zurück.", "dead": "Dieses Tier ist verstorben.", "died": "Tierverlust gespeichert.", "save_failed": "Speichern fehlgeschlagen; Auftrag und Kosten wurden zurückgenommen.",
		"not_owner": "Du kannst nur eigene gezähmte Tiere befehligen.", "already_tamed": "Das Tier ist bereits gezähmt.", "already_offering": "Es läuft bereits eine Futtergabe.", "no_offer": "Keine laufende Futtergabe.", "not_claimant": "Keine eigene begonnene Zähmung.", "claim_abandoned": "Zähmung aufgegeben. Der Platz ist wieder frei.", "paused": "Spiel pausiert."}
	status = texts.get(result["code"], "Futtergabe unterbrochen; die unfertige Gabe kostet keine Nahrung." if str(result["code"]).begins_with("interrupted:") else str(result["code"]))
	return result
