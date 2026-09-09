extends "res://world/resources/plants/berry_bush.gd"
## Reuses the existing plant visual and finite food API, with body-fixed state.
## The legacy foraging scene script writes GameState and assumes world +Y.
var adapter: RefCounted
var food_state: Dictionary = {}
var identity: String = ""

func _initialize_bush() -> void:
	is_depleted = food_state.remaining <= 0.0
	super._initialize_bush()
	add_to_group(&"wildlife_plant_food")

func _get_visual_seed() -> int:
	return int(identity.sha256_text().left(8).hex_to_int())

func _process(delta: float) -> void:
	if food_state.regrow_remaining <= 0.0: return
	food_state.regrow_remaining = maxf(0.0, float(food_state.regrow_remaining) - delta)
	if food_state.regrow_remaining == 0.0:
		food_state.remaining = hunger_restore
		is_depleted = false
		_generate_bush()

func get_food_remaining() -> float:
	return food_state.remaining

func has_food_available() -> bool:
	return get_food_remaining() > 0.0

func consume_food(actor: Node, amount: float) -> float:
	if not actor is CharacterBody3D or not is_finite(amount) or amount <= 0.0: return 0.0
	var up: Vector3 = adapter.up_at(adapter.location(self))
	var delta: Vector3 = actor.position - position
	if absf(delta.dot(up)) > 1.5 or delta.length() > 3.0 or not actor.is_on_floor(): return 0.0
	var ray := PhysicsRayQueryParameters3D.create(actor.position, position + up * 0.5, 1 | 2)
	ray.exclude = [get_rid(), actor.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return 0.0
	var eaten: float = minf(amount, food_state.remaining)
	food_state.remaining -= eaten
	if eaten > 0.0: food_state.regrow_remaining = 180.0
	if food_state.remaining == 0.0 and not is_depleted:
		is_depleted = true
		_generate_bush()
	return eaten

func interact(actor: Node) -> void:
	if actor == null or not actor.has_method("can_perform_action") or not actor.can_perform_action(required_ability) or not actor.has_method("restore_hunger"): return
	actor.restore_hunger(consume_food(actor, hunger_restore))
