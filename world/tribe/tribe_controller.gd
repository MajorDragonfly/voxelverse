extends Node

signal order_resolved(order: StringName, command_id: String, accepted: bool)
var _order_sequence: int = 0

const Husbandry = preload("res://world/tribe/village_husbandry.gd")
const HusbandryRuntime = preload("res://world/tribe/husbandry_runtime.gd")
const Housing = preload("res://world/tribe/village_housing.gd")
const Shelters = preload("res://world/tribe/village_shelters.gd")
const Economy = preload("res://world/tribe/village_economy.gd")
const Model = preload("res://world/tribe/tribe_state.gd")
const Work = preload("res://world/tribe/village_work.gd")
const Navigation = preload("res://world/tribe/village_navigation.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const HomeState = preload("res://world/home_group/home_group_state.gd")
const Companion = preload("res://world/home_group/home_companion.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const TribePanel = preload("res://ui/tribe/tribe_panel.gd")
const Visuals = preload("res://world/tribe/village_visuals.gd")
const NeighborRuntime = preload("res://world/tribe/neighbors/neighbor_runtime.gd")
const MOVEMENT_ARRIVAL_RADIUS: float = 0.45
var neighbors: Node3D

var home: Node
var player: CharacterBody3D
var panel: CanvasLayer
var camera: Camera3D
var actors: Dictionary = {}
var selected: Array[String] = []
var navigation := Navigation.new()
var domestication: Node
var husbandry := HusbandryRuntime.new()
var status: String = ""
var _state: Node
var _saves: Node
var _active: bool = false
var _campaign_id: String = ""
var _body_id: String = ""
var _prepared: Dictionary = {}
var _token: String = ""
var _signature: String = ""
var _routes: Dictionary = {}
var _goals: Dictionary = {}
var _visuals: Node3D
var _shelters: Node3D
var _growth_retry: float = 0.0
var _player_processing: Dictionary = {}
var _hidden_layers: Array[CanvasLayer] = []
var _original_camera: Camera3D
var _focus := Vector3.ZERO
var _zoom: float = 26.0
var _timer: float = 0.0
var _transaction: bool = false
var placement: String = ""
var _route_retry: float = 0.0
var _stalls: Dictionary = {}
signal community_event(kind: StringName, details: Dictionary)

func _ready() -> void:
	var surface: RefCounted = Space.adapter(self)
	if surface != null: surface.origin_shifted.connect(surface_origin_shifted)
	husbandry.controller = self
	home = get_parent().get_node("HomeGroup")
	_state = get_node("/root/GameState")
	_saves = get_node("/root/SaveGameService")
	neighbors = NeighborRuntime.new()
	neighbors.controller = self
	add_child(neighbors)
	panel = TribePanel.new()
	panel.controller = self
	add_child(panel)
	_saves.game_loaded.connect(_invalidate)
	_state.phase_changed.connect(_invalidate)
	_state.world_seed_changed.connect(_invalidate)
	add_to_group(&"tribe_controller")
	domestication = preload("res://world/domestication/campaign_domestication.gd").new()
	domestication.name = "Domestication"
	add_child(domestication)

func _process(delta: float) -> void:
	var flow := get_node_or_null("/root/SessionFlow")
	if flow != null and flow.loading: return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	var manager: Node = get_tree().current_scene.get_node_or_null("WorldManager") if get_tree().current_scene else null
	if manager == null or not bool(manager.get("world_initialized")):
		return
	if _active and (_campaign_id != str(_state.campaign.data["id"]) or _body_id != _state.active_body_id or int(_state.current_phase) != 1):
		_deactivate()
	if not _active and int(_state.current_phase) == 1 and not village().is_empty():
		_activate()
	if is_active():
		var pan := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		_focus += Space.frame(self, anchor()) * pan * delta * 10.0
		var offset: Vector3 = _focus - anchor()
		offset = offset.slide(Space.up(self, anchor()))
		_focus = anchor() + offset.limit_length(NeighborRuntime.Model.SITE_RADIUS if body().has("tribal_neighbor") else 10.0)
		_update_camera()
	_timer -= delta
	if _timer <= 0:
		_timer = 0.2
		panel.refresh()

func _invalidate(_value: Variant) -> void:
	navigation.cancel()
	_prepared.clear()
	_token = ""
	panel.cancel_confirmation()
	if panel._owns_pause:
		get_tree().paused = false
		panel._owns_pause = false
	_deactivate()

func _exit_tree() -> void:
	navigation.cancel()
	_deactivate()

func body() -> Dictionary:
	return _state.get_current_body_record()

func village() -> Dictionary:
	var value: Variant = body().get("tribe", {})
	return value if value is Dictionary else {}

func anchor() -> Vector3:
	return Space.resolve(self, village()["anchor"])

func is_active() -> bool:
	var flow := get_node_or_null("/root/SessionFlow")
	return _active and not _transaction and not get_tree().paused and (flow == null or not flow.loading) and int(_state.current_phase) == 1 and _campaign_id == str(_state.campaign.data["id"])

func blockers() -> Array[String]:
	if int(_state.current_phase) != 0:
		return ["Dein Stamm befindet sich bereits in einem anderen Zeitalter."]
	if not home.can_use_panel() or not is_instance_valid(player) or bool(player.is_dead):
		return ["Kehre zuerst mit deiner Kreatur in die geladene Welt zurück."]
	var group: Dictionary = home.group_state()
	if group.is_empty():
		return ["Lege mit N einen Heimatplatz für deine Nestgruppe fest."]
	var problem: String = HomeState.validate(group, str(body()["id"]), str(_state.campaign.data["player_species_id"]))
	if not problem.is_empty():
		return [problem]
	if player.global_position.distance_to(home.home_position()) > 5.0:
		return ["Kehre zum Heimatplatz zurück, um mit deiner Gruppe fortzuschreiten."]
	for member: Dictionary in group["members"]:
		if not home.actors.has(member["id"]) or Space.resolve(self, member["position"]).distance_to(home.home_position()) > 6.0:
			return ["Rufe beide Gefährten mit N → Heimkehren zum Heimatplatz."]
	if not _state.campaign.data["pending_transition"].is_empty() or _transaction:
		return ["Ein anderer Übergang wird noch abgeschlossen."]
	return []

func prepare_confirmation() -> String:
	_prepared.clear()
	_token = ""
	var reasons: Array[String] = blockers()
	if not reasons.is_empty():
		return reasons[0]
	navigation.rebuild(home, home.home_position())
	var sites: Dictionary = navigation.sites()
	if sites.is_empty():
		return "Für das erste Dorf fehlen sichere Wege und fünf freie Arbeitsplätze. Verlege den Heimatplatz auf eine größere trockene Fläche."
	for actor: Node3D in home.actors.values():
		if navigation.route(actor.global_position, home.home_position()).is_empty():
			return "Ein Gefährte erreicht den Dorfplatz noch nicht. Hole ihn näher heran."
	if navigation.route(player.global_position, home.home_position()).is_empty():
		return "Deine Kreatur erreicht den Dorfplatz noch nicht."
	_prepared = Model.create(home.group_state(), _state.campaign.data, player.export_runtime_state(), sites)
	var problem: String = Model.validate(_prepared, body(), _state.campaign.data)
	if not problem.is_empty():
		_prepared.clear()
		return problem
	_signature = _current_signature()
	_token = "%s:%s" % [_signature.sha256_text(), Time.get_ticks_usec()]
	return ""

func _current_signature() -> String:
	return JSON.stringify([_state.campaign.data["id"], _state.active_body_id, _state.current_phase, home.group_state(), player.export_runtime_state()])

func confirmed_handoff(token: String) -> Dictionary:
	if token.is_empty() or token != _token or _prepared.is_empty() or not panel.confirmation_open or not get_tree().paused or _current_signature() != _signature or not blockers().is_empty():
		return {}
	return _prepared.duplicate(true)

func _activate() -> void:
	var problem: String = Model.validate(village(), body(), _state.campaign.data)
	if not problem.is_empty():
		status = problem
		return
	# Wait for terrain collision and the home controller's reference to the player.
	if home.player == null or not home.has_ground(Space.resolve(self, village()["anchor"])):
		return
	if navigation.pending: return
	if navigation.completed_generation != navigation.generation:
		Model.upgrade(village())
		navigation.begin(home, Space.resolve(self, village()["anchor"]), village(), navigation_extent())
		return
	if navigation.graph.get_point_count() == 0:
		navigation.cancel()
		return
	# The home controller refreshes on a slower tick. Install the visible nest
	# with this runtime, so a cold start cannot briefly expose the default home.
	get_parent().global_position = Space.resolve(self, village()["anchor"])
	_campaign_id = str(_state.campaign.data["id"])
	_body_id = _state.active_body_id
	_player_processing = {"process": player.is_processing(), "physics": player.is_physics_processing(), "input": player.is_processing_input(), "unhandled": player.is_processing_unhandled_input(), "collision_layer": player.collision_layer, "collision_mask": player.collision_mask}
	player.collision_layer = 0
	# The player is now a resident on the same navigation graph as companions.
	# Use their terrain/obstacle mask; a waiting animal must not pin only this
	# one carrier to a route which every other resident can traverse.
	player.collision_mask = 1 | 2
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	_hide_creature_ui(player)
	_original_camera = player.get_viewport().get_camera_3d()
	var blueprint: Dictionary = Assembly.load_best_available()
	if blueprint.is_empty():
		blueprint = Assembly.create_default()
	for i in range(village()["members"].size()):
		var member: Dictionary = village()["members"][i]
		var actor: CharacterBody3D = player if i == 0 else Companion.new()
		if i != 0:
			get_parent().get_parent().add_child(actor)
			actor.setup(self, member, blueprint, i)
			actor.set_physics_process(false)
		actor.global_position = Space.resolve(self, member["position"])
		actor.velocity = Vector3.ZERO
		actors[member["id"]] = actor
		selected.append(str(member["id"]))
	camera = Camera3D.new()
	get_parent().get_parent().add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 400.0
	_focus = anchor()
	_update_camera()
	camera.make_current()
	_visuals = Visuals.new()
	get_parent().get_parent().add_child(_visuals)
	_visuals.rebuild(village())
	_shelters = Shelters.new()
	get_parent().get_parent().add_child(_shelters)
	_shelters.sync(village(), actors)
	_active = true
	neighbors.refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status = "Wähle Bewohner und erteile gemeinsame oder einzelne Aufträge."
	panel.refresh()

func _hide_creature_ui(node: Node) -> void:
	if node is CanvasLayer and node.visible and not node.is_in_group(&"discovery_journal") and not node.is_in_group(&"minimap_hud"):
		_hidden_layers.append(node)
		node.hide()
	for child: Node in node.get_children():
		_hide_creature_ui(child)

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	neighbors.clear_runtime()
	for actor: Node in actors.values():
		if is_instance_valid(actor) and actor != player:
			Space.untrack(actor)
			actor.queue_free()
	actors.clear()
	selected.clear()
	_routes.clear()
	_goals.clear()
	placement = ""
	_stalls.clear()
	if is_instance_valid(camera):
		Space.untrack(camera)
		camera.queue_free()
	if is_instance_valid(_visuals):
		Space.untrack(_visuals)
		_visuals.queue_free()
	if is_instance_valid(_shelters):
		Space.untrack(_shelters)
		_shelters.queue_free()
	if is_instance_valid(player):
		for child_name: String in ["TribeSelection", "TribeCargo"]:
			var indicator: Node = player.get_node_or_null(child_name)
			if indicator != null:
				indicator.queue_free()
		player.collision_layer = int(_player_processing.get("collision_layer", 1))
		player.collision_mask = int(_player_processing.get("collision_mask", 5))
		player.set_process(_player_processing.get("process", true))
		player.set_physics_process(_player_processing.get("physics", true))
		player.set_process_input(_player_processing.get("input", true))
		player.set_process_unhandled_input(_player_processing.get("unhandled", true))
	for layer_node: CanvasLayer in _hidden_layers:
		if is_instance_valid(layer_node):
			layer_node.show()
	_hidden_layers.clear()
	if is_instance_valid(_original_camera):
		_original_camera.make_current()

func _update_camera() -> void:
	camera.size = _zoom
	camera.v_offset = -_zoom * 0.16
	camera.global_position = Space.offset(self, _focus, Vector3(0, 22, 17))
	camera.look_at(_focus, Space.up(self, _focus))

func zoom(amount: float) -> void:
	_zoom = clampf(_zoom + amount, 16.0, 40.0)
	_update_camera()

func member_record(identity: String) -> Dictionary:
	for member: Dictionary in village().get("members", []):
		if member["id"] == identity:
			return member
	return {}

func select_member(identity: String, additive: bool = false) -> void:
	if not actors.has(identity):
		return
	if not additive:
		selected.clear()
	if additive and identity in selected:
		selected.erase(identity)
	else:
		selected.append(identity)
	panel.refresh()

func select_all() -> void:
	selected.clear()
	for identity: String in actors:
		selected.append(identity)
	panel.refresh()

func screen_select(rect: Rect2, additive: bool) -> void:
	if not additive:
		selected.clear()
	for identity: String in actors:
		var actor: Node3D = actors[identity]
		if not camera.is_position_behind(actor.global_position) and rect.has_point(camera.unproject_position(actor.global_position + Space.up(self, actor.global_position))) and identity not in selected:
			selected.append(identity)
	panel.refresh()

func screen_command(position: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(position)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(position) * 200, 1)
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		status = "Hier ist kein geladener Boden."
		_resolve_order("move", false)
		return
	var target: Vector3 = hit["position"]
	if not placement.is_empty():
		if issue_order(placement, target):
			placement = ""
		return
	for kind: String in village()["deposits"]:
		if kind in ["water", "fiber"] and not village()["economy"]["stations"].has("well" if kind == "water" else "fiberbed"):
			continue
		if target.distance_to(Space.resolve(self, village()["deposits"][kind]["position"])) < 1.8:
			issue_order(kind)
			return
	issue_order("move", target)

func issue_order(order: String, destination: Vector3 = Vector3.ZERO, movement_limit: float = 18.0) -> bool:
	if not is_active() or selected.is_empty():
		status = "Wähle zuerst mindestens einen Bewohner aus." if selected.is_empty() else "Die Gruppe kann gerade keine Befehle annehmen."
		_resolve_order(order, false)
		return false
	if order in Economy.STATIONS.keys() + Housing.BUILDS and destination == Vector3.ZERO and is_active():
		if int(village()["tools"]) == 0:
			status = "Zuerst ein Steinwerkzeug herstellen."
			_resolve_order(order, false)
			return false
		if not village()["project"].is_empty() and village()["project"]["kind"] == order:
			destination = Space.resolve(self, village()["project"]["position"])
		else:
			placement = order
			status = "Rechtsklick auf einen freien Bauplatz · Esc bricht die Platzierung ab."
			panel.refresh()
			return true
	var success: bool = _commit_order(order, destination, movement_limit)
	_resolve_order(order, success)
	return success

func _resolve_order(order: String, success: bool) -> void:
	_order_sequence += 1
	order_resolved.emit(StringName(order), "%d:%d" % [get_instance_id(), _order_sequence], success)
	panel.refresh()

func _commit_order(order: String, destination: Vector3 = Vector3.ZERO, movement_limit: float = 18.0) -> bool:
	if not navigation.is_ready() and order in ["move"] + Economy.STATIONS.keys() + Housing.BUILDS:
		status = "Die Dorfwege werden geprüft. Bitte einen Moment warten."
		return false
	if not is_active() or selected.is_empty() or order not in Model.ORDERS + Economy.ORDERS + ["resume", "profession"]:
		return false
	var before: Dictionary = village().duplicate(true)
	var data: Dictionary = village()
	if order == "move":
		destination = navigation.snap(destination)
		if not destination.is_finite() or destination.distance_to(anchor()) > clampf(movement_limit, 0.0, 20.0):
			status = "Befehle bleiben zunächst in der sicheren Umgebung des Dorfes."
			return false
		for identity: String in selected:
			if navigation.route(actors[identity].global_position, destination).is_empty():
				status = "Mindestens ein ausgewählter Bewohner erreicht diesen Ort nicht."
				return false
	var costs: Dictionary = Model.COSTS.merged(Economy.COSTS)
	if order in costs:
		if (order == "tool" and int(data["tools"]) == 1) or (order in Housing.KINDS and data["housing"]["homes"].size() >= Housing.MAX_HOMES) or (order == "garden" and int(data["garden"]) == 1) or (order == "pen" and data["husbandry"]["pens"].size() >= Husbandry.MAX_PENS) or data["economy"]["stations"].has(order):
			status = "Dieser Ausbau ist bereits abgeschlossen."
			return false
		if order != "tool" and int(data["tools"]) == 0:
			status = "Stelle zuerst ein Steinwerkzeug her."
			return false
		if not data["project"].is_empty() and data["project"]["kind"] != order:
			status = "Schließe zuerst die laufende Arbeit ab."
			return false
		if data["project"].is_empty():
			if order in Economy.STATIONS.keys() + Housing.BUILDS:
				var snapped: Vector3 = navigation.snap(destination)
				if snapped.distance_to(destination) > 1.8 or neighbors.occupies(snapped) or not (navigation.free_shelter(snapped, data, order) if order in Housing.BUILDS else navigation.free_workplace(snapped, data, order)):
					status = "Hier fehlen Platz, trockener Boden oder ein freier Weg zum Lager."
					return false
				destination = snapped
				for identity: String in selected:
					if navigation.route(actors[identity].global_position, destination).is_empty():
						status = "Ein ausgewählter Bewohner erreicht diesen Bauplatz nicht."
						return false
			for kind: String in costs[order]:
				if int(data["stock"][kind]) < int(costs[order][kind]):
					status = "Es fehlen eingelagerte Materialien: %d %s." % [costs[order][kind], Economy.TITLES[kind]]
					return false
			for kind: String in costs[order]:
				data["stock"][kind] -= costs[order][kind]
			data["project"] = {"kind": order, "progress": 0.0}
			if order in Housing.BUILDS:
				var index: int = data["husbandry"]["pens"].size() if order == "pen" else data["housing"]["homes"].size()
				data["project"].merge(Housing.site(data, order, Space.encode(self, destination), index))
				data["project"]["materials"] = costs[order].duplicate()
				data["project"]["delivered_materials"] = {}
				for kind: String in costs[order]:
					data["project"]["delivered_materials"][kind] = 0
			elif order in Economy.STATIONS:
				data["project"]["position"] = Space.encode(self, destination)
	for identity: String in selected:
		var member: Dictionary = member_record(identity)
		var next: String = order
		if order == "wait":
			if member["order"] != "wait":
				member["paused_order"] = member["order"]
		elif order == "resume":
			next = member["paused_order"] if member["paused_order"] != "" else Economy.JOB_ORDER[member["profession"]]
			member["paused_order"] = ""
		elif order == "profession":
			next = Economy.JOB_ORDER[member["profession"]]
			member["paused_order"] = ""
		else:
			member["paused_order"] = ""
			member["work"] = 0.0
			member["task"] = ""
		member["order"] = next
		member["blocked"] = false
		# Changing tasks never discards a carried unit of material.
		member["stage"] = "return" if member["cargo"] != "" else "outbound"
		if order == "move":
			member["destination"] = Space.encode(self, _workplace(destination, selected.find(identity)) if selected.size() > 1 else destination)
	_transaction = true
	var success: bool = _saves.save_now()
	if not success:
		body()["tribe"] = before
	_transaction = false
	_routes.clear()
	_goals.clear()
	status = "Auftrag gespeichert." if success else "Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten."
	if success:
		placement = ""
		_visuals.rebuild(village())
		if Housing.obstacles(before) != Housing.obstacles(village()):
			navigation.begin(home, anchor(), village(), navigation_extent())
	panel.refresh()
	return success

func _physics_process(delta: float) -> void:
	if navigation.pending:
		if navigation.advance():
			_routes.clear()
			_goals.clear()
			_route_retry = 2.0
		if not navigation.is_ready(): return
	if not is_active():
		return
	var simulation_delta: float = _state.simulation_delta(delta)
	if simulation_delta <= 0:
		return
	var owner: Dictionary = body().get("village_simulation", {})
	if not owner.is_empty():
		if owner.owner != "near": return
		owner.cursor = _state.campaign.data.elapsed_seconds
	var grew: bool = Model.grow(village(), simulation_delta)
	var renewed: bool = Economy.tick(village(), simulation_delta)
	if grew or renewed:
		_changed()
	_route_retry -= delta
	if _route_retry <= 0:
		_route_retry = 2.0
		var blocked: bool = not navigation.is_ready() or neighbors.has_blocked()
		for member: Dictionary in village()["members"]:
			blocked = blocked or bool(member["blocked"])
		if blocked and not navigation.pending:
			# A single stalled patrol must not suspend everybody's work while
			# the same topology is checked again. Hard building changes still
			# discard old routes through begin()'s default mode.
			navigation.begin(home, anchor(), village(), navigation_extent(), true)
	if not navigation.is_ready(): return
	for member: Dictionary in village()["members"]:
		if not navigation.is_ready(): break
		var actor: CharacterBody3D = actors[member["id"]]
		Work.prepare(village(), member, simulation_delta)
		var order: String = _effective_order(member)
		var target: Vector3 = actor.global_position
		var construction: bool = false
		if member["construction_id"] != "" and order != "wait":
			target = Space.resolve(self, village()["project"]["entrance"])
			construction = true
		elif member["care_pen_id"] != "" and order != "wait":
			target = husbandry.cargo_target(member)
			construction = target.distance_to(anchor()) > 0.1
		elif member["cargo"] != "" and order != "wait":
			target = anchor()
		elif member["stage"] in ["meal", "drink"]:
			target = anchor()
		elif order == "milk":
			var incoming: Array = village()["economy"]["incoming"]
			target = Space.resolve(self, incoming[0]["position"]) if not incoming.is_empty() and not Economy.at_target(village(), member, "milk") else anchor()
		elif order in Economy.RESOURCES or order in ["supply", "provision"]:
			var kind: String = Economy.gather_kind(village(), member)
			target = Space.resolve(self, village()["deposits"][kind]["position"]) if not kind.is_empty() and not Economy.at_target(village(), member, kind) else anchor()
		elif order in ["feed", "drink", "tool", "build", "tend"]:
			target = anchor()
		elif order in Housing.BUILDS and village()["project"].get("kind") == order:
			construction = not Housing.pending(village()["project"])
			target = Space.resolve(self, village()["project"]["entrance"]) if construction else anchor()
		elif order == "garden":
			target = Space.resolve(self, village()["deposits"]["food"]["position"])
		elif order in Economy.STATIONS and not village()["project"].is_empty():
			target = Space.resolve(self, village()["project"]["position"])
		elif order == "move":
			target = Space.resolve(self, member["destination"])
		var neighbor_target: Vector3 = neighbors.target(member)
		if neighbor_target.is_finite():
			target = neighbor_target
		if order != "wait" and (neighbor_target.is_finite() or member["cargo"] != "" or order != "move"):
			var index: int = village()["members"].find(member)
			target = _construction_workplace(target, index) if construction else _workplace(target, index)
		var arrived: bool = _walk(actor, str(member["id"]), target, delta, minf(float(member["hunger"]), float(member["hydration"])))
		member["position"] = Space.encode(self, actor.global_position)
		if arrived:
			_work(member, simulation_delta)
		if actor == player:
			# The resident owns both needs, including this tick's meal/drink.
			# Keep the exported traveler consistent with that authoritative state.
			player.current_hunger = player.maximum_hunger * float(member["hunger"]) / 100.0
			player.current_thirst = player.maximum_thirst * float(member["hydration"]) / 100.0
	_update_selection()
	_shelters.clear_entrances(actors)
	husbandry.tick(simulation_delta)
	_grow_residents(simulation_delta)
	neighbors.tick(delta, simulation_delta)
	get_node("/root/ProgressionService").record_tribal_tick(simulation_delta, self)

func _construction_workplace(entrance: Vector3, index: int) -> Vector3:
	var target: Vector3 = navigation.snap(Space.offset(self, entrance, Vector3(index % 3 - 1, 0, index / 3)))
	return target if target.distance_to(entrance) < 2.5 and not navigation.route(entrance, target).is_empty() else entrance

func _workplace(center: Vector3, index: int) -> Vector3:
	# Give residents separate work positions, keeping them visible/selectable.
	var offsets: Array[Vector3] = [Vector3(-1.5, 0, 1), Vector3(1.5, 0, 1), Vector3(0, 0, -1.6), Vector3(-1.5, 0, -1), Vector3(1.5, 0, -1), Vector3(0, 0, 2)]
	var target: Vector3 = navigation.snap(Space.offset(self, center, offsets[index % offsets.size()]))
	if target.is_finite() and target.distance_to(center) < 2.8 and not navigation.route(center, target).is_empty():
		return target
	return center

func _walk(actor: CharacterBody3D, identity: String, target: Vector3, delta: float, hunger: float, record: Dictionary = {}) -> bool:
	if record.is_empty():
		record = member_record(identity)
	if not home.has_ground(actor.global_position):
		record["blocked"] = true
		status = "Ein Bewohner wartet auf geladenen Boden."
		return false
	Space.orient(actor)
	var offset: Vector3 = (target - actor.global_position).slide(actor.up_direction)
	var arrived: bool = offset.length() < MOVEMENT_ARRIVAL_RADIUS
	var direction := Vector3.ZERO
	var lookahead: float = 1.2
	if not arrived:
		if not _goals.has(identity) or _goals[identity].distance_to(target) > 0.2:
			_routes[identity] = navigation.route(actor.global_position, target)
			_goals[identity] = target
		var route: PackedVector3Array = _routes.get(identity, PackedVector3Array())
		while not route.is_empty():
			var next_offset: Vector3 = route[0] - actor.global_position
			next_offset = next_offset.slide(actor.up_direction)
			if next_offset.length() > 0.25:
				direction = next_offset.normalized()
				# Stop the probe at the next waypoint; looking past a turn can
				# incorrectly test a tree or water outside the planned path.
				lookahead = minf(1.2, next_offset.length())
				break
			route.remove_at(0)
		_routes[identity] = route
		if direction != Vector3.ZERO and not home.safe_step(actor, direction, lookahead):
			direction = Vector3.ZERO
			status = "Weg blockiert · der Auftrag bleibt erhalten; neue Wege werden geprüft."
		elif direction != Vector3.ZERO and status.begins_with("Weg blockiert"):
			status = "Die Bewohner setzen ihre Aufträge fort."
	record["blocked"] = not arrived and direction == Vector3.ZERO
	var speed: float = 3.8 * (0.6 if hunger < 20.0 else 1.0)
	actor.velocity = direction * speed + actor.up_direction * (-0.5 if actor.is_on_floor() else maxf(-12.0, actor.velocity.dot(actor.up_direction) - 20.0 * delta))
	if actor.is_on_floor(): Space.step(actor, direction * speed * delta, 0.55, 0.15)
	var before_motion: Vector3 = actor.global_position
	actor.move_and_slide()
	var moved: Vector3 = actor.global_position - before_motion
	moved = moved.slide(actor.up_direction)
	if not arrived and direction != Vector3.ZERO and moved.length() < speed * delta * 0.1:
		_stalls[identity] = float(_stalls.get(identity, 0.0)) + delta
		if float(_stalls[identity]) >= 0.75:
			record["blocked"] = true
	else:
		_stalls[identity] = 0.0
	if actor.is_on_floor():
		actor.apply_floor_snap()
	if direction != Vector3.ZERO:
		var visual: Node3D = actor.get_node_or_null("CreatureRuntimeVisual")
		if visual != null:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-(actor.global_basis.inverse() * direction).x, -(actor.global_basis.inverse() * direction).z), minf(delta * 7.0, 1.0))
	return arrived

