extends "res://creatures/wildlife/procedural_wildlife_v8.gd"
## Optional scene-level extension. Keeps the original editor/rendering, attack,
## discovery, death, identity and social components in the inherited scripts.

const Steering = preload("res://creatures/ai/wildlife_steering.gd")
const SENSE_INTERVAL: float = 0.20
const STEER_INTERVAL: float = 0.10
const NEIGHBOR_LIMIT: int = 32
const LABELS: Dictionary = {"wander": "Wandert", "rest": "Ruht", "herd": "Sucht Anschluss", "flee": "Flieht", "alert": "Warnt", "chase": "Verfolgt", "search": "Sucht", "return": "Kehrt zurück", "social": "Ist aufmerksam", "blocked": "Weg blockiert", "unloaded": "Wartet auf Boden"}

@export_category("Wildlife AI")
@export_range(4.0, 20.0, 0.5) var sight_range: float = 13.0
@export_range(0.3, 3.0, 0.1) var warning_seconds: float = 0.9
@export_range(2.0, 16.0, 0.5) var maximum_chase_seconds: float = 8.0
@export_range(10.0, 35.0, 1.0) var territory_radius: float = 20.0

var ai_state: String = "rest"
var _intent: String = "rest"
var _anchor := Vector3.ZERO
var _anchor_ready: bool = false
var _ambient_heading := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _memory: float = 0.0
var _warning: float = 0.0
var _chase_time: float = 0.0
var _cooldown: float = 0.0
var _returning: bool = false
var _sense_remaining: float = 0.0
var _steer_remaining: float = 0.0
var _steered := Vector3.ZERO
var _goal := Vector3.ZERO
var _separation := Vector3.ZERO
var _target: Node3D
var _ignore_player: bool = false
var _last_attacker: int = 0
var _side: float = 1.0
var _progress_time: float = 0.0
var _progress_position := Vector3.ZERO
var _label: Label3D

func _ready() -> void:
	super._ready()
	if not catalog_species.is_empty():
		sight_range = float(catalog_species["domestication"]["perception_range"])
	_side = -1.0 if posmod(individual_seed, 2) == 0 else 1.0
	_sense_remaining = float(posmod(individual_seed, 10)) * 0.02
	_label = Label3D.new()
	_label.name = "WildlifeIntent"
	_label.position.y = 1.9
	_label.font_size = 32
	_label.pixel_size = 0.009
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.95, 0.87, 0.62)
	add_child(_label)

func _choose_wander_state() -> void:
	super._choose_wander_state()
	_ambient_heading = _wander_direction

