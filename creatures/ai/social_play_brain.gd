extends "res://creatures/ai/hunting_brain.gd"
## Ambient same-species play after danger, needs and explicit player attention.
## Uses the existing sensing batch; no new population owner or global search.
const PlaySession = preload("res://creatures/ai/wildlife_play_session.gd")
const PlayText = preload("res://core/localization/ui_text.gd")
const PLAY_INTENTS: Array[String] = ["play_approach", "play_greet", "play_play", "play_rest"]
const PLAY_ROLES: Array[String] = ["grazer", "forager", "climber", "predator", "scavenger"]
const CANDIDATE_BUDGET: int = 8
const SEARCH_RANGE: float = 7.0
const PLAY_LABELS: Dictionary = {"play_approach": "WILDLIFE_PLAY_APPROACH", "play_greet": "WILDLIFE_PLAY_GREET", "play_play": "WILDLIFE_PLAY_ACTIVE", "play_rest": "WILDLIFE_PLAY_REST"}

var _play_session: RefCounted
var _play_cooldown: float = 0.0
var _play_search: float = 0.0
var _play_cursor: int = 0
var _play_examined: int = 0
var _play_last_reason: String = ""
var _play_saves: Node

func _ready() -> void:
	super._ready()
	_play_cooldown = 5.0 + float(posmod(individual_seed, 9)) * 0.5
	_play_search = float(posmod(individual_seed, 7)) * 0.13
	_play_saves = get_node("/root/SaveGameService")
	_play_saves.game_loaded.connect(_reset_play)

func _exit_tree() -> void:
	_stop_play("removed")
	if is_instance_valid(_play_saves) and _play_saves.game_loaded.is_connected(_reset_play):
		_play_saves.game_loaded.disconnect(_reset_play)
	super._exit_tree()

func _reset_play(_path: String) -> void:
	_stop_play("loaded")
	_play_cooldown = 5.0 + float(posmod(individual_seed, 9)) * 0.5
	_play_search = 1.0
	_play_cursor = 0

func _physics_process(delta: float) -> void:
	# The inherited movement predates simulation-speed pause; do not allow an
	# active play pair to keep walking while its session/needs clock is frozen.
	var dt: float = GameState.simulation_delta(delta)
	if get_tree().paused or dt <= 0.0: return
	_play_cooldown = maxf(0.0, _play_cooldown - dt)
	_play_search = maxf(0.0, _play_search - dt)
	if _play_session != null:
		if not play_available(): _stop_play("priority")
		elif Steering.ground(self, global_position).is_empty(): _stop_play("unloaded")
		else: _play_session.advance(self, dt, Engine.get_physics_frames())
	super._physics_process(delta)
	if _play_session != null and not play_available(): _stop_play("priority")
	if _play_session != null and _play_session.stage in ["greet", "rest"]:
		var other: Node3D = _play_session.partner(self)
		if is_instance_valid(other):
			var local: Vector3 = global_basis.inverse() * (other.global_position - global_position)
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-local.x, -local.z), 1.0 - exp(-4.5 * dt))

func play_available() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or is_dead or not is_physics_processing(): return false
	if GameState.current_phase not in [0, 1] or ecological_role not in PLAY_ROLES: return false
	if str(_campaign_identity.get("body_id", "")) != GameState.active_body_id: return false
	if get_health_ratio() < 0.70 or _threat_timer > 0.0 or _memory > 0.0 or _returning: return false
	if _intent not in ["rest", "wander", "herd"] and _intent not in PLAY_INTENTS: return false
	if ai_state == "unloaded" or satiety < 60.0 or hydration < 60.0: return false
	if bool(_needs.get("seeking", false)) or bool(_drinking.get("seeking", false)): return false
	if _meal_rest > 0.0 or _water_rest > 0.0: return false
	var social: Node = get_node_or_null("SocialBehavior")
	if social != null and float(social.get("attention_remaining")) > 0.0: return false
	return true

func _sense() -> void:
	super._sense()
	if get_tree().paused or GameState.simulation_delta(1.0) <= 0.0: return
	if _play_session != null:
		if not _play_session.valid(): return
		var other: Node3D = _play_session.partner(self)
		if not Steering.clear_sight(self, other) or Steering.ground(other, other.global_position).is_empty():
			_stop_play("occluded_or_unloaded")
			return
	elif _play_search <= 0.0 and _play_cooldown <= 0.0 and play_available():
		_play_search = 1.0
		_find_play_partner()
	if _play_session != null:
		_intent = "play_" + _play_session.stage