func _effective_order(member: Dictionary) -> String:
	return str(village()["project"].get("kind", "build")) if member["order"] == "build" else str(member["order"])

func _work(member: Dictionary, delta: float) -> void:
	if member["order"] == "wait": return
	var before: Dictionary = Work.snapshot(village())
	if not neighbors.work(member):
		_perform_work(member, delta)
	get_node("/root/ProgressionService").record_tribal_work(before, str(member["id"]), self)

func _perform_work(member: Dictionary, delta: float) -> void:
	var effects: Array = []
	Work.step(village(), member, delta, _work_rate(member), effects)
	_apply_work_effects(member, effects)

func _apply_work_effects(member: Dictionary, effects: Array) -> void:
	var changed: bool = false
	for effect: Dictionary in effects:
		if effect.kind == "care_delivery": husbandry.deliver(member)
		elif effect.kind == "care_pickup": husbandry.pickup(member)
		elif effect.kind == "changed": changed = true
		else:
			if effect.kind == "construction":
				_shelters.sync(village(), actors)
				if effect.data.kind in Housing.BUILDS:
					navigation.begin(home, anchor(), village(), navigation_extent())
				_routes.clear()
				_goals.clear()
				status = "Ausbau fertig · Bewohner mit Beruf setzen ihre Zuständigkeit fort."
			community_event.emit(StringName(effect.kind), effect.data)
	if changed: _changed()

