extends RefCounted
class_name CampaignState

const Ids = preload("res://core/campaign/campaign_ids.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const SCHEMA: int = 1
const GENERATOR_VERSION: String = "planetary_v9"
const SURFACE_MODE: String = "legacy_plane_v9"

var data: Dictionary = {}


func reset(identity: String = "") -> void:
	var campaign_id: String = Ids.create("campaign") if identity.is_empty() else identity
	data = {
		"schema": SCHEMA, "id": campaign_id,
		"player_species_id": Ids.scoped("species", campaign_id, "player"),
		"player_faction_id": Ids.scoped("faction", campaign_id, "player"),
		"player_object_id": Ids.scoped("object", campaign_id, "player"),
		"bodies": {}, "design_refs": {}, "event_cursors": {}, "recent_events": [],
		"elapsed_seconds": 0.0, "time_scale": 1.0, "pending_transition": {},
		"completed_transitions": {},
	}


func ensure_initialized() -> void:
	if data.is_empty():
		reset()


func export_state() -> Dictionary:
	ensure_initialized()
	return data.duplicate(true)


func import_state(value: Dictionary) -> void:
	reset(str(value.get("id", "")))
	for key in data.keys():
		if value.has(key):
			data[key] = value[key]
	data = data.duplicate(true)


func body_for_seed(world_seed: int, system_seed: int) -> Dictionary:
	ensure_initialized()
	# Legacy seed lookup is only an adapter; callers store the returned body ID.
	var key: String = str(world_seed)
	var bodies: Dictionary = data["bodies"]
	if not bodies.has(key):
		var system_id: String = Ids.scoped("system", data["id"], str(system_seed))
		bodies[key] = {"id": Ids.scoped("body", system_id, key), "system_id": system_id,
			"seed": world_seed, "generator_version": GENERATOR_VERSION, "surface_mode": SURFACE_MODE}
	return bodies[key].duplicate(true)


func region_id(body_id: String, coordinates: Vector2i) -> String:
	return Ids.scoped("region", body_id, "legacy:%d:%d" % [coordinates.x, coordinates.y])


func species_id(body_id: String, species_seed: int) -> String:
	return Ids.scoped("species", body_id, str(species_seed))


func surface_address(body_id: String, position: Array, yaw: float) -> Dictionary:
	return {"body_id": body_id, "mode": SURFACE_MODE, "position": position.duplicate(), "yaw": yaw}


func accept_event(event: GameEvent, current_phase: int) -> bool:
	ensure_initialized()
	if not event.is_valid() or event.campaign_id != data["id"] or event.phase != current_phase:
		return false
	var cursors: Dictionary = data["event_cursors"]
	if event.sequence <= int(cursors.get(event.channel(), 0)):
		return false
	# Producers deliver ordered events. Keeping a high-water mark never reopens
	# old rewards, unlike evicting IDs from a fixed-size deduplication cache.
	cursors[event.channel()] = event.sequence
	var recent: Array = data["recent_events"]
	recent.append(event.to_dict())
	if recent.size() > 32:
		recent.pop_front()
	return true


func next_event(kind: int, target_id: String, phase: int, outcome: String) -> GameEvent:
	ensure_initialized()
	var event := GameEvent.new()
	event.kind = kind
	event.campaign_id = data["id"]
	event.source_id = data["player_object_id"]
	event.target_id = target_id
	event.phase = phase
	event.outcome = outcome
	event.sequence = int(data["event_cursors"].get(event.channel(), 0)) + 1
	return event



func object_id(region_identity: String, instance_key: String) -> String:
	return Ids.scoped("object", region_identity, instance_key)
