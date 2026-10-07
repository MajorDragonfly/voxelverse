extends RefCounted
## Real actor location/physics, independent of the observer camera and visuals.
const Space = preload("res://world/surface/gameplay_space.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const Climate = preload("res://world/weather/planet_climate.gd")
const Receipt = preload("res://world/weather/r33_exposure_state.gd")
var _attached_body: Dictionary = {}
var last_result: Dictionary = {}

func reset() -> void:
	_attached_body = {}
	last_result = {}

static func protection(actor: Node3D, sample: Dictionary) -> Dictionary:
	var up: Vector3 = Space.up(actor, actor.global_position)
	var point: Vector3 = actor.global_position + up * 0.45
	var terrain: Dictionary = Space.sample(actor, point)
	if bool(terrain.get("water", false)) and float(terrain.altitude) < float(terrain.water_level):
		return {"protected": true, "reason": "underwater", "rays": 0}
	var excluded: Array[RID] = []
	if actor is CollisionObject3D: excluded.append(actor.get_rid())
	var world: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var roof := PhysicsRayQueryParameters3D.create(point, point + up * 22.0, 1 | 2 | 4)
	roof.exclude = excluded
	if world.intersect_ray(roof).is_empty(): return {"protected": false, "reason": "open", "rays": 1}
	var wind: Array = sample.get("wind_velocity", [0.0, 0.0, 0.0])
	var direction := Vector3(wind[0], wind[1], wind[2]).slide(up)
	if direction.length_squared() < 0.000001: direction = -actor.global_basis.z.slide(up)
	var wall := PhysicsRayQueryParameters3D.create(point, point - direction.normalized() * 6.0, 1 | 2 | 4)
	wall.exclude = excluded
	var blocked: bool = not world.intersect_ray(wall).is_empty()
	return {"protected": blocked, "reason": "roof_and_windbreak" if blocked else "open_sided_roof", "rays": 2}

static func local_sample(owner: Node, actor: Node3D, body: Dictionary, clock: float) -> Dictionary:
	var adapter: RefCounted = Space.adapter(owner)
	if adapter == null: return {}
	var terrain: Dictionary = Space.sample(owner, actor.global_position)
	if body.has(Climate.FIELD): terrain[Climate.FIELD] = body[Climate.FIELD]
	terrain.atmosphere = adapter.terrain.surface.body.get("atmosphere", "temperate")
	return Regional.sample(body.id, body.seed, clock, Space.address(owner, actor.global_position),
		adapter.terrain.surface.body.radius, terrain)

func tick(owner: Node, body: Dictionary, campaign: Dictionary, player: Node3D, sample: Dictionary,
		preview_active: bool, tribe_active: bool) -> void:
	var clock: float = float(campaign.elapsed_seconds)
	# A new live owner has no catch-up debt, even if the campaign continued away.
	if not is_same(_attached_body, body):
		_attached_body = body
		if body.has(Receipt.FIELD) or sample.get("extreme_storm_schema") == 1:
			Receipt.attach(body, campaign.player_object_id, clock)
		last_result = {"damage": 0.0, "reason": "arrival", "clock": clock}
		return
	if not body.has(Receipt.FIELD) and sample.get("extreme_storm_schema") != 1: return
	var value: Dictionary = body.get(Receipt.FIELD, {})
	if value.is_empty(): value = Receipt.attach(body, campaign.player_object_id, clock)
	if value.is_empty(): return
	var guard: bool = preview_active or tribe_active or player.is_dead or player.recovery.protected() \
		or bool(player.get("waiting_for_terrain")) or not Space.ground_ready(owner, player.global_position) \
		or owner.get_tree().paused
	var intensity: float = float(sample.get("hazard_intensity", 0.0)) if sample.get("extreme_storm_schema") == 1 else 0.0
	var cover: Dictionary = {"protected": true, "reason": "inactive", "rays": 0}
	if not guard and intensity >= 0.25: cover = protection(player, sample)
	var before: float = player.current_health
	var ratio: float = Receipt.consume(value, body, clock, intensity, guard or cover.protected, player.get_health_ratio())
	if ratio > 0.0: player.receive_damage(ratio * player.maximum_health)
	last_result = {"damage": before - player.current_health, "protected": guard or cover.protected,
		"reason": cover.reason, "intensity": intensity, "event_id": value.event_id,
		"spent_ratio": value.spent_ratio, "clock": clock, "rays": cover.rays}

static func suspends_work(sample: Dictionary, cover: Dictionary, order: String) -> bool:
	return order not in ["wait", "move"] and sample.get("extreme_storm_schema") == 1 \
		and not bool(sample.get("preview", false)) and float(sample.get("hazard_intensity", 0.0)) >= 0.25 \
		and not bool(cover.get("protected", false))
