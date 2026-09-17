extends "res://world/home_group/home_companion.gd"
## Same species, individual presentation and purposeful participation. The
## original movement owner still checks every physical step and records place.
signal audio_event(event: StringName)
const Text = preload("res://core/localization/ui_text.gd")
const Play = preload("res://creatures/ai/wildlife_play_session.gd")
const Steering = preload("res://creatures/ai/wildlife_steering.gd")
const ACTIVITY_KEYS := {"defending": "LIVING_DEFENDING", "assisting": "LIVING_ASSISTING",
	"retreating": "LIVING_RETREAT", "recovering": "LIVING_RECOVERING", "scouting": "LIVING_SCOUTING",
	"patrolling": "LIVING_PATROLLING", "play_approach": "WILDLIFE_PLAY_APPROACH",
	"play_greet": "WILDLIFE_PLAY_GREET", "play_play": "WILDLIFE_PLAY_ACTIVE", "play_rest": "WILDLIFE_PLAY_REST"}
var individual_seed: int = 0
var personality: String = "guardian"
var _preview: Node3D
var _enemy: Node3D
var _assist: WeakRef
var _assist_seconds: float = 0.0
var _scan: float = 0.0
var _attack_cooldown: float = 0.0
var _windup: float = 0.0
var _winding: bool = false
var _recovering: bool = false
var _quiet: float = 0.0
var _clock: float = 0.0
var _food_notice: float = 0.0
var _food_source: Node3D
var _last_order: String = ""
var _play_session: RefCounted
var _play_cooldown: float = 5.0
var _play_last_reason: String = ""
# Shared play-session port; movement remains owned by the base class.
var _sense_remaining: float = 0.0
var _steer_remaining: float = 0.0
var ai_state: String = "rest"

func setup(owner_node: Node, member: Dictionary, blueprint: Dictionary, index: int) -> void:
	individual_seed = int(str(member.id).sha256_text().left(7).hex_to_int())
	personality = "guardian" if index == 0 else "scout"
	var appearance: Dictionary = blueprint.duplicate(true)
	var color: Color = appearance.get("body", {}).get("color", Color("73b696"))
	appearance.body.color = color.darkened(0.12) if personality == "guardian" else color.lightened(0.12)
	appearance.paint.intensity = 0.82 if personality == "guardian" else 0.55
	super.setup(owner_node, member, appearance, index)
	_preview = _visual.get_node("BlueprintCreatureVisual")
	_preview.scale *= 1.06 if personality == "guardian" else 0.94
	current_health = float(member.get("health", maximum_health))
	_recovering = current_health <= 30.0
	_play_cooldown += float(posmod(individual_seed, 7))
	var expressions := preload("res://creatures/behavior/creature_expression_driver.gd").new()
	expressions.name = "ExpressionBehavior"
	add_child(expressions)
	add_to_group(&"home_companion")
	set_meta(&"species_seed", int(str(controller.group_state().species_id).sha256_text().left(7).hex_to_int()))
	set_meta(&"audio_body_size", 1.06 if personality == "guardian" else 0.94)
	if is_instance_valid(controller.player) and controller.player.has_signal("creature_attacked"):
		controller.player.creature_attacked.connect(_player_attacked)

func _physics_process(delta: float) -> void:
	var dt: float = get_node("/root/GameState").simulation_delta(delta)
	if dt <= 0.0 or get_tree().paused: return
	if not is_instance_valid(controller) or not controller.is_active():
		_stop_play("inactive")
		_enemy = null
		_assist = null
		_winding = false
		return
	super._physics_process(dt)
	if not visible:
		_stop_play("unloaded")
		return
	ai_state = status_code
	if _play_session != null and _play_session.stage in ["greet", "rest"]:
		_face(_play_session.partner(self), dt)
	elif is_instance_valid(_enemy):
		_face(_enemy, dt)
	_label.text = "%s · %s\n%s · %d%%" % [controller.member_record(member_id).name,
		Text.text("LIVING_GUARDIAN" if personality == "guardian" else "LIVING_SCOUT"), status, roundi(current_health)]
	_label.visible = global_position.distance_to(controller.player.global_position) < 22.0

