extends "res://creatures/player/player_controller_v2.gd"
## The normal player scene owns needs, scanner, behavior, body and books.
## This specialization only owns body-fixed placement and terrain streaming.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
var terrain: Node3D
var adapter: RefCounted
var creature_design: Dictionary = {}
var traveled: float = 0.0
var waiting_for_terrain: bool = false
var camera: Camera3D
var preview: Node3D:
	get: return get_node("CreatureRuntimeVisual")._preview
var forward: Vector3:
	get: return -global_basis.z
var pitch: float:
	get: return camera_pivot.rotation.x
var _runtime: Dictionary = {}

func _ready() -> void:
	set_meta("surface_mode", Cube.MODE)
	minimum_camera_angle = rad_to_deg(-0.85)
	maximum_camera_angle = rad_to_deg(0.5)
	super._ready()
	camera = get_node("CameraPivot/SpringArm3D/Camera3D")
	fall_acceleration = float(terrain.surface.body.gravity)
	safe_margin = 0.01

func location() -> Dictionary:
	return Space.address(self, global_position)

func place(value: Dictionary, heading: Vector3 = Vector3.FORWARD) -> void:
	var point: Array = Cube.cartesian(value, terrain.surface.body.radius)
	terrain.rebase(point)
	global_position = Vector3.ZERO
	up_direction = adapter.up_at(value)
	global_basis = Cube.frame(up_direction, heading)
	velocity = Vector3.ZERO
	terrain.stream_at(up_direction, true)

func export_runtime_state() -> Dictionary:
	var result: Dictionary = _runtime.duplicate(true)
	var shared: Dictionary = super.export_runtime_state()
	shared.erase("position")
	shared.erase("yaw")
	result.merge(shared, true)
	result.merge({"surface_address": Space.encode(self, global_position), "surface_forward": [forward.x, forward.y, forward.z],
		"surface_velocity": [velocity.x, velocity.y, velocity.z], "surface_pitch": pitch}, true)
	return result

func import_runtime_state(data: Dictionary) -> void:
	if not Surface.player_problem(data, terrain.surface.body).is_empty(): return
	_runtime = data.duplicate(true)
	var shared: Dictionary = data.duplicate(true)
	shared.erase("position")
	shared.erase("yaw")
	super.import_runtime_state(shared)
	camera_pivot.rotation.x = float(data.surface_pitch)
	place(data.surface_address, Cube.vector(data.surface_forward))
	velocity = Cube.vector(data.surface_velocity)

func _process(delta: float) -> void:
	if get_node("/root/SessionFlow").loading or not get_parent().world_initialized: return
	super._process(delta)

func _physics_process(delta: float) -> void:
	if get_node("/root/SessionFlow").loading or not get_parent().world_initialized: return
	var up: Vector3 = adapter.up_at(location())
	var lead: Vector3 = (velocity.slide(up) * clampf(terrain.last_worker_seconds + 0.25, 0.75, 2.5)).limit_length(32.0)
	terrain.lookahead_direction = (up + lead / float(terrain.surface.body.radius)).normalized()
	terrain.stream_at(up)
	waiting_for_terrain = not Space.ground_ready(self, global_position + velocity * delta * 2.0)
	if not Space.ground_ready(self, global_position): return
	var before: Vector3 = global_position
	super._physics_process(delta)
	traveled += global_position.distance_to(before)
	if global_position.length() > 64.0:
		terrain.rebase(Cube.global_position(global_position, terrain.origin))

func _unhandled_input(event: InputEvent) -> void:
	if get_node("/root/SessionFlow").loading or not get_parent().world_initialized: return
	super._unhandled_input(event)
