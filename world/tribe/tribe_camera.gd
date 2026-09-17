extends RefCounted
## Local view state only. Camera movement never moves a resident or a save address.
const Space = preload("res://world/surface/gameplay_space.gd")
const RANGE: float = 128.0
const MIN_ZOOM: float = 12.0
const MAX_ZOOM: float = 72.0
const MOTION := ["move_forward", "move_back", "move_left", "move_right",
	"tribe_turn_left", "tribe_turn_right", "tribe_tilt_up", "tribe_tilt_down"]
var controller: Node
var surface: RefCounted
var yaw: float = 0.0
var tilt: float = 55.0
var current_zoom: float = 26.0
var orbiting: bool = false
var held: Dictionary = {}
var _preferences: RefCounted
var _default_tilt: float = 55.0
var _last_pose: Array = []

func setup(owner: Node) -> void:
	controller = owner
	surface = Space.adapter(owner)
	_preferences = owner.get_node("/root/DisplaySettings").input_preferences
	_default_tilt = float(_preferences.tribe_camera.tilt)
	tilt = _default_tilt
	current_zoom = controller._zoom
	_preferences.bindings_changed.connect(_settings_changed)
	update_camera()

func cancel_input() -> void:
	orbiting = false
	held.clear()

func close() -> void:
	cancel_input()
	if _preferences.bindings_changed.is_connected(_settings_changed):
		_preferences.bindings_changed.disconnect(_settings_changed)
	if surface != null and is_instance_valid(surface.terrain):
		surface.terrain.set_view_focus(Vector3.ZERO)

func _settings_changed() -> void:
	cancel_input()
	var next: float = float(_preferences.tribe_camera.tilt)
	if not is_equal_approx(next, _default_tilt): tilt = next
	_default_tilt = next

func handle_input(event: InputEvent) -> bool:
	if not controller.is_active():
		cancel_input()
		return false
	# Releases must reach the owner even after the pointer enters a GUI control.
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventAction:
		if event.is_action_released("tribe_orbit"):
			var was_orbiting: bool = orbiting
			orbiting = false
			return was_orbiting
		for action: String in MOTION:
			if event.is_action_released(action): held.erase(action)
	if orbiting and event is InputEventMouseMotion:
		var motion: Vector2 = _preferences.camera_motion(event.relative, 0.22)
		yaw = wrapf(yaw - motion.x, -180.0, 180.0)
		tilt = clampf(tilt + motion.y, 30.0, 80.0)
		update_camera()
		return true
	return false

func handle_unhandled(event: InputEvent) -> bool:
	if not controller.is_active(): return false
	if event.is_action_pressed("tribe_orbit"):
		orbiting = true
		return true
	if event.is_action_pressed("tribe_focus_home"):
		focus_home()
		return true
	if event.is_action_pressed("tribe_focus_selection"):
		focus_selection()
		return true
	for action: String in MOTION:
		if event.is_action_pressed(action):
			held[action] = true
			return true
	return false

func advance(delta: float) -> void:
	if not controller.is_active():
		cancel_input()
		return
	var dt: float = minf(delta, 0.1)
	yaw = wrapf(yaw + (_axis("tribe_turn_right", "tribe_turn_left") * 75.0 * dt), -180.0, 180.0)
	tilt = clampf(tilt + _axis("tribe_tilt_up", "tribe_tilt_down") * 45.0 * dt, 30.0, 80.0)
	var motion := Vector2(_axis("move_right", "move_left"), _axis("move_back", "move_forward")).limit_length(1.0)
	if not motion.is_zero_approx():
		var frame: Basis = view_frame()
		var speed: float = 12.0 * float(_preferences.tribe_camera.pan_speed)
		move_focus((frame.x * motion.x + frame.z * motion.y) * speed * dt)
	current_zoom = lerpf(current_zoom, controller._zoom, 1.0 - exp(-12.0 * dt))
	if absf(current_zoom - controller._zoom) < 0.001: current_zoom = controller._zoom
	update_camera()
	if surface != null and is_instance_valid(surface.terrain):
		# Keep the existing physical cover at the village. Only the visual LOD
		# selector gets a second, bounded observer. Flora/population stay owned.
		var physical: Vector3 = Space.up(controller, controller.anchor())
		surface.terrain.set_view_focus(Space.up(controller, controller._focus))
		surface.terrain.set_motion_hint(physical, Vector3.ZERO)
		surface.terrain.stream_at(physical)

func _axis(positive: String, negative: String) -> float:
	return float(held.has(positive)) - float(held.has(negative))

func view_frame() -> Basis:
	var base: Basis = Space.frame(controller, controller.anchor())
	var forward: Vector3 = (-base.z).rotated(base.y, deg_to_rad(yaw))
	return Space.frame(controller, controller._focus, forward)

func move_focus(offset: Vector3) -> void:
	var anchor: Vector3 = controller.anchor()
	var proposed: Vector3 = controller._focus + offset
	var tangent: Vector3 = (proposed - anchor).slide(Space.up(controller, anchor)).limit_length(RANGE)
	controller._focus = surface_point(anchor + tangent)

func surface_point(point: Vector3) -> Vector3:
	if surface != null:
		var place: Dictionary = Space.address(controller, point)
		var sample: Dictionary = surface.sample(place)
		place.height = maxf(float(sample.height), float(sample.water_level)) + 0.08
		return surface.to_local(place)
	var hit: Dictionary = Space.floor_hit(controller.camera, point, 100.0, 200.0)
	return hit.position + Vector3.UP * 0.08 if not hit.is_empty() else point

func focus_home() -> void:
	controller._focus = controller.anchor()
	update_camera()

func focus_selection() -> void:
	var point := Vector3.ZERO
	var count: int = 0
	for id: String in controller.selected:
		var actor: Node3D = controller.actors.get(id)
		if not is_instance_valid(actor): continue
		point += actor.global_position
		count += 1
	if count > 0:
		move_focus(point / count - controller._focus)
		update_camera()

func reset_view() -> void:
	yaw = 0.0
	tilt = float(_preferences.tribe_camera.tilt)
	controller._zoom = 26.0
	current_zoom = 26.0
	focus_home()

func update_camera() -> void:
	var camera: Camera3D = controller.camera
	if not is_instance_valid(camera): return
	var pose: Array = [controller._focus, yaw, tilt, current_zoom]
	if pose == _last_pose: return
	_last_pose = pose
	var frame: Basis = view_frame()
	var angle: float = deg_to_rad(tilt)
	var distance: float = maxf(28.0, current_zoom * 1.3)
	var eye: Vector3 = controller._focus + (frame.y * sin(angle) + frame.z * cos(angle)) * distance
	if surface != null:
		var clearance: Dictionary = Space.sample(controller, eye)
		var required: float = maxf(float(clearance.height), float(clearance.water_level)) + 2.0
		if float(clearance.altitude) < required:
			eye += Space.up(controller, eye) * (required - float(clearance.altitude))
	camera.size = current_zoom
	camera.v_offset = -current_zoom * 0.16
	camera.global_position = eye
	camera.look_at(controller._focus, frame.y)
