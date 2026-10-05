extends SceneTree
## Actual canonical placements in the visible ring of an accepted delayed job.
const Cube = preload("res://world/space/cube_sphere.gd")
const Context = preload("res://core/campaign/surface_context.gd")
const Job = preload("res://world/surface/surface_scenery_job.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var campaign: Dictionary = Context.create({"id": "r32-07-margin", "seed": 15838})
	var body: Dictionary = Context.descriptor(campaign)
	var focus: Dictionary = campaign.surface_context.spawn
	var anchor: Array = Cube.cartesian(focus, body.radius)
	var basis: Basis = Cube.frame(Cube.vector(Cube.direction(focus.face, focus.u, focus.v)))
	var missing: Array = []
	var counts: Array = []
	# Existing acceptance permits 64 m displacement, but the shader still
	# displays proxies out to 256 m. Test both travel directions, not a cap formula.
	for sign_value in [-1.0, 1.0]:
		var observer: Array = Cube.global_position(basis.x * (sign_value * 63.5), anchor)
		var job := Job.new()
		job.body = body
		job.focus = Cube.from_cartesian(body.id, observer, body.radius)
		job.prepare()
		job.run()
		var holes: int = 0
		var visible: int = 0
		for batch: Dictionary in job.result.batches:
			for transform: Transform3D in batch.transforms:
				var distance: float = transform.origin.length()
				if distance >= 256.0: continue
				visible += 1
				var old_relative: Vector3 = transform.origin + Cube.local_position(job.result.anchor, anchor)
				if old_relative.length() > Job.RADIUS:
					holes += 1
					missing.append({"direction": sign_value, "observer_distance": distance, "old_anchor_distance": old_relative.length(), "asset": batch.asset_id})
		counts.append({"direction": sign_value, "visible": visible, "missing": holes, "instances": job.result.instances, "cells": job.result.cell_ids.size(), "worker_ms": job.elapsed_usec / 1000.0})
		_expect(visible > 40, "Margin route contains no meaningful visible scenery")
		_expect(holes == 0, "Accepted 63.5 m delayed scenery omits still-visible canonical proxies")
	var max_cells: int = 0
	for radius in [50000.0, 4194305.0, 6371000.0, 100000000.0]:
		var descriptor: Dictionary = body.duplicate(true)
		descriptor.radius = radius
		for face in range(6):
			for uv in [Vector2.ZERO, Vector2(1.0, 0.3), Vector2(1.0, 1.0)]:
				var address: Dictionary = Cube.address(body.id, face, uv.x, uv.y)
				var cells: Dictionary = Job.cells_within(descriptor, address)
				max_cells = maxi(max_cells, cells.size())
				_expect(cells.size() <= Job.MAX_CELLS, "Canonical scenery cell cap exceeded at a cube edge/corner")
	print("R32_07_SCENERY_MARGIN ", JSON.stringify({"checks": checks, "radius": Job.RADIUS, "max_cells": max_cells, "routes": counts, "missing": missing, "passed": failures.is_empty()}))
	for failure in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok and message not in failures: failures.append(message)
