extends SceneTree

const State = preload("res://creatures/ai/drinking_state.gd")
const BodyState = preload("res://world/resources/plants/foraging_state.gd")
const Shore = preload("res://creatures/ai/shore_water_search.gd")
const SAVE: String = "user://wildlife_drinking_test.json"

class WaterProvider:
	extends Node
	var enabled: bool = true
	var kind: String = "lake"
	var level: float = 100.0
	func get_water_info(x: float, _z: float) -> Dictionary:
		return {"kind": kind, "distance": 6.0 - x} if enabled and x > 6.0 else {}
	func get_water_level(_x: float, _z: float) -> float:
		return level
	func get_terrain_height(x: float, _z: float) -> float:
		return 98.0 if x > 6.0 else 100.5

class Observer:
	extends CharacterBody3D
	var is_dead: bool = true
	func receive_damage(_amount: float) -> void:
		pass

class SocialContract:
	extends Node
	var attention_remaining: float = 10.0
	func controls_movement() -> bool:
		return attention_remaining > 0.0
	func entry() -> Dictionary:
		return {"relation": "ally"}

var failures: Array[String] = []
var scene: Node3D
var player: Observer
var provider: WaterProvider
var bed: StaticBody3D
var state: Node
var saves: Node
var wildlife: PackedScene
var captures: String = ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = SAVE
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--restart-check" in args:
		_expect(saves.load_now(), "Fresh process could not restore drinking state.")
		var body: Dictionary = BodyState.body(state)
		var records: Dictionary = body.get("wildlife_drinking", {}).get("animals", {})
		_expect(records.size() == 1, "Fresh process lost individual hydration.")
		if records.size() == 1:
			_expect(float(records.values()[0]["hydration"]) >= 80.0 and not records.values()[0]["seeking"], "Fresh process reset thirst or drinking need.")
		_finish()
		return
	state.start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	_build_fixture()
	await _frames(5)
	# JSON persistence normalizes integer metadata to floats; compare the same
	# representation on both sides while still checking every progression field.
	var progression: Dictionary = JSON.parse_string(JSON.stringify(root.get_node("ProgressionService").export_state()))
	await _drink_and_save(args)
	await _shore_safety()
	await _interruptions_and_priorities()
	await _roles_and_clock()
	_expect(JSON.parse_string(JSON.stringify(root.get_node("ProgressionService").export_state())) == progression, "Ambient drinking changed player progression or relationships.")
	_check_state_contract()
	scene.queue_free()
	await _frames(4)
	_finish()

func _drink_and_save(args: PackedStringArray) -> void:
	var animal: CharacterBody3D = _animal(Vector3(0, 100.55, 0), 710)
	_thirsty(animal, 60.0)
	var started: bool = false
	var drank: bool = false
	for frame in range(500):
		await _frames(1)
		if animal.ai_state == "seek_water" and not started:
			started = true
			await _capture("01_water_search")
		if animal.ai_state == "drink":
			drank = true
			await _capture("02_drinking")
			break
	_expect(started and drank and animal.position.x > 1.5, "Thirsty animal did not physically seek/reach a shore: " + str(animal.get_ai_debug_state()))
	await _frames(150)
	_expect(animal.hydration >= 80.0 and not animal._drinking["seeking"] and animal.ai_state == "rest", "Animal failed to stop drinking and rest.")
	_expect(animal.position.x < 6.0 and animal.is_on_floor(), "Drinking led the animal into the water.")
	animal.set_physics_process(false)
	var saved: float = animal.hydration
	var identity: String = animal.get_campaign_identity()["object_id"]
	_expect(saves.save_now(), "Normal campaign save failed.")
	var restart: PackedStringArray = ["--headless"]
	if "--restart-pack" in args:
		restart.append_array(["--main-pack", args[args.find("--restart-pack") + 1]])
	else:
		restart.append_array(["--path", ProjectSettings.globalize_path("res://")])
	restart.append_array(["--script", get_script().resource_path, "--", "--restart-check"])
	var output: Array = []
	_expect(OS.execute(OS.get_executable_path(), restart, output, true) == 0, "Separate-process load failed: " + str(output))
	_thirsty(animal, 1.0)
	_expect(saves.load_now() and is_equal_approx(animal.hydration, saved), "Live actor overwrote hydration restored from disk.")
	_expect(animal._water_source.is_empty(), "Loading retained an unverified shore target.")
	animal.queue_free()
	await _frames(4)
	animal = _animal(Vector3(0, 100.55, 0), 710)
	animal.set_physics_process(false)
	_expect(animal.get_campaign_identity()["object_id"] == identity and is_equal_approx(animal.hydration, saved), "Reinstantiating the same individual reset hydration.")
	animal.queue_free()
	await _frames(4)

