extends RefCounted
## Local view state only. Camera movement never moves a resident or a save address.
const Space = preload("res://world/surface/gameplay_space.gd")
const RANGE: float = 128.0
const MIN_ZOOM: float = 12.0
const MAX_ZOOM: float = 72.0
const MIN_TILT: float = 3.0
const MAX_TILT: float = 80.0
const LOW_PITCH_LIMIT_DEGREES: float = 8.0
const PAN_METRES_PER_SECOND: float = 32.0
const FAST_FACTOR: float = 2.0
const CLEARANCE_REFRESH_SECONDS: float = 0.2
const MOTION := ["move_forward", "move_back", "move_left", "move_right",
	"tribe_turn_left", "tribe_turn_right", "tribe_tilt_up", "tribe_tilt_down"]
var controller: Node
var surface: RefCounted
var yaw: float = 0.0
var tilt: float = 55.0
var current_zoom: float = 26.0
var orbiting: bool = false
var held: Dictionary = {}
var fast_pan: bool = false
var _preferences: RefCounted
var _default_tilt: float = 55.0
var _last_pose: Array = []
var _clearance_refresh_remaining: float = 0.0

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
	fast_pan = false

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
		if event is InputEventKey and event.keycode == KEY_SHIFT:
			fast_pan = event.pressed
			return false
		if event.is_action_released("tribe_orbit"):
			var was_orbiting: bool = orbiting
			orbiting = false
			return was_orbiting
		for action: String in MOTION:
			if event.is_action_released(action): held.erase(action)
	if orbiting and event is InputEventMouseMotion:
		var motion: Vector2 = _preferences.camera_motion(event.relative, 0.22)
		yaw = wrapf(yaw - motion.x, -180.0, 180.0)
		tilt = clampf(tilt + motion.y, MIN_TILT, MAX_TILT)
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
	_clearance_refresh_remaining = maxf(_clearance_refresh_remaining - dt, 0.0)
	yaw = wrapf(yaw + (_axis("tribe_turn_right", "tribe_turn_left") * 75.0 * dt), -180.0, 180.0)
	tilt = clampf(tilt + _axis("tribe_tilt_up", "tribe_tilt_down") * 45.0 * dt, MIN_TILT, MAX_TILT)
	var motion := Vector2(_axis("move_right", "move_left"), _axis("move_back", "move_forward")).limit_length(1.0)
	if not motion.is_zero_approx():
		var frame: Basis = view_frame()
		var speed: float = PAN_METRES_PER_SECOND * float(_preferences.tribe_camera.pan_speed) * (FAST_FACTOR if fast_pan else 1.0)
		var before: Vector3 = controller._focus
		move_focus((frame.x * motion.x + frame.z * motion.y) * speed * dt)
		controller.guidance_action.emit("tribe_camera", controller._focus.distance_to(before))
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

func adjust_view(yaw_delta: float, tilt_delta: float) -> void:
	if not controller.is_active(): return
	yaw = wrapf(yaw + yaw_delta, -180.0, 180.0)
	tilt = clampf(tilt + tilt_delta, MIN_TILT, MAX_TILT)
	update_camera()

