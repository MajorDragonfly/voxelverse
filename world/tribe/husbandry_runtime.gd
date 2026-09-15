extends RefCounted
## Read-only D1/D2 bridge and village-owned transport/production transactions.
const Source = preload("res://world/tribe/husbandry_source.gd")
const H = preload("res://world/tribe/village_husbandry.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
var controller: Node
var source := Source.new()
var retry: float = 0.0
var refresh_clock: float = 0.0

func configure(registry: Callable, species: Callable, actor: Callable) -> void:
	source.registry = registry
	source.species = species
	source.actor = actor
	retry = 0.0

func candidates(p: Dictionary = {}) -> Array[String]:
	return source.candidates(controller.village(), controller._state.campaign.data["id"], H.site_recipe(p))

func attendance(p: Dictionary, identity: String = "") -> Dictionary:
	if identity.is_empty():
		identity = p["animal_id"]
	if identity.is_empty():
		return {"error": "Führe ein passendes gezähmtes Tier hierher und ordne es zu."}
	var data: Dictionary = controller.village()
	var result: Dictionary = source.read(data, controller._state.campaign.data["id"], identity, H.site_recipe(p))
	if not result["error"].is_empty():
		return result
	var animal: Dictionary = result["animal"]
	var record: Dictionary = data["husbandry"]["records"].get(identity, {})
	if not record.is_empty() and not H.matches(record, animal, result["recipe"]):
		return {"error": "Art oder Körper des Tieres hat sich geändert."}
	var actor: Node3D = result["actor"]
	if animal["order"] not in ["wait", "home"] or actor.global_position.distance_to(Space.resolve(controller, p["position"])) > 1.8:
		return {"error": "Das Tier muss am Tierplatz bleiben."}
	if not controller.home.has_ground(actor.global_position) or not controller.home._dry(actor.global_position) or controller.navigation.route(controller.anchor(), Space.resolve(controller, p["entrance"])).is_empty():
		return {"error": "Tierplatz oder Zugang ist momentan nicht erreichbar."}
	return result

func assign(pen_id: String, identity: String) -> bool:
	if not controller.is_active():
		return false
	var p: Dictionary = H.pen(controller.village(), pen_id)
	if p.is_empty():
		return false
	var result: Dictionary = attendance(p, identity)
	if not result["error"].is_empty():
		controller.status = result["error"]
		return false
	var before: Dictionary = controller.village().duplicate(true)
	var problem: String = H.bind(controller.village(), p, result["animal"], result["recipe"])
	if not problem.is_empty():
		controller.status = problem
		return false
	return controller._save_economy(before)

func release(pen_id: String) -> bool:
	if not controller.is_active():
		return false
	var p: Dictionary = H.pen(controller.village(), pen_id)
	if p.is_empty():
		return false
	var before: Dictionary = controller.village().duplicate(true)
	var problem: String = H.unbind(controller.village(), p)
	if not problem.is_empty():
		controller.status = problem
		return false
	return controller._save_economy(before)

func change_site(pen_id: String) -> bool:
	if not controller.is_active(): return false
	var data: Dictionary = controller.village()
	var p: Dictionary = H.pen(data, pen_id)
	if p.is_empty(): return false
	if p.animal_id != "":
		controller.status = "Löse zuerst die Tierzuordnung."
		return false
	for member: Dictionary in data.members:
		if member.care_pen_id == pen_id:
			controller.status = "Warte, bis Futter und Wasser zurückgebracht wurden."
			return false
	var before: Dictionary = data.duplicate(true)
	# Same footprint and material cost. Reuse the paid place without new IDs,
	# moving trough credits or discarding old receipts and collected products.
	p.kind = "pen" if p.get("kind", "pen") == "laying_site" else "laying_site"
	return controller._save_economy(before)

func cargo_target(member: Dictionary) -> Vector3:
	var p: Dictionary = H.pen(controller.village(), member["care_pen_id"])
	return Space.resolve(controller, p["entrance"]) if not p.is_empty() and attendance(p)["error"].is_empty() else controller.anchor()

func pickup(member: Dictionary) -> void:
	if Space.resolve(controller, member["position"]).distance_to(controller.anchor()) > 3.0:
		return
	var data: Dictionary = controller.village()
	for p: Dictionary in data["husbandry"]["pens"]:
		var kind: String = H.needed(data, p)
		if kind.is_empty() or not attendance(p)["error"].is_empty():
			continue
		data["stock"][kind] -= 1
		data["husbandry"]["withdrawn"][kind] += 1
		member["cargo"] = kind
		member["care_pen_id"] = p["id"]
		member["stage"] = "return"
		controller._changed()
		return

func deliver(member: Dictionary) -> void:
	var target: Vector3 = cargo_target(member)
	if Space.resolve(controller, member["position"]).distance_to(target) > 3.0:
		return
	var data: Dictionary = controller.village()
	var kind: String = member["cargo"]
	if target.distance_to(controller.anchor()) < 0.1:
		# Carried care supplies reserve warehouse space until delivered or returned.
		data["stock"][kind] += 1
		data["husbandry"]["returned"][kind] += 1
	else:
		H.pen(data, member["care_pen_id"])[kind] += 1.0
		data["husbandry"]["delivered"][kind] += 1
	member["cargo"] = ""
	member["care_pen_id"] = ""
	member["stage"] = "outbound"
	controller._changed()

func tick(delta: float) -> void:
	if not controller.is_active() or not is_finite(delta) or delta <= 0:
		return
	retry = maxf(0.0, retry - delta)
	if retry > 0:
		return
	var data: Dictionary = controller.village()
	if data["husbandry"]["records"].is_empty():
		return
	var before: Dictionary = data.duplicate(true)
	var durable: bool = false
	for p: Dictionary in data["husbandry"]["pens"]:
		if attendance(p)["error"].is_empty():
			durable = H.advance(data, p, minf(delta, 0.25)) or durable
	for identity: String in data["husbandry"]["records"]:
		var record: Dictionary = data["husbandry"]["records"][identity]
		# Already produced resources survives disappearance of its source animal.
		if H.pending(record) > 0 and not controller.navigation.route(controller.anchor(), Space.resolve(controller, record["pickup"])).is_empty():
			durable = H.offer(data, identity) or durable
	if durable and not controller._save_economy(before):
		retry = 5.0
		return
	refresh_clock += delta
	if refresh_clock >= 1.0:
		refresh_clock = 0.0
		controller._changed()

func description(p: Dictionary) -> String:
	var result: Dictionary = attendance(p)
	var status: String = result["error"]
	if status.is_empty():
		var record: Dictionary = controller.village()["husbandry"]["records"][p["animal_id"]]
		var recipe: Dictionary = H.production_recipe(record)
		var title: String = H.E.TITLES[recipe.resource_id]
		if H.pending(record) > 0:
			status = title + " bereit · Abholung wartet auf Lagerplatz."
		elif float(p["food"]) <= 0 or float(p["water"]) <= 0:
			status = title + "produktion wartet auf Futter und Wasser."
		else:
			status = "%s in %d s · %s %s je Intervall." % [title, ceili(float(recipe.interval) - float(record.clock)), str(recipe["yield"]), "Stück" if recipe.resource_id == "eggs" else "Liter"]
	return "Futter %.1f / 4 · Wasser %.1f / 8 Liter\n%s" % [p["food"], p["water"], status]
