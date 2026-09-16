extends "res://creatures/ai/drinking_brain.gd"
## Hunger-driven predation/carrion on the same needs, encounters and death path.
## No separate population, carcass ledger, player reward or distant simulation.
const HuntText = preload("res://core/localization/ui_text.gd")
const HUNT_BUDGET: int = 8
const HUNT_RANGE: float = 13.0
const HUNT_SECONDS: float = 12.0
const HUNT_INTENTS: Array[String] = ["hunt", "seek_carcass", "eat_carcass"]
const HUNT_LABELS: Dictionary = {"hunt": "WILDLIFE_HUNT", "seek_carcass": "WILDLIFE_CARRION", "eat_carcass": "WILDLIFE_EAT_CARCASS"}
var _hunt_target: Node3D
var _hunt_clock: float = 0.0
var _hunt_trip: float = 0.0
var _hunt_progress: float = 0.0
var _hunt_distance: float = INF
var _hunt_bite: float = 0.0
var _hunt_retry: float = 0.0
var _hunt_cursor: int = 0
var _hunt_examined: int = 0
var _hunt_avoided: Dictionary = {}
var _hunt_saves: Node

func _ready() -> void:
	super._ready()
	_hunt_saves = get_node("/root/SaveGameService")
	_hunt_saves.game_loaded.connect(_reset_hunt)

func _exit_tree() -> void:
	_drop_hunt(false)
	if is_instance_valid(_hunt_saves) and _hunt_saves.game_loaded.is_connected(_reset_hunt):
		_hunt_saves.game_loaded.disconnect(_reset_hunt)

func _reset_hunt(_path: String) -> void:
	_drop_hunt(false)
	_hunt_avoided.clear()
	_hunt_retry = 0.0
	_hunt_cursor = 0

func _physics_process(delta: float) -> void:
	var dt: float = GameState.simulation_delta(delta)
	if get_tree().paused or dt <= 0.0: return
	_hunt_clock += dt
	_hunt_retry = maxf(0.0, _hunt_retry - dt)
	super._physics_process(delta)
	if not _hunting_active() or _intent not in HUNT_INTENTS or not _valid_hunt_target(_hunt_target):
		_hunt_bite = 0.0
		if _intent not in HUNT_INTENTS or not _hunting_active(): _drop_hunt(false)
		return
	if Steering.ground(self, global_position).is_empty() or not _reachable_meal(_hunt_target):
		_hunt_bite = 0.0
		return
	if _intent == "hunt" and not bool(_hunt_target.is_dead):
		if _attack_timer <= 0.0:
			_attack_timer = predator_attack_cooldown
			_hunt_target.receive_creature_attack(predator_attack_damage, self)
			if is_instance_valid(_preview): _preview.play_part_action("bite")
			_sense_remaining = 0.0
	elif _intent == "eat_carcass" and bool(_hunt_target.is_dead):
		_hunt_bite += dt
		if _hunt_bite >= BITE_SECONDS:
			_hunt_bite = 0.0
			_consume_carcass()

func _hunting_active() -> bool:
	if is_dead or ecological_role not in MEAT_EATERS or _needs.is_empty() or GameState.current_phase not in [0, 1]: return false
	if str(_campaign_identity.get("body_id", "")) != GameState.active_body_id or get_health_ratio() <= 0.30: return false
	if not bool(_needs.get("seeking", false)) or _meal_rest > 0.0: return false
	if get_node("/root/SaveGameService")._write_blocked: return false
	var social: Node = get_node_or_null("SocialBehavior")
	return social == null or float(social.get("attention_remaining")) <= 0.0