func _shore_safety() -> void:
	var animal: CharacterBody3D = _animal(Vector3(4.5, 100.55, 0), 711)
	animal.set_physics_process(false)
	var source: Dictionary = {"water": Vector3(7, 100, 0), "bank": Vector3(5, 100.5, 0), "kind": "lake", "key": "7:0"}
	await _frames(3)
	_expect(Shore.can_drink(animal, provider, source), "Valid dry shore was rejected.")
	provider.kind = "ocean"
	_expect(not Shore.can_drink(animal, provider, source), "Ocean was accepted as inland drinking water.")
	provider.kind = "river"
	_expect(Shore.can_drink(animal, provider, source), "River provider was rejected.")
	provider.enabled = false
	_expect(not Shore.can_drink(animal, provider, source), "Disappeared water still restored hydration.")
	provider.enabled = true
	provider.level = 99.0
	_expect(not Shore.valid_source(animal, provider, source), "Changed water level retained a stale shore target.")
	provider.level = 100.0
	var wall: StaticBody3D = _box(Vector3(0.15, 4, 8), Vector3(5.5, 102, 0))
	await _frames(3)
	_expect(not Shore.can_drink(animal, provider, source), "Animal drank through a wall.")
	wall.queue_free()
	await _frames(3)
	animal.position = Vector3(0, 100.55, 0)
	_expect(not Shore.can_drink(animal, provider, source), "Distant animal drank remotely.")
	animal.position = Vector3(4.5, 101.7, 0)
	_expect(not Shore.can_drink(animal, provider, source), "High ledge allowed remote drinking.")
	animal.position = Vector3(4.5, 100.95, 0)
	_expect(not Shore.can_drink(animal, provider, source), "Airborne animal drank without ground contact.")
	animal.position = Vector3(7.0, 98.05, 0)
	_expect(not Shore.can_drink(animal, provider, source), "Submerged animal counted as standing on a safe shore.")
	animal.position = Vector3(4.5, 100.55, 0)
	bed.get_node("CollisionShape3D").disabled = true
	await _frames(3)
	_expect(not Shore.can_drink(animal, provider, source), "Unloaded water bed remained usable.")
	bed.get_node("CollisionShape3D").disabled = false
	await _frames(3)
	animal.queue_free()
	await _frames(3)

func _interruptions_and_priorities() -> void:
	var animal: CharacterBody3D = _animal(Vector3(4.5, 100.55, -10), 712)
	_thirsty(animal, 40.0)
	await _frames(20)
	var before: float = animal.hydration
	var social := SocialContract.new()
	social.name = "SocialBehavior"
	animal.add_child(social)
	await _frames(65)
	_expect(animal.ai_state == "social" and animal.hydration < before, "Social attention did not interrupt drinking.")
	social.queue_free()
	player.is_dead = false
	player.position = animal.position + Vector3(-1.1, 0, 0)
	before = animal.hydration
	await _frames(35)
	_expect(animal.get_ai_debug_state()["intent"] == "flee" and animal.hydration < before, "Danger did not interrupt water-seeking/drinking.")
	player.is_dead = true
	player.position = Vector3(15, 100.55, 15)
	animal.queue_free()
	await _frames(4)
	animal = _animal(Vector3(3, 100.55, -10), 713)
	var bush: Node3D = load("res://world/resources/plants/berry_bush.tscn").instantiate()
	bush.snap_to_terrain = false
	scene.add_child(bush)
	bush.position = Vector3(1.3, 100.5, -10)
	animal.satiety = 20.0
	animal._needs["satiety"] = 20.0
	animal._needs["seeking"] = true
	_thirsty(animal, 55.0)
	await _frames(65)
	_expect(bush.get_food_remaining() < 30.0 and animal._water_source.is_empty(), "More urgent hunger did not win before a water trip.")
	_thirsty(animal, 20.0)
	var chose_water: bool = false
	for frame in range(200):
		await _frames(1)
		if animal.ai_state in ["seek_water", "drink"]:
			chose_water = true
			break
	_expect(chose_water, "Critical thirst never took priority over a meal.")
	animal.queue_free()
	bush.queue_free()
	await _frames(4)
	# No inland water: keep the existing food/herd behavior and bounded retries.
	provider.enabled = false
	animal = _animal(Vector3(0, 100.55, 0), 714)
	_thirsty(animal, 20.0)
	await _frames(300)
	_expect(animal.ai_state in ["rest", "wander", "herd"] and animal._water_source.is_empty() and animal.hydration < 20.0, "Missing water trapped the animal or gave free hydration.")
	animal.queue_free()
	provider.enabled = true
	await _frames(4)
	# A low enclosing barrier allows sight over it, but exceeds this grazer's
	# step height. The candidate must be abandoned instead of chasing forever.
	animal = _animal(Vector3(0, 100.55, 0), 715)
	_thirsty(animal, 20.0)
	var fences: Array[Node3D] = []
	for x in [-1.0, 1.0]:
		fences.append(_box(Vector3(0.15, 0.65, 2.2), Vector3(x, 100.825, 0)))
	for z in [-1.0, 1.0]:
		fences.append(_box(Vector3(2.2, 0.65, 0.15), Vector3(0, 100.825, z)))
	await _frames(480)
	_expect(not animal._water_avoided.is_empty() and animal.hydration < 20.0, "Unreachable visible water was not abandoned.")
	_expect(absf(animal.position.x) < 1.0 and absf(animal.position.z) < 1.0, "Thirst bypassed physical barriers.")
	for fence in fences:
		fence.queue_free()
	animal.queue_free()
	await _frames(4)

