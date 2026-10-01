extends RefCounted
## Route-only instrumentation. Poll physical publication each frame and pending
## regional records every 250 ms; never alter the game clock, budgets or actors.
const Space = preload("res://world/surface/gameplay_space.gd")
const Model = preload("res://world/surface/campaign_population_state.gd")
const LIMIT: int = 4096
var events: Array[Dictionary] = []
var generated: Dictionary = {}
var eligible: Dictionary = {}
var physical: Dictionary = {}
var started: int = 0
var next_scan: int = 0
var dropped: int = 0

func sample(population: Node, now: int) -> void:
	if started == 0: started = now
	if now >= next_scan:
		next_scan = now + 250000
		for cell: Dictionary in Model.Cells.nearby(population.descriptor, population.player.location()).values():
			var region: Dictionary = population.storage.region(cell.id, false)
			if region.is_empty() or not region.generated: continue
			if not generated.has(cell.id):
				generated[cell.id] = true
				var center: Dictionary = Model.Cube.address(population.descriptor.id, cell.face,
					-1.0 + (cell.x + 0.5) * cell.step, -1.0 + (cell.y + 0.5) * cell.step)
				center.height = population.player.location().height
				_event({"kind":"region", "id":cell.id, "since_population_ms":(now-started)/1000.0,
					"distance_m":Space.resolve(population, center).distance_to(population.player.global_position)})
			for section: String in ["objects", "plants"]:
				for record: Dictionary in region[section].values():
					if Space.resolve(population, record.location).distance_to(population.player.global_position) < population.ACTIVE_DISTANCE:
						var key: String = section + ":" + str(record.id)
						if not eligible.has(key): eligible[key] = now
	var current: Dictionary = {}
	for kind: String in ["animals", "plants", "nests"]:
		for id: String in population.get(kind):
			var node: Node3D = population.get(kind)[id]
			if not is_instance_valid(node): continue
			var key: String = kind + ":" + id
			current[key] = true
			if physical.has(key): continue
			var entry: Dictionary = {"kind":kind, "id":id, "since_population_ms":(now-started)/1000.0,
				"distance_m":node.global_position.distance_to(population.player.global_position)}
			var pending_key: String = ("objects" if kind == "animals" else "plants") + ":" + id
			entry.eligible_wait_lower_bound_ms = (now-int(eligible[pending_key]))/1000.0 if eligible.has(pending_key) else null
			if kind == "animals":
				entry.role = node.ecological_role
				entry.colony_id = node.colony_id
			_event(entry)
	physical = current

func _event(entry: Dictionary) -> void:
	if events.size() < LIMIT: events.append(entry)
	else: dropped += 1

func report() -> Dictionary:
	return {"events":events.duplicate(true), "dropped_events":dropped, "limit":LIMIT,
		"pending_poll_ms":250, "note":"Physical publication sampled per process frame; pending eligibility sampled every 250 ms, so waits are lower bounds. Distance at publication measures proximity pop-in, not camera visibility."}
