extends SceneTree
const Navigation = preload("res://world/tribe/village_navigation.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.start_world_with_seed(15838)
	root.get_node("SaveGameService").autosave_enabled = false
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	_box(scene, Vector3(50, 1, 50), Vector3(0, 99.5, 0))
	_box(scene, Vector3(2, 6, 50), Vector3(0, 102, 0))
	var player := CharacterBody3D.new()
	scene.add_child(player)
	player.position = Vector3(-5, 100, 0)
	var home: Node = preload("res://world/home_group/home_group_controller.gd").new()
	scene.add_child(home)
	home.set_process(false)
	home.player = player
	await physics_frame
	var navigation := Navigation.new()
	navigation.begin(home, Vector3(0, 100, 0))
	navigation.advance(1)
	_expect(navigation.pending and navigation.last_slice_cells == 1 and navigation.route(player.position, Vector3(5, 100, 0)).is_empty(), "Partial graph was published or slice exceeded its cell budget.")
	var slices: int = 1
	while navigation.pending and slices < 3000:
		navigation.advance()
		_expect(navigation.last_slice_cells <= Navigation.MAX_CELLS_PER_SLICE, "Navigation exceeded its hard work limit.")
		slices += 1
	_expect(not navigation.pending and navigation.graph.get_point_count() > 100, "Incremental physical graph did not finish.")
	_expect(navigation.route(Vector3(-5, 100, 0), Vector3(-3, 100, 0)).size() > 0, "Clear local ground was disconnected.")
	_expect(navigation.route(Vector3(-5, 100, 0), Vector3(5, 100, 0)).is_empty(), "A complete wall produced a traversable path.")
	var previous_graph: AStar3D = navigation.graph
	var previous_route: PackedVector3Array = navigation.route(Vector3(-5, 100, 0), Vector3(-3, 100, 0))
	_box(scene, Vector3(0.5, 6, 50), Vector3(-4, 102, 0))
	await physics_frame
	navigation.begin(home, Vector3(0, 100, 0), {}, Navigation.RADIUS, true)
	navigation.advance(1)
	_expect(navigation.pending and navigation.is_ready() and navigation.graph == previous_graph and navigation.route(Vector3(-5, 100, 0), Vector3(-3, 100, 0)) == previous_route, "Soft retry removed a complete graph or exposed partial replacement routes.")
	_expect(not home._clear_space(Vector3(-4, 100.75, 0)), "New physical obstacle disappeared during background path checks.")
	slices = 0
	while navigation.pending and slices < 3000:
		navigation.advance()
		_expect(navigation.last_slice_cells <= Navigation.MAX_CELLS_PER_SLICE, "Soft retry exceeded its work budget.")
		slices += 1
	_expect(not navigation.pending and navigation.graph != previous_graph and navigation.route(Vector3(-5, 100, 0), Vector3(-3, 100, 0)).is_empty(), "Complete replacement failed to publish the new obstacle atomically.")
	# Both completed and staged geometry follow a local origin shift.
	navigation.begin(home, Vector3(0, 100, 0), {}, Navigation.RADIUS, true)
	navigation.advance(1)
	var published_id: int = navigation.graph.get_point_ids()[0]
	var staged_id: int = navigation._building_graph.get_point_ids()[0]
	var published_point: Vector3 = navigation.graph.get_point_position(published_id)
	var staged_point: Vector3 = navigation._building_graph.get_point_position(staged_id)
	var shift := Vector3(7, -2, 4)
	navigation.surface_origin_shifted(shift)
	_expect(navigation.graph.get_point_position(published_id).is_equal_approx(published_point + shift) and navigation._building_graph.get_point_position(staged_id).is_equal_approx(staged_point + shift), "Origin shift missed a published or staged graph.")
	# Hard topology changes still hide every old route immediately.
	navigation.begin(home, Vector3(0, 100, 0))
	_expect(not navigation.is_ready() and navigation.graph.get_point_count() == 0, "Hard rebuild retained stale routes.")
	navigation.rebuild(home, Vector3(0, 100, 0))
	navigation.begin(home, Vector3(0, 100, 0), {}, Navigation.RADIUS, true)
	var generation: int = navigation.generation
	navigation.advance(1)
	var next: Dictionary = state.campaign.ensure_body(15838, 23757)
	state.activate_body(next.id, 23757, 0, false)
	_expect(not navigation.advance() and not navigation.pending and navigation.generation != generation and navigation.graph.get_point_count() == 0, "Old-body job published into the new generation.")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("NAVIGATION_BUDGET_PASSED: real floor/walls, bounded slices, retained complete routes during soft retries, atomic replacement, rebase and canceled body generation.")
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