func _roles_and_clock() -> void:
	for role in ["predator", "scavenger", "forager", "climber"]:
		var animal: CharacterBody3D = _animal(Vector3(4.5, 100.55, 0), 720, role)
		_thirsty(animal, 60.0)
		await _frames(100)
		_expect(animal.hydration > 60.0, "Land role did not drink: " + role)
		state.set_simulation_speed(0.0)
		var before: float = animal.hydration
		await _frames(65)
		_expect(animal.hydration == before, "Time stop changed hydration for " + role)
		state.set_simulation_speed(1.0)
		animal.is_dead = true
		await _frames(10)
		_expect(animal.hydration == before, "Dead animal advanced thirst.")
		animal.queue_free()
		await _frames(4)
	var swimmer: CharacterBody3D = _animal(Vector3(0, 100.55, 0), 721, "swimmer")
	_expect(swimmer._drinking.is_empty(), "Land-shore logic was applied to aquatic fauna.")
	swimmer.queue_free()
	await _frames(4)

func _check_state_contract() -> void:
	var body: Dictionary = BodyState.body(state)
	var identity: Dictionary = {"body_id": body["id"], "object_id": "contract"}
	var original: Dictionary = body["wildlife_drinking"]
	var future: Dictionary = {"schema": 99, "opaque": [1, 2, 3]}
	body["wildlife_drinking"] = future.duplicate(true)
	_expect(State.animal(state, identity, 50).is_empty() and body["wildlife_drinking"] == future, "Future drinking payload was overwritten.")
	body["wildlife_drinking"] = original
	var invalid: Dictionary = {"hydration": "invalid", "seeking": true}
	original["animals"]["contract"] = invalid.duplicate(true)
	_expect(State.animal(state, identity, 50).is_empty() and original["animals"]["contract"] == invalid, "Malformed hydration was silently replaced.")
	identity["body_id"] = "another-body"
	_expect(State.animal(state, identity, 50).is_empty(), "Drinking state crossed body identity.")
	state.start_world_with_seed(63352)
	_expect(not BodyState.body(state).has("wildlife_drinking"), "New campaign inherited prior hydration.")

func _animal(point: Vector3, individual: int, role: String = "grazer") -> CharacterBody3D:
	var animal: CharacterBody3D = wildlife.instantiate()
	animal.water_provider = provider
	animal.configure(771, individual, Vector2i.ZERO, role)
	scene.add_child(animal)
	animal.position = point
	animal._ambient_heading = Vector3.ZERO
	animal._decision_timer = 100.0
	return animal

func _thirsty(animal: Node, value: float) -> void:
	animal.hydration = value
	animal._drinking["hydration"] = value
	animal._drinking["seeking"] = true

func _build_fixture() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	provider = WaterProvider.new()
	scene.add_child(provider)
	_box(Vector3(46, 1, 50), Vector3(-17, 100, 0))
	bed = _box(Vector3(34, 1, 50), Vector3(23, 97.5, 0))
	var surface := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(34, 50)
	surface.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.49, 0.70)
	surface.material_override = material
	scene.add_child(surface)
	surface.position = Vector3(23, 100, 0)
	player = Observer.new()
	player.add_to_group(&"player")
	scene.add_child(player)
	player.position = Vector3(15, 100.55, 15)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(-1, 106, 10)
	camera.look_at(Vector3(4, 100.5, 0))
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	scene.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.21, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.91, 0.98)
	environment.environment.ambient_light_energy = 0.7
	scene.add_child(environment)

func _box(size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = shape
	body.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.43, 0.30)
	visual.material_override = material
	body.add_child(visual)
	scene.add_child(body)
	body.position = point
	return body

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _capture(name: String) -> void:
	if captures.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name + ".png"))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)

func _finish() -> void:
	print(JSON.stringify({"test": "wildlife_drinking", "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
