extends RefCounted
## Observational bounds, never force terrain, meshes, colliders or AI forward.
const Space = preload("res://world/surface/gameplay_space.gd")
const Model = preload("res://world/surface/campaign_population_state.gd")
const LIMIT: int = 8192
var data: Dictionary = {"events": [], "work": [], "dropped": 0, "work_dropped": 0, "sample_work_max_ms": 0.0,
	"notes": "Process-frame observations after physics. Resident cached record/ground checks at 250 ms are upper bounds on first observed readiness; this probe never loads or marks a storage page writable. Mesh means a published MeshInstance3D with a non-null mesh, not GPU upload completion or camera visibility. Collider means a published enabled CollisionShape3D, not a physics-server synchronization timestamp. First AI step observation is an upper bound from the live wildlife decision timer changing after publication; earlier unobserved steps are possible and dead animals have no living AI observation. Lifetime maxima do not establish frame causality."}
var seen: Dictionary = {}
var physical: Dictionary = {}
var next_scan: int = 0
var started: int = 0

func record_work(kind: String, label: String, begin: int, end: int) -> void:
	if data.work.size() >= LIMIT:
		data.work_dropped += 1
		return
	data.work.append({"kind": kind, "label": label, "started_us": begin, "finished_us": end, "ms": (end - begin) / 1000.0})

func sample(population: Node, now: int, stage: String) -> void:
	var begin: int = Time.get_ticks_usec()
	if started == 0: started = now
	if now >= next_scan:
		next_scan = now + 250000
		for cell: Dictionary in Model.Cells.nearby(population.descriptor, population.player.location()).values():
			var region: Dictionary = population.storage.store.cache.get("r:" + str(cell.id), {})
			if region.is_empty(): continue
			for section: String in ["objects", "plants"]:
				for record: Dictionary in region.get(section, {}).values():
					_observe_record(population, record, "animals" if section == "objects" else "plants", now, stage)
			var colony: Dictionary = region.get("colony", {})
			if not colony.is_empty():
				_observe_record(population, {"id": colony.id, "location": colony.anchor}, "nests", now, stage)
	for kind: String in ["animals", "plants", "nests"]:
		var present: Dictionary = population.get(kind)
		for id: String in present:
			var node: Node3D = present[id]
			if not is_instance_valid(node): continue
			var key: String = kind + ":" + id
			var instance: int = node.get_instance_id()
			if not physical.has(key) or physical[key].instance != instance:
				physical[key] = {"instance": instance, "ai": false,
					"timer": float(node._decision_timer) if kind == "animals" else 0.0,
					"mesh": false, "collider": false}
				_event(population, kind, id, "physical", node.global_position, now, stage)
			var value: Dictionary = physical[key]
			if not value.mesh or not value.collider:
				var ready: Dictionary = published_components(node)
				for component: String in ["mesh", "collider"]:
					if not value[component] and ready[component]:
						value[component] = true
						_event(population, kind, id, component, node.global_position, now, stage)
			if kind == "animals" and not value.ai and not node.is_dead and float(node._decision_timer) != value.timer:
				value.ai = true
				_event(population, kind, id, "first_ai_step_observed", node.global_position, now, stage)
	data.sample_work_max_ms = maxf(data.sample_work_max_ms, (Time.get_ticks_usec() - begin) / 1000.0)

func _observe_record(population: Node, record: Dictionary, kind: String, now: int, stage: String) -> void:
	var point: Vector3 = Space.resolve(population, record.location)
	if point.distance_squared_to(population.player.global_position) > population.ACTIVE_DISTANCE * population.ACTIVE_DISTANCE: return
	var key: String = kind + ":" + str(record.id)
	if not seen.has(key):
		seen[key] = false
		_event(population, kind, record.id, "record", point, now, stage)
	if not seen[key] and Space.ground_ready(population, point):
		seen[key] = true
		_event(population, kind, record.id, "terrain_ready_observed", point, now, stage)

static func published_components(node: Node) -> Dictionary:
	var result: Dictionary = {"mesh": false, "collider": false}
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is MeshInstance3D and current.is_inside_tree() and current.mesh != null: result.mesh = true
		if current is CollisionShape3D and current.is_inside_tree() and current.shape != null and not current.disabled: result.collider = true
		if result.mesh and result.collider: break
		for child: Node in current.get_children(): pending.append(child)
	return result

func _event(population: Node, kind: String, id: String, component: String, point: Vector3, now: int, stage: String) -> void:
	if data.events.size() >= LIMIT:
		data.dropped += 1
		return
	data.events.append({"tick_us": now, "since_population_ms": (now - started) / 1000.0,
		"stage": stage, "kind": kind, "id": id, "component": component,
		"distance_m": point.distance_to(population.player.global_position)})
