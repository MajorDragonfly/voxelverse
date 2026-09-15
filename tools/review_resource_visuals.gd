extends SceneTree
## Native render of exactly the meshes used by the campaign resources.
const Visuals = preload("res://world/visuals/scenery/resource_visual_factory.gd")
const Profile = preload("res://world/space/celestial_body_profile.gd")
var world: Node3D
var camera: Camera3D
var resources: Array[Node3D] = []

func _initialize() -> void:
	call_deferred("_run")

func _label(title: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = 52
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	world.add_child(label)

func _mesh(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	world.add_child(instance)
	return instance

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--mesh-export" in OS.get_cmdline_user_args():
		_export_meshes()
		await preload("res://core/runtime_shutdown.gd").finish(self,0)
		return
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	root.size = Vector2i(1600,1000)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b292a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c6d7d5")
	environment.environment.ambient_light_energy = 0.72
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_color = Color("ffedcf")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	world.add_child(sun)
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("344446")
	plane.material = floor_material
	_mesh(plane,Vector3(0,-0.035,0))
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	world.add_child(camera)
	camera.position = Vector3(6,12,17)
	camera.look_at(Vector3(0,0.1,0.6))
	camera.make_current()
	var profile: Dictionary = Profile.terrain_profile(15838)
	var names: Array[String] = ["Verzweigt", "Aufrecht", "Etagen", "Faecher", "Bogen", "Polster"]
	for form in range(6):
		var point := Vector3((form%3-1)*4,0,(form/3)*3.5-3.5)
		for variant in range(2):
			var seed_value: int = form+variant*6
			var appearance: Dictionary = Visuals.forage(seed_value,0.85,1.15,9,0.25,0.12,profile,"forest")
			var at: Vector3 = point+Vector3((variant-0.5)*1.6,0,0)
			resources.append(_mesh(appearance.foliage,at))
			resources.append(_mesh(appearance.fruit,at))
		_label(names[form],point+Vector3(0,0,1.3))
	for variant in range(2):
		var at := Vector3((variant-0.5)*5,0,4.8)
		resources.append(_mesh(Visuals.nest(42+variant,1.25,0.25,24,2,0.12,profile,"forest"),at))
		_label("Nest %d" % (variant+1),at+Vector3(0,0,1.55))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[args.find("--capture")+1]
	DirAccess.make_dir_recursive_absolute(output)
	await _capture(output.path_join("resource_variants.png"))
	for resource: Node3D in resources: resource.visible = false
	for label: Node in world.find_children("*","Label3D",false,false): label.visible = false
	var detailed: MeshInstance3D = _mesh(Visuals.nest(42,1.25,0.25,24,2,0.12,profile,"forest"),Vector3.ZERO)
	camera.size = 3.8
	camera.position = Vector3(3.8,4.2,5)
	camera.look_at(Vector3(0,0.10,0))
	await _capture(output.path_join("nest_detail.png"))
	detailed.free()
	print("RESOURCE_REVIEW_PASSED")
	await preload("res://core/runtime_shutdown.gd").finish(self,0)

func _capture(path: String) -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(path)
	assert(error == OK,"Capture failed: " + path)

func _export_meshes() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--mesh-export")+1]
	DirAccess.make_dir_recursive_absolute(directory)
	var profile: Dictionary = Profile.terrain_profile(15838)
	var models: Array = []
	for form in range(6):
		var appearance: Dictionary = Visuals.forage(form,0.85,1.15,9,0.25,0.12,profile,"forest")
		models.append({"id":appearance.form,"name":appearance.form,"meshes":[_arrays(appearance.foliage),_arrays(appearance.fruit)]})
	var file := FileAccess.open(directory.path_join("forage_meshes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(models))
	file.close()
	models = []
	for seed_value in [42,43]:
		models.append({"id":"nest","name":"Nest %d" % seed_value,"meshes":[_arrays(Visuals.nest(seed_value,1.25,0.25,24,2,0.12,profile,"forest"))]})
	file = FileAccess.open(directory.path_join("nest_meshes.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(models))
	file.close()
	print("RESOURCE_MESH_EXPORT_PASSED: actual mesh arrays; no native rendering")

func _arrays(mesh: ArrayMesh) -> Dictionary:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: Array = []
	var colors: Array = []
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: vertices.append([vertex.x,vertex.y,vertex.z])
	for color: Color in arrays[Mesh.ARRAY_COLOR]: colors.append([color.r,color.g,color.b])
	return {"vertices":vertices,"colors":colors,"indices":Array(arrays[Mesh.ARRAY_INDEX])}