func _food_reserve_ready() -> bool:
	return int(village()["stock"]["food"]) + Model.cargo_count(village(), "food") >= Economy.target(village(), "food")

func _eat(member: Dictionary) -> bool:
	var effects: Array = []
	var changed: bool = Work.eat(village(), member, effects)
	_apply_work_effects(member, effects)
	return changed

func _drink(member: Dictionary) -> bool:
	var effects: Array = []
	var changed: bool = Work.drink(village(), member, effects)
	_apply_work_effects(member, effects)
	return changed

func assign_profession(profession: String) -> bool:
	if not is_active() or selected.is_empty() or profession not in Economy.JOBS:
		return false
	var before: Dictionary = village().duplicate(true)
	for identity: String in selected:
		var member: Dictionary = member_record(identity)
		member["profession"] = profession
		member["order"] = Economy.JOB_ORDER[profession]
		member["paused_order"] = ""
		member["work"] = 0.0
		member["task"] = ""
		member["stage"] = "return" if member["cargo"] != "" else "outbound"
	var success: bool = _save_economy(before)
	if success:
		placement = ""
		panel.refresh()
	return success

func receive_milk(batch: Dictionary) -> bool:
	if not is_active():
		return false
	var before: Dictionary = village().duplicate(true)
	var problem: String = Economy.receive_milk(village(), batch)
	# A durable receipt remains acknowledged even if its old pickup route is
	# now blocked or the milk has already been consumed.
	if problem.is_empty() and village() == before:
		return true
	if problem.is_empty() and navigation.route(anchor(), Space.resolve(self, batch["position"])).is_empty():
		problem = "Die Milchabholstelle ist nicht erreichbar."
	if not problem.is_empty():
		body()["tribe"] = before
		status = problem
		return false
	return _save_economy(before)

