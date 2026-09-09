extends SceneTree

const Steering = preload("res://creatures/ai/wildlife_steering.gd")

class Observer:
	extends CharacterBody3D
	var is_dead: bool = false
	var health: float = 100.0
	func receive_damage(value: float) -> void:
		health -= value

# Public movement contract of the independently developed social component.
class SocialContract:
	extends Node
	var attention_remaining: float = 0.0
	var allied: bool = true
	var released_for_external_threat: bool = false
	func entry() -> Dictionary:
		return {"relation": "ally" if allied else "wild"}
	func controls_movement() -> bool:
		if attention_remaining > 0.0:
			get_parent()._wander_direction = Vector3.ZERO
			return true
		return allied and not released_for_external_threat

var failures: Array[String] = []
var scene: Node3D
var player: Observer
var serial: int = 100
var captures: String = ""
var wildlife: PackedScene

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	root.get_node("GameState").start_world_with_seed(15838)
	await process_frame
	wildlife = load("res://creatures/wildlife/procedural_wildlife_v7.tscn")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	_build_fixture()
	await _frames(5)
	var before_progression: Dictionary = root.get_node("ProgressionService").export_state().duplicate(true)
	await _perception_and_combat()
	await _herd_and_social()
	await _escape_and_ground()
	_expect(root.get_node("ProgressionService").export_state() == before_progression, "Ambient AI manufactured discoveries, rewards or relationship changes.")
	scene.queue_free()
	await _frames(4)
	print(JSON.stringify({"test": "wildlife_ai", "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _perception_and_combat() -> void:
	player.position = Vector3(8, 100.05, 0)
	var predator: CharacterBody3D = _animal("predator", Vector3(0, 100.05, 0), 411)
	predator._visual_root.rotation.y = -PI * 0.5
	predator._ambient_heading = Vector3.ZERO
	predator._decision_timer = 100.0
	var wall: StaticBody3D = _box(Vector3(0.5, 4, 7), Vector3(4, 101.8, 0))
	await _frames(35)
	_expect(not predator.can_perceive(player, 13.0), "Predator saw through a wall.")
	_expect(predator.ai_state in ["rest", "wander"], "Occluded player provoked a chase.")
	wall.queue_free()
	await _frames(3)
	player.position = Vector3(-8, 100.05, 0)
	_expect(not predator.can_perceive(player, 13.0), "Distant target behind predator bypassed field of view.")
	player.position = Vector3(1.25, 100.05, 0)
	await _frames(15)
	_expect(predator.ai_state == "alert" and player.health == 100.0, "Predator skipped its warning and attacked immediately.")
	await _capture("01_warning")
	await _frames(65)
	_expect(player.health < 100.0, "Visible target in actual bite range was never attacked.")
	var health: float = player.health
	wall = _box(Vector3(0.16, 4, 7), Vector3(0.65, 101.8, 0))
	await _frames(3)
	for attempt in range(4):
		predator._attack_timer = 0.0
		predator._try_predator_attack(player)
	_expect(player.health == health, "Predator bit through a wall at close range.")
	var last_seen: Vector3 = predator.get_ai_debug_state()["last_seen"]
	player.position = Vector3(6, 100.05, 4)
	await _frames(25)
	_expect(predator.get_ai_debug_state()["last_seen"] == last_seen, "Hidden target position leaked into predator memory.")
	_expect(predator.get_ai_debug_state()["intent"] == "search", "Predator did not search its last visible target position.")
	await _capture("02_occluded")
	predator.maximum_chase_seconds = 2.0
	await _frames(90)
	_expect(predator.get_ai_debug_state()["intent"] not in ["chase", "search", "alert"], "Predator pursued beyond its time budget.")
	wall.queue_free()
	predator.queue_free()
	await _frames(3)
	# A healthy player outside bite range must not receive remote damage.
	player.health = 100.0
	player.position = Vector3(8, 100.05, 0)
	predator = _animal("predator", Vector3(0, 100.05, 0), 411)
	predator._visual_root.rotation.y = -PI * 0.5
	predator._ambient_heading = Vector3.ZERO
	predator._decision_timer = 100.0
	predator.maximum_chase_seconds = 2.0
	await _frames(160)
	_expect(predator.get_ai_debug_state()["intent"] not in ["chase", "alert", "search"], "Visible player caused an endless chase.")
	player.is_dead = true
	predator._cooldown = 0.0
	predator._returning = false
	predator._memory = 0.0
	predator._chase_time = 0.0
	await _frames(15)
	_expect(predator.get_ai_debug_state()["intent"] not in ["chase", "alert"], "Predator acquired a dead player.")
	player.is_dead = false
	predator.queue_free()
	await _frames(3)

func _herd_and_social() -> void:
	player.position = Vector3(30, 100.05, 30)
	var first: CharacterBody3D = _animal("grazer", Vector3(-5, 100.05, 0), 771)
	var second: CharacterBody3D = _animal("grazer", Vector3(5, 100.05, 0), 771)
	first._ambient_heading = Vector3.ZERO
	second._ambient_heading = Vector3.ZERO
	first._decision_timer = 100.0
	second._decision_timer = 100.0
	await _frames(20)
	_expect(first.get_ai_debug_state()["intent"] == "herd", "Distant visible same-species neighbor did not invite regrouping.")
	await _frames(100)
	var gap: float = first.global_position.distance_to(second.global_position)
	_expect(gap < 8.0 and gap > 1.4, "Herd did not converge with personal space: " + str(gap))
	await _capture("03_herd")
	second.position = first.position + Vector3(0.3, 0, 0)
	await _frames(60)
	_expect(first.global_position.distance_to(second.global_position) > 0.8, "Neighbors remained overlapping.")
	var social := SocialContract.new()
	social.name = "SocialBehavior"
	first.add_child(social)
	player.position = first.position + Vector3(1.2, 0, 0)
	await _frames(15)
	_expect(first.get_ai_debug_state()["ignore_player"] and first.get_ai_debug_state()["intent"] != "flee", "Friendly animal still fled from its player ally.")
	social.released_for_external_threat = true
	await _frames(15)
	_expect(first.get_ai_debug_state()["ignore_player"], "An ally's external threat changed the player into a threat.")
	social.released_for_external_threat = false
	social.attention_remaining = 1.0
	var stopped: Vector3 = first.global_position
	await _frames(30)
	_expect(first.ai_state == "social" and Vector2(first.position.x - stopped.x, first.position.z - stopped.z).length() < 0.05, "Befriending attention lost movement ownership.")
	social.attention_remaining = 0.0
	social.allied = false
	await _frames(15)
	_expect(first.get_ai_debug_state()["intent"] == "flee", "Wild animal did not resume danger response after social control ended.")
	first.queue_free()
	second.queue_free()
	await _frames(3)

func _escape_and_ground() -> void:
	player.position = Vector3(-4, 100.05, 0)
	var grazer: CharacterBody3D = _animal("grazer", Vector3(0, 100.05, 0), 813)
	grazer._visual_root.rotation.y = PI * 0.5
	var wall: StaticBody3D = _box(Vector3(1, 4, 3.0), Vector3(3, 101.8, 0))
	await _frames(180)
	_expect(grazer.position.x > 4.0, "Fleeing animal did not navigate around a short wall: " + str(grazer.position))
	_expect(grazer.is_on_floor(), "Navigating animal lost floor contact.")
	await _capture("04_detour")
	wall.queue_free()
	grazer.position = Vector3(39.2, 100.05, 0)
	await _frames(2)
	_expect(not Steering.safe_direction(grazer, Vector3.RIGHT, grazer.maximum_step_height), "Steering accepted a cliff/unloaded floor.")
	var saved_position: Vector3 = Vector3(70, 100.05, 0)
	grazer.position = saved_position
	await _frames(15)
	_expect(grazer.ai_state == "unloaded" and grazer.position == saved_position, "Animal walked or fell through unloaded terrain.")
	var ground: StaticBody3D = _box(Vector3(6, 1, 6), Vector3(70, 99.5, 0))
	await _frames(15)
	_expect(grazer.ai_state != "unloaded", "Animal did not resume after floor streamed in.")
	grazer.queue_free()
	ground.queue_free()
	await _frames(3)
	# The actual world water query prevents a land animal entering submerged
	# collision geometry even when that geometry would otherwise be walkable.
	var generator: Node = root.get_node("WorldGenerator")
	var water_height: float = generator.get_water_level(0, 0)
	ground = _box(Vector3(6, 1, 6), Vector3(0, water_height - 1.0, 0))
	grazer = _animal("grazer", Vector3(0, water_height - 0.45, 0), 813)
	await _frames(2)
	_expect(not Steering.safe_direction(grazer, Vector3.RIGHT, grazer.maximum_step_height), "Land animal steering accepted underwater floor.")
	grazer.queue_free()
	ground.queue_free()
	await _frames(3)

func _animal(role: String, point: Vector3, species: int) -> CharacterBody3D:
	var animal: CharacterBody3D = wildlife.instantiate()
	serial += 1
	animal.configure(species, serial, Vector2i.ZERO, role)
	scene.add_child(animal)
	animal.position = point
	return animal

func _build_fixture() -> void:
	root.size = Vector2i(1280, 800)
	scene = Node3D.new()
	root.add_child(scene)
	current_scene = scene
	_box(Vector3(80, 1, 80), Vector3(0, 99.5, 0))
	player = Observer.new()
	player.add_to_group(&"player")
	scene.add_child(player)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(12, 112, 18)
	camera.look_at(Vector3(2, 100.5, 0))
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
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.5
	visual.mesh = mesh
	visual.position.y = 0.75
	player.add_child(visual)

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
	var animals: Array[Node] = get_nodes_in_group(&"wildlife")
	if not animals.is_empty():
		var center := Vector3.ZERO
		for creature in animals:
			center += creature.global_position
		center /= float(animals.size())
		var camera: Camera3D = root.get_camera_3d()
		camera.global_position = center + Vector3(5, 4, 7)
		camera.look_at(center + Vector3.UP * 0.9)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(captures.path_join(name + ".png"))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: " + message)
