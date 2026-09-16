extends Node3D
## Shared campaign entry, with no laboratory store or fixture identities.
## Terrain, radial movement and maps work here; full creature/tribe consumers
## are separate M1f/M1g acceptance gates before replacing the regular start.
const Space = preload("res://world/surface/gameplay_space.gd")
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Terrain = preload("res://world/surface/surface_terrain.gd")
const Adapter = preload("res://world/surface/radial_surface_adapter.gd")
const Player = preload("res://creatures/player/spherical_campaign_player.gd")
const Blueprint = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
var terrain: Node3D
var adapter: RefCounted
var player: CharacterBody3D
var flora: Node
var scenery: Node
var population: Node
var world_initialized: bool = false
var _atmosphere: Node3D

func _ready() -> void:
	var state := get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	var surface_problem: String = Surface.validate(body)
	if body.get("surface_mode") != Cube.MODE or not surface_problem.is_empty():
		get_node("/root/SessionFlow").call_deferred("_fail_loading", surface_problem if not surface_problem.is_empty() else "Dieser Spielstand besitzt keinen gültigen Kugelkontext.")
		return
	var saves := get_node("/root/SaveGameService")
	var design: Dictionary = Blueprint.load_best_available()
	if design.has("_protected_design_source"):
		get_node("/root/SessionFlow").call_deferred("_fail_loading", Blueprint.PROTECTED_NOTICE)
		return
	# Freeze the selected design (or the first default if none exists) once in
	# the current slot. Older embedded editor files remain untouched as evidence.
	if not saves._design_files.has(Blueprint.SAVE_PATH):
		saves.record_design(Blueprint.SAVE_PATH, JSON.stringify(Blueprint.serialize_snapshot(design), "\t"))
		if not saves.save_now():
			get_node("/root/SessionFlow").call_deferred("_fail_loading", "Der erste Kreaturenentwurf konnte nicht gesichert werden.")
			return
	_build_environment()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.configure(Surface.descriptor(body))
	adapter = Adapter.new(terrain)
	set_meta("campaign_surface", adapter)
	adapter.origin_shifted.connect(get_node("/root/AudioManager").director.surface_origin_shifted)
	var water := preload("res://world/surface/campaign_water.gd").new()
	water.name = "Water"
	add_child(water)
	player = preload("res://creatures/player/player.tscn").instantiate()
	player.set_script(Player)
	player.name = "Player"
	player.terrain = terrain
	player.adapter = adapter
	player.creature_design = design
	# Blueprint.load_best_available reads SaveGameService's authoritative slot
	# snapshot; it cannot inherit another campaign's editor files.
	add_child(player)
	player.collision_layer = 8
	player.collision_mask = 1 | 2 | 4
	player.place(body.surface_context.spawn)
	get_node("/root/SaveGameService")._apply_pending_runtime_state()
	adapter.bind(str(state.campaign.data.player_object_id), player, player.location(), player.forward)
	player.camera.near = 0.2
	player.camera.far = 30000.0
	player.camera.make_current()
	var underwater := preload("res://world/visuals/underwater_view.gd").new()
	underwater.sample_water = water.view_sample
	add_child(underwater)
	var manager := preload("res://world/surface/campaign_world_manager.gd").new()
	manager.name = "WorldManager"
	add_child(manager)
	var nest: Node3D = preload("res://world/resources/nests/nest.tscn").instantiate()
	nest.name = "Nest"
	nest.snap_to_terrain = false
	nest.persistent_visual_key = str(body.id) + ":nest"
	nest.visual_profile = terrain.surface.terrain
	nest.visual_biome = str(terrain.surface.sample(body.get("home_group", {}).get("anchor", body.surface_context.spawn)).biome)
	# The campaign population supplies radial food; do not start the plane streamer.
	nest.get_node("PlantFoodStreamer").free()
	add_child(nest)
	var nest_address: Dictionary = body.get("home_group", {}).get("anchor", body.surface_context.spawn).duplicate(true)
	if not body.has("home_group"): nest_address.height = terrain.surface.sample(nest_address).height + 0.02
	adapter.bind(str(body.id) + ":nest", nest, nest_address)
	flora = preload("res://world/surface/surface_ecosystem.gd").new()
	flora.adapter = adapter
	flora.player = player
	flora.spawn = body.surface_context.spawn.duplicate(true)
	flora.wildlife_enabled = false
	add_child(flora)
	scenery = preload("res://world/surface/surface_distant_scenery.gd").new()
	scenery.adapter = adapter
	scenery.player = player
	scenery.nearby = flora
	add_child(scenery)
	population = preload("res://world/surface/campaign_population.gd").new()
	population.adapter = adapter
	population.player = player
	population.descriptor = Surface.descriptor(body)
	add_child(population)
	var ecology := preload("res://world/surface/campaign_ecology.gd").new()
	ecology.population = population
	add_child(ecology)
	# ProgressionHUD on the shared player owns the single campaign minimap.
	var development := preload("res://core/development_tools.gd").new()
	development.name = "DevelopmentTools"
	add_child(development)
	var anchor: Dictionary = body.surface_context.spawn
	_atmosphere.configure(terrain.surface.terrain, int(terrain.surface.body.seed),
		Cube.vector(Cube.direction(anchor.face, anchor.u, anchor.v)), _atmosphere.campaign_sample)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and not world_initialized:
		world_initialized = terrain.ground_ready(Cube.global_position(player.position, terrain.origin)) and scenery.generation_complete