func _activity(delta: float, member: Dictionary, target: Vector3) -> Dictionary:
	var normal: Dictionary = super._activity(delta, member, target)
	_clock += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_assist_seconds = maxf(0.0, _assist_seconds - delta)
	_play_cooldown = maxf(0.0, _play_cooldown - delta)
	_food_notice = maxf(0.0, _food_notice - delta)
	_scan -= delta
	if member.order != _last_order:
		_stop_play("order")
		_enemy = null
		_assist = null
		_winding = false
		_food_source = null
		_scan = 0.0
		_last_order = member.order
	if _scan <= 0.0:
		_scan = 0.3
		_sense_party(member.order)
	if is_instance_valid(_enemy) and (_enemy.is_dead or _enemy.is_queued_for_deletion()): _enemy = null
	_quiet = 0.0 if is_instance_valid(_enemy) else _quiet + delta
	if _recovering:
		_stop_play("hurt")
		if _quiet >= 3.0 and (global_position.distance_to(controller.home_position()) < 4.0 or current_health <= 0.0):
			current_health = minf(maximum_health, current_health + delta * 3.0)
			member.health = current_health
			if current_health >= 65.0: _recovering = false
		if current_health <= 0.0 or member.order == "wait": return _choice(global_position, false, "recovering")
		return _choice(Space.offset(self, controller.home_position(), Vector3(_turn_sign * 2.3, 0, 2.3)), true, "retreating")
	# Waiting and returning never turn into an unsolicited chase or food trip.
	if member.order == "wait":
		_stop_play("wait")
		return normal
	if is_instance_valid(_enemy) and member.order == "follow":
		_stop_play("danger")
		_food_source = null
		var distance: float = global_position.distance_to(_enemy.global_position)
		if distance <= 1.65 and Steering.clear_sight(self, _enemy):
			if _attack_cooldown <= 0.0:
				if not _winding:
					_winding = true
					_windup = 0.32
				_windup -= delta
				if _windup <= 0.0:
					_enemy.receive_creature_attack(6.0 if personality == "guardian" else 4.0, self)
					_preview.play_part_action("bite")
					audio_event.emit(&"attack")
					_attack_cooldown = 1.6
					_winding = false
			return _choice(global_position, false, "defending")
		_winding = false
		return _choice(_enemy.global_position, true, "assisting" if _assist_seconds > 0.0 else "defending", 1.3)
	_winding = false
	var regroup: Vector3 = target if _play_session == null else controller.player.global_position if member.order == "follow" else controller.home_position()
	if global_position.distance_to(regroup) > (5.0 if _play_session == null else 6.0):
		_stop_play("regroup")
		return normal
	if personality == "scout" and member.order == "follow" and is_instance_valid(_food_source):
		_stop_play("food")
		if _food_notice <= 0.0 and controller.player.has_method("show_gameplay_message"):
			controller.player.show_gameplay_message(Text.text("LIVING_FOUND_FOOD"))
			_food_notice = 20.0
		return _choice(_food_source.global_position, true, "scouting", 2.0)
	if _play_session == null and _play_cooldown <= 0.0 and play_available():
		for other: Node in controller.actors.values():
			if other == self or not is_instance_valid(other) or not other.play_available() or other._play_session != null or other._play_cooldown > 0.0: continue
			if global_position.distance_to(other.global_position) > 6.0 or not Steering.clear_sight(self, other): continue
			var session := Play.new()
			session.configure(self, other, 2.4)
			_play_session = session
			other._play_session = session
			break
	if _play_session != null:
		_play_session.advance(self, delta, Engine.get_physics_frames())
		if _play_session != null:
			var heading: Vector3 = _play_session.heading(self)
			return _choice(global_position + heading * 2.0, heading != Vector3.ZERO, "play_" + _play_session.stage, 0.15)
	if member.order == "home" and global_position.distance_to(controller.home_position()) < 6.0:
		var angle: float = float(posmod(individual_seed, 31)) + floorf(_clock / 7.0) * 1.2
		return _choice(Space.offset(self, controller.home_position(), Vector3(cos(angle), 0, sin(angle)) * 3.0), true, "patrolling")
	return normal

func _choice(target: Vector3, move: bool, activity: String, stop: float = 1.1) -> Dictionary:
	return {"target": target, "move": move, "idle": activity, "moving": activity, "stop_distance": stop,
		"speed": 1.5 if activity.begins_with("play_") else move_speed}

