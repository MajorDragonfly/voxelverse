extends CharacterBody3D
## An adopted individual uses its frozen D1 body, never the species generator.
const State = preload("res://world/domestication/animal_state.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Steering = preload("res://creatures/ai/wildlife_steering.gd")
const STEP: float = 0.55
const HOME_REACH: float = 1.5
signal health_changed(current_health: float, maximum_health: float)
signal creature_defeated(creature: Node)
var runtime: Node
var object_id: String
var source: Dictionary
var blueprint: Dictionary
var species_seed: int
var individual_seed: int
var ecological_role: String
var maximum_health: float
var current_health: float
var is_dead: bool = false
var status: String = ""
var steer_distance: float = 1.1
var _visual_root: Node3D
var _preview: Node3D
var _side: float = 1.0
var _fear_origin := Vector3.ZERO

func setup(host: Node, record: Dictionary, appearance: Dictionary) -> void:
	runtime = host
	object_id = record["object_id"]
	source = appearance.duplicate(true)
	blueprint = D1.decode(source["blueprint"])
	species_seed = int(source["species_seed"])
	individual_seed = int(source["individual_seed"])
	ecological_role = source["role"]
	maximum_health = source["maximum_health"]
	position = State.vector(record["position"])
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.6
	_side = -1.0 if posmod(individual_seed, 2) == 0 else 1.0
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.15
	shape.shape = capsule
	shape.position.y = 0.56
	add_child(shape)
	_visual_root = Node3D.new()
	_visual_root.name = "SpeciesVisual"
	add_child(_visual_root)
	_preview = Preview.new()
	_preview.name = "ModularWildlifeCreature"
	_preview.scale = Vector3.ONE * float(source["visual_scale"])
	_visual_root.add_child(_preview)
	_preview.set_editor_state(blueprint, -1, -1, false)
	_preview.position = State.vector(source["preview_offset"])
	_visual_root.rotation.y = float(source["heading"])
	_disable_collisions(_preview)
	apply_record(record)

func _ready() -> void:
	# Preview._ready rebuilds its editor pick colliders after setup.
	_disable_collisions(_preview)
	add_to_group(&"domesticated_animals")
	add_to_group(&"wildlife")

func apply_record(record: Dictionary) -> void:
	current_health = float(record["health"]) * maximum_health / 100.0
	is_dead = record["status"] == "dead"
	if is_dead:
		velocity = Vector3.ZERO
		_visual_root.rotation.z = deg_to_rad(72)
		if _preview.motion_mode != "edit": _preview.set_motion("edit")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(runtime) or not runtime.is_active(): return
	var record: Dictionary = runtime.controller.record(object_id)
	if record.is_empty(): return
	apply_record(record)
	if is_dead:
		status = "Verstorben"
		return
	if Steering.ground(self, global_position).is_empty():
		velocity = Vector3.ZERO
		status = "Wartet auf geladenen Boden"
		return
	var target: Vector3 = global_position
	var desired := Vector3.ZERO
	steer_distance = 1.1
	var fear: bool = runtime.frightened(object_id)
	status = "Wartet"
	if fear:
		desired = global_position - _fear_origin
		if desired.length_squared() < 0.1: desired = Vector3(_side, 0, 1)
		status = "Flieht"
	elif not record["pending"].is_empty():
		status = "Nimmt Futter an"
	elif record["status"] == "tamed":
		if record["order"] == "follow":
			var handler: Node3D = runtime.handler_actor(record["handler_id"])
			if handler != null:
				target = handler.global_position
				status = "Folgt / bei dir"
			else: status = "Betreuer nicht verfügbar"
		elif record["order"] == "home":
			target = State.vector(record["home"])
			status = "Kehrt heim / am Heimatplatz"
		else:
			target = State.vector(record["wait_position"])
		var offset := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		# Arrival is the small home area around the shared village anchor.
		var reach: float = 1.6 if record["order"] == "follow" else HOME_REACH if record["order"] == "home" else 0.5
		if offset.length() > reach:
			desired = runtime.heading(self, target)
	else:
		status = "Wild / Zähmung begonnen"
		var home: Vector3 = State.vector(record["home"])
		if global_position.distance_to(home) > 8.0: desired = home - global_position
		else:
			var cycle: float = fmod(runtime.simulation_time() + float(posmod(individual_seed, 7)), 12.0)
			if cycle < 3:
				var angle: float = float(posmod(individual_seed, 53)) + floorf(runtime.simulation_time() / 12.0) * 1.9
				desired = Vector3(cos(angle), 0, sin(angle))
	desired.y = 0
	var direction: Vector3 = Steering.choose(self, desired, STEP, _side, steer_distance)
	if desired != Vector3.ZERO and direction == Vector3.ZERO: status = "Weg blockiert"
	var speed: float = float(source["speed"])
	velocity = Vector3(direction.x * speed, -0.5 if is_on_floor() else maxf(-15, velocity.y - 20 * delta), direction.z * speed)
	var motion: Vector3 = direction * speed * delta
	if is_on_floor() and direction != Vector3.ZERO and test_move(global_transform, motion):
		var raised: Transform3D = global_transform.translated(Vector3.UP * STEP)
		if not test_move(global_transform, Vector3.UP * STEP) and not test_move(raised, motion) and test_move(raised.translated(motion), Vector3.DOWN * (STEP + 0.15)): global_transform = raised
	move_and_slide()
	if is_on_floor(): apply_floor_snap()
	if direction != Vector3.ZERO: _visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 7))
	var motion_mode: String = "walk" if direction != Vector3.ZERO else "idle"
	if _preview.motion_mode != motion_mode: _preview.set_motion(motion_mode)
	runtime.controller.record_position(object_id, global_position)
	runtime.sources[object_id]["heading"] = _visual_root.rotation.y

func receive_creature_attack(damage: float, attacker: Node = null) -> void:
	if is_dead or not is_finite(damage) or damage <= 0: return
	if attacker != null and attacker.is_in_group(&"player"): return
	var was_alive: bool = not is_dead
	if runtime.damage_animal(object_id, damage * 100.0 / maximum_health):
		if attacker is Node3D: _fear_origin = attacker.global_position
		apply_record(runtime.controller.record(object_id))
		health_changed.emit(current_health, maximum_health)
		if was_alive and is_dead: creature_defeated.emit(self)

func get_campaign_identity() -> Dictionary: return source["identity"].duplicate(true)
func get_display_name() -> String: return source["name"]
func get_health_ratio() -> float: return current_health / maximum_health
func get_target_health_data() -> Dictionary:
	return {"name": get_display_name(), "current_health": current_health, "maximum_health": maximum_health, "health_ratio": get_health_ratio(), "dead": is_dead}

func _disable_collisions(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child: Node in node.get_children(): _disable_collisions(child)
