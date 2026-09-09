extends RefCounted
## Read-only bridges. No discoveries, rewards, generation state or saves are
## written here. A later surface runtime can supply this same snapshot contract.
const MapProjection = preload("res://core/map/surface_map_projection.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const COLORS := {"forest": Color("3d6854"), "dense_forest": Color("315346"),
	"grassland": Color("718663"), "grass": Color("718663"), "savanna": Color("a99a68"),
	"steppe": Color("999168"), "desert": Color("bca879"), "snow": Color("d1ddd8"),
	"ice": Color("d1ddd8"), "alpine": Color("9ea7a0"), "rocky_highlands": Color("85877a"),
	"wetland": Color("537969"), "coast": Color("b8ab7c")}

static func campaign_snapshot(player: Node3D, tree: SceneTree) -> Dictionary:
	if not is_instance_valid(player) or not player.is_inside_tree(): return {}
	var state: Node = tree.root.get_node("GameState")
	var phase: int = state.current_phase
	var tribe := tree.get_first_node_in_group(&"tribe_controller")
	var in_tribe: bool = tribe != null and tribe.is_active()
	if not player.is_physics_processing() and not in_tribe: return {}
	var manager: Node = tree.current_scene.get_node_or_null("WorldManager") if tree.current_scene != null else null
	if manager != null and not bool(manager.get("world_initialized")): return {}
	var body_key: String = str(state.get_world_seed())
	if not state.campaign.data["bodies"].has(body_key): state.get_current_body()
	var body: Dictionary = state.campaign.data["bodies"][body_key]
	if str(body.get("surface_mode", "")) != "legacy_plane_v9": return {}
	var id: String = str(body["id"])
	var actual: Dictionary = body
	var focus: Vector3 = tribe.map_focus() if in_tribe else player.global_position
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_basis.z if camera != null else -player.global_basis.z
	var markers: Array[Dictionary] = []
	var home: Dictionary = actual.get("home_group", {})
	if home.get("body_id") == id and Home.valid_position(home.get("anchor")):
		markers.append({"kind": "home", "address": _plane(id, home["anchor"]), "name": "Heimat"})
	var group: Dictionary = actual.get("tribe", {}) if in_tribe else home
	# Records must belong to this body's own group. Never enumerate wildlife.
	if home.get("body_id") == id:
		var owner := tribe if in_tribe else tree.get_first_node_in_group(&"home_group_controller")
		for member: Dictionary in group.get("members", []):
			if markers.size() >= 64: break
			if not Home.valid_position(member.get("position")): continue
			var address: Dictionary = _plane(id, member["position"])
			if is_instance_valid(owner):
				var actor: Node3D = owner.actors.get(str(member.get("id", "")))
				if is_instance_valid(actor): address = MapProjection.plane_address(id, actor.global_position)
			markers.append({"kind": "resident" if in_tribe else "companion", "address": address,
				"name": str(member.get("name", "")), "selected": in_tribe and str(member.get("id", "")) in tribe.selected})
	return {"context_id": str(state.campaign.data["id"]) + ":" + id, "address": MapProjection.plane_address(id, focus),
		"forward": forward, "phase": phase, "body_radius": 0.0, "markers": markers, "group_view": in_tribe,
		"sample": sample_plane.bind(tree.root.get_node("WorldGenerator"))}

static func laboratory_snapshot(lab: Node3D) -> Dictionary:
	if not is_instance_valid(lab) or not lab._ready_complete or lab.view_mode != "surface": return {}
	if not is_instance_valid(lab.walker) or not is_instance_valid(lab.terrain): return {}
	if is_instance_valid(lab.galaxy_panel) and lab.galaxy_panel.visible: return {}
	var address: Dictionary = lab.walker.location()
	var body: Dictionary = lab.terrain.surface.body
	return {"context_id": "lab:" + str(body["id"]) + ":" + str(body.get("terrain_revision", 1)),
		"address": address, "forward": lab.walker.forward, "phase": 0, "body_radius": float(body["radius"]),
		"markers": [], "group_view": false, "sample": sample_sphere.bind(lab.terrain.surface)}

static func _plane(id: String, p: Array) -> Dictionary:
	return {"body_id": id, "mode": "legacy_plane_v9", "position": p.duplicate()}

static func sample_plane(address: Dictionary, generator: Node) -> Color:
	var x: float = address.position[0]
	var z: float = address.position[2]
	var height: float = generator.get_terrain_height(x, z)
	var water: float = generator.get_water_level(x, z)
	if height < water - 0.08:
		return Color("387f96").lerp(Color("234d6c"), clampf((water - height) / 18.0, 0.0, 1.0))
	var biome: String = generator.get_biome_key(x, z, height)
	var base: Color = COLORS.get(biome, COLORS["grassland"])
	return base.lightened(clampf(height / 200.0, -0.12, 0.16))

static func sample_sphere(address: Dictionary, surface: RefCounted) -> Color:
	var d: Array = Cube.direction(address.face, address.u, address.v)
	var height: float = surface.height_precise(d)
	if surface.body.get("kind") == "planet" and height < 0.0:
		return Color("387f96").lerp(Color("234d6c"), clampf(-height / 120.0, 0.0, 1.0))
	return surface.color_at(Cube.vector(d), height).lerp(Color("b7c0ad"), 0.14)
