extends "res://tests/wildlife_ai_test.gd"
## Real scene, collision, needs, save/load and fresh-process checks. No synthetic
## replacement of the production AI or its two-sided cancellation callbacks.
const Emotion = preload("res://creatures/behavior/creature_emotion.gd")
var checks: int = 0
var observations: Dictionary = {}
var state: Node
var saves: Node

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = "user://wildlife_play_test.json"
	state.start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	_build_fixture()
	player.position = Vector3(30, 100.05, 30)
	await _frames(3)
	if "--play-restart" in OS.get_cmdline_user_args():
		_expect(saves.load_now(), "Fresh process could not load actual save")
		var loaded: CharacterBody3D = _animal("grazer", Vector3(0, 100.05, 0), 771)
		_expect(loaded._play_session == null and loaded._play_cooldown >= 5.0, "Restart resumed a stale pair")
		_expect(loaded.get_campaign_identity().object_id == FileAccess.get_file_as_string("user://play_identity.txt"), "Restart changed animal identity")
		_expect(absf(loaded.satiety - 82.0) < 0.01 and absf(loaded.hydration - 83.0) < 0.01, "Restart lost stored needs")
	else:
		await _complete_play()
		await _priorities_and_lifecycle()
		await _visibility_and_selection()
		await _save_restart()
		_expression_and_radial_vectors()
	scene.queue_free()
	await _frames(4)
	print(JSON.stringify({"test": "wildlife_social_play", "passed": failures.is_empty(), "checks": checks, "observations": observations, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _ready_animal(point: Vector3, species: int = 771) -> CharacterBody3D:
	var animal: CharacterBody3D = _animal("grazer", point, species)
	# Some deterministic encounter seeds start injured. This fixture explicitly
	# requires healthy animals; injured refusal has its own case below.
	animal.current_health = animal.maximum_health
	animal.satiety = 90.0
	animal.hydration = 90.0
	animal._needs["satiety"] = 90.0
	animal._needs["seeking"] = false
	animal._drinking["hydration"] = 90.0
	animal._drinking["seeking"] = false
	animal._ambient_heading = Vector3.ZERO
	animal._decision_timer = 1000.0
	animal._play_cooldown = 0.0
	animal._play_search = 0.0
	animal._visual_root.rotation.y = -PI * 0.5 if point.x < 0.0 else PI * 0.5
	return animal

func _new_pair(gap: float = 2.4) -> Array[CharacterBody3D]:
	await _clear_animals()
	var a: CharacterBody3D = _ready_animal(Vector3(-gap * 0.5, 100.05, 0))
	var b: CharacterBody3D = _ready_animal(Vector3(gap * 0.5, 100.05, 0))
	await _frames(4)
	a._sense()
	b._sense()
	_expect(a._play_session != null and a._play_session == b._play_session, "Eligible actors did not form one shared pair: " + JSON.stringify([a.get_ai_debug_state(), b.get_ai_debug_state()]))
	return [a, b]

func _clear_animals() -> void:
	for animal: Node in get_nodes_in_group(&"wildlife"): animal.queue_free()
	await _frames(3)

func _complete_play() -> void:
	var pair: Array[CharacterBody3D] = await _new_pair(5.0)
	var a: CharacterBody3D = pair[0]
	var b: CharacterBody3D = pair[1]
	var initial: float = a.global_position.distance_to(b.global_position)
	var seen: Dictionary = {}
	var closest: float = INF
	var travelled: float = 0.0
	var previous: Vector3 = a.global_position
	var progression: Node = root.get_node("ProgressionService")
	var before: Dictionary = progression.export_state().duplicate(true)
	var snapshots: Array = [a.get_campaign_identity(), b.get_campaign_identity(), a.current_health, b.current_health]
	for tick in range(850):
		await _frames(1)
		closest = minf(closest, a.global_position.distance_to(b.global_position))
		travelled += a.global_position.distance_to(previous)
		previous = a.global_position
		if a._play_session == null: break
		seen[a._play_session.stage] = true
	_expect(seen.has("greet") and seen.has("play") and seen.has("rest"), "Live pair missed greeting/play/rest: " + str(seen))
	_expect(a._play_last_reason == "complete" and b._play_last_reason == "complete", "Pair failed to complete: " + str(a.get_ai_debug_state().play))
	_expect(closest < initial - 1.0 and closest > 1.4 and travelled > 2.0, "Pair did not walk/play with personal space")
	_expect(a.is_on_floor() and b.is_on_floor(), "Play lost ground support")
	_expect(a._play_cooldown > 0.0 and b._play_cooldown > 0.0, "Finished pair can immediately loop")
	_expect(progression.export_state() == before, "Ambient play changed relationship, rewards or discoveries")
	_expect(snapshots == [a.get_campaign_identity(), b.get_campaign_identity(), a.current_health, b.current_health], "Play changed identity/health")
	observations["live_loop"] = {"stages": seen.keys(), "min_gap": closest, "travelled": travelled, "reason": a._play_last_reason}

func _priorities_and_lifecycle() -> void:
	var pair: Array[CharacterBody3D] = await _new_pair()
	var a: CharacterBody3D = pair[0]
	var b: CharacterBody3D = pair[1]
	var session: RefCounted = a._play_session
	var positions: Array[Vector3] = [a.global_position, b.global_position]
	var clock: float = session.elapsed
	paused = true
	await _frames(4)
	_expect(session.elapsed == clock and positions == [a.global_position, b.global_position], "Scene pause advanced play")
	paused = false
	state.set_simulation_speed(0.0)
	await _frames(4)
	_expect(session.elapsed == clock and positions == [a.global_position, b.global_position], "Zero simulation speed advanced play")
	state.set_simulation_speed(1.0)
	await _frames(3)
	_expect(session.elapsed > clock, "Play failed to resume")
	b.get_node("SocialBehavior").attention_remaining = 1.0
	await _frames(2)
	_expect(a._play_session == null and b._play_session == null and b.ai_state == "social", "Player attention failed to release both participants")
	for cause: String in ["hunger", "thirst", "injured", "threat", "death", "phase", "disabled", "queued", "removed", "range", "ground"]:
		pair = await _new_pair()
		a = pair[0]
		b = pair[1]
		var attacker := Node3D.new()
		scene.add_child(attacker)
		attacker.position = b.position + Vector3(0, 0, 1)
		match cause:
			"hunger": b.satiety = 40.0; b._needs["seeking"] = true
			"thirst": b.hydration = 40.0; b._drinking["seeking"] = true
			"injured": b.current_health = b.maximum_health * 0.55
			"threat": b.receive_creature_attack(1.0, attacker)
			"death": b.is_dead = true
			"phase": state.current_phase = 2
			"disabled": b.set_physics_process(false)
			"queued": b.queue_free()
			"removed": scene.remove_child(b)
			"range": b.position.x += 15.0
			"ground": b.position.x = 70.0
		await _frames(3)
		_expect(a._play_session == null, "Pair stayed bound after " + cause)
		if is_instance_valid(b): _expect(b._play_session == null, "Partner stayed bound after " + cause)
		if cause == "threat": _expect(b._intent == "flee", "Play swallowed real danger response")
		if cause == "removed": b.free()
		attacker.queue_free()
		state.current_phase = 0

func _visibility_and_selection() -> void:
	await _clear_animals()
	var wall: StaticBody3D = _box(Vector3(0.25, 4.0, 8.0), Vector3(0, 101.5, 0))
	var a: CharacterBody3D = _ready_animal(Vector3(-2.0, 100.05, 0))
	var b: CharacterBody3D = _ready_animal(Vector3(2.0, 100.05, 0))
	await _frames(4)
	a._sense()
	b._sense()
	_expect(a._play_session == null and b._play_session == null, "Pair formed through real wall")
	wall.queue_free()
	await _frames(3)
	a._play_search = 0.0
	b._campaign_identity["body_id"] = "another-body"
	a._sense()
	_expect(a._play_session == null, "Equal seeds paired across body IDs")
	b._campaign_identity["body_id"] = a._campaign_identity.body_id
	b._campaign_identity["species_id"] = "another-species"
	a._play_search = 0.0
	a._sense()
	_expect(a._play_session == null, "Different species formed play pair")
	b._campaign_identity["species_id"] = a._campaign_identity.species_id
	a._play_search = 0.0
	a._sense()
	b._sense()
	_expect(a._play_session != null, "Eligible pair failed after wall removal: " + JSON.stringify([a.get_ai_debug_state(), b.get_ai_debug_state()]))
	var original: RefCounted = a._play_session
	var c: CharacterBody3D = _ready_animal(Vector3(0, 100.05, -2.0))
	await _frames(3)
	c._sense()
	_expect(c._play_session == null and a._play_session == original and b._play_session == original, "Third actor stole partner")
	wall = _box(Vector3(0.25, 4.0, 8.0), Vector3(0, 101.5, 0))
	await _frames(3)
	a._sense()
	_expect(a._play_session == null and b._play_session == null, "New wall did not cancel both sides")
	wall.queue_free()
	# Repeated references stress the fixed search budget without extra mesh work.
	a._play_cooldown = 0.0
	a._sensed_neighbors.clear()
	for index in range(32): a._sensed_neighbors.append(c)
	a._find_play_partner()
	_expect(a._play_examined <= 8, "Candidate work exceeded eight actors")
	await _clear_animals()

func _save_restart() -> void:
	# The first actor must get exactly the same saved identity in a fresh process.
	serial = 100
	var pair: Array[CharacterBody3D] = await _new_pair()
	var a: CharacterBody3D = pair[0]
	var b: CharacterBody3D = pair[1]
	a.satiety = 82.0
	a._needs["satiety"] = 82.0
	a.hydration = 83.0
	a._drinking["hydration"] = 83.0
	var file := FileAccess.open("user://play_identity.txt", FileAccess.WRITE)
	file.store_string(a.get_campaign_identity().object_id)
	file.close()
	_expect(saves.save_now(), "Save during a real shared session failed")
	_expect(saves.load_now(), "Load during play failed")
	_expect(a._play_session == null and b._play_session == null, "Load retained actor pair references")
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/wildlife_social_play_test.gd", "--", "--play-restart"], output, true)
	_expect(code == 0 and "".join(output).contains('"passed":true'), "Fresh process failed: " + str(output))
	observations["restart_exit"] = code
	await _clear_animals()

func _expression_and_radial_vectors() -> void:
	var emotion := Emotion.new()
	emotion.configure(1)
	for intent: String in {"play_approach": "curious", "play_greet": "affectionate", "play_play": "playful", "play_rest": "content"}:
		emotion.advance(0.2, {"intent": intent})
		_expect(emotion.state == {"play_approach": "curious", "play_greet": "affectionate", "play_play": "playful", "play_rest": "content"}[intent], "Missing play expression " + intent)
	emotion.advance(0.2, {"intent": "play_play", "threat": true})
	_expect(emotion.state == "afraid", "Positive pair pose swallowed danger")
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in ["WILDLIFE_PLAY_APPROACH", "WILDLIFE_PLAY_GREET", "WILDLIFE_PLAY_ACTIVE", "WILDLIFE_PLAY_REST"]:
			_expect(str(TranslationServer.translate(key)) != key, "Missing " + locale + " translation: " + key)
	# Actual session heading against rotated actors (no global-Y assumptions).
	var a: CharacterBody3D = _ready_animal(Vector3(-1.2, 100.05, 0))
	var b: CharacterBody3D = _ready_animal(Vector3(1.2, 100.05, 0))
	var session := preload("res://creatures/ai/wildlife_play_session.gd").new()
	session.configure(a, b, 2.4)
	session.stage = "play"
	session.stage_elapsed = 0.4
	var heading: Vector3 = session.heading(a)
	var rotation := Basis(Vector3(1, 2, 3).normalized(), 1.7)
	a.global_position = rotation * a.global_position
	b.global_position = rotation * b.global_position
	a.up_direction = rotation * Vector3.UP
	b.up_direction = a.up_direction
	_expect(session.heading(a).distance_to(rotation * heading) < 0.0001, "Play direction changes under radial rotation")
	var shift := Vector3(300, -125, 817)
	a.global_position += shift
	b.global_position += shift
	_expect(session.heading(a).distance_to(rotation * heading) < 0.0001, "Origin rebase changed live relative play direction")
	for hz: int in [30, 60, 120]:
		session.stage = "greet"
		session.reason = ""
		session.elapsed = 0.0
		session.stage_elapsed = 0.0
		session._last_frame = -1
		for frame in range(hz):
			session.advance(a, 1.0 / hz, frame)
			session.advance(b, 1.0 / hz, frame)
			session.advance(a, 1.0 / hz, frame)
		_expect(absf(session.elapsed - 1.0) < 0.0001, "Shared session advanced twice at " + str(hz))
	a.queue_free()
	b.queue_free()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)
