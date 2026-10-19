extends RefCounted
## Read only the local D2 ownership ledger. Never enumerate or reveal wildlife.
const Surface = preload("res://core/map/surface_map_projection.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Animals = preload("res://world/domestication/campaign_animal_state.gd")

static func collect(body: Dictionary, faction: String, tree: SceneTree) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if faction.is_empty(): return result
	var saved: Dictionary = body.get(Animals.FIELD, {})
	var registry: Dictionary = saved.get("registry", {})
	var live: Dictionary = {}
	for runtime: Node in tree.get_nodes_in_group(&"domestication_runtime"):
		# A loaded registry remains authoritative at 0x simulation speed.
		# current_registry() is empty after unload/invalidation.
		var loaded: Dictionary = runtime.current_registry()
		if loaded.get("body_id") != body.get("id"): continue
		registry = loaded
		live = runtime.animals
		break
	if registry.get("body_id") != body.get("id"): return result
	for id: String in registry.get("animals", {}):
		if result.size() >= Animals.CAPACITY: break
		var animal: Dictionary = registry.animals[id]
		if animal.get("body_id") != body.get("id") or animal.get("status") != "tamed" or animal.get("owner_faction_id") != faction or float(animal.get("health", 0.0)) <= 0.0: continue
		var position: Variant = animal.get("position")
		var address: Dictionary = position if position is Dictionary else {"body_id": body.id, "mode": body.surface_mode, "position": position}
		var actor: Node3D = live.get(id)
		if is_instance_valid(actor):
			var live_place: Variant = Space.encode(actor, actor.global_position)
			address = live_place if live_place is Dictionary else Surface.plane_address(body.id, actor.global_position)
		if not Surface.valid(address) or address.body_id != body.id or address.mode != body.surface_mode: continue
		result.append({"kind": "owned_animal", "id": id, "address": address,
			"name": str(saved.get("sources", {}).get(id, {}).get("name", ""))})
	return result
