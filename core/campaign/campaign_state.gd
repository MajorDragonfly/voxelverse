extends RefCounted
class_name CampaignState

const Ids = preload("res://core/campaign/campaign_ids.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const Registry = preload("res://core/campaign/body_registry.gd")
const SCHEMA: int = Registry.CAMPAIGN_SCHEMA
const Surface = preload("res://core/campaign/surface_context.gd")
const GENERATOR_VERSION: String = "planetary_v9"
const SURFACE_MODE: String = "legacy_plane_v9"

var data: Dictionary = {}
var last_error: String = ""


func reset(identity: String = "") -> void:
	last_error = ""
	var campaign_id: String = Ids.create("campaign") if identity.is_empty() else identity
	data = {
		"schema": SCHEMA, "id": campaign_id,
		"player_species_id": Ids.scoped("species", campaign_id, "player"),
		"player_faction_id": Ids.scoped("faction", campaign_id, "player"),
		"player_object_id": Ids.scoped("object", campaign_id, "player"),
		"bodies": {}, "body_lookup": {}, "design_refs": {}, "event_cursors": {}, "recent_events": [],
		"elapsed_seconds": 0.0, "time_scale": 1.0, "pending_transition": {},
		"completed_transitions": {},
		"surface_policy": SURFACE_MODE, "surface_migration": {},
	}


func ensure_initialized() -> void:
	if data.is_empty():
		reset()


func export_state() -> Dictionary:
	ensure_initialized()
	return data.duplicate(true)


func import_state(value: Dictionary) -> bool:
	var converted: Dictionary = Registry.upgrade_campaign(value)
	last_error = converted.get("error", "")
	if not converted.ok: return false
	data = converted.data
	return true


func get_body_by_id(body_id: String) -> Dictionary:
	return Registry.by_id(data, body_id).duplicate(true)


func body_record(body_id: String) -> Dictionary:
	return Registry.by_id(data, body_id)


func find_body(world_seed: int, system_id: String) -> Dictionary:
	return Registry.by_seed(data, world_seed, system_id).duplicate(true)

func find_body_id(world_seed: int, system_id: String) -> String:
	return str(Registry.by_seed(data, world_seed, system_id).get("id", ""))


func ensure_body(world_seed: int, system_seed: int, system_id: String = "") -> Dictionary:
	ensure_initialized()
	if world_seed < 1 or world_seed > 2147483647 or system_seed < 1 or system_seed > 2147483647:
		last_error = "Ungültiger Generatorseed für neuen Körper."
		return {}
	if system_id.is_empty(): system_id = Registry.system_identity(data.id, system_seed)
	var existing: Dictionary = Registry.by_seed(data, world_seed, system_id)
	if not existing.is_empty():
		last_error = ""
		return existing.duplicate(true)
	var key: String = Ids.scoped("body", system_id, str(world_seed))
	var bodies: Dictionary = data["bodies"]
	if bodies.has(key):
		last_error = "Körperidentität widerspricht dem Systemindex."
		return {}
	var record: Dictionary = {"id": key, "system_id": system_id, "seed": world_seed,
		"generator_version": GENERATOR_VERSION, "surface_mode": SURFACE_MODE}
	if data.get("surface_policy", SURFACE_MODE) == Surface.Cube.MODE:
		record = Surface.create(record)
		if record.is_empty():
			last_error = "Kein geeigneter Startbereich auf diesem Körper."
			return {}
	bodies[key] = record
	data.body_lookup[Registry.context_key(system_id, world_seed)] = key
	last_error = ""
	return bodies[key].duplicate(true)


## Compatibility construction API for old contract fixtures. Runtime reads use
## body_record/get_body_by_id; creation is explicit at new-game and travel.
func body_for_seed(world_seed: int, system_seed: int) -> Dictionary:
	return ensure_body(world_seed, system_seed)


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
