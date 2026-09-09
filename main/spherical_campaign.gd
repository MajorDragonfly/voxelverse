extends Node3D
## Shared campaign entry, with no laboratory store or fixture identities.
## Terrain, radial movement and maps work here; full creature/tribe consumers
## are separate M1f/M1g acceptance gates before replacing the regular start.
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
var world_initialized: bool = false
var _sun: DirectionalLight3D

func _ready() -> void:
	var state := get_node("/root/GameState")
	var body: Dictionary = state.get_current_body()
	if body.get("surface_mode") != Cube.MODE or not Surface.validate(body).is_empty():
		get_node("/root/SessionFlow").call_deferred("_fail_loading", "Dieser Spielstand besitzt keinen gültigen Kugelkontext.")
		return
	var saves := get_node("/root/SaveGameService")
	var design: Dictionary = Blueprint.load_best_available()
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
	player = Player.new()
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
	flora = preload("res://world/surface/surface_ecosystem.gd").new()
	flora.adapter = adapter
	flora.player = player
	flora.spawn = body.surface_context.spawn.duplicate(true)
	flora.wildlife_enabled = false
	add_child(flora)
	var map := preload("res://ui/minimap/minimap_hud.gd").new()
	map.player = player
	add_child(map)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22)
	label.text = "Kugelwelt · Früher Kampagnenstand\nBewegen, Springen, Weltkarte und Speichern\nNahrung, Begegnungen und Siedlungen folgen. · Esc: Pause"
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(label)
	var frame: Basis = Cube.frame(player.up_direction)
	_sun.basis = frame.rotated(frame.x, -0.65)

func _process(_delta: float) -> void:
	if is_instance_valid(player) and not world_initialized:
		world_initialized = terrain.ground_ready(Cube.global_position(player.position, terrain.origin))

func _unhandled_input(event: InputEvent) -> void:
	if not world_initialized or get_tree().paused or get_node("/root/SessionFlow").loading: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.turn(event.relative)
	if event.is_action_pressed("jump"): player.jump_requested = true

func map_snapshot() -> Dictionary:
	if not world_initialized or not is_instance_valid(player) or get_node("/root/SessionFlow").loading: return {}
	var body: Dictionary = terrain.surface.body
	return {"context_id": str(get_node("/root/GameState").campaign.data.id) + ":" + str(body.id),
		"address": player.location(), "forward": player.forward, "phase": 0, "body_radius": body.radius,
		"markers": [], "group_view": false,
		"sample": preload("res://ui/minimap/minimap_source.gd").sample_sphere.bind(terrain.surface)}

func _exit_tree() -> void:
	if is_instance_valid(flora): flora.close()
	if adapter != null: adapter.close()

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("83b4ce")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c4d8e4")
	environment.ambient_light_energy = 0.22
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("83b4ce")
	environment.fog_depth_begin = 1500.0
	environment.fog_depth_end = 18000.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 0.8
	_sun.shadow_enabled = true
	add_child(_sun)
