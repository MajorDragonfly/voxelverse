extends Node

const FRIEND_RANGE: float = 6.0
const TRUST_PER_SECOND: float = 12.5
const HELP_COST: float = 12.0
const HELP_HEALTH: float = 0.30
const Space = preload("res://world/surface/gameplay_space.gd")

var creature: CharacterBody3D
var attention_remaining: float = 0.0
var help_cooldown: float = 0.0


func _ready() -> void:
	creature = get_parent()
	_restore()
	get_node("/root/SaveGameService").game_loaded.connect(func(_path: String) -> void: _restore())


func _process(delta: float) -> void:
	attention_remaining = maxf(attention_remaining - delta, 0.0)
	help_cooldown = maxf(help_cooldown - delta, 0.0)


func entry() -> Dictionary:
	return get_node("/root/ProgressionService").get_creature_encounter(
		creature.get_campaign_identity(), creature.ecological_role, creature.individual_seed)


func _restore() -> void:
	var data: Dictionary = entry()
	creature.current_health = creature.maximum_health * float(data["health_ratio"])
	creature.is_dead = data["dead"]
	creature.carcass_food_remaining = data["carcass_food"]
	attention_remaining = 0.0
	creature._threat_timer = 0.0
	if creature.is_dead:
		creature.velocity = Vector3.ZERO


func can_reach(actor: Node, reach: float = FRIEND_RANGE) -> bool:
	if not actor is Node3D or not actor.is_in_group(&"player") or actor.is_dead or creature.is_dead:
		return false
	if get_tree().paused or not actor.is_physics_processing() or get_node("/root/GameState").current_phase != 0:
		return false
	if actor.global_position.distance_to(creature.global_position) > reach:
		return false
	if not actor.has_method("_has_clear_line_of_sight"):
		return false
	return actor._has_clear_line_of_sight(creature, actor.global_position + Space.up(actor, actor.global_position) * 0.7,
		creature.global_position + Space.up(creature, creature.global_position) * 0.7)


func befriend(actor: Node, delta: float) -> Dictionary:
	if not can_reach(actor) or not is_finite(delta) or delta <= 0.0 or delta > 0.25:
		return _failure("Komm näher und halte Sichtkontakt.")
	var data: Dictionary = entry()
	if data["relation"] == "ally":
		return _failure("Diese Kreatur ist bereits mit dir befreundet.")
	if data["relation"] == "hostile" or data["player_harmed"] or creature._threat_timer > 0.0:
		return _failure("Diese Kreatur fühlt sich bedroht und lässt sich nicht befreunden.")
	attention_remaining = 0.4
	var multiplier: float = actor.get_behavior_multiplier("befriend_efficiency")
	data["trust"] = minf(float(data["trust"]) + delta * TRUST_PER_SECOND * multiplier, 100.0)
	var completed: bool = float(data["trust"]) >= 100.0
	var context := {"target_relation": data["relation"]}
	if completed:
		data["relation"] = "ally"
	var result: Dictionary = get_node("/root/ProgressionService").store_creature_encounter(
		data, completed, "befriended" if completed else "", context)
	if not result["ok"]:
		return _failure("Speichern fehlgeschlagen. Befreunden kann erneut versucht werden.")
	if completed:
		creature._threat_timer = 0.0
		creature.audio_event.emit(&"friend")
		actor.show_gameplay_message("Befreundet · Beziehung gespeichert.")
	return {"ok": true, "completed": completed, "trust": data["trust"], "multiplier": multiplier}


func help(actor: Node) -> Dictionary:
	if not can_reach(actor, 3.6):
		return _failure("Zum Helfen näher herangehen und Sichtkontakt halten.")
	var data: Dictionary = entry()
	if help_cooldown > 0.0:
		return _failure("Einen Moment warten.")
	if data["relation"] == "hostile" or data["player_harmed"]:
		return _failure("Selbst verursachte Not bringt keine Hilfe-Belohnung.")
	if float(data["health_ratio"]) >= 1.0 or data["need_origin"] not in ["environment", "third_party"]:
		return _failure("Diese Kreatur benötigt gerade keine Hilfe.")
	if actor.current_hunger < HELP_COST + 10.0:
		return _failure("Zum Teilen brauchst du mindestens 22 Sättigung.")
	var multiplier: float = actor.get_behavior_multiplier("ally_support_efficiency") if data["relation"] == "ally" else 1.0
	data["health_ratio"] = minf(float(data["health_ratio"]) + HELP_HEALTH * multiplier, 1.0)
	var context := {"target_relation": data["relation"], "need_origin": data["need_origin"]}
	var completed: bool = float(data["health_ratio"]) >= 1.0
	if completed:
		data["need_origin"] = "none"
	var before_hunger: float = actor.current_hunger
	actor.current_hunger -= HELP_COST
	var result: Dictionary = get_node("/root/ProgressionService").store_creature_encounter(
		data, true, "helped" if completed else "", context)
	if not result["ok"]:
		actor.current_hunger = before_hunger
		return _failure("Speichern fehlgeschlagen. Deine Sättigung wurde zurückgegeben.")
	creature.current_health = creature.maximum_health * float(data["health_ratio"])
	help_cooldown = 0.8
	attention_remaining = 1.2
	actor._update_hud()
	actor.show_gameplay_message("Versorgt · %d %% Gesundheit · −12 Sättigung%s" % [roundi(float(data["health_ratio"]) * 100.0), " · Hilfe abgeschlossen" if completed else ""])
	return {"ok": true, "completed": completed, "health_ratio": data["health_ratio"]}