func map_snapshot() -> Dictionary:
	if not world_initialized or not is_instance_valid(player) or get_node("/root/SessionFlow").loading: return {}
	var state := get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	var tribe: Node = get_node("Nest/Tribe")
	var in_tribe: bool = tribe.is_active()
	var focus: Vector3 = tribe.map_focus() if in_tribe else player.global_position
	var camera: Camera3D = get_viewport().get_camera_3d()
	var markers: Array[Dictionary] = []
	var explorers: Array[Dictionary] = []
	var home: Dictionary = body.get("home_group", {})
	if not home.is_empty(): markers.append({"kind": "home", "address": home.anchor, "name": "Heimat"})
	var Settlements = preload("res://world/tribe/settlement_collection.gd")
	for id: String in Settlements.ids(body):
		if id != Settlements.origin_id(body): markers.append({"kind": "home", "address": Settlements.village(body, id).anchor, "name": "Außenlager"})
	var owner: Node = tribe if in_tribe else get_node("Nest/HomeGroup")
	var group: Dictionary = tribe.village() if in_tribe else home
	for member: Dictionary in group.get("members", []):
		var place: Dictionary = member.position
		var actor: Node3D = owner.actors.get(member.id)
		if is_instance_valid(actor):
			place = Space.encode(self, actor.global_position)
			if in_tribe: explorers.append(place)
		markers.append({"kind": "resident" if in_tribe else "companion", "address": place, "name": member.name,
			"selected": in_tribe and member.id in tribe.selected})
	if not in_tribe: explorers.append(player.location())
	return {"context_id": str(state.campaign.data.id) + ":" + str(body.id),
		"address": Space.encode(self, focus), "forward": -camera.global_basis.z, "phase": state.current_phase,
		"body_radius": body.surface_context.radius, "markers": markers, "explorers": explorers, "group_view": in_tribe,
		"sample": preload("res://ui/minimap/minimap_source.gd").sample_sphere.bind(terrain.surface)}

func known_map_places() -> Array[Dictionary]:
	var state := get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	var Source = preload("res://ui/world_map/world_map_source.gd")
	var places: Array[Dictionary] = []
	var home: Dictionary = body.get("home_group", {})
	places.append(Source._place(str(body.id) + ":nest", "Eigenes Nest", "nest", state.campaign.data.player_species_id, "", true, Space.encode(self, get_node("Nest").global_position)))
	if not home.is_empty(): places.append(Source._place(home.id, "Heimat deiner Spezies", "home", home.species_id, "", true, home.anchor))
	var Settlements = preload("res://world/tribe/settlement_collection.gd")
	for id: String in Settlements.ids(body):
		if id != Settlements.origin_id(body): places.append(Source._place(id, TranslationServer.translate("SETTLEMENT_OUTPOST"), "home", state.campaign.data.player_species_id, "", true, Settlements.village(body, id).anchor))
	if population != null:
		for record: Dictionary in population.records.values():
			var encounter: Dictionary = get_node("/root/ProgressionService").get_saved_creature_encounter(record.id)
			if encounter.get("relation") == "ally" and not encounter.get("dead", true):
				places.append(Source._place(record.id + ":habitat", "Befreundete Kreatur · Lebensraum", "friend_habitat", record.identity.species_id, record.id, false, record.get("home", record.location)))
	return places

func _exit_tree() -> void:
	if is_instance_valid(scenery): scenery.close()
	if is_instance_valid(flora): flora.close()
	if adapter != null: adapter.close()

func _build_environment() -> void:
	_atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd").new()
	add_child(_atmosphere)
