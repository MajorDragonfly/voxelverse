extends Node
## Bounded line-of-sight approximation. Each voice keeps its own filter and gain.
## Collider geometry is authoritative; no gameplay/terrain nodes are modified.

const MAX_VOICES := 17 # Sixteen effects plus the existing shoreline emitter.
const MAX_RAYS_PER_FRAME := 4
const SAMPLE_INTERVAL := 0.12
const BLOCKED_GAIN_DB := -9.0
const BLOCKED_CUTOFF_HZ := 1600.0

var enabled := true
var collision_mask: int = 0xFFFFFFFF
var queries_last_frame := 0
var _slots: Array[Dictionary] = []
var _next := 0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 110


func register_voice(voice: AudioStreamPlayer3D, destination: StringName) -> bool:
	if _slots.size() >= MAX_VOICES or not is_instance_valid(voice):
		return false
	for slot in _slots:
		if slot.voice == voice:
			return true
	var bus := StringName("VV Occlusion %02d" % _slots.size())
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus)
	AudioServer.set_bus_send(bus_index, destination)
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus_index, filter)
	AudioServer.set_bus_effect_enabled(bus_index, 0, false)
	voice.bus = bus
	voice.set_meta(&"occlusion_slot", _slots.size())
	_slots.append({"voice": voice, "destination": destination, "bus": bus,
		"filter": filter, "amount": 0.0, "target": 0.0, "due": 0.0})
	return true


func reset_voice(voice: AudioStreamPlayer3D) -> void:
	var index := int(voice.get_meta(&"occlusion_slot", -1))
	if index < 0 or index >= _slots.size():
		return
	var slot := _slots[index]
	slot.amount = 0.0
	slot.target = 0.0
	slot.due = 0.0
	_apply(slot)


func reset() -> void:
	for slot in _slots:
		if is_instance_valid(slot.voice):
			reset_voice(slot.voice)
	_next = 0


func get_amount(voice: AudioStreamPlayer3D) -> float:
	var index := int(voice.get_meta(&"occlusion_slot", -1))
	return float(_slots[index].amount) if index >= 0 and index < _slots.size() else 0.0


func _physics_process(delta: float) -> void:
	queries_last_frame = 0
	_clock += delta
	var camera := get_viewport().get_camera_3d()
	if not enabled or camera == null:
		for slot in _slots:
			slot.target = 0.0
	else:
		var visited := 0
		while visited < _slots.size() and queries_last_frame < MAX_RAYS_PER_FRAME:
			var slot := _slots[_next]
			_next = (_next + 1) % _slots.size()
			visited += 1
			var voice: AudioStreamPlayer3D = slot.voice
			if not is_instance_valid(voice) or not voice.playing:
				slot.target = 0.0
				continue
			if _clock < float(slot.due):
				continue
			slot.due = _clock + SAMPLE_INTERVAL
			if voice.get_world_3d() != camera.get_world_3d():
				slot.target = 0.0
				continue
			var source := instance_from_id(int(voice.get_meta(&"audio_source_id", 0))) as Node
			var result := _blocked(camera, voice, source)
			if result >= 0.0:
				slot.target = result
			else:
				slot.due = _clock # Continue fairly next frame after budget exhaustion.
	for slot in _slots:
		if not is_instance_valid(slot.voice) or not slot.voice.playing:
			slot.target = 0.0
		var speed := 12.0 if float(slot.target) > float(slot.amount) else 4.0
		slot.amount = move_toward(float(slot.amount), float(slot.target), delta * speed)
		_apply(slot)


func _blocked(camera: Camera3D, voice: AudioStreamPlayer3D, source: Node) -> float:
	var start := camera.global_position
	var finish := voice.global_position
	if not start.is_finite() or not finish.is_finite() or start.distance_squared_to(finish) < 0.09:
		return 0.0
	var excluded: Array[RID] = []
	var player := get_tree().get_first_node_in_group(&"player")
	for body in [source, player]:
		if body is CollisionObject3D:
			excluded.append(body.get_rid())
	var ancestor: Node = camera
	while ancestor != null:
		if ancestor is CollisionObject3D and not excluded.has(ancestor.get_rid()):
			excluded.append(ancestor.get_rid())
		ancestor = ancestor.get_parent()
	var space := camera.get_world_3d().direct_space_state
	while queries_last_frame < MAX_RAYS_PER_FRAME:
		var query := PhysicsRayQueryParameters3D.create(start, finish, collision_mask, excluded)
		query.collide_with_areas = false
		query.hit_from_inside = true
		queries_last_frame += 1
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return 0.0
		var collider := hit.get("collider") as Node
		if collider == null:
			return 0.0
		# Source, listener/player body and opt-out geometry cannot muffle themselves.
		if _related(collider, source) or _related(collider, camera) or _related(collider, player) or _transparent(collider):
			excluded.append(hit.rid)
			continue
		# Footstep positions can touch the ground at the sound's endpoint.
		if Vector3(hit.position).distance_squared_to(finish) < 0.18 * 0.18:
			return 0.0
		return 1.0
	# Inconclusive queries retain their previous state and retry under the same cap.
	return -1.0


func _related(collider: Node, other: Node) -> bool:
	return is_instance_valid(other) and (collider == other or other.is_ancestor_of(collider) or collider.is_ancestor_of(other))


func _transparent(collider: Node) -> bool:
	var node := collider
	while node != null:
		if node.get_meta(&"audio_transparent", false) == true:
			return true
		node = node.get_parent()
	return false


func _apply(slot: Dictionary) -> void:
	var bus_index := AudioServer.get_bus_index(slot.bus)
	if bus_index < 0:
		return
	var amount := float(slot.amount)
	AudioServer.set_bus_volume_db(bus_index, amount * BLOCKED_GAIN_DB)
	slot.filter.cutoff_hz = exp(lerpf(log(20000.0), log(BLOCKED_CUTOFF_HZ), amount))
	AudioServer.set_bus_effect_enabled(bus_index, 0, amount > 0.001)


func _exit_tree() -> void:
	for slot in _slots:
		if is_instance_valid(slot.voice):
			slot.voice.bus = slot.destination
		var index := AudioServer.get_bus_index(slot.bus)
		if index >= 0:
			AudioServer.remove_bus(index)
	_slots.clear()
