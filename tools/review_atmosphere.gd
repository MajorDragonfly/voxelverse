extends SceneTree
## Native renderer fixture for the actual campaign sky/light controller.
const Atmosphere = preload("res://world/visuals/atmosphere/campaign_atmosphere.gd")
const Profile = preload("res://world/generation/planet_profile_v9.gd")
var air: Node3D
var scene: Node3D
var sample: Dictionary = {"up": Vector3.UP,"height": 30.0,"moisture": 0.65,"seconds": 750.0}
var output: String

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var settings := root.get_node("DisplaySettings")
	for i in range(4): await process_frame
	settings.display_mode = 0
	settings.resolution = Vector2i(960,540)
	settings._apply_settings(false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output = args[args.find("--capture")+1]
	scene = Node3D.new()
	root.add_child(scene)
	air = Atmosphere.new()
	scene.add_child(air)
	air.configure(Profile.create(15838),15838,Vector3.UP,func(): return sample)
	air.set_process(false)
	var camera := Camera3D.new()
	camera.far = 20000.0
	scene.add_child(camera)
	camera.position = Vector3(10,8,20)
	camera.look_at(Vector3(0,9,-20))
	camera.make_current()
	# Deliberate voxel diorama, not a claimed campaign screenshot.
	_box(Vector3(0,-2,-20),Vector3(130,3,140),Color("6d8742"))
	for i in range(28):
		var x: float = float(i%7)*14.0-45.0
		var z: float = -float(i/7)*24.0-35.0
		var h: float = 8.0+sin(float(i)*1.7)*4.0
		_box(Vector3(x,h*0.5,z),Vector3(13,h,15),Color("627559"))
	for i in range(7):
		var x: float = float(i)*6.0-18.0
		var z: float = -9.0-float(i%3)*5.0
		_box(Vector3(x,2,z),Vector3(0.6,5,0.6),Color("65503a"))
		_box(Vector3(x,5.2,z),Vector3(4,3,4),Color("3f773e"))
		_box(Vector3(x,7.0,z),Vector3(2.8,1.3,2.8),Color("639344"))
	_box(Vector3(3,0,4),Vector3(2,2,2),Color("b59c7d"))
	_box(Vector3(5,0,4),Vector3(2,1,2),Color("899484"))
	for i in range(5):
		_box(Vector3(float(i)*20-40,0,-400-float(i)*160),Vector3(80,90+float(i)*40,80),Color("71888a"))
	var native_environment: Environment = air.environment
	var world: WorldEnvironment = air.get_node("WorldEnvironment")
	var baseline := Environment.new()
	baseline.background_mode = Environment.BG_COLOR
	baseline.background_color = Color("83b4ce")
	baseline.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	baseline.ambient_light_color = Color("c4d8e4")
	baseline.ambient_light_energy = 0.22
	baseline.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	baseline.fog_enabled = true
	baseline.fog_mode = Environment.FOG_MODE_DEPTH
	baseline.fog_light_color = Color("83b4ce")
	baseline.fog_depth_begin = 1500.0
	baseline.fog_depth_end = 18000.0
	world.environment = baseline
	air.sun.light_color = Color.WHITE
	air.sun.light_energy = 0.8
	air.sun.basis = Basis.IDENTITY.rotated(Vector3.RIGHT,-0.65)
	await _capture("01-before")
	world.environment = native_environment
	air.configure(Profile.create(15838),15838,Vector3.UP,func(): return sample)
	air.set_quality(1)
	await _capture("02-atmospheric")
	air.set_quality(2)
	await _capture("03-cinematic")
	# Rotate the whole radial scene together; horizon and lighting must follow.
	var rotation_basis := Basis(Vector3.FORWARD,PI*0.5)
	scene.basis = rotation_basis
	sample.up = rotation_basis * Vector3.UP
	air._sun_direction = rotation_basis * air._sun_direction
	air.sky_material.set_shader_parameter("sun_direction",air._sun_direction)
	air.update_view(0.0,true)
	await _capture("04-radial")
	scene.basis = Basis.IDENTITY
	air.configure(Profile.create(15838),15838,Vector3.UP,func(): return sample)
	sample.up = Vector3.UP
	air._sun_direction = Vector3(-0.5,0.09,-0.85).normalized()
	air.sun.basis = Basis.looking_at(-air._sun_direction,Vector3.UP)
	air.sky_material.set_shader_parameter("sun_direction",air._sun_direction)
	air.update_view(0.0,true)
	await _capture("05-sunset")
	air._sun_direction = Vector3(-0.5,-0.8,-0.3).normalized()
	air.sun.basis = Basis.looking_at(-air._sun_direction,Vector3.UP)
	air.sky_material.set_shader_parameter("sun_direction",air._sun_direction)
	air.update_view(0.0,true)
	await _capture("06-night")
	scene.free()
	print("ATMOSPHERE_RENDER_PASSED renderer=",RenderingServer.get_current_rendering_method())
	await preload("res://core/runtime_shutdown.gd").finish(self,0)

func _box(position: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	instance.material_override = material
	scene.add_child(instance)
	instance.position = position

func _capture(filename: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(output.path_join(filename+".png"))
	if error != OK:
		push_error("Capture failed: "+filename)
		quit(1)
