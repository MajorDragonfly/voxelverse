extends Node

const Model = preload("res://world/tribe/tribe_state.gd")
const Navigation = preload("res://world/tribe/village_navigation.gd")
const HomeState = preload("res://world/home_group/home_group_state.gd")
const Companion = preload("res://world/home_group/home_companion.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const TribePanel = preload("res://ui/tribe/tribe_panel.gd")
const Visuals = preload("res://world/tribe/village_visuals.gd")

var home: Node
var player: CharacterBody3D
var panel: CanvasLayer
var camera: Camera3D
var actors: Dictionary = {}
var selected: Array[String] = []
var navigation := Navigation.new()
var status: String = ""
var _state: Node
var _saves: Node
var _active: bool = false
var _campaign_id: String = ""
var _world_seed: int = 0
var _prepared: Dictionary = {}
var _token: String = ""
var _signature: String = ""
var _routes: Dictionary = {}
var _goals: Dictionary = {}
var _visuals: Node3D
var _player_processing: Dictionary = {}
var _hidden_layers: Array[CanvasLayer] = []
var _original_camera: Camera3D
var _focus := Vector3.ZERO
var _zoom: float = 26.0
var _timer: float = 0.0
var _transaction: bool = false

func _ready() -> void:
	home = get_parent().get_node("HomeGroup")
	_state = get_node("/root/GameState")
	_saves = get_node("/root/SaveGameService")
	panel = TribePanel.new()
	panel.controller = self
	add_child(panel)
	_saves.game_loaded.connect(_invalidate)
	_state.phase_changed.connect(_invalidate)
	_state.world_seed_changed.connect(_invalidate)
	add_to_group(&"tribe_controller")

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player == null:
		return
	var manager: Node = get_tree().current_scene.get_node_or_null("WorldManager") if get_tree().current_scene else null
	if manager == null or not bool(manager.get("world_initialized")):
		return
	if _active and (_campaign_id != str(_state.campaign.data["id"]) or _world_seed != _state.get_world_seed() or int(_state.current_phase) != 1):
		_deactivate()
	if not _active and int(_state.current_phase) == 1 and not village().is_empty():
		_activate()
	if is_active():
		var pan := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		_focus += pan * delta * 10.0
		var offset: Vector3 = _focus - anchor()
		offset.y = 0
		_focus = anchor() + offset.limit_length(10.0)
		_update_camera()
	_timer -= delta
	if _timer <= 0:
		_timer = 0.2
		panel.refresh()

func _invalidate(_value: Variant) -> void:
	_prepared.clear()
	_token = ""
	panel.cancel_confirmation()
	if panel._owns_pause:
		get_tree().paused = false
		panel._owns_pause = false
	_deactivate()

func _exit_tree() -> void:
	_deactivate()

func body() -> Dictionary:
	_state.get_current_body()
	return _state.campaign.data["bodies"][str(_state.get_world_seed())]

func village() -> Dictionary:
	var value: Variant = body().get("tribe", {})
	return value if value is Dictionary else {}

func anchor() -> Vector3:
	return HomeState.vector(village()["anchor"])

func is_active() -> bool:
	return _active and not _transaction and not get_tree().paused and int(_state.current_phase) == 1 and _campaign_id == str(_state.campaign.data["id"])

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
		if not home.actors.has(member["id"]) or HomeState.vector(member["position"]).distance_to(home.home_position()) > 6.0:
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
	return JSON.stringify([_state.campaign.data["id"], _state.get_world_seed(), _state.current_phase, home.group_state(), player.export_runtime_state()])

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
	if home.player == null or not home.has_ground(HomeState.vector(village()["anchor"])):
		return
	navigation.rebuild(home, HomeState.vector(village()["anchor"]))
	if navigation.graph.get_point_count() == 0:
		return
	_campaign_id = str(_state.campaign.data["id"])
	_world_seed = _state.get_world_seed()
	_player_processing = {"process": player.is_processing(), "physics": player.is_physics_processing(), "input": player.is_processing_input(), "unhandled": player.is_processing_unhandled_input(), "collision_layer": player.collision_layer}
	player.collision_layer = 0
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	_hide_creature_ui(player)
	_original_camera = player.get_viewport().get_camera_3d()
	var blueprint: Dictionary = Assembly.load_best_available()
	if blueprint.is_empty():
		blueprint = Assembly.create_default()
	for i in range(3):
		var member: Dictionary = village()["members"][i]
		var actor: CharacterBody3D = player if i == 0 else Companion.new()
		if i != 0:
			get_parent().get_parent().add_child(actor)
			actor.setup(self, member, blueprint, i)
			actor.set_physics_process(false)
		actor.global_position = HomeState.vector(member["position"])
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
	_active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status = "Wähle Bewohner und erteile gemeinsame oder einzelne Aufträge."
	panel.refresh()

func _hide_creature_ui(node: Node) -> void:
	if node is CanvasLayer and node.visible:
		_hidden_layers.append(node)
		node.hide()
	for child: Node in node.get_children():
		_hide_creature_ui(child)

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	for actor: Node in actors.values():
		if is_instance_valid(actor) and actor != player:
			actor.queue_free()
	actors.clear()
	selected.clear()
	_routes.clear()
	_goals.clear()
	if is_instance_valid(camera):
		camera.queue_free()
	if is_instance_valid(_visuals):
		_visuals.queue_free()
	if is_instance_valid(player):
		for child_name: String in ["TribeSelection", "TribeCargo"]:
			var indicator: Node = player.get_node_or_null(child_name)
			if indicator != null:
				indicator.queue_free()
		player.collision_layer = int(_player_processing.get("collision_layer", 1))
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
	camera.global_position = _focus + Vector3(0, 22, 17)
	camera.look_at(_focus)

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
		if not camera.is_position_behind(actor.global_position) and rect.has_point(camera.unproject_position(actor.global_position + Vector3.UP)) and identity not in selected:
			selected.append(identity)
	panel.refresh()

func screen_command(position: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(position)
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(position) * 200, 1)
	ray.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		status = "Hier ist kein geladener Boden."
		return
	var target: Vector3 = hit["position"]
	for kind: String in Model.KINDS:
		if target.distance_to(HomeState.vector(village()["deposits"][kind]["position"])) < 1.8:
			issue_order(kind)
			return
	issue_order("move", target)

func issue_order(order: String, destination: Vector3 = Vector3.ZERO) -> bool:
	if not is_active() or selected.is_empty() or order not in Model.ORDERS:
		return false
	var before: Dictionary = village().duplicate(true)
	var data: Dictionary = village()
	if order == "move":
		destination = navigation.snap(destination)
		if not destination.is_finite() or destination.distance_to(anchor()) > 18.0:
			status = "Befehle bleiben zunächst in der sicheren Umgebung des Dorfes."
			return false
		for identity: String in selected:
			if navigation.route(actors[identity].global_position, destination).is_empty():
				status = "Mindestens ein ausgewählter Bewohner erreicht diesen Ort nicht."
				return false
	if order in ["tool", "hut"]:
		if (order == "tool" and int(data["tools"]) == 1) or (order == "hut" and int(data["huts"]) >= 2):
			status = "Dieser Ausbau ist bereits abgeschlossen."
			return false
		if order == "hut" and int(data["tools"]) == 0:
			status = "Stelle zuerst ein Steinwerkzeug her."
			return false
		if not data["project"].is_empty() and data["project"]["kind"] != order:
			status = "Schließe zuerst die laufende Arbeit ab."
			return false
		if data["project"].is_empty():
			for kind: String in Model.COSTS[order]:
				if int(data["stock"][kind]) < int(Model.COSTS[order][kind]):
					status = "Es fehlen eingelagerte Materialien: %d Holz und %d Stein." % [Model.COSTS[order]["wood"], Model.COSTS[order]["stone"]]
					return false
			for kind: String in Model.COSTS[order]:
				data["stock"][kind] -= Model.COSTS[order][kind]
			data["project"] = {"kind": order, "progress": 0.0}
	for identity: String in selected:
		var member: Dictionary = member_record(identity)
		member["order"] = order
		member["work"] = 0.0
		# Changing tasks never discards a carried unit of material.
		member["stage"] = "return" if member["cargo"] != "" else "outbound"
		if order == "move":
			member["destination"] = HomeState.vector_array(_workplace(destination, selected.find(identity)) if selected.size() > 1 else destination)
	_transaction = true
	var success: bool = _saves.save_now()
	if not success:
		body()["tribe"] = before
	_transaction = false
	_routes.clear()
	_goals.clear()
	status = "Auftrag gespeichert." if success else "Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten."
	if success:
		_visuals.rebuild(village())
	panel.refresh()
	return success

func _physics_process(delta: float) -> void:
	if not is_active():
		return
	var simulation_delta: float = _state.simulation_delta(delta)
	if simulation_delta <= 0:
		return
	for member: Dictionary in village()["members"]:
		var actor: CharacterBody3D = actors[member["id"]]
		member["hunger"] = maxf(0.0, float(member["hunger"]) - simulation_delta * 0.08)
		var order: String = member["order"]
		var target: Vector3 = actor.global_position
		if member["cargo"] != "" and order != "wait":
			target = anchor()
		elif order in Model.KINDS:
			target = HomeState.vector(village()["deposits"][order]["position"])
		elif order in ["feed", "tool"]:
			target = anchor()
		elif order == "hut" and int(village()["huts"]) < 2:
			target = HomeState.vector(village()["sites"][int(village()["huts"])])
		elif order == "move":
			target = HomeState.vector(member["destination"])
		if order != "wait" and (member["cargo"] != "" or order != "move"):
			target = _workplace(target, village()["members"].find(member))
		var arrived: bool = _walk(actor, str(member["id"]), target, delta, float(member["hunger"]))
		member["position"] = HomeState.vector_array(actor.global_position)
		if actor == player:
			player.current_hunger = float(member["hunger"])
		if arrived:
			_work(member, simulation_delta)
	_update_selection()

func _workplace(center: Vector3, index: int) -> Vector3:
	# Give residents separate work positions, keeping them visible/selectable.
	var offsets: Array[Vector3] = [Vector3(-1.5, 0, 1), Vector3(1.5, 0, 1), Vector3(0, 0, -1.6)]
	var target: Vector3 = navigation.snap(center + offsets[index % 3])
	if target.is_finite() and target.distance_to(center) < 2.8 and not navigation.route(center, target).is_empty():
		return target
	return center

func _walk(actor: CharacterBody3D, identity: String, target: Vector3, delta: float, hunger: float) -> bool:
	if not home.has_ground(actor.global_position):
		status = "Ein Bewohner wartet auf geladenen Boden."
		return false
	var offset: Vector3 = target - actor.global_position
	offset.y = 0
	var arrived: bool = offset.length() < 0.45
	var direction := Vector3.ZERO
	if not arrived:
		if not _goals.has(identity) or _goals[identity].distance_to(target) > 0.2:
			_routes[identity] = navigation.route(actor.global_position, target)
			_goals[identity] = target
		var route: PackedVector3Array = _routes.get(identity, PackedVector3Array())
		while not route.is_empty():
			var next_offset: Vector3 = route[0] - actor.global_position
			next_offset.y = 0
			if next_offset.length() > 0.25:
				direction = next_offset.normalized()
				break
			route.remove_at(0)
		_routes[identity] = route
		if direction != Vector3.ZERO and not home.safe_step(actor, direction):
			direction = Vector3.ZERO
			status = "Weg blockiert. Erteile dem Bewohner einen neuen Wegbefehl."
	var speed: float = 3.8 * (0.6 if hunger < 20.0 else 1.0)
	actor.velocity.x = direction.x * speed
	actor.velocity.z = direction.z * speed
	actor.velocity.y = -0.5 if actor.is_on_floor() else maxf(-12.0, actor.velocity.y - 20.0 * delta)
	var motion: Vector3 = direction * speed * delta
	if actor.is_on_floor() and direction != Vector3.ZERO and actor.test_move(actor.global_transform, motion):
		var raised: Transform3D = actor.global_transform.translated(Vector3.UP * 0.55)
		if not actor.test_move(actor.global_transform, Vector3.UP * 0.55) and not actor.test_move(raised, motion) and actor.test_move(raised.translated(motion), Vector3.DOWN * 0.7):
			actor.global_transform = raised
	actor.move_and_slide()
	if actor.is_on_floor():
		actor.apply_floor_snap()
	if direction != Vector3.ZERO:
		var visual: Node3D = actor.get_node_or_null("CreatureRuntimeVisual")
		if visual != null:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 7.0, 1.0))
	return arrived

