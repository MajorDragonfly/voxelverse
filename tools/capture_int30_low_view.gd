extends SceneTree
## Real spherical terrain/water + production tribe rig; isolated view owner.
const Cube = preload("res://world/space/cube_sphere.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Surface = preload("res://world/surface/living_planet_surface_v2.gd")
var failures: Array[String] = []
var evidence: Array[Dictionary] = []
var output: String

class ViewOwner extends Node3D:
	signal guidance_action(action: String, value: float)
	var camera: Camera3D
	var _focus: Vector3
	var _zoom: float = 12.0
	var selected: Array[String] = []
	var actors: Dictionary = {}
	func is_active() -> bool: return true
	func anchor() -> Vector3: return _focus

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var body: Dictionary = preload("res://world/space/celestial_body_profile.gd").create("int30:low-view", "planet", 15838, 6371000.0)
	body.terrain_revision = 4
	body.surface_generation = Surface.VERSION
	var sampler := Surface.new(body)
	var lake: Dictionary = {}
	for face in range(6):
		for y in range(-3, 4):
			for x in range(-3, 4):
				sampler._feature(Cube.direction(face, x * 0.3, y * 0.3))
				for candidate: Dictionary in sampler._lakes.values():
					if candidate.is_empty(): continue
					var sample: Dictionary = sampler._sample(candidate.direction)
					if sample.water and sample.get("water_kind", "ocean") in ["lake", "river"] and sample.water_level - sample.height > 0.4:
						lake = candidate; break
				if not lake.is_empty(): break
			if not lake.is_empty(): break
		if not lake.is_empty(): break
	if lake.is_empty(): push_error("No real freshwater view source."); quit(1); return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var terrain := preload("res://world/surface/surface_terrain.gd").new()
	stage.add_child(terrain)
	terrain.configure(body)
	var address: Dictionary = Cube.from_direction(body.id, lake.direction)
	var sample: Dictionary = sampler.sample(address)
	address.height = sample.water_level
	terrain.rebase(Cube.cartesian(address, body.radius))
	var adapter := preload("res://world/surface/radial_surface_adapter.gd").new(terrain)
	stage.set_meta("campaign_surface", adapter)
	var native_capture: bool = DisplayServer.get_name() != "headless"
	if native_capture: terrain.stream_at(adapter.up_at(address), true)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("456774")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ddebe4")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	stage.add_child(light)
	light.basis = adapter.frame_at(address) * Basis.from_euler(Vector3(-0.9, -0.4, 0))
	var owner := ViewOwner.new()
	stage.add_child(owner)
	owner.camera = Camera3D.new()
	owner.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	owner.camera.far = 30000.0
	owner.add_child(owner.camera)
	owner.camera.make_current()
	var rig := preload("res://world/tribe/tribe_camera.gd").new()
	rig.setup(owner)
	rig.tilt = 3.0
	rig.current_zoom = 12.0
	var frame: Basis = adapter.frame_at(address)
	var shore: Vector3 = Vector3.ZERO
	var hill: Vector3 = Vector3.ZERO
	var best_height: float = -INF
	var found_shore: bool = false
	for distance in [8.0, 16.0, 24.0, 32.0, 48.0, 64.0]:
		for index in range(16):
			var point: Vector3 = (frame.x * cos(index * TAU / 16.0) + frame.z * sin(index * TAU / 16.0)) * distance
			var value: Dictionary = Space.sample(owner, point)
			if not value.water and not found_shore:
				shore = rig.surface_point(point); found_shore = true
			if value.height > best_height:
				best_height = value.height; hill = rig.surface_point(point)
	if not found_shore: failures.append("No dry bank within 64 metres of actual lake.")
	root.content_scale_size = Vector2i.ZERO
	for dimensions in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for view in [{"name": "shore", "point": shore}, {"name": "slope", "point": hill}]:
			owner._focus = view.point
			for yaw in [0.0, 90.0, 180.0, 270.0]:
				rig.yaw = yaw
				rig.update_camera()
				await process_frame
				var name: String = "%s-%dx%d-%d" % [view.name, dimensions.x, dimensions.y, int(yaw)]
				if native_capture:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(name + ".png"))
				var eye: Dictionary = Space.sample(owner, owner.camera.global_position)
				var minimum_clearance: float = INF
				for portion in [0.0, 0.5, 1.0]:
					var origin: Vector3 = owner.camera.project_position(Vector2(root.get_visible_rect().size.x * portion, root.get_visible_rect().size.y), owner.camera.near)
					var near: Dictionary = Space.sample(owner, origin)
					minimum_clearance = minf(minimum_clearance, near.altitude - maxf(near.height, near.water_level))
				if minimum_clearance < 0.0: failures.append("Full lower viewport clips beneath world: " + name)
				evidence.append({"view": name, "requested_tilt_deg": 3.0, "effective_tilt_deg": rad_to_deg(asin(clampf((-owner.camera.global_basis.z).dot(-Space.up(owner, owner.camera.global_position)), -1, 1))), "eye_clearance_m": eye.altitude - maxf(eye.height, eye.water_level), "bottom_clearance_m": minimum_clearance})
	var file := FileAccess.open(output.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "views": evidence, "native_capture": native_capture, "source": "real living planet seed 15838; production terrain + tribe camera, diagnostic owner only"}, "\t"))
	for failure in failures: push_error(failure)
	rig.close()
	adapter.close()
	stage.free()
	current_scene = null
	if failures.is_empty(): print("INT30_LOW_VIEW_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