func _sense() -> void:
	super._sense()
	_hunt_examined = 0
	# Danger/return, an established water trip and explicit attention win.
	if get_tree().paused or not _hunting_active() or _intent not in ["rest", "wander", "herd"] or GameState.simulation_delta(1.0) <= 0.0:
		_drop_hunt(false)
		return
	if _hunt_retry > 0.0: return
	if not _valid_hunt_target(_hunt_target):
		_drop_hunt(false)
		_find_hunt_target()
	if not _valid_hunt_target(_hunt_target): return
	var dt: float = SENSE_INTERVAL * GameState.simulation_delta(1.0)
	_hunt_trip += dt
	_hunt_progress += dt
	var distance: float = global_position.distance_to(_hunt_target.global_position)
	if not _reachable_meal(_hunt_target):
		if _hunt_progress >= 3.0:
			if _hunt_distance - distance < 0.25:
				_drop_hunt(true)
				return
			_hunt_distance = distance
			_hunt_progress = 0.0
		if _hunt_trip > HUNT_SECONDS:
			_drop_hunt(true)
			return
	else:
		_hunt_progress = 0.0
	_goal = _hunt_target.global_position
	_intent = "eat_carcass" if bool(_hunt_target.is_dead) and _reachable_meal(_hunt_target) else "seek_carcass" if bool(_hunt_target.is_dead) else "hunt"
	_steer_remaining = 0.0

func _eligible_food(other: Variant) -> bool:
	if not is_instance_valid(other) or not other is Node3D or other == self or not other.is_inside_tree() or other.is_queued_for_deletion(): return false
	if not other.is_in_group(&"wildlife") or not other.has_method("get_campaign_identity") or not other.has_node("SocialBehavior"): return false
	if other.get_world_3d() != get_world_3d(): return false
	var identity: Dictionary = other.get_campaign_identity()
	if identity.get("body_id") != _campaign_identity.get("body_id") or identity.get("body_id") != GameState.active_body_id: return false
	if str(identity.get("object_id", "")).is_empty() or identity.get("species_id") == _campaign_identity.get("species_id"): return false
	if identity.get("species_id") == GameState.campaign.data.get("player_species_id"): return false
	# Catalog-guaranteed utility animals and every claimed/owned animal are safe.
	if not other.catalog_species.is_empty(): return false
	var body: Dictionary = ForagingState.body(GameState, str(identity.body_id))
	if body.is_empty() or body.get("domesticated_animals", {}).get("registry", {}).get("animals", {}).has(identity.object_id): return false
	var domestication: Node = get_tree().get_first_node_in_group(&"domestication_runtime")
	if domestication != null and domestication.current_registry().get("animals", {}).has(identity.object_id): return false
	var encounter: Dictionary = get_node("/root/ProgressionService").get_creature_encounter(identity, str(other.ecological_role), int(other.individual_seed))
	if encounter.is_empty() or encounter.get("relation") == "ally": return false
	if bool(other.is_dead): return float(other.carcass_food_remaining) > 0.01
	return ecological_role == "predator" and str(other.ecological_role) in PLANT_EATERS

func _valid_hunt_target(other: Variant) -> bool:
	if not _eligible_food(other): return false
	return global_position.distance_to(other.global_position) <= HUNT_RANGE + 2.0 and _flat_distance(_anchor, other.global_position) <= territory_radius and can_perceive(other, HUNT_RANGE + 2.0)

func _find_hunt_target() -> void:
	for id in _hunt_avoided.keys():
		if float(_hunt_avoided[id]) <= _hunt_clock: _hunt_avoided.erase(id)
	var candidates: Array[Node3D] = _sensed_carcasses.duplicate()
	candidates.append_array(_sensed_neighbors)
	var count: int = candidates.size()
	var best: float = INF
	for offset in range(mini(HUNT_BUDGET, count)):
		var other: Variant = candidates[(_hunt_cursor + offset) % count]
		_hunt_examined += 1
		if not is_instance_valid(other) or _hunt_avoided.has(other.get_instance_id()) or not _valid_hunt_target(other): continue
		if Steering.ground(other, other.global_position).is_empty() or not Space.dry(other, other.global_position): continue
		# Available carrion is cheaper than a fresh chase; no needless killing.
		var score: float = global_position.distance_to(other.global_position) + (0.0 if other.is_dead else HUNT_RANGE)
		if score < best:
			best = score
			_hunt_target = other
	_hunt_cursor = (_hunt_cursor + HUNT_BUDGET) % maxi(count, 1)
	_hunt_distance = global_position.distance_to(_hunt_target.global_position) if is_instance_valid(_hunt_target) else INF