func _work(member: Dictionary, delta: float) -> void:
	var data: Dictionary = village()
	var order: String = member["order"]
	if order == "wait":
		return
	if member["cargo"] != "":
		data["stock"][member["cargo"]] += 1
		data["delivered"] += 1
		member["cargo"] = ""
		member["stage"] = "outbound"
		_changed()
		return
	if order in Model.KINDS:
		var deposit: Dictionary = data["deposits"][order]
		if int(deposit["remaining"]) == 0:
			member["order"] = "wait"
			status = "Die örtliche Fundstelle ist aufgebraucht."
			return
		member["work"] = float(member["work"]) + delta * _work_rate(member)
		if float(member["work"]) >= 3.0:
			deposit["remaining"] -= 1
			member["cargo"] = order
			member["stage"] = "return"
			member["work"] = 0.0
			_changed()
	elif order == "feed":
		if float(member["hunger"]) < 95.0 and int(data["stock"]["food"]) > 0:
			data["stock"]["food"] -= 1
			data["meals"] += 1
			member["hunger"] = minf(100.0, float(member["hunger"]) + 25.0)
			_changed()
		member["order"] = "wait"
		status = "Versorgung abgeschlossen." if int(data["stock"]["food"]) > 0 else "Lagere weitere Nahrung ein, um die Bewohner zu versorgen."
	elif order in ["tool", "hut"]:
		var project: Dictionary = data["project"]
		if project.is_empty() or project["kind"] != order:
			member["order"] = "wait"
			return
		project["progress"] = minf(20.0, float(project["progress"]) + delta * _work_rate(member))
		if float(project["progress"]) >= (10.0 if order == "tool" else 20.0):
			data["tools" if order == "tool" else "huts"] += 1
			data["project"] = {}
			for worker: Dictionary in data["members"]:
				if worker["order"] == order:
					worker["order"] = "wait"
			status = "Steinwerkzeug fertig. Jetzt kannst du die erste Hütte bauen." if order == "tool" else "Hütte fertig: zwei weitere Schlafplätze."
			_changed()
	elif order == "move":
		member["order"] = "wait"

func _work_rate(member: Dictionary) -> float:
	var progression: Node = get_node("/root/ProgressionService")
	var legacy: Dictionary = progression.get_development_path()["legacy"]["group_cooperation"]
	return float(legacy["value"]) * (0.5 if float(member["hunger"]) < 20.0 else 1.0)

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
		cargo.material_override.albedo_color = Color("b9854d") if kind == "wood" else Color("bac8cf") if kind == "stone" else Color("c27b4e")