func _save_economy(before: Dictionary) -> bool:
	_transaction = true
	var success: bool = _saves.save_now()
	if not success:
		body()["tribe"] = before
	_transaction = false
	_routes.clear()
	_goals.clear()
	status = "Auftrag gespeichert." if success else "Speichern fehlgeschlagen. Der bisherige Stand bleibt erhalten."
	if success:
		_visuals.rebuild(village())
	panel.refresh()
	return success

func _work_rate(member: Dictionary) -> float:
	var progression: Node = get_node("/root/ProgressionService")
	var legacy: Dictionary = progression.get_behavior_effect("group_cooperation", 1)
	return float(legacy["value"]) * (0.5 if minf(float(member["hunger"]), float(member["hydration"])) < 20.0 else 1.0)

func finish_navigation_for_departure() -> bool:
	if not _active or _transaction or _body_id != _state.active_body_id: return false
	var stamp: int = navigation.generation
	var id: String = _state.active_body_id
	var rebuilding: bool = navigation.pending
	var deadline: int = Time.get_ticks_msec() + 45000
	# SessionFlow pauses the tree but keeps source collision registered until
	# this preflight ends. PROCESS_MODE_DISABLED would remove those shapes.
	while navigation.pending:
		if Time.get_ticks_msec() >= deadline: return false
		navigation.advance()
		if id != _state.active_body_id or stamp != navigation.generation: return false
		if navigation.pending: await get_tree().physics_frame
	if not navigation.is_ready(): return false
	if rebuilding:
		_routes.clear()
		_goals.clear()
		_route_retry = 2.0
	return true

