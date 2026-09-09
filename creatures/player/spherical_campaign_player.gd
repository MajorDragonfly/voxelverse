extends "res://world/planet_lab/radial_walker.gd"
## The shared campaign owns identity, designs, progression and persistence.
## M1f attaches the existing needs/interaction controllers to this radial actor.
const Surface = preload("res://core/campaign/surface_context.gd")
var adapter: RefCounted
var _runtime: Dictionary = {}

func _ready() -> void:
	add_to_group(&"player")
	set_meta("surface_mode", Cube.MODE)
	super._ready()

func export_runtime_state() -> Dictionary:
	var result: Dictionary = _runtime.duplicate(true)
	result.merge({"surface_address": location(), "surface_forward": [forward.x, forward.y, forward.z],
		"surface_velocity": [velocity.x, velocity.y, velocity.z], "surface_pitch": pitch}, true)
	return result

func import_runtime_state(data: Dictionary) -> void:
	if not Surface.player_problem(data, terrain.surface.body).is_empty(): return
	_runtime = data.duplicate(true)
	pitch = float(data.surface_pitch)
	place(data.surface_address, Cube.vector(data.surface_forward))
	velocity = Cube.vector(data.surface_velocity)

func _physics_process(delta: float) -> void:
	if get_node("/root/SessionFlow").loading or not get_parent().world_initialized: return
	super._physics_process(delta)

func _movement_input() -> Vector2:
	return Vector2(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")).limit_length()
