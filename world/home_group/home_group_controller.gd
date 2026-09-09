extends Node

const State = preload("res://world/home_group/home_group_state.gd")
const Companion = preload("res://world/home_group/home_companion.gd")
const GroupPanel = preload("res://ui/home_group/home_group_panel.gd")
const Assembly = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const Space = preload("res://world/surface/gameplay_space.gd")

var player: Node3D
var panel: CanvasLayer
var actors: Dictionary = {}
var problem: String = ""
var _campaign_id: String = ""
var _body_id: String = ""
var _timer: float = 0.0
var _ready_for_world: bool = false
var _transaction: bool = false
var _nest: Node3D
var _saves: Node
var _state: Node
var _generator: Node
var _manager: Node

func _ready() -> void:
	_nest = get_parent() as Node3D
	_state = get_node("/root/GameState")
	_saves = get_node("/root/SaveGameService")
	_generator = get_node("/root/WorldGenerator")
	panel = GroupPanel.new()
	panel.controller = self
	add_child(panel)
	_saves.game_loaded.connect(_on_loaded)
	_state.world_seed_changed.connect(_on_world_changed)
	_state.phase_changed.connect(_on_phase_changed)
	add_to_group(&"home_group_controller")

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_instance_valid(_manager) and get_tree().current_scene != null:
		_manager = get_tree().current_scene.get_node_or_null("WorldManager")
	if player == null or _manager == null or not bool(_manager.get("world_initialized")):
		return
	var body: Dictionary = _body_record()
	var campaign_id: String = str(_state.campaign.data["id"])
	if not _ready_for_world or campaign_id != _campaign_id or str(body["id"]) != _body_id:
		_campaign_id = campaign_id
		_body_id = str(body["id"])
		_ready_for_world = true
		_refresh_runtime()
	if is_active():
		# Rest heals slowly, without replacing food/water or awarding behavior.
		if not group_state().is_empty() and player.global_position.distance_to(home_position()) < 3.5:
			if float(player.get("current_hunger")) > 25.0 and float(player.get("current_thirst")) > 25.0:
				player.set("current_health", minf(float(player.get("maximum_health")), float(player.get("current_health")) + 0.25))
	panel.refresh_status()

func is_active() -> bool:
	return _ready_for_world and problem.is_empty() and is_instance_valid(player) and not bool(player.get("is_dead")) and int(_state.current_phase) == 0 and not get_tree().paused

func can_use_panel() -> bool:
	return _ready_for_world and is_instance_valid(player) and not bool(player.get("is_dead")) and int(_state.current_phase) == 0

func _body_record() -> Dictionary:
	# The record was already returned by reference; a deep copy solely for its
	# seed would repeatedly copy the complete exploration ledger.
	var key: String = str(_state.get_world_seed())
	if not _state.campaign.data["bodies"].has(key): _state.get_current_body_record()
	return _state.campaign.data["bodies"][key]

func group_state() -> Dictionary:
	var value: Variant = _body_record().get("home_group", {})
	return value if value is Dictionary else {}

func member_record(identity: String) -> Dictionary:
	for member in group_state().get("members", []):
		if str(member["id"]) == identity:
			return member
	return {}

func home_position() -> Vector3:
	var group: Dictionary = group_state()
	return Space.resolve(self, group["anchor"]) if group.has("anchor") else _nest.global_position

func _validate_group() -> String:
	var body: Dictionary = _body_record()
	if not body.has("home_group"):
		return ""
	return State.validate(body["home_group"], str(body["id"]), str(_state.campaign.data["player_species_id"]))

func _refresh_runtime() -> void:
	_clear_actors()
	problem = _validate_group()
	if not problem.is_empty() or group_state().is_empty():
		return
	var group: Dictionary = group_state()
	_nest.global_position = Space.resolve(self, group["anchor"])
	Space.orient(_nest)
	if int(_state.current_phase) != 0:
		return
	var blueprint: Dictionary = Assembly.load_best_available()
	if blueprint.is_empty():
		blueprint = Assembly.create_default()
	for i in range(group["members"].size()):
		var member: Dictionary = group["members"][i]
		var actor := Companion.new()
		# Actors use absolute positions and are siblings of the nest; relocating
		# the home never teleports residents or applies the nest transform twice.
		_nest.get_parent().add_child(actor)
		actor.setup(self, member, blueprint, i)
		actors[member["id"]] = actor

func _clear_actors() -> void:
	for actor in actors.values():
		if is_instance_valid(actor):
			Space.untrack(actor)
			actor.set_physics_process(false)
			actor.queue_free()
	actors.clear()

func _exit_tree() -> void:
	_clear_actors()

func _on_loaded(_path: String) -> void:
	_ready_for_world = false
	_clear_actors()
	if is_instance_valid(panel):
		panel.close_panel()

func _on_world_changed(_seed: int) -> void:
	_ready_for_world = false
	_clear_actors()
	if is_instance_valid(panel):
		panel.close_panel()

func _on_phase_changed(_phase: int) -> void:
	_clear_actors()
	_ready_for_world = false
	panel.close_panel()

func record_position(identity: String, position: Vector3) -> void:
	if _transaction or not problem.is_empty():
		return
	var member: Dictionary = member_record(identity)
	if not member.is_empty():
		member["position"] = Space.encode(self, position)