func _find_play_partner() -> void:
	_play_examined = 0
	var nearest: Node3D
	var best: float = SEARCH_RANGE * SEARCH_RANGE
	var count: int = _sensed_neighbors.size()
	for offset in range(mini(CANDIDATE_BUDGET, count)):
		var other: Node3D = _sensed_neighbors[(_play_cursor + offset) % count]
		_play_examined += 1
		if not is_instance_valid(other) or not other.has_method("play_available") or not other.play_available(): continue
		if other._play_session != null or other._play_cooldown > 0.0: continue
		if not _same_play_species(other): continue
		var distance: float = global_position.distance_squared_to(other.global_position)
		if distance >= best or not can_perceive(other, SEARCH_RANGE): continue
		if not Steering.ground(other, other.global_position).is_empty():
			nearest = other
			best = distance
	_play_cursor = (_play_cursor + CANDIDATE_BUDGET) % maxi(count, 1)
	if nearest == null: return
	# Recheck both sides at the atomic assignment point. SceneTree execution is
	# sequential; an existing session can never be stolen by a third animal.
	if not play_available() or not nearest.play_available() or nearest._play_session != null: return
	var session := PlaySession.new()
	var radius_a: float = float(collision_geometry(catalog_species).radius)
	var radius_b: float = float(collision_geometry(nearest.catalog_species).radius)
	session.configure(self, nearest, maxf(2.4, radius_a + radius_b + 0.65))
	_play_session = session
	nearest._play_session = session
	nearest._sense_remaining = 0.0
	_steer_remaining = 0.0
	nearest._steer_remaining = 0.0

func _same_play_species(other: Node3D) -> bool:
	if other.get_world_3d() != get_world_3d() or other == self: return false
	# Stable species/body IDs disambiguate equal seeds on different planets.
	return not str(_campaign_identity.get("species_id", "")).is_empty() \
		and _campaign_identity.get("species_id") == other._campaign_identity.get("species_id") \
		and _campaign_identity.get("body_id") == other._campaign_identity.get("body_id")

func _stop_play(reason: String) -> void:
	if _play_session != null: _play_session.cancel(reason)

func play_session_ended(session: RefCounted, reason: String) -> void:
	if session != _play_session: return
	_play_session = null
	_play_last_reason = reason
	_play_cooldown = 12.0 + float(posmod(individual_seed, 11))
	_sense_remaining = 0.0
	_steer_remaining = 0.0
	if _intent in PLAY_INTENTS:
		_intent = "rest"
		_wander_direction = Vector3.ZERO
		_steered = Vector3.ZERO
		velocity = velocity.project(up_direction)
	if ai_state in PLAY_INTENTS: ai_state = "rest"

func _desired_heading() -> Vector3:
	if _play_session != null and _intent in PLAY_INTENTS: return _play_session.heading(self)
	return super._desired_heading()

func get_expression_context() -> Dictionary:
	var context: Dictionary = super.get_expression_context()
	if _play_session != null and _intent in PLAY_INTENTS and play_available():
		var other: Node3D = _play_session.partner(self)
		if is_instance_valid(other):
			var offset: Vector3 = _visual_root.global_basis.inverse() * (other.global_position - global_position)
			context["look_yaw"] = atan2(-offset.x, -offset.z)
	return context

func _refresh_label() -> void:
	super._refresh_label()
	if is_instance_valid(_label) and PLAY_LABELS.has(ai_state):
		_label.text = PlayText.text(PLAY_LABELS[ai_state])
		_label.modulate = Color(0.68, 0.94, 0.79)

func get_inspection_data() -> Dictionary:
	var data: Dictionary = super.get_inspection_data()
	if PLAY_LABELS.has(ai_state): data["ai_description"] = PlayText.text(PLAY_LABELS[ai_state])
	return data

func get_ai_debug_state() -> Dictionary:
	var data: Dictionary = super.get_ai_debug_state()
	data["play"] = {"active": _play_session != null, "cooldown": _play_cooldown, "last_reason": _play_last_reason, "candidates_examined": _play_examined}
	if _play_session != null:
		var other: Node3D = _play_session.partner(self)
		data.play.merge({"stage": _play_session.stage, "elapsed": _play_session.elapsed, "partner": str(other._campaign_identity.get("object_id", "")) if is_instance_valid(other) else ""})
	return data