func prepare_far_simulation() -> Dictionary:
	# A frozen source is deliberately not is_active(): SessionFlow owns the
	# handoff while loading, with physics stopped and this exact host retained.
	if not _active or _transaction or navigation.pending or not navigation.is_ready() or _body_id != _state.active_body_id: return {}
	var stamp: int = navigation.generation
	var id: String = _state.active_body_id
	var Simulation = preload("res://world/tribe/village_simulation.gd")
	var data: Dictionary = village()
	var places: Array = [data.anchor]
	for deposit: Dictionary in data.deposits.values(): places.append(deposit.position)
	for member: Dictionary in data.members:
		places.append(member.position)
		places.append(member.destination)
	for batch: Dictionary in data.economy.incoming: places.append(batch.position)
	for pen: Dictionary in data.husbandry.pens: places.append(pen.entrance)
	for record: Dictionary in data.husbandry.records.values(): places.append(record.pickup)
	if body().has("tribal_neighbor"):
		places.append(body().tribal_neighbor.anchor)
		for resident: Dictionary in body().tribal_neighbor.members:
			places.append(resident.position)
			places.append(resident.workplace)
	if not data.project.is_empty(): places.append(data.project.get("entrance", data.project.get("position", data.anchor)))
	var roads: Dictionary = {}
	var visited: Dictionary = {}
	for place: Variant in places:
		var key: String = Simulation.key(place)
		if visited.has(key): continue
		visited[key] = true
		if visited.size() > Simulation.MAX_ROADS: return {}
		var route: PackedVector3Array = navigation.route(anchor(), Space.resolve(self, place))
		if not route.is_empty() and route.size() + 2 <= Simulation.MAX_POINTS:
			var path: Array = [data.anchor.duplicate(true)]
			for point: Vector3 in route: path.append(Space.encode(self, point))
			path.append(place.duplicate(true))
			roads[key] = path
		if visited.size() % 2 == 0:
			await get_tree().physics_frame
			if id != _state.active_body_id or stamp != navigation.generation: return {}
	var attending: Array = []
	for pen: Dictionary in data.husbandry.pens:
		if husbandry.attendance(pen).error.is_empty(): attending.append(pen.animal_id)
	return Simulation.create(id, float(_state.campaign.data.elapsed_seconds), roads, attending, str(_state.campaign.data.player_object_id))

