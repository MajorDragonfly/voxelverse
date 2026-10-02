extends SceneTree
## Lightweight real-sampler geometry probe. Publication/colliders are fixtures;
## the separately captured regular campaign remains the visual acceptance source.
const Cube = preload("res://world/space/cube_sphere.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Rig = preload("res://world/tribe/tribe_camera.gd")

class PublishedTerrain extends Node3D:
	signal origin_changed(previous: Array, current: Array)
	var surface: RefCounted
	var origin: Array = []
	func ground_ready(_point: Array) -> bool: return true

class Owner extends Node3D:
	var camera: Camera3D
	var _focus: Vector3
	var _zoom: float = 12.0
	func anchor() -> Vector3: return Vector3.ZERO

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	await process_frame
	var state: Node = root.get_node("GameState")
	state.start_world_with_seed(15838)
	var body: Dictionary = Context.create(state.get_current_body_record())
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var terrain := PublishedTerrain.new()
	terrain.surface = preload("res://world/surface/planet_surface_factory.gd").create(Context.descriptor(body))
	var spawn: Dictionary = body.surface_context.spawn.duplicate(true)
	spawn.height = terrain.surface.sample(spawn).height + 0.08
	terrain.origin = Cube.cartesian(spawn, terrain.surface.body.radius)
	stage.add_child(terrain)
	var adapter := preload("res://world/surface/radial_surface_adapter.gd").new(terrain)
	stage.set_meta("campaign_surface", adapter)
	var owner := Owner.new()
	stage.add_child(owner)
	owner.camera = Camera3D.new()
	owner.add_child(owner.camera)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	var rig := Rig.new()
	rig.controller = owner
	rig.surface = adapter
	var args: PackedStringArray = OS.get_cmdline_user_args()
	rig.tilt = float(args[0]) if args.size() > 0 else 3.0
	var rows: Array[Dictionary] = []
	for offset: Vector2 in [Vector2.ZERO, Vector2(64, 0), Vector2(-64, 0), Vector2(0, 64), Vector2(0, -64)]:
		var frame: Basis = adapter.frame_at(spawn)
		owner._focus = rig.surface_point(frame.x * offset.x + frame.z * offset.y)
		for yaw: float in [0.0, 90.0, 180.0, 270.0]:
			for zoom: float in [12.0, 26.0, 72.0]:
				rig.yaw = yaw
				rig.current_zoom = zoom
				rig.update_camera()
				var eye: Vector3 = owner.camera.global_position
				var value: Dictionary = Space.sample(owner, eye)
				var dot: float = absf((-owner.camera.global_basis.z).dot(Space.up(owner, eye)))
				var near_clearance: float = INF
				for portion: Vector2 in [Vector2(0,0), Vector2(1,0), Vector2(0,1), Vector2(1,1), Vector2(0,0.5), Vector2(1,0.5), Vector2(0.5,1)]:
					var p: Vector3 = owner.camera.project_position(Vector2(1920,1080) * portion, owner.camera.near)
					var sample: Dictionary = Space.sample(owner, p)
					near_clearance = minf(near_clearance, sample.altitude - maxf(sample.height, sample.water_level))
				rows.append({"offset": [offset.x, offset.y], "yaw": yaw, "zoom": zoom,
					"actual_pitch_deg": rad_to_deg(asin(dot)), "forward_up_abs": dot,
					"near_clearance_m": near_clearance, "eye_clearance_m": value.altitude - maxf(value.height, value.water_level),
					"eye_aim_m": eye.distance_to(owner._focus + rig.view_frame().y * 1.5)})
	print("R32_04_CAMERA_GEOMETRY ", JSON.stringify({"seed":15838, "requested_tilt_deg":rig.tilt, "spawn":spawn, "scope":"real sampler / fixture publication", "rows":rows}))
	adapter.close()
	stage.free()
	current_scene = null
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
