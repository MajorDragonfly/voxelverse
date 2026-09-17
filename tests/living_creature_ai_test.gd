extends "res://tests/wildlife_ai_test.gd"

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	player.position = Vector3(1.25, 100.05, 0)
	var predator: CharacterBody3D = _animal("predator", Vector3(0, 100.05, 0), 411)
	predator._ambient_heading = Vector3.ZERO
	predator._decision_timer = 100.0
	predator.maximum_chase_seconds = 2.0
	await _frames(55)
	_expect(player.health == 100.0, "Warning/wind-up caused instant damage")
	await _frames(42)
	_expect(player.health < 100.0, "Wind-up did not land a real bite")
	var first_health: float = player.health
	await _frames(200)
	_expect(player.health < first_health and predator._intent == "chase", "Connected melee randomly abandoned the player at the pursuit timeout")
	# The same intent cannot damage a target through newly inserted cover.
	predator._attack_timer = 0.0
	predator._try_predator_attack(player)
	var cover: StaticBody3D = _box(Vector3(0.15, 4, 8), Vector3(0.65, 101.8, 0))
	var protected_health: float = player.health
	await _frames(35)
	_expect(player.health == protected_health and predator._bite_target == null, "Bite was not cancelled after losing visibility")
	cover.queue_free()
	player.position = Vector3(30, 100.05, 30)
	await _frames(220)
	_expect(predator._intent not in ["alert", "chase", "search"], "Lost target caused an endless pursuit")
	predator.queue_free()
	await _frames(4)
	var first: CharacterBody3D = _animal("grazer", Vector3(-2, 100.05, 0), 711)
	var second: CharacterBody3D = _animal("grazer", Vector3(2, 100.05, 0), 711)
	var outsider: CharacterBody3D = _animal("grazer", Vector3(5, 100.05, 0), 711)
	first.colony_id = "nest:a"
	second.colony_id = "nest:a"
	outsider.colony_id = "nest:b"
	await _frames(15)
	# The observer is far away: nearby relatives react to the alarm itself.
	first._threat = player
	first._threat_timer = 5.0
	first._last_seen = player.global_position
	first._memory = 3.0
	first._alarm_attacker = 0
	first._call_nest(player)
	_expect(second._memory > 0.0 and second._intent == "flee", "Nestmate ignored an accepted alarm")
	_expect(outsider._memory == 0.0, "Alarm crossed nest boundaries")
	var before: Vector3 = second._last_seen
	player.position += Vector3(5, 0, 0)
	_expect(second._last_seen == before, "Pack alarm tracked an unseen attacker")
	var memory: float = second._memory
	paused = true
	await _frames(10)
	_expect(second._memory == memory, "Pause advanced alarm memory")
	paused = false
	scene.queue_free()
	await _frames(4)
	print(JSON.stringify({"test": "living_creature_ai", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
