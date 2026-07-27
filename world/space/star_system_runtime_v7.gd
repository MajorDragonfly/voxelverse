extends Node
class_name StarSystemRuntimeV7

const PlanetCatalog = preload(
	"res://world/generation/planet_catalog_v7.gd"
)

@export var enable_planet_cycle_debug_key: bool = true
@export var show_planet_runtime_label: bool = true

var system: Dictionary = {}
var active_planet: Dictionary = {}
var _runtime_label: Label


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
	if not enable_planet_cycle_debug_key:
		return
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo or event.keycode != KEY_F8:
		return
	get_viewport().set_input_as_handled()
	cycle_to_next_planet()


func cycle_to_next_planet() -> void:
	var planet_count: int = PlanetCatalog.get_planet_count(system)
	if planet_count <= 1:
		return
	var current_index: int = int(active_planet.get("index", 0))
	activate_planet(posmod(current_index + 1, planet_count))


func activate_planet(planet_index: int) -> void:
	var planet: Dictionary = PlanetCatalog.get_planet(system, planet_index)
	if planet.is_empty():
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and game_state.has_method("activate_planet"):
		game_state.call(
			"activate_planet",
			int(system.get("system_seed", 1)),
			planet_index,
			int(planet.get("planet_seed", 1))
		)
	else:
		WorldGenerator.set_world_seed(int(planet.get("planet_seed", 1)))
	active_planet = planet
	_update_runtime_label()
	get_tree().reload_current_scene()


func get_system() -> Dictionary:
	return system.duplicate(true)


func get_active_planet() -> Dictionary:
	return active_planet.duplicate(true)


func _create_runtime_label() -> void:
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var hud := player.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	_runtime_label = Label.new()
	_runtime_label.name = "PlanetRuntimeV7Label"
	_runtime_label.offset_left = 18.0
	_runtime_label.offset_top = 160.0
	_runtime_label.offset_right = 450.0
	_runtime_label.offset_bottom = 220.0
	_runtime_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_runtime_label)


func _update_runtime_label() -> void:
	if _runtime_label == null:
		return
	_runtime_label.text = (
		"System %s · Planet %s · %s\nF8: travel to next generated planet"
		% [
			str(system.get("system_name", "Unknown System")),
			str(active_planet.get("name", "Unknown Planet")),
			str(active_planet.get("planet_class", "unknown")).capitalize(),
		]
	)
