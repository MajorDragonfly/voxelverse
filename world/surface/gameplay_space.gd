extends RefCounted
## Geometry bridge for the existing campaign consumers. Saved places belong to
## the body; only short relative distances become Vector3 in the live scene.
const Cube = preload("res://world/space/cube_sphere.gd")

static func adapter(node: Node) -> RefCounted:
	if not is_instance_valid(node) or not node.is_inside_tree(): return null
	var scene: Node = node.get_tree().current_scene
	return scene.get_meta("campaign_surface") if is_instance_valid(scene) and scene.has_meta("campaign_surface") else null

static func address(node: Node, point: Vector3) -> Dictionary:
	var surface: RefCounted = adapter(node)
	assert(surface != null)
	return Cube.from_cartesian(surface.terrain.surface.body.id,
		Cube.global_position(point, surface.terrain.origin), surface.terrain.surface.body.radius)

static func up(node: Node, point: Vector3) -> Vector3:
	if adapter(node) == null: return Vector3.UP
	var place: Dictionary = address(node, point)
	return Cube.vector(Cube.direction(place.face, place.u, place.v))

static func frame(node: Node, point: Vector3, forward: Vector3 = Vector3.FORWARD) -> Basis:
	return Cube.frame(up(node, point), forward)

static func offset(node: Node, point: Vector3, local: Vector3) -> Vector3:
	return point + frame(node, point) * local

static func encode(node: Node, point: Vector3) -> Variant:
	if adapter(node) == null: return [point.x, point.y, point.z]
	var value: Dictionary = address(node, point)
	# Pure village/economy validators need the scale to compare nearby places.
	# The save service verifies this redundant radius against the body context.
	value["radius"] = adapter(node).terrain.surface.body.radius
	return value

static func resolve(node: Node, value: Variant) -> Vector3:
	if value is Vector3: return value
	if value is Dictionary:
		var surface: RefCounted = adapter(node)
		assert(surface != null and Cube.valid(value, surface.terrain.surface.body.id))
		return surface.to_local(value)
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func valid_place(value: Variant, mode: String, body_id: String) -> bool:
	if mode == Cube.MODE:
		return Cube.valid(value, body_id) and absf(float(value.height)) <= 20000.0
	if mode != "legacy_plane_v9" or not value is Array or value.size() != 3: return false
	for number in value:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 1.0e7: return false
	return true

static func track(node: Node3D, id: String) -> void:
	var surface: RefCounted = adapter(node)
	if surface == null: return
	if surface.attached.get(id) == node: return
	# Independent moving actors may live under a bound village root. Top-level
	# transforms give each physical root exactly one origin owner.
	var parent: Node = node.get_parent()
	while parent != null:
		if parent.has_meta("surface_object_id"):
			var before: Transform3D = node.global_transform
			node.top_level = true
			node.global_transform = before
			break
		parent = parent.get_parent()
	surface.bind(id, node, address(node, node.global_position), -node.global_basis.z)
	node.set_meta("surface_mode", Cube.MODE)
	node.tree_exiting.connect(func() -> void:
		if surface.attached.get(id) == node: surface.unbind(id), CONNECT_ONE_SHOT)

static func untrack(node: Node3D) -> void:
	var surface: RefCounted = adapter(node)
	if surface == null or not node.has_meta("surface_object_id"): return
	var id: String = node.get_meta("surface_object_id")
	if surface.attached.get(id) == node: surface.unbind(id)

static func orient(node: Node3D) -> void:
	if adapter(node) == null: return
	node.global_basis = frame(node, node.global_position, -node.global_basis.z)
	if node is CharacterBody3D: node.up_direction = node.global_basis.y

static func sample(node: Node, point: Vector3) -> Dictionary:
	var surface: RefCounted = adapter(node)
	if surface != null:
		var place: Dictionary = address(node, point)
		var result: Dictionary = surface.sample(place)
		result["altitude"] = place.height
		result["water_level"] = float(result.get("water_level", 0.0))
		return result
	var generator: Node = node.get_node("/root/WorldGenerator")
	var height: float = generator.get_terrain_height(point.x, point.z)
	var water: float = generator.get_water_level(point.x, point.z)
	return {"height": height, "altitude": point.y, "water_level": water, "water": water > height}

static func dry(node: Node, point: Vector3, clearance: float = 0.18) -> bool:
	var value: Dictionary = sample(node, point)
	return float(value.water_level) < float(value.altitude) - clearance

static func ground_ready(node: Node, point: Vector3) -> bool:
	var surface: RefCounted = adapter(node)
	return surface == null or surface.terrain.ground_ready(Cube.global_position(point, surface.terrain.origin))

static func floor_hit(node: Node3D, point: Vector3, rise: float = 1.2, drop: float = 2.4) -> Dictionary:
	if not ground_ready(node, point): return {}
	var normal: Vector3 = up(node, point)
	var ray := PhysicsRayQueryParameters3D.create(point + normal * rise, point - normal * drop, 1)
	if node is CollisionObject3D: ray.exclude = [node.get_rid()]
	return node.get_world_3d().direct_space_state.intersect_ray(ray)

static func step(actor: CharacterBody3D, motion: Vector3, height: float, probe: float = 0.12) -> bool:
	if motion.length_squared() < 0.00001 or not actor.test_move(actor.global_transform, motion): return false
	var rise: Vector3 = actor.up_direction * height
	if actor.test_move(actor.global_transform, rise): return false
	var raised: Transform3D = actor.global_transform.translated(rise)
	if actor.test_move(raised, motion): return false
	var landing := KinematicCollision3D.new()
	if not actor.test_move(raised.translated(motion), -actor.up_direction * (height + probe), landing): return false
	if landing.get_normal().dot(actor.up_direction) < cos(actor.floor_max_angle): return false
	actor.global_transform = raised
	return true

static func visual_data(root: Node3D, data: Variant) -> Variant:
	# Read-only scene copy. Economy and save records remain canonical.
	if data is Dictionary:
		if data.get("mode") == Cube.MODE and data.has("face"):
			var local: Vector3 = root.to_local(resolve(root, data))
			return [local.x, local.y, local.z]
		var result: Dictionary = {}
		for key in data: result[key] = visual_data(root, data[key])
		return result
	if data is Array:
		var result: Array = []
		for item in data: result.append(visual_data(root, item))
		return result
	return data