func _reachable_meal(other: Variant) -> bool:
	if not _valid_hunt_target(other): return false
	return global_position.distance_to(other.global_position) <= predator_attack_distance and absf((other.global_position - global_position).dot(up_direction)) <= 0.8 and not Steering.ground(other, other.global_position).is_empty() and Space.dry(self, global_position) and Space.dry(other, other.global_position)

func _consume_carcass() -> bool:
	if get_tree().paused or GameState.simulation_delta(1.0) <= 0.0 or not _hunting_active() or not _reachable_meal(_hunt_target) or not _hunt_target.is_dead: return false
	var food: Node3D = _hunt_target
	var amount: float = minf(BITE_AMOUNT, minf(100.0 - satiety, float(food.carcass_food_remaining)))
	if amount <= 0.0: return false
	var previous_satiety: float = satiety
	var previous_seeking: bool = bool(_needs.seeking)
	var previous_food: float = food.carcass_food_remaining
	satiety += amount
	_needs.satiety = satiety
	if satiety >= 75.0: _needs.seeking = false
	food.carcass_food_remaining -= amount
	# Both authoritative records already contain the meal at the joint snapshot.
	# Failure restores the entire transfer, including rebound campaign references.
	if not food.get_node("SocialBehavior").store_carcass():
		food.carcass_food_remaining = previous_food
		_load_needs("")
		satiety = previous_satiety
		_needs.satiety = previous_satiety
		_needs.seeking = previous_seeking
		_drop_hunt(true)
		_hunt_retry = 3.0
		return false
	if is_instance_valid(_preview): _preview.play_part_action("eat")
	if satiety >= 75.0:
		_meal_rest = 8.0
		_drop_hunt(false)
	elif food.carcass_food_remaining <= 0.01:
		_drop_hunt(false)
	if food.carcass_food_remaining <= 0.01: food.queue_free()
	_sense_remaining = 0.0
	return true

func _drop_hunt(avoid: bool) -> void:
	if avoid and is_instance_valid(_hunt_target):
		if _hunt_avoided.size() >= HUNT_BUDGET: _hunt_avoided.erase(_hunt_avoided.keys()[0])
		_hunt_avoided[_hunt_target.get_instance_id()] = _hunt_clock + 12.0
	_hunt_target = null
	_hunt_trip = 0.0
	_hunt_progress = 0.0
	_hunt_distance = INF
	_hunt_bite = 0.0
	if _intent in HUNT_INTENTS:
		_intent = "rest"
		_steer_remaining = 0.0

func _desired_heading() -> Vector3:
	if _intent == "eat_carcass": return Vector3.ZERO
	if _intent in ["hunt", "seek_carcass"]:
		var direction: Vector3 = (_goal - global_position).slide(up_direction)
		return direction.normalized() if direction.length() > predator_attack_distance * 0.8 else Vector3.ZERO
	return super._desired_heading()

func get_expression_context() -> Dictionary:
	var context: Dictionary = super.get_expression_context()
	if _intent in HUNT_INTENTS:
		context.intent = "eat" if _intent == "eat_carcass" else "chase" if _intent == "hunt" else "forage"
	return context

func _refresh_label() -> void:
	super._refresh_label()
	if is_instance_valid(_label) and HUNT_LABELS.has(ai_state):
		_label.text = HuntText.text(HUNT_LABELS[ai_state])

func get_inspection_data() -> Dictionary:
	var data: Dictionary = super.get_inspection_data()
	if HUNT_LABELS.has(ai_state): data.ai_description = HuntText.text(HUNT_LABELS[ai_state])
	return data

func get_ai_debug_state() -> Dictionary:
	var data: Dictionary = super.get_ai_debug_state()
	data.hunting = {"target": str(_hunt_target.get_campaign_identity().object_id) if is_instance_valid(_hunt_target) else "", "trip": _hunt_trip, "examined": _hunt_examined, "avoided": _hunt_avoided.size(), "retry": _hunt_retry}
	return data