## The first attack freezes its cause. Betrayal can never become a rewarded hunt.
func receive_player_attack(damage: float, actor: Node) -> bool:
	if not can_reach(actor, actor.bite_reach + 0.35) or not is_finite(damage) or damage <= 0.0:
		return false
	var data: Dictionary = entry()
	if str(data["conflict_relation"]).is_empty():
		if data["relation"] == "hostile":
			data["conflict_relation"] = "hostile"
			data["conflict_reason"] = "self_defense"
		elif data["relation"] == "wild" and actor.get_diet_affinity("meat") > 0.05:
			data["conflict_relation"] = "prey"
			data["conflict_reason"] = "hunt"
		else:
			data["conflict_relation"] = data["relation"]
			data["conflict_reason"] = "unprovoked"
	data["player_harmed"] = true
	data["need_origin"] = "player"
	data["relation"] = "hostile"
	data["trust"] = 0.0
	data["health_ratio"] = maxf(float(data["health_ratio"]) - damage / creature.maximum_health, 0.0)
	data["dead"] = float(data["health_ratio"]) == 0.0
	if data["dead"]:
		data["carcass_food"] = clampf(creature.maximum_health * 0.55, 20.0, 90.0)
	var result: Dictionary = get_node("/root/ProgressionService").store_creature_encounter(data, true,
		"won" if data["dead"] else "", {"target_relation": data["conflict_relation"], "conflict_reason": data["conflict_reason"]})
	if not result["ok"]:
		actor.show_gameplay_message("Treffer nicht gespeichert. Angriff wurde zurückgenommen.")
		return false
	creature.current_health = creature.maximum_health * float(data["health_ratio"])
	creature._threat = actor
	creature._threat_timer = creature.threat_memory_seconds
	attention_remaining = 0.0
	if data["dead"]:
		creature._die(actor)
		get_node("/root/SaveGameService").schedule_autosave(0.1)
	else:
		actor.show_gameplay_message("Treffer · %.1f Schaden · %d/%d Gesundheit" % [damage, roundi(creature.current_health), roundi(creature.maximum_health)])
	if creature.has_method("show_behavior_hit"):
		creature.show_behavior_hit()
	return true


func controls_movement() -> bool:
	if get_node("/root/GameState").current_phase != 0:
		return false
	if attention_remaining > 0.0:
		creature._wander_direction = Vector3.ZERO
		return true
	if entry()["relation"] != "ally":
		return false
	if creature._threat_timer > 0.0 and is_instance_valid(creature._threat) and not creature._threat.is_in_group(&"player"):
		return false
	# Friends keep their natural wandering but no longer flee/attack the player.
	# Nest membership and companion commands belong to the separate group workstream.
	return true


func record_external_damage(attacker: Node) -> void:
	if get_node("/root/GameState").current_phase == 1:
		get_node("/root/ProgressionService").store_fauna_health(
			creature.get_campaign_identity()["object_id"], creature.get_health_ratio(), creature.is_dead, creature.carcass_food_remaining)
		return
	if get_node("/root/GameState").current_phase != 0:
		return
	var data: Dictionary = entry()
	data["health_ratio"] = creature.get_health_ratio()
	data["dead"] = creature.is_dead
	data["carcass_food"] = creature.carcass_food_remaining
	# Unknown causes do not manufacture a help reward. A future ecology producer
	# supplies its real wildlife attacker through the existing combat interface.
	if not data["player_harmed"]:
		data["need_origin"] = "third_party" if is_instance_valid(attacker) and attacker.is_in_group(&"wildlife") else "none"
	get_node("/root/ProgressionService").store_creature_encounter(data)


func store_carcass() -> bool:
	var data: Dictionary = entry()
	data["carcass_food"] = creature.carcass_food_remaining
	return get_node("/root/ProgressionService").store_creature_encounter(data, true).get("ok", false)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
