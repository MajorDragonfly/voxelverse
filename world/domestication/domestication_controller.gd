extends RefCounted
signal animal_changed(object_id: String, code: String)
## No autoload, species database, social points or citizen recruitment.
## The host supplies trusted live context, a D1 adapter and an atomic commit.
const State = preload("res://world/domestication/animal_state.gd")
const REACH: float = 4.5
var registry: Dictionary = {}
var persist: Callable
var suitability: Callable
var last_result: Dictionary = {}

func configure(data: Dictionary, commit_callback: Callable, checked_d1_adapter: Callable = Callable()) -> String:
	var error: String = State.validate(data)
	if not error.is_empty():
		return error
	registry = data.duplicate(true)
	persist = commit_callback
	suitability = checked_d1_adapter
	return ""

func record(object_id: String) -> Dictionary:
	return registry.get("animals", {}).get(object_id, {}).duplicate(true)

func owned_animals(faction_id: String, include_dead: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for a: Dictionary in registry.get("animals", {}).values():
		if a["owner_faction_id"] == faction_id and (include_dead or a["status"] != "dead"):
			result.append(a.duplicate(true))
	return result

func begin_offer(object_id: String, food: String, context: Dictionary) -> Dictionary:
	var a: Dictionary = record(object_id)
	var error: String = _offer_error(a, food, context)
	if not error.is_empty():
		return _result(false, error)
	if not a["pending"].is_empty():
		return _result(false, "already_offering")
	a["status"] = "taming"
	a["claim_faction_id"] = context["faction_id"]
	a["home"] = State.point_array(context["home"])
	a["pending"] = {"actor_id": context["actor_id"], "faction_id": context["faction_id"], "food": food, "elapsed": 0.0}
	return _replace(a, {}, "offer_started")

func advance_offer(object_id: String, delta: float, context: Dictionary) -> Dictionary:
	var a: Dictionary = record(object_id)
	if a.is_empty() or a["pending"].is_empty():
		return _result(false, "no_offer")
	if not State.number(delta, 0.000001, 0.25):
		return _result(false, "invalid_delta")
	if context.get("paused", false):
		return _result(false, "paused")
	var pending: Dictionary = a["pending"]
	var error: String = _offer_error(a, pending["food"], context)
	if error.is_empty() and (pending["actor_id"] != context.get("actor_id") or pending["faction_id"] != context.get("faction_id")):
		error = "handler_changed"
	if not error.is_empty():
		return interrupt_offer(object_id, error)
	var elapsed: float = float(pending["elapsed"]) + delta
	if elapsed < State.OFFER_SECONDS - 0.000001:
		# Simulation time only; the host checkpoints this with its next joint save.
		a["pending"]["elapsed"] = elapsed
		registry["animals"][object_id] = a
		return _result(true, "offering")
	var policy: Dictionary = suitability.call(a["species_id"], pending["food"])
	a["trust"] = minf(100.0, float(a["trust"]) + float(policy["trust_gain"]))
	a["pending"] = {}
	var completed: bool = float(a["trust"]) >= 100.0
	if completed:
		a["status"] = "tamed"
		a["owner_faction_id"] = a["claim_faction_id"]
		a["claim_faction_id"] = ""
		a["wait_position"] = a["position"].duplicate()
	# Cost and trust/ownership are accepted only by the same successful host save.
	return _replace(a, {pending["food"]: policy["food_units"]}, "tamed" if completed else "trust_gained")

func interrupt_offer(object_id: String, reason: String = "cancelled") -> Dictionary:
	var a: Dictionary = record(object_id)
	if a.is_empty() or a["pending"].is_empty():
		return _result(false, "no_offer")
	a["pending"] = {}
	# Completed meals retain trust and the claim; an unpaid first offer releases it.
	if float(a["trust"]) == 0.0:
		a["status"] = "wild"
		a["claim_faction_id"] = ""
	return _replace(a, {}, "interrupted:" + reason)

func abandon_claim(object_id: String, context: Dictionary) -> Dictionary:
	var a: Dictionary = record(object_id)
	var error: String = _context_error(a, context)
	if not error.is_empty():
		return _result(false, error)
	if a["status"] != "taming" or a["claim_faction_id"] != context["faction_id"]:
		return _result(false, "not_claimant")
	a.merge({"status": "wild", "claim_faction_id": "", "trust": 0.0, "pending": {}}, true)
	return _replace(a, {}, "claim_abandoned")

func command(object_id: String, order: String, context: Dictionary) -> Dictionary:
	var a: Dictionary = record(object_id)
	var error: String = _context_error(a, context)
	if not error.is_empty():
		return _result(false, error)
	if a["status"] != "tamed" or a["owner_faction_id"] != context["faction_id"]:
		return _result(false, "not_owner")
	if order not in State.ORDERS:
		return _result(false, "invalid_order")
	a["order"] = order
	a["handler_id"] = context["actor_id"] if order == "follow" else ""
	if order == "wait":
		a["wait_position"] = a["position"].duplicate()
	return _replace(a, {}, "order_" + order)

func damage(object_id: String, amount: float) -> Dictionary:
	var a: Dictionary = record(object_id)
	if a.is_empty() or a["status"] == "dead" or not State.number(amount, 0.000001, 100000.0):
		return _result(false, "invalid_damage")
	a["health"] = maxf(0.0, float(a["health"]) - amount)
	a["pending"] = {}
	if a["health"] == 0.0:
		a.merge({"status": "dead", "claim_faction_id": "", "order": "wait", "handler_id": ""}, true)
	elif a["status"] == "taming" and float(a["trust"]) == 0.0:
		a.merge({"status": "wild", "claim_faction_id": ""}, true)
	return _replace(a, {}, "died" if a["health"] == 0.0 else "hurt")

func record_position(object_id: String, position: Vector3) -> void:
	if registry["animals"].has(object_id) and State.point(State.point_array(position)):
		registry["animals"][object_id]["position"] = State.point_array(position)

func checkpoint() -> bool:
	return persist.is_valid() and bool(persist.call(registry.duplicate(true), {}))

func _context_error(a: Dictionary, c: Dictionary) -> String:
	if a.is_empty(): return "unknown_animal"
	if c.get("paused", false): return "paused"
	if not State.integer(c.get("phase"), 1, 5): return "tribal_age_required"
	if c.get("campaign_id") != registry["campaign_id"] or c.get("body_id") != a["body_id"]: return "wrong_world"
	if not State.identity(c.get("faction_id")) or not State.identity(c.get("actor_id")) or not State.identity(c.get("player_species_id")) or not c.get("actor_alive", false): return "invalid_handler"
	if a["species_id"] == c["player_species_id"]: return "own_species"
	if a["status"] == "dead": return "dead"
	return ""

func _offer_error(a: Dictionary, food: String, c: Dictionary) -> String:
	var error: String = _context_error(a, c)
	if not error.is_empty(): return error
	if not c.get("handler_available", true): return "handler_busy"
	if a["status"] == "tamed": return "already_tamed"
	if a["claim_faction_id"] not in ["", c["faction_id"]]: return "claimed_by_other"
	if not State.integer(c.get("capacity"), 1, State.MAX_ANIMALS): return "invalid_capacity"
	if a["claim_faction_id"].is_empty() and State.occupied(registry, c["faction_id"]) >= int(c["capacity"]): return "capacity_full"
	if not c.get("actor_position") is Vector3 or not c.get("home") is Vector3 or not State.point(State.point_array(c["actor_position"])) or not State.point(State.point_array(c["home"])): return "invalid_position"
	if c["actor_position"].distance_to(State.vector(a["position"])) > REACH: return "out_of_range"
	if not c.get("line_of_sight", false): return "no_line_of_sight"
	if c.get("threatened", false): return "fleeing"
	if not suitability.is_valid(): return "d1_unavailable"
	var policy: Variant = suitability.call(a["species_id"], food)
	# This is the D2 host-policy result, explicitly NOT a competing D1 schema.
	if not policy is Dictionary or policy.get("eligible") != true: return "unsuitable"
	if policy.get("food_allowed") != true: return "wrong_food"
	if not State.integer(policy.get("food_units"), 1, 1000) or not State.number(policy.get("trust_gain"), 0.01, 100.0): return "invalid_policy"
	var stock: Variant = c.get("stock", {})
	if not stock is Dictionary or not State.integer(stock.get(food), int(policy["food_units"]), 1000000000): return "insufficient_food"
	return ""

func _replace(animal: Dictionary, cost: Dictionary, code: String) -> Dictionary:
	var proposed: Dictionary = registry.duplicate(true)
	proposed["animals"][animal["object_id"]] = animal
	if not State.validate(proposed).is_empty():
		return _result(false, "invalid_state")
	if not persist.is_valid() or not bool(persist.call(proposed.duplicate(true), cost.duplicate())):
		return _result(false, "save_failed")
	registry = proposed
	animal_changed.emit(animal["object_id"], code)
	return _result(true, code)

func _result(ok: bool, code: String) -> Dictionary:
	last_result = {"ok": ok, "code": code}
	return last_result.duplicate()
