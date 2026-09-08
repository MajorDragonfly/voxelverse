extends Node
class_name StarSystemRuntimeV7

const PlanetCatalog = preload(
	"res://world/generation/planet_catalog_v7.gd"
)

# F8 is Godot Editor's Stop Running Project shortcut. Using it as an in-game
# debug key made the game window close before Voxelverse could process it.
const DEBUG_PLANET_CYCLE_KEY: Key = KEY_P

signal planet_transition_started(planet_index: int, planet_seed: int)

@export var enable_planet_cycle_debug_key: bool = true
@export var show_planet_runtime_label: bool = false
@export var reload_scene_on_planet_change: bool = true

var system: Dictionary = {}
var active_planet: Dictionary = {}
var _runtime_label: Label
var _transition_in_progress: bool = false


func _ready() -> void:
	add_to_group(&"star_system_runtime")
	var game_state := get_node_or_null("/root/GameState")
	var system_seed: int = WorldGenerator.get_world_seed()
	var planet_index: int = 0
	if game_state != null:
		if game_state.has_method("get_system_seed"):
			system_seed = int(game_state.call("get_system_seed"))
		if game_state.has_method("get_current_planet_index"):
			planet_index = int(game_state.call("get_current_planet_index"))
	system = PlanetCatalog.create_system(system_seed)
	active_planet = PlanetCatalog.get_planet(system, planet_index)
	if active_planet.is_empty():
		active_planet = PlanetCatalog.get_planet(system, 0)
	if show_planet_runtime_label:
		_create_runtime_label()
	_update_runtime_label()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_planet_cycle_debug_key or _transition_in_progress:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (
		key_event.keycode != DEBUG_PLANET_CYCLE_KEY
		and key_event.physical_keycode != DEBUG_PLANET_CYCLE_KEY
	):
		return
	get_viewport().set_input_as_handled()
	cycle_to_next_planet()


func cycle_to_next_planet() -> void:
	if _transition_in_progress:
		return
	var planet_count: int = PlanetCatalog.get_planet_count(system)
	if planet_count <= 1:
		return
	var current_index: int = int(active_planet.get("index", 0))
	activate_planet(posmod(current_index + 1, planet_count))


func activate_planet(planet_index: int) -> void:
	if _transition_in_progress:
		return
	var planet: Dictionary = PlanetCatalog.get_planet(system, planet_index)
	if planet.is_empty():
		return
	_transition_in_progress = true
	var planet_seed: int = int(planet.get("planet_seed", 1))
	planet_transition_started.emit(planet_index, planet_seed)

	var save_service := get_node_or_null("/root/SaveGameService")
	if save_service != null and save_service.has_method("prepare_planet_transition"):
		if not bool(save_service.call("prepare_planet_transition")):
			_transition_in_progress = false
			return
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("activate_planet"):
		game_state.call(
			"activate_planet",
			int(system.get("system_seed", 1)),
			planet_index,
			planet_seed
		)
	else:
		WorldGenerator.set_world_seed(planet_seed)
	active_planet = planet
	_update_runtime_label()
	if save_service != null and save_service.has_method("queue_current_world_restore"):
		save_service.call("queue_current_world_restore")

	if reload_scene_on_planet_change:
		call_deferred("_reload_after_planet_transition")
	else:
		_transition_in_progress = false


func get_system() -> Dictionary:
	return system.duplicate(true)


func get_active_planet() -> Dictionary:
	return active_planet.duplicate(true)


func get_debug_cycle_key_name() -> String:
	return "P"


func _reload_after_planet_transition() -> void:
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		_transition_in_progress = false
		push_error("Could not reload planet scene: %s" % error)


func _create_runtime_label() -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var hud := player.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	_runtime_label = Label.new()
	_runtime_label.name = "PlanetRuntimeV7Label"
	_runtime_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_runtime_label.offset_left = -520.0
	_runtime_label.offset_top = 18.0
	_runtime_label.offset_right = -18.0
	_runtime_label.offset_bottom = 76.0
	_runtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_runtime_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runtime_label.add_theme_font_size_override("font_size", 13)
	_runtime_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.95, 0.92))
	hud.add_child(_runtime_label)


func _update_runtime_label() -> void:
	if _runtime_label == null:
		return
	_runtime_label.text = (
		"%s · %s · %s · P next planet"
		% [
			str(system.get("system_name", "Unknown System")),
			str(active_planet.get("name", "Unknown Planet")),
			str(active_planet.get("planet_class", "unknown")).capitalize(),
		]
	)
