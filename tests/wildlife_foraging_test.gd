extends SceneTree

const State = preload("res://world/resources/plants/foraging_state.gd")
const SAVE: String = "user://wildlife_foraging_test.json"

class Observer:
	extends CharacterBody3D
	var is_dead: bool = false
	var restored: float = 0.0
	func can_perform_action(_ability: StringName) -> bool:
		return true
	func get_hunger_ratio() -> float:
		return 0.2
	func restore_hunger(amount: float) -> void:
		restored += amount

class SocialContract:
	extends Node
	var attention_remaining: float = 10.0
	func controls_movement() -> bool:
		return attention_remaining > 0.0
	func entry() -> Dictionary:
		return {"relation": "ally"}

var failures: Array[String] = []
var state: Node
var saves: Node
var scene: Node3D
var player: Observer
var wildlife: PackedScene
var bushes: PackedScene
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
		_expect(saves.load_now(), "Fresh process failed to read campaign.")
		var ledger: Dictionary = State.body(state).get("wildlife_foraging", {})
		_expect(not ledger.is_empty() and float(ledger["plants"]["berry:700:0"]["remaining"]) == 0.0, "Fresh process refilled depleted plant.")
		_expect(not ledger.is_empty() and ledger["animals"].size() == 1, "Fresh process lost individual needs.")
		_finish()
		return
	state.start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	bushes = load("res://world/resources/plants/berry_bush.tscn")
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	_build_fixture()
	await _frames(5)
	var progression: Dictionary = root.get_node("ProgressionService").export_state().duplicate(true)
	await _meal_and_persistence(args)
	await _interruptions_and_obstacles()
	await _validation_and_scope()
	_expect(root.get_node("ProgressionService").export_state() == progression, "Ambient feeding awarded player progression or discovery.")
	scene.queue_free()
	await _frames(4)
	_finish()

func _meal_and_persistence(args: PackedStringArray) -> void:
	var bush: Node3D = _bush(Vector3(7, 100, 0))
	var animal: CharacterBody3D = _animal(Vector3(0, 100.05, 0), 120)
	_hungry(animal, 60.0)
	await _frames(35)
	_expect(animal.ai_state == "forage" and animal.position.x > 0.2, "Hungry animal did not walk to visible food.")
	await _capture("01_food_search")
	for frame in range(500):
		await _frames(1)
		if animal.ai_state == "eat":
			break
	_expect(animal.ai_state == "eat", "Animal could not reach physical feeding range: " + str(animal.get_ai_debug_state()))
	await _capture("02_eating")
	await _frames(120)
	_expect(animal.satiety >= 75.0 and not animal._needs["seeking"], "Meal did not satiate the animal.")
	_expect(bush.get_food_remaining() == 10.0 and animal.ai_state == "rest", "Animal failed to stop eating and rest, or duplicated food.")
	player.position = animal.position
	bush.interact(player)
	_expect(player.restored == 10.0 and bush.get_food_remaining() == 0.0 and bush.is_depleted, "Player did not share the exact remaining stock.")
	player.position = Vector3(15, 100.05, 15)
	await _capture("03_depleted")
	animal.set_physics_process(false)
	var saved_satiety: float = animal.satiety
	var identity: String = animal.get_campaign_identity()["object_id"]
	_expect(saves.save_now(), "Ordinary save failed.")
	var output: Array = []
	var restart: PackedStringArray = ["--headless"]
	if "--restart-pack" in args:
		restart.append_array(["--main-pack", args[args.find("--restart-pack") + 1]])
	else:
		restart.append_array(["--path", ProjectSettings.globalize_path("res://")])
	restart.append_array(["--script", get_script().resource_path, "--", "--restart-check"])
	_expect(OS.execute(OS.get_executable_path(), restart, output, true) == 0, "Restart failed: " + str(output))
	state.campaign.data["elapsed_seconds"] += 200.0
	_expect(bush.get_food_remaining() == 30.0, "Plant did not regrow after 180 campaign seconds.")
	_expect(saves.load_now(), "Same-session load failed.")
	_expect(is_equal_approx(animal.satiety, saved_satiety) and bush.get_food_remaining() == 0.0, "Live actors overwrote loaded needs or plant stock.")
	animal.queue_free()
	bush.queue_free()
	await _frames(4)
	animal = _animal(Vector3(0, 100.05, 0), 120)
	animal.set_physics_process(false)
	bush = _bush(Vector3(7, 100, 0))
	await _frames(4)
	_expect(animal.get_campaign_identity()["object_id"] == identity and is_equal_approx(animal.satiety, saved_satiety), "Reinstantiating the same individual reset hunger.")
	_expect(bush.get_food_remaining() == 0.0 and bush.is_depleted, "Chunk recreation refilled or displayed empty berries.")
	animal.queue_free()
	bush.queue_free()
	await _frames(4)