func _changed() -> void:
	_saves.schedule_autosave(1.0)
	_visuals.rebuild(village())

func _update_selection() -> void:
	for identity: String in actors:
		var actor: Node3D = actors[identity]
		var ring: MeshInstance3D = actor.get_node_or_null("TribeSelection")
		if ring == null:
			ring = MeshInstance3D.new()
			ring.name = "TribeSelection"
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.65
			mesh.outer_radius = 0.74
			ring.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("81dfb2")
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ring.material_override = material
			ring.position.y = 0.1
			actor.add_child(ring)
		ring.visible = identity in selected
		var cargo: MeshInstance3D = actor.get_node_or_null("TribeCargo")
		if cargo == null:
			cargo = MeshInstance3D.new()
			cargo.name = "TribeCargo"
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.45, 0.35, 0.5)
			cargo.mesh = mesh
			cargo.material_override = StandardMaterial3D.new()
			cargo.position = Vector3(0, 1.45, 0.1)
			actor.add_child(cargo)
		var kind: String = member_record(identity)["cargo"]
		cargo.visible = not kind.is_empty()
		cargo.material_override.albedo_color = {"wood": Color("b9854d"), "stone": Color("bac8cf"), "food": Color("c27b4e"), "water": Color("60bde8"), "fiber": Color("b8bf67"), "milk": Color("f4f0dd")}.get(kind, Color.WHITE)

