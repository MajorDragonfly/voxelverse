extends SceneTree
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
const Job = preload("res://world/surface/surface_scenery_job.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var campaign: Dictionary = Context.create({"id": "distance-fixture", "seed": 15838})
	var body: Dictionary = Context.descriptor(campaign)
	var surface: RefCounted = Factory.create(body)
	var max_top_normal_error: float = 0.0
	for face in range(6):
		var level: int = Layout.new(body.radius).max_level - 2
		var side: int = 1 << level
		var tile: Dictionary = Layout.patch(face, level, side / 2, side / 2)
		tile.mask = 5
		tile.anchor = surface.point(face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		var mesh: Array = Patch.build_arrays(tile, surface).land_arrays
		# The first 256 quads are column tops, including the stitched perimeter.
		# Walls keep their geometric normals; collision uses unchanged positions.
		for y in range(16):
			for x in range(16):
				var up: Vector3 = Cube.vector(Cube.direction(face, tile.uv.x + (x + 0.5) * tile.width / 16.0, tile.uv.y + (y + 0.5) * tile.width / 16.0))
				var normal: Vector3 = mesh[Mesh.ARRAY_NORMAL][mesh[Mesh.ARRAY_INDEX][(y * 16 + x) * 6]]
				max_top_normal_error = maxf(max_top_normal_error, normal.distance_to(up))
	_expect(max_top_normal_error < 0.00001, "Stitched column tops introduce artificial slope lighting / patch grid")
	# All six cube orientations: the sun above a coarse slope must light its
	# outside, just as it lights the nearby voxel tops.
	for face in range(6):
		var tile: Dictionary = Layout.patch(face, Layout.new(body.radius).max_level - 4, 10, 10)
		tile.mask = 0
		tile.anchor = surface.point(face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		var arrays: Array = Patch.build_arrays(tile, surface).land_arrays
		for i in range(arrays[Mesh.ARRAY_VERTEX].size()):
			var up: Vector3 = Cube.vector(Cube.global_position(arrays[Mesh.ARRAY_VERTEX][i], tile.anchor)).normalized()
			_expect(arrays[Mesh.ARRAY_NORMAL][i].dot(up) > 0.8, "Distant terrain normals point into the planet")
	var max_cells: int = 0
	# Just above a level boundary gives the smallest cells and largest cell set.
	for radius in [50000.0, 4194305.0, 6371000.0, 100000000.0]:
		body.radius = radius
		var layout := Layout.new(radius)
		for uv in [Vector2.ZERO, Vector2(1.0, 0.3), Vector2(1.0, 1.0)]:
			var center: Dictionary = Cube.address(body.id, 0, uv.x, uv.y)
			var cells: Dictionary = Job.cells_within(body, center)
			max_cells = maxi(max_cells, cells.size())
			_expect(cells.size() <= Job.MAX_CELLS, "Distant scenery exceeded its cell budget")
			var cover: Dictionary = layout.choose(Cube.vector(Cube.direction(center.face, center.u, center.v)))
			var frame: Basis = Cube.frame(Cube.vector(Cube.direction(center.face, center.u, center.v)))
			var absolute: Array = Cube.cartesian(center, radius)
			for i in range(24):
				var tangent: Vector3 = frame * Vector3(cos(i * TAU / 24.0) * 200.0, 0, sin(i * TAU / 24.0) * 200.0)
				var point: Dictionary = Cube.from_cartesian(body.id, Cube.global_position(tangent, absolute), radius)
				var target: String = _cell_id(body, point)
				_expect(cells.has(target), "Scenery misses a direction at 200 metres, including cube seams")
				var tile: Dictionary = layout.find_at(point.face, point.u, point.v, cover)
				_expect(not tile.is_empty() and tile.width * radius / Patch.CELLS <= 8.0, "Terrain loses its voxel silhouette inside 200 metres")
	body = Context.descriptor(campaign)
	var job := Job.new()
	job.body = body
	job.focus = campaign.surface_context.spawn
	job.prepare()
	job.run()
	_expect(not job.result.has("error") and job.result.instances > 40, "Real starting landscape has no distant scenery")
	var distant: int = 0
	var maximum_error: float = 0.0
	var cells: Dictionary = Job.cells_within(body, job.focus)
	var exact: Dictionary = {}
	for batch: Dictionary in job.result.batches:
		for i in range(batch.transforms.size()):
			var far: Transform3D = batch.transforms[i]
			if far.origin.length() >= 150.0 and far.origin.length() <= 224.0: distant += 1
			var index: int = floori(batch.custom[i].b * Job.MAX_CELLS)
			var id: String = job.result.cell_ids[index]
			if not exact.has(id):
				var full := Job.Placement.new()
				full.body = body
				full.cell = cells[id]
				full.surface = job.surface
				full.run()
				exact[id] = full.result
			var data: Dictionary = exact[id]
			var nearest: float = INF
			for near: Dictionary in data.batches:
				if near.asset_id != batch.asset_id: continue
				for transform: Transform3D in near.transforms:
					var error: float = far.origin.distance_to(transform.origin + Cube.local_position(data.anchor, job.result.anchor))
					if error < nearest and transform.basis.is_equal_approx(far.basis): nearest = error
			maximum_error = maxf(maximum_error, nearest)
	_expect(maximum_error < 0.002, "Approaching a distant tree changes its position or shape")
	_expect(distant > 20, "No actual trees, bushes or rocks populate the 150–224 metre ring")
	print("SURFACE_DISTANCE ", JSON.stringify({"checks": checks, "max_cells": max_cells, "instances": job.result.instances,
		"distant_instances": distant, "batches": job.result.batches.size(), "worker_ms": job.elapsed_usec / 1000.0, "near_far_error_m": maximum_error,
		"max_top_normal_error": max_top_normal_error}))
	for failure in failures: push_error(failure)
	print("SURFACE_DISTANCE_PASSED ", failures.is_empty())
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _cell_id(body: Dictionary, address: Dictionary) -> String:
	var level: int = Job.Placement.level_for(body.radius)
	var side: int = 1 << level
	return "%s:land1:%d:%d:%d:%d" % [body.id, level, address.face,
		clampi(floori((address.u + 1.0) * 0.5 * side), 0, side - 1), clampi(floori((address.v + 1.0) * 0.5 * side), 0, side - 1)]

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok and message not in failures: failures.append(message)
