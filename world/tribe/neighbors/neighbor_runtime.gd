extends Node3D
const Model = preload("res://world/tribe/neighbors/neighbor_state.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Companion = preload("res://world/home_group/home_companion.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Props = preload("res://world/tribe/village_visuals.gd")
var controller: Node
var actors: Dictionary = {}
var props: Node3D
var _appearance: String = ""

func clear_runtime() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	actors.clear()
	props = null
	_appearance = ""

func data() -> Dictionary:
	return controller.body().get("tribal_neighbor", {})

func refresh() -> void:
	if data().is_empty():
		return
	if actors.is_empty():
		var blueprint: Dictionary = Assembly.load_best_available()
		if blueprint.is_empty():
			blueprint = Assembly.create_default()
		for member: Dictionary in data()["members"]:
			var actor := Companion.new()
			add_child(actor)
			actor.setup(controller, member, blueprint, actors.size() + 10)
			actor.set_physics_process(false)
			actor._label.hide()
			actor.global_position = Home.vector(member["position"])
			actors[member["id"]] = actor
	var signature: String = str(data()["stock"]) + str(data()["technology"])
	if signature == _appearance:
		return
	_appearance = signature
	if is_instance_valid(props):
		remove_child(props)
		props.queue_free()
	props = Props.new()
	add_child(props)
	var center: Vector3 = Home.vector(data()["anchor"])
	props._box(center + Vector3(0, 0.12, 0), Vector3(2.5, 0.24, 2.5), Color("765130"))
	# The amber banner identifies another faction; the body blueprint stays yours.
	props._box(center + Vector3(1.4, 1.4, 0), Vector3(0.12, 2.8, 0.12), Color("785031"))
	props._box(center + Vector3(1.8, 2.3, 0), Vector3(0.75, 0.55, 0.12), Color("d9b878"))
	if int(data()["technology"]["shelter"]) == 1:
		var raised: Vector3 = center
		for ground: Array in data()["foundation"]:
			raised.y = maxf(raised.y, float(ground[1]))
		props._box(raised + Vector3(0, 0.1, 0), Vector3(2.2, 0.2, 2.2), Color("785031"))
		for ground: Array in data()["foundation"]:
			var floor_point: Vector3 = Home.vector(ground)
			var height: float = raised.y - floor_point.y + 0.2
			props._box(floor_point + Vector3(0, height * 0.5, 0), Vector3(0.24, height, 0.24), Color("785031"))
		props._hut(raised + Vector3(0, 0.2, 0))
	else:
		for index in range(int(data()["stock"]["wood"])):
			props._box(center + Vector3(-0.8 + index * 0.45, 0.4, 0), Vector3(0.3, 0.3, 1.3), Color("95643e"))
	for index in range(int(data()["stock"]["food"])):
		props._box(center + Vector3(-1.0 + (index % 3) * 0.35, 0.35 + (index / 3) * 0.25, 1.1), Vector3(0.25, 0.25, 0.25), Color("ab7857"))

func contact() -> bool:
	if not controller.is_active() or not data().is_empty():
		return false
	controller.navigation.rebuild(controller.home, controller.anchor(), Model.NAV_EXTENT)
	var center: Vector3 = Vector3.INF
	var places: Array[Vector3] = []
	var foundation: Array = []
	var nearest: float = INF
	# Bounded deterministic scan of the existing loaded graph; no distant spawn,
	# terrain replacement or fallback inside water/obstacles.
	for point_id: int in controller.navigation.graph.get_point_ids():
		var candidate: Vector3 = controller.navigation.graph.get_point_position(point_id)
		var distance: float = candidate.distance_to(controller.anchor())
		if distance < 6.0 or distance >= nearest or not controller.navigation.free_workplace(candidate, controller.village(), "neighbor", Model.SITE_RADIUS, 0.75):
			continue
		var project: Dictionary = controller.village()["project"]
		if project.has("position") and candidate.distance_to(Home.vector(project["position"])) < 3.5:
			continue
		var first: Vector3 = controller.navigation.snap(candidate + Vector3(-1, 0, 1))
		var second: Vector3 = controller.navigation.snap(candidate + Vector3(1, 0, 1))
		if first.distance_to(second) < 1.0 or first.distance_to(candidate) > 2.0 or second.distance_to(candidate) > 2.0:
			continue
		center = candidate
		nearest = distance
		places = [first, second]
	if not center.is_finite():
		controller.navigation.rebuild(controller.home, controller.anchor())
		controller.status = "Kein sicher erreichbarer Lagerplatz in der geladenen Umgebung frei. Suche nach einer Änderung der Umgebung erneut."
		return false
	for corner: Vector3 in [Vector3(-1,0,-1), Vector3(1,0,-1), Vector3(-1,0,1), Vector3(1,0,1)]:
		foundation.append(Home.vector_array(controller.navigation.snap(center + corner)))
	controller.body()["tribal_neighbor"] = Model.create(controller._state.campaign.data, controller.village(), center, places, foundation)
	controller._transaction = true
	var saved: bool = controller._saves.save_now()
	controller._transaction = false
	if not saved:
		controller.body().erase("tribal_neighbor")
		controller.navigation.rebuild(controller.home, controller.anchor())
		controller.status = "Kontakt konnte nicht gespeichert werden. Es wurde kein Lager angelegt."
		return false
	refresh()
	controller.status = "Der Uferbund braucht 6 Nahrung und 4 Holz für seine Unterkunft. Wähle zwei freie Bewohner als Träger."
	return true

func start_aid() -> bool:
	if not controller.is_active() or data().is_empty():
		return false
	for id: String in controller.selected:
		if controller.navigation.route(controller.actors[id].global_position, controller.anchor()).is_empty() or controller.navigation.route(controller.anchor(), Home.vector(data()["anchor"])).is_empty():
			controller.status = "Der Weg zum eigenen oder zum Nachbarlager ist blockiert."
			return false
	var previous: Dictionary = data().duplicate(true)
	var village_before: Dictionary = controller.village().duplicate(true)
	var problem: String = Model.begin(data(), controller.village(), controller.selected)
	if not problem.is_empty():
		controller.status = problem
		return false
	controller._transaction = true
	var saved: bool = controller._saves.save_now()
	controller._transaction = false
	if not saved:
		controller.body()["tribal_neighbor"] = previous
		controller.body()["tribe"] = village_before
	controller._routes.clear()
	controller._goals.clear()
	controller.status = "Hilfslieferung unterwegs · Anhalten und Fortsetzen gelten auch für diese Träger." if saved else "Speichern fehlgeschlagen. Der bisherige Auftrag bleibt erhalten."
	return saved

func target(member: Dictionary) -> Vector3:
	return Model.target(data(), controller.village(), member) if not data().is_empty() else Vector3.INF

func work(member: Dictionary) -> bool:
	if data().is_empty():
		return false
	var before: Dictionary = data()["aid"].duplicate(true)
	var handled: bool = Model.work(data(), controller.village(), member)
	if handled and before != data()["aid"]:
		controller._saves.schedule_autosave(1.0)
		controller._visuals.rebuild(controller.village())
		refresh()
	return handled

func tick(delta: float, simulation_delta: float) -> void:
	if data().is_empty():
		return
	var before: Dictionary = data().duplicate(true)
	for member: Dictionary in data()["members"]:
		var goal: Vector3 = Home.vector(member["workplace"])
		if data()["aid"]["status"] != "building" and int(member["walk"]) == 1:
			goal = controller.navigation.snap(goal + Vector3(0, 0, -2))
		var actor: CharacterBody3D = actors[member["id"]]
		var arrived: bool = controller._walk(actor, member["id"], goal, delta, 100.0, member)
		member["position"] = Home.vector_array(actor.global_position)
		if arrived:
			if data()["aid"]["status"] == "building":
				Model.build(data(), member["id"], simulation_delta)
			else:
				member["walk"] = 1 - int(member["walk"])
	if before["aid"]["status"] != data()["aid"]["status"]:
		get_node("/root/ProgressionService").record_neighbor_help(before, controller)
		controller._saves.schedule_autosave(1.0)
		controller.status = "Gemeinsam geholfen · Der Uferbund hat seine Unterkunft fertiggestellt und ist euch freundlich gesinnt."
		refresh()

func has_blocked() -> bool:
	return not data().is_empty() and data()["members"].any(func(member: Dictionary) -> bool: return member["blocked"])

func occupies(point: Vector3) -> bool:
	return not data().is_empty() and point.distance_to(Home.vector(data()["anchor"])) < 3.5

func focus(own: bool = false) -> void:
	if controller.is_active() and (own or not data().is_empty()):
		controller._focus = controller.anchor() if own else Home.vector(data()["anchor"])
		controller._update_camera()