func _grow_residents(delta: float) -> void:
	_growth_retry = maxf(0.0, _growth_retry - delta)
	if not Housing.tick(village(), delta) or _growth_retry > 0:
		return
	var location := Vector3.INF
	for shelter: Dictionary in village()["housing"]["homes"]:
		var entrance: Vector3 = Space.resolve(self, shelter["entrance"])
		var candidate: Vector3 = navigation.snap(entrance)
		if candidate.distance_to(entrance) > 0.45 or navigation.route(anchor(), candidate).is_empty() or not home._clear_space(candidate + Space.up(self, candidate) * 0.78):
			continue
		var occupied: bool = false
		for actor: Node3D in actors.values():
			occupied = occupied or actor.global_position.distance_to(candidate) < 1.2
		if not occupied:
			location = candidate
			break
	if not location.is_finite():
		status = "Dorfwachstum wartet auf einen freien, erreichbaren Eingang."
		return
	var before: Dictionary = village().duplicate(true)
	var member: Dictionary = Housing.add_resident(village(), Space.encode(self, location))
	if not _save_economy(before):
		_growth_retry = 5.0
		return
	var blueprint: Dictionary = Assembly.load_best_available()
	if blueprint.is_empty():
		blueprint = Assembly.create_default()
	var actor := Companion.new()
	get_parent().get_parent().add_child(actor)
	actor.setup(self, member, blueprint, village()["members"].size() - 1)
	actor.set_physics_process(false)
	actors[member["id"]] = actor
	status = "%s gehört jetzt zu deinem Stamm. Wähle einen Beruf oder Auftrag." % member["name"]
	community_event.emit(&"resident_added", {"member_id": member["id"], "tribe_id": village()["id"], "population": village()["members"].size()})
	panel.refresh()

func navigation_extent() -> int:
	if is_instance_valid(domestication) and domestication._ready_runtime:
		return 20
	return NeighborRuntime.Model.NAV_EXTENT if body().has("tribal_neighbor") else Navigation.RADIUS

func map_focus() -> Vector3:
	return _focus

func surface_origin_shifted(shift: Vector3) -> void:
	_focus += shift
	navigation.surface_origin_shifted(shift)
	for id in _goals: _goals[id] += shift
	for id in _routes:
		var route: PackedVector3Array = _routes[id]
		for i in range(route.size()): route[i] += shift
		_routes[id] = route
	if is_instance_valid(camera): camera.global_position += shift
	if is_instance_valid(domestication): domestication.surface_origin_shifted(shift)