func establish_home() -> Dictionary:
	if not can_use_panel() or _transaction:
		return {"ok": false, "message": "Der Heimatplatz ist gerade nicht verfügbar."}
	problem = _validate_group()
	if not problem.is_empty():
		return {"ok": false, "message": problem}
	var location: Vector3 = player.global_position
	var hit: Dictionary = _floor_hit(location)
	var up: Vector3 = Space.up(self, location)
	if hit.is_empty() or hit["normal"].dot(up) < 0.9:
		return {"ok": false, "message": "Wähle festen, möglichst ebenen Boden."}
	location = Vector3(hit["position"]) + up * 0.02
	if not _dry(location):
		return {"ok": false, "message": "Der Heimatplatz muss auf trockenem Boden liegen."}
	# Check the full footprint and initial resident positions, not only the
	# centre ray; refuse ledges, water and obstructed spawn points.
	for offset in [Vector3(2.5, 0, 2.5), Vector3(-2.5, 0, 2.5), Vector3(0, 0, -2.0), Vector3(2.0, 0, 0), Vector3(-2.0, 0, 0)]:
		var sample: Dictionary = _floor_hit(Space.offset(self, location, offset))
		if sample.is_empty() or absf((Vector3(sample["position"]) - location).dot(up)) > 0.45 or sample["normal"].dot(up) < 0.9 or not _dry(sample["position"]):
			return {"ok": false, "message": "Hier ist zu wenig ebene, trockene Fläche für die Gruppe."}
		if not _clear_space(Vector3(sample["position"]) + up * 0.8):
			return {"ok": false, "message": "Bäume oder andere Hindernisse versperren den Heimatplatz."}
	var candidate: Dictionary = group_state().duplicate(true)
	if candidate.is_empty():
		candidate = State.create(str(_body_record()["id"]), str(_state.campaign.data["player_species_id"]), Vector3.ZERO)
		candidate.surface_mode = _body_record().surface_mode
		if candidate.surface_mode == State.Cube.MODE: candidate.schema = State.SCHEMA
		candidate.anchor = Space.encode(self, location)
		for member in candidate["members"]:
			var point: Vector3 = Space.offset(self, location, State.vector(member["position"]))
			point = Vector3(_floor_hit(point)["position"]) + up * 0.08
			member["position"] = Space.encode(self, point)
	else:
		candidate["anchor"] = Space.encode(self, location)
	var result: Dictionary = _commit(candidate)
	if result["ok"]:
		_refresh_runtime()
		result["message"] = "Heimatplatz gespeichert. Deine beiden Gefährten gehören dauerhaft zu dieser Nestgruppe."
	return result

func issue_order(order: String, identity: String = "") -> Dictionary:
	if order not in State.ORDERS or not can_use_panel() or _transaction:
		return {"ok": false, "message": "Dieser Befehl ist gerade nicht verfügbar."}
	problem = _validate_group()
	if not problem.is_empty():
		return {"ok": false, "message": problem}
	var candidate: Dictionary = group_state().duplicate(true)
	if candidate.is_empty():
		return {"ok": false, "message": "Lege zuerst einen Heimatplatz fest."}
	var found: bool = false
	for member in candidate["members"]:
		if identity.is_empty() or member["id"] == identity:
			member["order"] = order
			found = true
	if not found:
		return {"ok": false, "message": "Dieses Gruppenmitglied ist nicht verfügbar."}
	return _commit(candidate)

func _commit(candidate: Dictionary) -> Dictionary:
	var body: Dictionary = _body_record()
	var had_value: bool = body.has("home_group")
	var previous: Variant = body.get("home_group")
	_transaction = true
	body["home_group"] = candidate
	var saved: bool = bool(_saves.save_now())
	if not saved:
		if had_value:
			body["home_group"] = previous
		else:
			body.erase("home_group")
	_transaction = false
	return {"ok": saved, "message": "Befehl gespeichert." if saved else "Speichern fehlgeschlagen. Die bisherige Gruppe und ihre Befehle bleiben erhalten."}

func _floor_hit(position: Vector3) -> Dictionary:
	if not is_inside_tree() or _nest.get_world_3d() == null:
		return {}
	if not Space.ground_ready(self, position): return {}
	var up: Vector3 = Space.up(self, position)
	var ray := PhysicsRayQueryParameters3D.create(position + up * 1.2, position - up * 2.4, 1)
	ray.exclude = [player.get_rid()] if player is CollisionObject3D else []
	return _nest.get_world_3d().direct_space_state.intersect_ray(ray)

func has_ground(position: Vector3) -> bool:
	return not _floor_hit(position).is_empty()

func _dry(position: Vector3) -> bool:
	return Space.dry(self, position, 0.2)

func _clear_space(position: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Space.frame(self, position), position)
	query.collision_mask = 1 | 2
	query.exclude = [player.get_rid()] if player is CollisionObject3D else []
	return _nest.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func safe_step(actor: CharacterBody3D, direction: Vector3, distance: float = 1.2) -> bool:
	var next: Vector3 = actor.global_position + direction * distance
	var hit: Dictionary = _floor_hit(next)
	if hit.is_empty() or hit["normal"].dot(actor.up_direction) < 0.7 or not _dry(hit["position"]):
		return false
	var difference: float = (Vector3(hit["position"]) - actor.global_position).dot(actor.up_direction)
	if difference > 0.58 or difference < -0.85:
		return false
	var raised: Transform3D = actor.global_transform.translated(actor.up_direction * 0.56)
	return not actor.test_move(raised, direction * distance)
