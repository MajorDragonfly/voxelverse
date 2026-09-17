extends "res://creatures/ai/social_play_brain.gd"
## Encounter continuity above the existing needs, social and navigation layers.
## Bites have a cancellable wind-up; nest alarms never grant player rewards.
const WINDUP_SECONDS: float = 0.32
const ALARM_RANGE: float = 11.0
var colony_id: String = ""
var _bite_target: WeakRef
var _windup: float = 0.0
var _alarm_cooldown: float = 0.0
var _alarm_attacker: int = 0
var _recovering: bool = false
var _recovery_tick: float = 0.0

func _physics_process(delta: float) -> void:
	var dt: float = GameState.simulation_delta(delta)
	if get_tree().paused or dt <= 0.0: return
	_alarm_cooldown = maxf(0.0, _alarm_cooldown - dt)
	super._physics_process(delta)
	if _threat_timer <= 0.0 and _memory <= 0.0: _alarm_attacker = 0
	# Player combat can enter through SocialBehavior directly, so observe the
	# accepted threat here as well as the ordinary creature-damage interface.
	if _threat_timer > 0.0 and is_instance_valid(_threat): _call_nest(_threat)
	if _bite_target != null:
		var target: Node3D = _bite_target.get_ref()
		if not _can_bite(target):
			_cancel_bite()
		else:
			_windup -= dt
			if _windup <= 0.0:
				_cancel_bite()
				_attack_timer = predator_attack_cooldown
				if target.has_method("receive_creature_attack"):
					target.receive_creature_attack(predator_attack_damage, self)
				elif target.has_method("receive_damage"):
					target.receive_damage(predator_attack_damage)
				if is_instance_valid(_preview): _preview.play_part_action("bite")
	if _recovering and not is_dead and _flat_distance(global_position, _anchor) < 2.5:
		_recovery_tick += dt
		if _recovery_tick >= 0.5:
			var encounter: Dictionary = get_node("SocialBehavior").entry()
			if not encounter.is_empty() and GameState.current_phase == 0:
				encounter.health_ratio = minf(1.0, get_health_ratio() + 0.75 / maximum_health)
				if get_node("/root/ProgressionService").store_creature_encounter(encounter).get("ok", false):
					current_health = maximum_health * float(encounter.health_ratio)
			_recovery_tick = 0.0
		if get_health_ratio() >= 0.60:
			_recovering = false
			_cooldown = 5.0
	if _intent == "alert" or _bite_target != null:
		var facing: Vector3 = global_basis.inverse() * (_last_seen - global_position)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-facing.x, -facing.z), minf(dt * 7.0, 1.0))

func _sense() -> void:
	if is_instance_valid(_target) and _target.has_method("is_combat_target") and not _target.is_combat_target():
		if _threat == _target:
			_threat = null
			_threat_timer = 0.0
		_target = null
		_memory = 0.0
		_chase_time = 0.0
	# A connected melee is not abandoned because the approach timer expired.
	# A fleeing/occluded target still has the original finite pursuit budget.
	if _intent == "chase" and _can_bite(_target): _chase_time = 0.0
	super._sense()
	if is_dead: return
	if get_health_ratio() <= 0.30 and _memory > 0.0: _recovering = true
	if _recovering:
		_stop_play("injured")
		if _memory <= 0.0:
			_begin_return()
			if _flat_distance(global_position, _anchor) < 2.5:
				_returning = false
				_intent = "rest"
	# Alarm information is a last-seen position, not omniscient tracking.
	if _threat_timer > 0.0 and is_instance_valid(_threat): _call_nest(_threat)

func _try_predator_attack(target: Node) -> void:
	if _attack_timer > 0.0 or _bite_target != null or not _can_bite(target): return
	_bite_target = weakref(target)
	_windup = WINDUP_SECONDS
	react_expression("warn")

func _can_bite(target: Node) -> bool:
	if not is_instance_valid(target) or not target is Node3D or not target.is_inside_tree() or target.is_queued_for_deletion(): return false
	if is_dead or bool(target.get("is_dead")) or _intent != "chase" or _warning > 0.0 or _recovering: return false
	if target.has_method("is_combat_target") and not target.is_combat_target(): return false
	var social: Node = get_node("SocialBehavior")
	if float(social.get("attention_remaining")) > 0.0: return false
	if target.is_in_group(&"player") and social.entry().get("relation") == "ally": return false
	if GameState.current_phase != 0 or (_ignore_player and target.is_in_group(&"player")): return false
	return global_position.distance_to(target.global_position) <= predator_attack_distance and Steering.clear_sight(self, target)

func _cancel_bite() -> void:
	_bite_target = null
	_windup = 0.0

func _desired_heading() -> Vector3:
	# Plant feet while preparing the bite; stepping away cancels it.
	if _bite_target != null: return Vector3.ZERO
	return super._desired_heading()

func _call_nest(attacker: Node3D) -> void:
	if colony_id.is_empty() or _alarm_cooldown > 0.0 or not is_instance_valid(attacker): return
	if _alarm_attacker == attacker.get_instance_id(): return
	_alarm_attacker = attacker.get_instance_id()
	_alarm_cooldown = 6.0
	for other: Node3D in _sensed_neighbors:
		if not is_instance_valid(other) or not other.has_method("receive_nest_alarm"): continue
		if global_position.distance_to(other.global_position) > ALARM_RANGE or not Steering.clear_sight(self, other): continue
		other.receive_nest_alarm(self, attacker)

func receive_nest_alarm(caller: Node3D, attacker: Node3D) -> void:
	if is_dead or colony_id.is_empty() or caller.colony_id != colony_id or _recovering: return
	if not is_instance_valid(attacker) or bool(attacker.get("is_dead")): return
	if get_node("SocialBehavior").entry().get("relation") == "ally" and attacker.is_in_group(&"player"): return
	if _memory > 0.0: return
	_stop_play("alarm")
	_target = attacker
	_last_seen = caller._last_seen if caller._memory > 0.0 else attacker.global_position
	_memory = 3.5
	_warning = warning_seconds
	_chase_time = 0.0
	_intent = "alert" if ecological_role == "predator" else "flee"
	_sense_remaining = SENSE_INTERVAL
	_steer_remaining = 0.0
	audio_event.emit(&"warn")

func threatens_party(player_actor: Node3D, companions: Array) -> bool:
	if is_dead or _intent != "chase" or not is_instance_valid(_target): return false
	return _target == player_actor or _target in companions

func _refresh_label() -> void:
	super._refresh_label()
	if is_instance_valid(_label) and _bite_target != null:
		_label.text = PlayText.text("LIVING_WINDUP")
	elif is_instance_valid(_label) and _recovering:
		_label.text = PlayText.text("LIVING_RETREAT")

func get_ai_debug_state() -> Dictionary:
	var data: Dictionary = super.get_ai_debug_state()
	data["colony_id"] = colony_id
	data["windup"] = _windup
	data["recovering"] = _recovering
	return data