func _physics_process(delta: float) -> void:
	Space.orient(self)
	if not _anchor_ready:
		# Streamers configure/add the scene before assigning its world position.
		_anchor = global_position
		_progress_position = global_position
		_anchor_ready = true
	_memory = maxf(0.0, _memory - delta)
	_warning = maxf(0.0, _warning - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	_sense_remaining -= delta
	_steer_remaining -= delta
	if _intent in ["chase", "search", "alert"]:
		_chase_time += delta
	if not is_dead and Steering.ground(self, global_position).is_empty():
		velocity = Vector3.ZERO
		_wander_direction = Vector3.ZERO
		ai_state = "unloaded"
		_refresh_label()
		return
	super._physics_process(delta)
	if is_dead:
		_label.hide()
		return
	_progress_time += delta
	if _progress_time >= 1.0:
		if _steered.length_squared() > 0.1 and _flat_distance(global_position, _progress_position) < 0.15:
			_side = -_side
			_steer_remaining = 0.0
		_progress_position = global_position
		_progress_time = 0.0
	_refresh_label()

func _update_role_direction() -> void:
	if int(get_node("/root/GameState").current_phase) not in [0, 1]:
		_wander_direction = Vector3.ZERO
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	# Respect the other workstream's public movement hook without importing it.
	var social: Node = get_node_or_null("SocialBehavior")
	var social_owns: bool = social != null and social.has_method("controls_movement") and bool(social.controls_movement())
	if social_owns and float(social.get("attention_remaining")) > 0.0:
		_wander_direction = Vector3.ZERO
		ai_state = "social"
		_steer_remaining = 0.0
		return
	# An ally can release movement control to flee a third-party attacker.
	# Its friendship still excludes the player from potential threats.
	var ally: bool = social_owns
	if social != null and social.has_method("entry"):
		ally = str(social.entry().get("relation", "wild")) == "ally"
	# Tribal control is a group. Never target the disabled phase-0 player.
	ally = ally or int(get_node("/root/GameState").current_phase) == 1
	if ally != _ignore_player:
		_ignore_player = ally
		_sense_remaining = 0.0
		if _ignore_player and is_instance_valid(_target) and _target.is_in_group(&"player"):
			_target = null
			_memory = 0.0
			_chase_time = 0.0
	if _sense_remaining <= 0.0:
		_sense_remaining = SENSE_INTERVAL
		_sense()
	var desired: Vector3 = _desired_heading()
	if desired.length_squared() > 0.001:
		desired = (desired.normalized() + _separation * (0.2 if _intent == "flee" else 0.65)).normalized()
	elif _intent in ["rest", "herd", "wander"] and _separation.length_squared() > 0.2:
		desired = _separation.normalized()
	if _steer_remaining <= 0.0 or desired == Vector3.ZERO:
		_steer_remaining = STEER_INTERVAL
		_steered = Steering.choose(self, desired, maximum_step_height, _side)
	_wander_direction = _steered
	ai_state = "blocked" if desired.length_squared() > 0.001 and _steered == Vector3.ZERO else _intent
	if _intent == "chase" and is_instance_valid(_target):
		_try_predator_attack(_target)

func _sense() -> void:
	var old_intent: String = _intent
	var neighbors: Array[Node3D] = []
	_separation = Vector3.ZERO
	for node in get_tree().get_nodes_in_group(&"wildlife"):
		if node == self or not node is Node3D or bool(node.get("is_dead")):
			continue
		var distance: float = global_position.distance_to(node.global_position)
		if distance > 13.0:
			continue
		neighbors.append(node)
		if distance < 1.8 and distance > 0.01:
			_separation += (global_position - node.global_position).normalized() * (1.0 - distance / 1.8)
		elif distance <= 0.01:
			var angle: float = float(posmod(individual_seed, 31)) / 31.0 * TAU
			_separation += global_basis * Vector3(cos(angle), 0.0, sin(angle))
		if neighbors.size() >= NEIGHBOR_LIMIT:
			break
	_separation = _separation.slide(up_direction)
	_separation = _separation.limit_length(1.0)
	var perceived: Node3D = null
	if _threat_timer > 0.0 and is_instance_valid(_threat) and not (_ignore_player and _threat.is_in_group(&"player")):
		if _last_attacker != _threat.get_instance_id() or can_perceive(_threat, sight_range):
			perceived = _threat
			_last_attacker = _threat.get_instance_id()
	if perceived == null and not _ignore_player and is_instance_valid(_player) and not bool(_player.get("is_dead")):
		if can_perceive(_player, sight_range if ecological_role == "predator" else _player_caution_range()):
			perceived = _player
	if ecological_role != "predator":
		for other in neighbors:
			if str(other.get("ecological_role")) == "predator" and can_perceive(other, 9.0):
				if perceived == null or global_position.distance_squared_to(other.global_position) < global_position.distance_squared_to(perceived.global_position):
					perceived = other
	if _returning:
		_intent = "return"
		_goal = _anchor
		if _flat_distance(global_position, _anchor) < 1.8:
			_returning = false
			_cooldown = 5.0
			_intent = "rest"
	elif ecological_role == "predator" and (_chase_time > maximum_chase_seconds or _flat_distance(global_position, _anchor) > territory_radius):
		_begin_return()
	elif perceived != null and (ecological_role != "predator" or _cooldown <= 0.0):
		var fresh: bool = _memory <= 0.0 or _target != perceived
		_target = perceived
		_last_seen = perceived.global_position
		_memory = 3.5
		if ecological_role == "predator" and get_health_ratio() > 0.30:
			if fresh:
				_warning = warning_seconds
				_chase_time = 0.0
			_intent = "alert" if _warning > 0.0 else "chase"
		else:
			_intent = "flee"
	elif _memory > 0.0:
		_intent = "search" if ecological_role == "predator" and get_health_ratio() > 0.30 else "flee"
	elif ecological_role == "predator" and _chase_time > 0.0:
		_begin_return()
	else:
		_target = null
		_intent = "rest" if _ambient_heading == Vector3.ZERO else "wander"
		if _cooldown > 0.0:
			_intent = "rest"
		elif _flat_distance(global_position, _anchor) > territory_radius + 8.0:
			_intent = "return"
			_goal = _anchor
		elif ecological_role in ["grazer", "forager", "climber"]:
			var center := Vector3.ZERO
			var count: int = 0
			for other in neighbors:
				if int(other.get("species_seed")) == species_seed and Steering.clear_sight(self, other):
					center += other.global_position
					count += 1
			if count > 0:
				center /= float(count)
				if _flat_distance(global_position, center) > 3.5:
					_intent = "herd"
					_goal = center
	if old_intent != _intent:
		_steer_remaining = 0.0
		if _intent == "alert":
			audio_event.emit(&"warn")

func _begin_return() -> void:
	_returning = true
	_intent = "return"
	_goal = _anchor
	_memory = 0.0
	_target = null
	_chase_time = 0.0

func _desired_heading() -> Vector3:
	if _intent in ["rest", "alert", "social"]:
		return Vector3.ZERO
	if _intent == "wander":
		return _ambient_heading
	var delta: Vector3
	if _intent == "flee":
		delta = global_position - _last_seen
	elif _intent in ["chase", "search"]:
		delta = _last_seen - global_position
		if _flat_distance(global_position, _last_seen) < (0.8 if _intent == "search" else predator_attack_distance * 0.80):
			return Vector3.ZERO
	else:
		delta = _goal - global_position
		if _flat_distance(global_position, _goal) < 1.3:
			return Vector3.ZERO
	delta = delta.slide(up_direction)
	return delta.normalized()

func can_perceive(target: Node3D, radius: float) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var delta: Vector3 = target.global_position - global_position
	if delta.length() > radius or absf(delta.dot(up_direction)) > 3.5:
		return false
	var forward: Vector3 = -_visual_root.global_basis.z
	forward = forward.slide(up_direction)
	delta = delta.slide(up_direction)
	# Very near movement is noticed in all directions; distant targets need
	# to be within a broad forward field of view and unobstructed sight.
	if delta.length() > 2.4 and forward.normalized().dot(delta.normalized()) < -0.25:
		return false
	return Steering.clear_sight(self, target)

func _try_predator_attack(target: Node) -> void:
	if not target is Node3D or is_dead or _intent != "chase" or _warning > 0.0 or _ignore_player:
		return
	if bool(target.get("is_dead")) or global_position.distance_to(target.global_position) > predator_attack_distance:
		return
	if not Steering.clear_sight(self, target):
		return
	# Retain the existing damage/cooldown pathway and its optional signals.
	super._try_predator_attack(target)

func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	_label.text = str(LABELS.get(ai_state, ai_state))
	_label.visible = not is_dead and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 22.0 and ai_state not in ["wander", "rest"]
	_label.modulate = Color(1.0, 0.56, 0.35) if ai_state in ["alert", "chase"] else Color(0.95, 0.87, 0.62)

func get_ai_debug_state() -> Dictionary:
	return {"state": ai_state, "intent": _intent, "anchor": _anchor, "last_seen": _last_seen, "memory": _memory, "goal": _goal, "chase_time": _chase_time, "returning": _returning, "ignore_player": _ignore_player}

func get_inspection_data() -> Dictionary:
	var data: Dictionary = super.get_inspection_data()
	data["ai_state"] = ai_state
	data["ai_description"] = LABELS.get(ai_state, ai_state)
	return data

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return (a - b).slide(up_direction).length()

func surface_origin_shifted(shift: Vector3) -> void:
	_anchor += shift
	_last_seen += shift
	_goal += shift
	_progress_position += shift

func _player_caution_range() -> float:
	if catalog_species.is_empty(): return 6.0
	return 2.8 if catalog_species["domestication"]["temperament"] == "social" else 4.0
