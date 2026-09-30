extends SceneTree
## Combined captions; synthetic view fixture, independent of the tribe panel.
const Props = preload("res://world/tribe/village_visuals.gd")
const Shelters = preload("res://world/tribe/village_shelters.gd")
const Home = preload("res://world/home_group/home_group_state.gd")
const Tribe = preload("res://world/tribe/tribe_state.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.set_process(false)
	state.start_world_with_seed(15838)
	var home: Dictionary = Home.create(state.active_body_id, state.campaign.data.player_species_id, Vector3.ZERO)
	var data: Dictionary = Tribe.create(home, state.campaign.data, {"position": [0, 0, 0]},
		{"wood": [-5, 0, -4], "stone": [5, 0, -4], "food": [-5, 0, 4], "huts": [[5, 0, 4], [8, 0, 0]]})
	data.tools = 1
	data.huts = 1
	data.housing.homes.append(Tribe.Housing.site(data, "hut", [5, 0, 4], 0))
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.make_current()
	camera.position = Vector3(0, 20, 20)
	var props := Props.new()
	var shelters := Shelters.new()
	scene.add_child(props)
	scene.add_child(shelters)
	props.rebuild(data)
	shelters.sync(data, {})
	var captions: Array[Label3D] = []
	for child: Node in props.get_children():
		if child is Label3D: captions.append(child)
	var building: Node3D = shelters.get_child(0)
	var label: Label3D = building.get_child(building.get_child_count() - 1)
	captions.append(label)
	var nodes: Array = props.get_children()
	var stock_mesh: MultiMesh = props.stockpiles.lots.wood.stored.multimesh
	var before: String = JSON.stringify(data)
	await create_timer(0.35).timeout
	for caption: Label3D in captions: _expect(caption.visible, "Near caption hidden: " + caption.text)
	camera.position = Vector3(0, 90, 90)
	await create_timer(0.35).timeout
	for caption: Label3D in captions: _expect(not caption.visible, "Far caption remained visible: " + caption.text)
	# Ten-metre hysteresis retains the prior hidden state at the middle band.
	camera.position = Vector3(0, 65, 0)
	await create_timer(0.35).timeout
	for caption: Label3D in captions: _expect(not caption.visible, "Caption flickered inside the far/near band: " + caption.text)
	camera.position = Vector3(0, 20, 20)
	await create_timer(0.35).timeout
	for caption: Label3D in captions: _expect(caption.visible, "Near caption did not return: " + caption.text)
	_expect(props.get_children() == nodes and shelters.get_child(0) == building and props.stockpiles.lots.wood.stored.multimesh == stock_mesh,
		"Distance changes rebuilt props, storage or building collisions.")
	_expect(JSON.stringify(data) == before, "Presentation changed saved village data.")
	scene.queue_free()
	await process_frame
	print(JSON.stringify({"test": "int30_village_view", "passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