func face_map_heading(requested: Vector2, shown: Vector2) -> void:
	if requested.length_squared() < 0.1 or shown.length_squared() < 0.1: return
	# The map's east/south axes turn opposite to yaw about the local up vector.
	adjust_view(-rad_to_deg(shown.angle_to(requested)), 0.0)

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
	# Streaming/construction can change collisions while the view stays still.
	# Resize also changes the orthographic near plane without changing its pose.
	var pose: Array = [controller._focus, yaw, tilt, current_zoom, camera.get_viewport().get_visible_rect().size]
	if pose == _last_pose and _clearance_refresh_remaining > 0.0: return
	_last_pose = pose
	_clearance_refresh_remaining = CLEARANCE_REFRESH_SECONDS
	var frame: Basis = view_frame()
	var angle: float = deg_to_rad(tilt)
	var low_view: float = 1.0 - smoothstep(MIN_TILT, 25.0, tilt)
	var aim: Vector3 = controller._focus + frame.y * (1.5 * low_view)
	var distance: float = maxf(lerpf(28.0, 16.0, low_view), current_zoom * 1.3)
	var eye: Vector3 = aim + (frame.y * sin(angle) + frame.z * cos(angle)) * distance
	if low_view > 0.01:
		# A low orbit needs clearance along the sight line, not only at its endpoint.
		# Sampling the existing height source also works while visual LOD streams in.
		for step in range(1, 6):
			var fraction: float = float(step) / 6.0
			var sample_point: Vector3 = aim.lerp(eye, fraction)
			var sample: Dictionary = Space.sample(controller, sample_point)
			var minimum: float = maxf(float(sample.height), float(sample.water_level)) + 1.2
			if float(sample.altitude) < minimum:
				eye += Space.up(controller, eye) * ((minimum - float(sample.altitude)) / fraction)
	var clearance: Dictionary = Space.sample(controller, eye)
	var required: float = maxf(float(clearance.height), float(clearance.water_level)) + 2.0
	if float(clearance.altitude) < required:
		eye += Space.up(controller, eye) * (required - float(clearance.altitude))
	# Village buildings have physical colliders. Stop the eye in front of them.
	if low_view > 0.01:
		var ray := PhysicsRayQueryParameters3D.create(aim, eye, 1)
		var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and aim.distance_to(hit.position) > 1.5:
			eye = hit.position - (eye - aim).normalized() * 0.5
	camera.size = current_zoom
	# A tall orthographic near plane cannot stay at eye level at 3 degrees:
	# clearing its lower edge raises and pitches the whole view. Use a matching
	# perspective lens for the low orbit; overhead planning keeps orthography.
	var perspective: bool = tilt < 25.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
	if perspective:
		camera.fov = rad_to_deg(2.0 * atan(current_zoom * 0.5 / maxf(aim.distance_to(eye), 1.0)))
	camera.v_offset = 0.0 if perspective else -current_zoom * 0.16
	camera.global_position = eye
	_orient_camera(camera, aim, frame.y)
	# The orthographic lens at the 25-degree boundary can put its lower edge
	# underground even though the eye is safe. Check the real frame for both
	# projections, including the exact side corners, at every settled pose.
	_clear_near_plane(camera, aim, frame.y)

func _orient_camera(camera: Camera3D, aim: Vector3, up: Vector3) -> void:
	camera.look_at(aim, up)
	if camera.projection != Camera3D.PROJECTION_PERSPECTIVE: return
	# A shore/slope can raise the eye above its requested orbit. Keeping the
	# focus at screen centre would turn a 3-degree setting into a steep view.
	# Preserve the saved/map focus and clearance, but limit the low view's
	# downward pitch relative to the actual eye's spherical up vector.
	var eye_up: Vector3 = Space.up(controller, camera.global_position)
	var forward: Vector3 = -camera.global_basis.z
	var angle: float = deg_to_rad(maxf(tilt, LOW_PITCH_LIMIT_DEGREES))
	if -forward.dot(eye_up) <= sin(angle): return
	var tangent: Vector3 = forward.slide(eye_up).normalized()
	camera.look_at(camera.global_position + tangent * cos(angle) - eye_up * sin(angle), eye_up)

func _clear_near_plane(camera: Camera3D, aim: Vector3, up: Vector3) -> void:
	# Sample the actual near plane for both lenses. Perspective ray origins
	# alone would only sample the eye and miss the screen corners.
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0: return
	for iteration in range(4):
		var deficit: float = 0.0
		for x: float in [0.0, 0.5, 1.0]:
			for y: float in [0.0, 0.5, 1.0]:
				var origin: Vector3 = camera.project_position(Vector2(size.x * x, size.y * y), camera.near)
				var sample: Dictionary = Space.sample(controller, origin)
				deficit = maxf(deficit, maxf(float(sample.height), float(sample.water_level)) + 1.0 - float(sample.altitude))
		if deficit <= 0.0: return
		camera.global_position += Space.up(controller, camera.global_position) * (deficit + 0.5)
		_orient_camera(camera, aim, up)
