extends "res://world/resources/plants/berry_bush.gd"
## Player and animals consume the same finite stock, with the inherited mesh.

const ForagingState = preload("res://world/resources/plants/foraging_state.gd")
const Steering = preload("res://creatures/ai/wildlife_steering.gd")
const REGROW_SECONDS: float = 180.0

var _body_id: String = ""
var _food_key: String = ""
var _initialized: bool = false
var _refresh_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	get_node("/root/SaveGameService").game_loaded.connect(_on_loaded)

func _initialize_bush() -> void:
	_body_id = str(ForagingState.body(GameState)["id"])
	_food_key = "berry:%d:%d" % [roundi(global_position.x * 100.0), roundi(global_position.z * 100.0)]
	_initialized = true
	var entry: Dictionary = _entry()
	is_depleted = entry.is_empty() or float(entry["remaining"]) <= 0.0
	super._initialize_bush()
	add_to_group(&"wildlife_plant_food")

func _process(delta: float) -> void:
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0 and _initialized:
		_refresh_remaining = 1.0
		_sync_visual()

func _on_loaded(_path: String) -> void:
	if _initialized:
		_sync_visual()

func _entry() -> Dictionary:
	if not _initialized:
		return {}
	var entry: Dictionary = ForagingState.plant(GameState, _body_id, _food_key, hunger_restore)
	if not entry.is_empty() and float(entry["regrow_at"]) > 0.0 and float(GameState.campaign.data["elapsed_seconds"]) >= float(entry["regrow_at"]):
		entry["remaining"] = hunger_restore
		entry["regrow_at"] = 0.0
	return entry

func _sync_visual() -> void:
	var entry: Dictionary = _entry()
	var empty: bool = entry.is_empty() or float(entry["remaining"]) <= 0.0
	if empty != is_depleted:
		is_depleted = empty
		_generate_bush()

func get_food_remaining() -> float:
	var entry: Dictionary = _entry()
	return 0.0 if entry.is_empty() else float(entry["remaining"])

func has_food_available() -> bool:
	return get_food_remaining() > 0.0

func feeding_distance() -> float:
	# Leave room for the existing 1.1 m obstacle probe and the animal's body.
	if bush_collision.shape is BoxShape3D:
		return maxf(bush_collision.shape.size.x * absf(global_basis.get_scale().x), bush_collision.shape.size.z * absf(global_basis.get_scale().z)) * 0.5 + 1.35
	return 2.5

func can_feed(actor: Node) -> bool:
	if not actor is CharacterBody3D or not actor.is_inside_tree() or not _initialized:
		return false
	if absf(actor.global_position.y - global_position.y) > 1.25 or actor.global_position.distance_to(global_position) > feeding_distance():
		return false
	return not Steering.ground(actor, actor.global_position).is_empty() and Steering.clear_sight(actor, self)

func consume_food(actor: Node, amount: float) -> float:
	if not is_finite(amount) or amount <= 0.0 or not can_feed(actor):
		return 0.0
	var entry: Dictionary = _entry()
	if entry.is_empty():
		return 0.0
	var eaten: float = minf(amount, float(entry["remaining"]))
	entry["remaining"] = float(entry["remaining"]) - eaten
	if eaten > 0.0:
		entry["regrow_at"] = float(GameState.campaign.data["elapsed_seconds"]) + REGROW_SECONDS
	_sync_visual()
	return eaten

func interact(actor: Node) -> void:
	if actor == null or not actor.has_method("can_perform_action") or not actor.can_perform_action(required_ability) or not actor.has_method("restore_hunger"):
		return
	if actor.has_method("get_hunger_ratio") and float(actor.get_hunger_ratio()) >= 0.999:
		return
	var amount: float = consume_food(actor, hunger_restore)
	if amount > 0.0:
		actor.restore_hunger(amount)