func _sense_party(order: String) -> void:
	# Reuse the bounded voice registry through its public attachment port.
	var voices: Node = get_node("/root/AudioManager").creatures
	if is_instance_valid(voices) and voices.audible(self): voices.attach(self, true)
	var previous: Node3D = _enemy
	_enemy = null
	_food_source = null
	if order != "follow": return
	var assist: Node3D = _assist.get_ref() if _assist != null and _assist_seconds > 0.0 else null
	var best: float = 10.0
	for other: Node in get_tree().get_nodes_in_group(&"wildlife"):
		if not is_instance_valid(other) or other.is_queued_for_deletion() or other.is_dead or not other.has_method("receive_creature_attack"): continue
		if other.get_node("SocialBehavior").entry().get("relation") == "ally": continue
		if other.global_position.distance_to(controller.player.global_position) > 12.0: continue
		var distance: float = global_position.distance_to(other.global_position)
		if distance > best or not Steering.clear_sight(self, other): continue
		if other != assist and (not other.has_method("threatens_party") or not other.threatens_party(controller.player, controller.actors.values())): continue
		_enemy = other
		best = distance
	if _enemy != previous: _winding = false
	if is_instance_valid(_enemy) or personality != "scout" or float(controller.player.get("current_hunger")) >= 65.0: return
	for food: Node3D in get_tree().get_nodes_in_group(&"wildlife_plant_food"):
		if not food.has_food_available() or food.global_position.distance_to(controller.player.global_position) > 7.0: continue
		if not Steering.clear_sight(self, food): continue
		_food_source = food
		break

func _player_attacked(target: Node, _damage: float) -> void:
	if not controller.is_active() or controller.member_record(member_id).order != "follow": return
	if not is_instance_valid(target) or not target.is_in_group(&"wildlife"): return
	_assist = weakref(target)
	_assist_seconds = 6.0
	_scan = 0.0

func receive_creature_attack(damage: float, _attacker: Node = null) -> void:
	receive_damage(damage)

func receive_damage(damage: float) -> void:
	if not is_finite(damage) or damage <= 0.0 or not controller.is_active() or get_node("/root/GameState").simulation_delta(1.0) <= 0.0: return
	current_health = maxf(0.0, current_health - damage)
	controller.member_record(member_id).health = current_health
	_recovering = current_health <= 30.0
	_quiet = 0.0
	_stop_play("hurt")
	get_node("ExpressionBehavior").react("hurt")

func is_combat_target() -> bool:
	return current_health > 0.0 and controller.is_active()

func play_available() -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not is_physics_processing() or not visible or _recovering or current_health < 70.0: return false
	if not controller.is_active() or is_instance_valid(_enemy) or is_instance_valid(_food_source): return false
	var member: Dictionary = controller.member_record(member_id)
	if member.is_empty() or member.order == "wait": return false
	var anchor: Vector3 = controller.player.global_position if member.order == "follow" else controller.home_position()
	return global_position.distance_to(anchor) < 6.0

func _stop_play(reason: String) -> void:
	if _play_session != null: _play_session.cancel(reason)

func play_session_ended(session: RefCounted, reason: String) -> void:
	if session != _play_session: return
	_play_session = null
	_play_last_reason = reason
	_play_cooldown = 12.0 + float(posmod(individual_seed, 9))

func _face(other: Node3D, delta: float) -> void:
	if not is_instance_valid(other): return
	var local: Vector3 = global_basis.inverse() * (other.global_position - global_position)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-local.x, -local.z), minf(delta * 7.0, 1.0))

func get_expression_context() -> Dictionary:
	return {"active": controller.is_active() and visible, "dead": false, "health": current_health / maximum_health,
		"intent": status_code if status_code.begins_with("play_") else "flee" if _recovering else "alert" if is_instance_valid(_enemy) else "rest",
		"friendly_near": not is_instance_valid(_enemy), "sated": true}

func _set_status(code: String) -> void:
	if ACTIVITY_KEYS.has(code):
		status_code = code
		status = Text.text(ACTIVITY_KEYS[code])
	else:
		super._set_status(code)

func _exit_tree() -> void:
	_stop_play("removed")
	if is_instance_valid(controller) and is_instance_valid(controller.player) and controller.player.has_signal("creature_attacked") and controller.player.creature_attacked.is_connected(_player_attacked):
		controller.player.creature_attacked.disconnect(_player_attacked)
