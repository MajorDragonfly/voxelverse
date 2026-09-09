extends RefCounted
## Incremental local sampling of existing water data and loaded collision.
## Water meshes have no physics shape: require a loaded submerged bed as well.

const Steering = preload("res://creatures/ai/wildlife_steering.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const SAMPLES: int = 80
const BATCH: int = 4
const REACH: float = 3.0

static func freshwater(provider: Node, point: Vector3) -> Dictionary:
	if is_instance_valid(provider) and provider.has_method("freshwater_at"): return provider.freshwater_at(point)
	if not is_instance_valid(provider) or not provider.has_method("get_water_info"):
		return {}
	var info: Dictionary = provider.get_water_info(point.x, point.z)
	if info.get("kind", "") not in ["lake", "river"] or float(info.get("distance", 1.0)) >= -0.10:
		return {}
	var level: float = float(provider.get_water_level(point.x, point.z))
	if not is_finite(level) or float(provider.get_terrain_height(point.x, point.z)) > level - 0.15:
		return {}
	return {"point": Vector3(point.x, level, point.z), "kind": str(info["kind"])}

static func floor_at(actor: CharacterBody3D, point: Vector3, up: float = 1.0, down: float = 2.5) -> Dictionary:
	var vertical: Vector3 = Space.up(actor, point)
	var query := PhysicsRayQueryParameters3D.create(point + vertical * up, point - vertical * down, 1)
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query)

static func visible(actor: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

static func loaded_water(actor: CharacterBody3D, water: Vector3) -> bool:
	var bed: Dictionary = floor_at(actor, water, 0.12, 3.0)
	return not bed.is_empty() and (water - bed.position).dot(Space.up(actor, water)) > 0.12

static func dry_floor(actor: CharacterBody3D, provider: Node, point: Vector3) -> Dictionary:
	var floor: Dictionary = floor_at(actor, point)
	if floor.is_empty() or floor["normal"].dot(Space.up(actor, point)) < 0.85:
		return {}
	var p: Vector3 = floor["position"]
	if provider.has_method("is_dry_at"): return floor if provider.is_dry_at(p) else {}
	if p.y < float(provider.get_water_level(p.x, p.z)) + 0.18:
		return {}
	return floor

static func can_drink(actor: CharacterBody3D, provider: Node, source: Dictionary) -> bool:
	if source.is_empty() or not source.get("water") is Vector3:
		return false
	var current: Dictionary = freshwater(provider, source["water"])
	if current.is_empty():
		return false
	var water: Vector3 = current["point"]
	var up: Vector3 = Space.up(actor, water)
	var height: float = (actor.global_position - water).dot(up)
	if height < 0.15 or height > 1.25 or actor.global_position.distance_to(water) > REACH:
		return false
	var floor: Dictionary = dry_floor(actor, provider, actor.global_position)
	return not floor.is_empty() and absf((actor.global_position - floor.position).dot(up)) <= 0.12 and loaded_water(actor, water) and visible(actor, actor.global_position + up * 0.65, water + up * 0.12)

static func valid_source(actor: CharacterBody3D, provider: Node, source: Dictionary) -> bool:
	if source.is_empty() or not source.get("bank") is Vector3 or not source.get("water") is Vector3:
		return false
	var current: Dictionary = freshwater(provider, source["water"])
	if current.is_empty() or current["point"].distance_to(source["water"]) > 0.10:
		return false
	var floor: Dictionary = dry_floor(actor, provider, source["bank"])
	return not floor.is_empty() and floor["position"].distance_to(source["bank"]) < 0.15 and loaded_water(actor, source["water"])

static func find_batch(actor: CharacterBody3D, provider: Node, origin: Vector3, start: int, avoided: Dictionary) -> Dictionary:
	var frame: Basis = Space.frame(actor, origin)
	var up: Vector3 = frame.y
	for index in range(start, mini(start + BATCH, SAMPLES)):
		var angle: float = float(index % 16) * TAU / 16.0
		var radius: float = 2.0 + float(index / 16) * 3.0
		var probe: Vector3 = origin + frame * Vector3(cos(angle), 0, sin(angle)) * radius
		var water_data: Dictionary = freshwater(provider, probe)
		if water_data.is_empty():
			continue
		var water: Vector3 = water_data["point"]
		var key: String = "%d:%d" % [roundi(water.x), roundi(water.z)]
		if Space.adapter(actor) != null:
			var place: Dictionary = Space.encode(actor, water)
			key = "%s:%d:%d:%d" % [place.body_id, place.face, roundi(place.u * place.radius), roundi(place.v * place.radius)]
		if avoided.has(key) or absf((water - actor.global_position).dot(up)) > 3.0 or not loaded_water(actor, water):
			continue
		var towards: Vector3 = (actor.global_position - water).normalized()
		towards = towards.slide(up)
		if towards.length_squared() < 0.01:
			towards = frame.x
		for turn in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, PI]:
			var candidate: Vector3 = water + towards.rotated(up, turn).normalized() * 2.0 + up * 0.55
			var ground: Dictionary = dry_floor(actor, provider, candidate)
			if ground.is_empty():
				continue
			var bank: Vector3 = ground["position"]
			if (bank - water).dot(up) > 1.15 or bank.distance_to(actor.global_position) > 16.0:
				continue
			if not visible(actor, actor.global_position + up * 0.65, bank + up * 0.65) or not visible(actor, bank + up * 0.65, water + up * 0.12):
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = actor.get_node("CollisionShape3D").shape
			query.transform = Transform3D(actor.global_basis, bank + up * 0.64)
			query.collision_mask = 1
			query.exclude = [actor.get_rid()]
			if not actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
			return {"bank": bank, "water": water, "kind": water_data["kind"], "key": key}
	return {}
