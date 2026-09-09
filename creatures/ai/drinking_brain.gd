extends "res://creatures/ai/foraging_brain.gd"
## Needs arbitration over completed feeding, danger and social behavior.

const DrinkingState = preload("res://creatures/ai/drinking_state.gd")
const Shore = preload("res://creatures/ai/shore_water_search.gd")
const LAND_ROLES: Array[String] = ["grazer", "forager", "climber", "predator", "scavenger"]
const THIRST_PER_SECOND: float = 0.16

# Default uses the live generator. A provider may be supplied before entering
# the tree, allowing another surface adapter and controlled contract fixtures.
var water_provider: Node
var hydration: float = 100.0
var _drinking: Dictionary = {}
var _water_source: Dictionary = {}
var _water_avoided: Dictionary = {}
var _water_clock: float = 0.0
var _water_scan: int = 0
var _water_origin := Vector3.ZERO
var _water_retry: float = 0.0
var _sip: float = 0.0
var _water_trip: float = 0.0
var _water_progress: float = 0.0
var _bank_distance: float = INF
var _water_rest: float = 0.0

func _ready() -> void:
	if water_provider == null:
		water_provider = get_node("/root/WorldGenerator")
	super._ready()
	_load_drinking("")
	get_node("/root/SaveGameService").game_loaded.connect(_load_drinking)

func _load_drinking(_path: String) -> void:
	_drop_water(false)
	_water_avoided.clear()
	_water_retry = 0.0
	_water_scan = 0
	_water_rest = 0.0
	_drinking = {}
	if ecological_role in LAND_ROLES:
		_drinking = DrinkingState.animal(GameState, _campaign_identity, 40.0 + float(posmod(individual_seed * 7, 51)))
		if not _drinking.is_empty():
			hydration = float(_drinking["hydration"])
	_sense_remaining = 0.0

func _physics_process(delta: float) -> void:
	var dt: float = GameState.simulation_delta(delta)
	var active: bool = not is_dead and GameState.current_phase in [0, 1] and dt > 0.0 and not _drinking.is_empty() and not ForagingState.body(GameState, str(_campaign_identity.get("body_id", ""))).is_empty() and not Steering.ground(self, global_position).is_empty()
	if active:
		_water_clock += dt
		_water_retry = maxf(0.0, _water_retry - dt)
		_water_rest = maxf(0.0, _water_rest - dt)
		hydration = maxf(0.0, hydration - THIRST_PER_SECOND * dt)
		_drinking["hydration"] = hydration
		if hydration < 45.0:
			_drinking["seeking"] = true
	super._physics_process(delta)
	if not active or ai_state != "drink" or not Shore.can_drink(self, water_provider, _water_source):
		_sip = 0.0
		return
	_sip += dt
	if _sip >= 0.8:
		_sip = 0.0
		hydration = minf(100.0, hydration + 12.0)
		_drinking["hydration"] = hydration
		if hydration >= 80.0:
			_drinking["seeking"] = false
			_water_rest = 3.0
			_drop_water(false)
		_sense_remaining = 0.0

func _sense() -> void:
	super._sense()
	if _drinking.is_empty() or GameState.simulation_delta(1.0) <= 0.0 or _intent not in ["rest", "wander", "herd", "forage", "eat"]:
		_drop_water(false)
		return
	if _water_rest > 0.0 and satiety > 30.0:
		_drop_food(false)
		_intent = "rest"
		return
	if not bool(_drinking["seeking"]):
		return
	# Once chosen, finish a water trip. A substantially more urgent meal can
	# still win before a trip begins; missing water never blocks food search.
	if _water_source.is_empty() and _intent in ["forage", "eat"] and hydration > 25.0 and satiety < hydration:
		return
	if not _water_source.is_empty() and not Shore.valid_source(self, water_provider, _water_source):
		_drop_water(true)
	if _water_source.is_empty() and _water_retry <= 0.0:
		_scan_water()
	if _water_source.is_empty():
		return
	var dt: float = SENSE_INTERVAL * GameState.simulation_delta(1.0)
	_water_trip += dt
	_water_progress += dt
	var distance: float = _flat_distance(global_position, _water_source["bank"])
	if Shore.can_drink(self, water_provider, _water_source):
		_intent = "drink"
		_water_trip = 0.0
		_water_progress = 0.0
	else:
		if _water_progress >= 3.0:
			if _bank_distance - distance < 0.3:
				_drop_water(true)
				return
			_bank_distance = distance
			_water_progress = 0.0
		if _water_trip >= 14.0:
			_drop_water(true)
			return
		_intent = "seek_water"
		_goal = _water_source["bank"]
	_drop_food(false)
	_steer_remaining = 0.0

func _scan_water() -> void:
	for key in _water_avoided.keys():
		if float(_water_avoided[key]) <= _water_clock:
			_water_avoided.erase(key)
	if _water_scan == 0 or _flat_distance(global_position, _water_origin) > 3.0:
		_water_scan = 0
		_water_origin = global_position
	_water_source = Shore.find_batch(self, water_provider, _water_origin, _water_scan, _water_avoided)
	_water_scan += Shore.BATCH
	if not _water_source.is_empty():
		if _flat_distance(_anchor, _water_source["bank"]) > territory_radius + 6.0:
			_drop_water(true)
		else:
			_bank_distance = _flat_distance(global_position, _water_source["bank"])
	if _water_scan >= Shore.SAMPLES:
		_water_scan = 0
		_water_retry = 2.0

func _drop_water(avoid: bool) -> void:
	if avoid and not _water_source.is_empty():
		_water_avoided[str(_water_source["key"])] = _water_clock + 12.0
	_water_source = {}
	_water_trip = 0.0
	_water_progress = 0.0
	_bank_distance = INF
	_sip = 0.0

func _desired_heading() -> Vector3:
	if _intent == "drink":
		return Vector3.ZERO
	if _intent == "seek_water":
		var direction: Vector3 = _goal - global_position
		direction.y = 0.0
		return direction.normalized() if direction.length() > 0.35 else Vector3.ZERO
	return super._desired_heading()

func _refresh_label() -> void:
	super._refresh_label()
	if ai_state in ["seek_water", "drink"]:
		_label.text = "Trinkt" if ai_state == "drink" else "Sucht Wasser"
		_label.modulate = Color(0.65, 0.87, 1.0)

func get_ai_debug_state() -> Dictionary:
	var data: Dictionary = super.get_ai_debug_state()
	data.merge({"hydration": hydration, "seeking_water": bool(_drinking.get("seeking", false)), "drinking_available": not _drinking.is_empty(), "water_source": _water_source.duplicate(), "water_scan": _water_scan})
	return data

func get_inspection_data() -> Dictionary:
	var data: Dictionary = super.get_inspection_data()
	if ecological_role in LAND_ROLES:
		data["hydration"] = hydration
		data["ai_description"] = "Trinkt" if ai_state == "drink" else ("Sucht Wasser" if ai_state == "seek_water" else data["ai_description"])
	return data
