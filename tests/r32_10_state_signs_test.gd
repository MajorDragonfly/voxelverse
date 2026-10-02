extends "res://tests/wildlife_ai_test.gd"
## Presentation contract: real runtime actors, controlled state inputs for ranking.
const Cue = preload("res://creatures/behavior/creature_emotion_cue.gd")
const Inspection = preload("res://ui/creature_inspection_hud.gd")
var checks := 0

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	await _frames(3)
	await _ranked_group()
	await _inspection_language()
	_timing()
	scene.queue_free()
	await _frames(3)
	print(JSON.stringify({"test": "r32_10_state_signs", "checks": checks, "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _ranked_group() -> void:
	player.position = Vector3(0, 100.05, 0)
	var animals: Array[CharacterBody3D] = []
	for index in range(6):
		var animal := _animal("grazer", Vector3(index * 0.6, 100.05, 4), 771)
		animal.set_physics_process(false)
		var driver: Node = animal.get_node("ExpressionBehavior")
		driver.set_process(false)
		driver.emotion.state = "curious"
		animal._refresh_label(0.1)
		animals.append(animal)
	_expect(get_nodes_in_group(&"wildlife_emotion_marker").size() == 4, "Group limit must remain four.")
	animals[4]._intent = "alert"
	animals[4]._refresh_label(0.1)
	_expect(animals[4]._label.visible and animals[4]._label.text == "!", "Four curiosity markers suppressed a genuine danger warning.")
	_expect(get_nodes_in_group(&"wildlife_emotion_marker").size() == 4, "Danger bypassed group limit.")
	var attacker := Node3D.new()
	scene.add_child(attacker)
	attacker.position = animals[5].position + Vector3.RIGHT
	animals[5].receive_creature_attack(1.0, attacker)
	animals[5].get_node("ExpressionBehavior")._process(0.1)
	animals[5]._refresh_label(0.1)
	_expect(animals[5]._label.visible and animals[5]._label.text == "✚", "Real damage was suppressed by the group budget.")
	animals[0]._emotion_cue.reset()
	animals[0].get_node("ExpressionBehavior").emotion.state = "playful"
	animals[0]._refresh_label(0.1)
	_expect(animals[4]._label.visible and animals[5]._label.visible, "Social feedback displaced danger or pain.")
	for animal in animals:
		_expect(not animal._label.no_depth_test, "Marker bypasses terrain depth.")
		_expect(animal._label.text in ["?", "!", "!!", "✚", "♥", "♪", ""], "Technical world label returned.")
		animal._refresh_label(3.0)
	_expect(get_nodes_in_group(&"wildlife_emotion_marker").is_empty(), "Held states became permanent signs.")
	for animal in animals: animal.queue_free()
	attacker.queue_free()
	await _frames(3)

func _inspection_language() -> void:
	var hud := Inspection.new()
	player.add_child(hud)
	hud.set_process(false)
	# Isolate the presentation read port, using real actor inspection data.
	hud._player = player
	hud._detail = Label.new()
	hud.add_child(hud._detail)
	for id: String in ["health", "speed", "attack", "defense"]:
		var label := Label.new()
		hud.add_child(label)
		hud._stats[id] = label
	var actor := _animal("grazer", Vector3(0, 100.05, 4), 771)
	actor.set_physics_process(false)
	actor.ai_state = "flee"
	root.get_node("LocaleManager")._apply("en")
	hud._show_target(actor)
	_expect(hud._detail.text.contains("Alive") and not hud._detail.text.contains("LEBEND"), "English inspection retained German life state.")
	_expect(hud._detail.text.contains("Fleeing"), "Targeted behavior cause did not translate.")
	_expect(hud._diet_label(1.0, 0.0) == "Herbivore", "English herbivore text missing.")
	_expect(hud._diet_label(0.0, 1.0) == "Carnivore", "English carnivore text missing.")
	_expect(hud._diet_label(1.0, 1.0) == "Omnivore", "English omnivore text missing.")
	root.get_node("LocaleManager")._apply("de")
	hud._show_target(actor)
	_expect(hud._detail.text.contains("Lebend") and hud._detail.text.contains("Flieht"), "Language switch did not refresh the inspection detail.")
	actor.queue_free()
	hud.queue_free()
	await _frames(3)

func _timing() -> void:
	for state: String in Cue.CUES:
		var cue := Cue.new()
		_expect(not cue.advance(0.01, state).is_empty(), "Missing cue " + state)
		var faded: Dictionary = cue.advance(float(Cue.CUES[state].seconds) - 0.2, state)
		_expect(not faded.is_empty() and faded.alpha < 1.0, "Cue did not fade " + state)
		_expect(cue.advance(1.0, state).is_empty(), "Persistent cue " + state)
	var cue := Cue.new()
	cue.advance(0.1, "hurt")
	var before: float = cue._remaining
	cue.advance(NAN, "angry")
	_expect(cue._remaining == before, "Invalid delta advanced pain.")
	cue.reset()
	_expect(cue.advance(0.1, "calm").is_empty(), "Load retained cue.")

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)
