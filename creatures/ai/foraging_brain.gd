extends "res://creatures/ai/wildlife_brain.gd"
## Needs layer over danger/herding AI. Uses existing object identities and
## never creates encounter records, rewards or relationships.

const ForagingState = preload("res://world/resources/plants/foraging_state.gd")
const PLANT_EATERS: Array[String] = ["grazer", "forager", "climber"]
const HUNGER_PER_SECOND: float = 0.12
const FOOD_SIGHT: float = 16.0
const BITE_SECONDS: float = 0.8
const BITE_AMOUNT: float = 10.0

var satiety: float = 100.0
var _needs: Dictionary = {}
var _food: Node3D
var _bite_elapsed: float = 0.0
var _meal_rest: float = 0.0
var _food_time: float = 0.0
var _food_progress_time: float = 0.0
var _food_distance: float = INF
var _avoided: Dictionary = {}
var _foraging_clock: float = 0.0

func _ready() -> void:
	super._ready()
	_load_needs("")
	get_node("/root/SaveGameService").game_loaded.connect(_load_needs)

func _load_needs(_path: String) -> void:
	_food = null
	_bite_elapsed = 0.0
	_avoided.clear()
	_meal_rest = 0.0
	_needs = {}
	if ecological_role in PLANT_EATERS:
		_needs = ForagingState.animal(GameState, str(_campaign_identity.get("body_id", "")), str(_campaign_identity.get("object_id", "")), 35.0 + float(posmod(individual_seed, 51)))
		if not _needs.is_empty():
			satiety = float(_needs["satiety"])
	_sense_remaining = 0.0

func _physics_process(delta: float) -> void:
	var dt: float = GameState.simulation_delta(delta)
	var active: bool = not is_dead and GameState.current_phase == 0 and dt > 0.0 and not _needs.is_empty() and not ForagingState.body(GameState, str(_campaign_identity.get("body_id", ""))).is_empty() and not Steering.ground(self, global_position).is_empty()
	if active:
		_foraging_clock += dt
		_meal_rest = maxf(0.0, _meal_rest - dt)
		satiety = maxf(0.0, satiety - HUNGER_PER_SECOND * dt)
		_needs["satiety"] = satiety
		if satiety < 45.0:
			_needs["seeking"] = true
	super._physics_process(delta)
	if not active or ai_state != "eat" or not _valid_food() or not _food.can_feed(self):
		_bite_elapsed = 0.0
		return
	_bite_elapsed += dt
	if _bite_elapsed >= BITE_SECONDS:
		_bite_elapsed = 0.0
		var amount: float = _food.consume_food(self, minf(BITE_AMOUNT, 100.0 - satiety))
		satiety = minf(100.0, satiety + amount)
		_needs["satiety"] = satiety
		if satiety >= 75.0:
			_needs["seeking"] = false
			_meal_rest = 6.0
			_drop_food(false)
		_sense_remaining = 0.0

func _sense() -> void:
	super._sense()
	# Threats, territory return and the existing social attention hook win.
	if _intent not in ["rest", "wander", "herd"] or _needs.is_empty() or GameState.simulation_delta(1.0) <= 0.0:
		_drop_food(false)
		return
	if _meal_rest > 0.0:
		_intent = "rest"
		return
	if not bool(_needs["seeking"]):
		return
	if not _valid_food():
		_drop_food(false)
		_select_food()
	if not _valid_food():
		return
	var distance: float = global_position.distance_to(_food.global_position)
	_food_time += SENSE_INTERVAL * GameState.simulation_delta(1.0)
	_food_progress_time += SENSE_INTERVAL * GameState.simulation_delta(1.0)
	if _food.can_feed(self):
		_intent = "eat"
		_food_time = 0.0
		_food_progress_time = 0.0
	else:
		if _food_progress_time >= 3.0:
			if _food_distance - distance < 0.3:
				_drop_food(true)
				return
			_food_distance = distance
			_food_progress_time = 0.0
		if _food_time >= 14.0:
			_drop_food(true)
			return
		_intent = "forage"
		_goal = _food.global_position
	_steer_remaining = 0.0

func _valid_food() -> bool:
	return is_instance_valid(_food) and _food.is_inside_tree() and _food.has_food_available() and global_position.distance_to(_food.global_position) <= FOOD_SIGHT + 2.0 and Steering.clear_sight(self, _food)

func _select_food() -> void:
	var nearest: float = FOOD_SIGHT
	for key in _avoided.keys():
		if float(_avoided[key]) <= _foraging_clock:
			_avoided.erase(key)
	for source in get_tree().get_nodes_in_group(&"wildlife_plant_food"):
		if not source is Node3D or _avoided.has(source.get_instance_id()) or not source.has_food_available():
			continue
		var distance: float = global_position.distance_to(source.global_position)
		if distance >= nearest or _flat_distance(_anchor, source.global_position) > territory_radius + 6.0 or not can_perceive(source, FOOD_SIGHT):
			continue
		_food = source
		nearest = distance
	_food_distance = nearest

func _drop_food(avoid: bool) -> void:
	if avoid and is_instance_valid(_food):
		_avoided[_food.get_instance_id()] = _foraging_clock + 12.0
	_food = null
	_food_time = 0.0
	_food_progress_time = 0.0
	_food_distance = INF
	_bite_elapsed = 0.0

func _desired_heading() -> Vector3:
	if _intent == "eat":
		return Vector3.ZERO
	return super._desired_heading()

func _refresh_label() -> void:
	super._refresh_label()
	if ai_state in ["forage", "eat"]:
		_label.text = "Frisst" if ai_state == "eat" else "Sucht Nahrung"

func get_ai_debug_state() -> Dictionary:
	var data: Dictionary = super.get_ai_debug_state()
	data.merge({"satiety": satiety, "seeking_food": bool(_needs.get("seeking", false)), "food_target": _food.get_instance_id() if is_instance_valid(_food) else 0, "needs_available": not _needs.is_empty()})
	return data

func get_inspection_data() -> Dictionary:
	var data: Dictionary = super.get_inspection_data()
	if ecological_role in PLANT_EATERS:
		data["satiety"] = satiety
		data["ai_description"] = "Frisst" if ai_state == "eat" else ("Sucht Nahrung" if ai_state == "forage" else data["ai_description"])
	return data
