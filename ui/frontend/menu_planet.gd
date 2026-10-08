extends SubViewportContainer

## Self-contained title artwork: a small voxel shell, no campaign generator,
## physics, save data or external texture needed on the title screen.
var _planet: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	stretch_shrink = 2
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(2, 3, 40)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 33
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	world.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("a6b0a0")
	environment.environment.ambient_light_energy = 0.42
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -45, 0)
	light.light_color = Color("f2dfb9")
	light.light_energy = 1.7
	world.add_child(light)
	_planet = Node3D.new()
	_planet.rotation_degrees.z = -16
	world.add_child(_planet)
	var cells: Array[Vector3] = []
	for x in range(-12, 13):
		for y in range(-12, 13):
			for z in range(-12, 13):
				var cell := Vector3(x, y, z)
				if cell.length() <= 12.0 and cell.length() > 10.8:
					cells.append(cell)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = cells.size()
	for i in range(cells.size()):
		var p: Vector3 = cells[i]
		var land: float = sin(p.x * 0.31 + cos(p.z * 0.36) * 2.1) + cos(p.y * 0.33 + sin(p.z * 0.29))
		var color := Color("405c58")
		if land > 0.25:
			color = Color("839178") if land < 1.0 else Color("b0a17d")
		if absf(p.y) > 10.0:
			color = Color("d8d0bd")
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		instances.set_instance_color(i, color)
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = instances
	_planet.add_child(visual)
	# A small voxel moon balances the composition without representing a saved body.
	var moon := MeshInstance3D.new()
	var moon_mesh := BoxMesh.new()
	moon_mesh.size = Vector3(2.1, 2.1, 2.1)
	var moon_material := StandardMaterial3D.new()
	moon_material.albedo_color = Color("a8987a")
	moon_mesh.material = moon_material
	moon.mesh = moon_mesh
	moon.position = Vector3(13, 8, -4)
	moon.rotation_degrees = Vector3(18, 32, 8)
	world.add_child(moon)

func _process(delta: float) -> void:
	if is_instance_valid(_planet):
		_planet.rotate_y(delta * 0.028)