func _interruptions_and_obstacles() -> void:
	var bush: Node3D = _bush(Vector3(1.8, 100, -10))
	var animal: CharacterBody3D = _animal(Vector3(0, 100.05, -10), 220)
	_hungry(animal, 40.0)
	await _frames(15)
	_expect(animal.ai_state == "eat", "Nearby hungry animal did not begin a meal.")
	var social := SocialContract.new()
	social.name = "SocialBehavior"
	animal.add_child(social)
	await _frames(75)
	_expect(animal.ai_state == "social" and bush.get_food_remaining() == 30.0, "Social attention did not interrupt eating.")
	social.queue_free()
	await _frames(3)
	player.position = animal.position + Vector3(-1.2, 0, 0)
	await _frames(35)
	_expect(animal.get_ai_debug_state()["intent"] == "flee" and bush.get_food_remaining() == 30.0, "Danger did not stop the meal before a bite.")
	player.position = Vector3(15, 100.05, 15)
	animal.queue_free()
	await _frames(4)
	animal = _animal(Vector3(0, 100.05, -10), 221)
	_hungry(animal, 40.0)
	var wall: StaticBody3D = _box(Vector3(0.15, 4, 12), Vector3(0.8, 101.8, -10))
	await _frames(80)
	_expect(bush.get_food_remaining() == 30.0 and bush.consume_food(animal, 10.0) == 0.0, "Animal ate through an occluding wall.")
	wall.queue_free()
	await _frames(3)
	animal.position = Vector3(-20, 100.05, -10)
	_expect(bush.consume_food(animal, 10.0) == 0.0, "Distant animal consumed food remotely.")
	animal.position = Vector3(0, 105, -10)
	_expect(bush.consume_food(animal, 10.0) == 0.0, "Animal ate across excessive height difference.")
	animal.position = Vector3(0, 100.05, -10)
	state.set_simulation_speed(0.0)
	var satiety: float = animal.satiety
	await _frames(70)
	_expect(animal.satiety == satiety and bush.get_food_remaining() == 30.0, "Stopped simulation advanced hunger or feeding.")
	state.set_simulation_speed(1.0)
	# Two consumers in the same frame may divide, but never duplicate stock.
	animal.set_physics_process(false)
	var other: CharacterBody3D = _animal(Vector3(1.8, 100.05, -8.2), 222)
	other.set_physics_process(false)
	await _frames(3)
	var total: float = bush.consume_food(animal, 20.0) + bush.consume_food(other, 20.0)
	_expect(total == 30.0 and bush.get_food_remaining() == 0.0, "Concurrent consumers duplicated food.")
	bush.queue_free()
	animal.queue_free()
	other.queue_free()
	await _frames(4)
	# Visible food across unloaded ground cannot trap an animal indefinitely.
	bush = _bush(Vector3(44, 100, 0))
	animal = _animal(Vector3(37, 100.05, 0), 223)
	_hungry(animal, 40.0)
	await _frames(450)
	_expect(bush.get_food_remaining() == 30.0 and animal.position.x < 40.0 and animal.position.y > 99.9, "Unreachable food caused remote feeding or a fall: " + str(animal.position))
	_expect(not animal._avoided.is_empty(), "Unreachable food was never abandoned.")
	animal.queue_free()
	bush.queue_free()
	await _frames(4)

func _validation_and_scope() -> void:
	var body: Dictionary = State.body(state)
	var original: Dictionary = body["wildlife_foraging"].duplicate(true)
	var future: Dictionary = {"schema": 99, "body_id": body["id"], "opaque": [1, 2, 3]}
	body["wildlife_foraging"] = future.duplicate(true)
	_expect(State.animal(state, body["id"], "unknown", 40).is_empty() and State.plant(state, body["id"], "unknown", 30).is_empty(), "Future payload was treated as writable.")
	_expect(body["wildlife_foraging"] == future, "Future payload was altered.")
	body["wildlife_foraging"] = original
	var malformed: Dictionary = {"satiety": "broken", "seeking": true}
	original["animals"]["broken"] = malformed.duplicate(true)
	_expect(State.animal(state, body["id"], "broken", 40).is_empty() and original["animals"]["broken"] == malformed, "Corrupt needs were overwritten.")
	_expect(State.ledger(state, "another-body").is_empty(), "Body-scoped state crossed into another world.")
	var old_body: String = body["id"]
	state.start_world_with_seed(63352)
	_expect(State.body(state)["id"] != old_body and not State.body(state).has("wildlife_foraging"), "New campaign inherited old food or hunger.")

func _animal(point: Vector3, individual: int) -> CharacterBody3D:
	var animal: CharacterBody3D = wildlife.instantiate()
	animal.configure(771, individual, Vector2i.ZERO, "grazer")
	scene.add_child(animal)
	animal.position = point
	animal._visual_root.rotation.y = -PI * 0.5
	animal._ambient_heading = Vector3.ZERO
	animal._decision_timer = 100.0
	return animal

func _hungry(animal: Node, value: float) -> void:
	animal.satiety = value
	animal._needs["satiety"] = value
	animal._needs["seeking"] = true

func _bush(point: Vector3) -> Node3D:
	var bush: Node3D = bushes.instantiate()
	bush.snap_to_terrain = false
	scene.add_child(bush)
	bush.position = point
	return bush

func _build_fixture() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	_box(Vector3(80, 1, 80), Vector3(0, 99.5, 0))
	player = Observer.new()
	player.add_to_group(&"player")
	scene.add_child(player)
	player.position = Vector3(15, 100.05, 15)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(8, 105, 9)
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
	print(JSON.stringify({"test": "wildlife_foraging", "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
