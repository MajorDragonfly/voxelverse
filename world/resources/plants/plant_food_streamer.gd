extends Node3D
## Bounded, deterministic interactive food beside the decorative ecosystem.
## No terrain/biome renderer or fauna-spawner implementation is replaced.

const Bush = preload("res://world/resources/plants/berry_bush.tscn")
const State = preload("res://world/resources/plants/foraging_state.gd")
const CELL: float = 12.0
const RADIUS: float = 38.0
const MAXIMUM: int = 32

var _plants: Dictionary = {}
var _body_id: String = ""
var _timer: float = 0.0

func _ready() -> void:
	set_as_top_level(true)
	global_transform = Transform3D.IDENTITY
	get_node("/root/SaveGameService").game_loaded.connect(_on_loaded)

func _on_loaded(_path: String) -> void:
	_clear()
	_timer = 0.0

func _clear() -> void:
	for plant in _plants.values():
		if is_instance_valid(plant):
			plant.queue_free()
	_plants.clear()

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.4
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(player) or GameState.current_phase not in [0, 1]:
		return
	# The nest is also used in editors and fixtures; require a real ready world.
	var manager: Node = get_tree().current_scene.get_node_or_null("WorldManager") if get_tree().current_scene != null else null
	if manager == null or not bool(manager.get("world_initialized")):
		return
	var body: Dictionary = State.body(GameState)
	if _body_id != str(body["id"]):
		_clear()
		_body_id = str(body["id"])
	for key in _plants.keys():
		var plant: Node3D = _plants[key]
		if not is_instance_valid(plant):
			_plants.erase(key)
		elif Vector2(plant.global_position.x - player.global_position.x, plant.global_position.z - player.global_position.z).length() > RADIUS + 12.0:
			plant.queue_free()
			_plants.erase(key)
	if _plants.size() >= MAXIMUM:
		return
	var center := Vector2i(floori(player.global_position.x / CELL), floori(player.global_position.z / CELL))
	var candidates: Array[Vector2i] = []
	for x in range(-3, 4):
		for z in range(-3, 4):
			candidates.append(center + Vector2i(x, z))
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	var created: int = 0
	for cell in candidates:
		if _plants.has(cell):
			continue
		var point: Vector3 = _candidate(cell)
		if Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > RADIUS or Vector2(point.x, point.z).length() < 9.0:
			continue
		var floor_point: Dictionary = _placement(point)
		if floor_point.is_empty():
			continue
		var plant: Node3D = Bush.instantiate()
		plant.snap_to_terrain = false
		add_child(plant)
		plant.global_position = floor_point["position"]
		_plants[cell] = plant
		created += 1
		if created >= 2 or _plants.size() >= MAXIMUM:
			break

func _candidate(cell: Vector2i) -> Vector3:
	var random := RandomNumberGenerator.new()
	random.seed = GameState.get_world_seed() + cell.x * 73856093 + cell.y * 19349663 + 610001
	var x: float = (float(cell.x) + 0.5) * CELL + random.randf_range(-3.0, 3.0)
	var z: float = (float(cell.y) + 0.5) * CELL + random.randf_range(-3.0, 3.0)
	return Vector3(x, WorldGenerator.get_visual_terrain_height(x, z), z)

func _placement(point: Vector3) -> Dictionary:
	if point.y <= WorldGenerator.get_water_level(point.x, point.z) + 0.45 or WorldGenerator.get_terrain_slope(point.x, point.z, 0.75) > 0.38:
		return {}
	var biome: int = WorldGenerator.get_biome(point.x, point.z, point.y)
	if biome in [WorldGenerator.Biome.OCEAN, WorldGenerator.Biome.SNOW, WorldGenerator.Biome.ALPINE, WorldGenerator.Biome.DESERT]:
		return {}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point + Vector3.DOWN * 2.0, 1))
	if hit.is_empty() or hit["normal"].dot(Vector3.UP) < 0.9 or absf(hit["position"].y - point.y) > 0.65:
		return {}
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.6, 1.8)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, hit["position"] + Vector3.UP * 0.9)
	query.collision_mask = 1
	if not space.intersect_shape(query, 1).is_empty():
		return {}
	return hit
