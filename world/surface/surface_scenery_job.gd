extends RefCounted
## Bounded, render-only scenery using the exact canonical nearby placements.
const Placement = preload("res://world/surface/surface_population_job.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Factory = preload("res://world/surface/planet_surface_factory.gd")
const RADIUS: float = 288.0
const MAX_CELLS: int = 2048
var body: Dictionary
var focus: Dictionary
var exclusions: Array[Dictionary] = []
var surface: RefCounted
var result: Dictionary = {}
var elapsed_usec: int = 0


func prepare() -> void:
	surface = Factory.create(body)


static func cells_within(descriptor: Dictionary, address: Dictionary) -> Dictionary:
	var level: int = Placement.level_for(descriptor.radius)
	var side: int = 1 << level
	var step: float = 2.0 / side
	var origin: Array = Cube.direction(address.face, address.u, address.v)
	var cx: int = floori((address.u + 1.0) / step)
	var cy: int = floori((address.v + 1.0) / step)
	# Cube projection contracts most at corners (factor 1/3). Normalizing
	# candidates reaches adjacent faces too, without world-size float positions.
	var ring: int = ceili(RADIUS * 3.0 / (step * descriptor.radius)) + 2
	var cells: Dictionary = {}
	for y in range(cy - ring, cy + ring + 1):
		for x in range(cx - ring, cx + ring + 1):
			var normalized: Dictionary = Cube.address(descriptor.id, address.face, -1.0 + (x + 0.5) * step, -1.0 + (y + 0.5) * step)
			var nx: int = clampi(floori((normalized.u + 1.0) / step), 0, side - 1)
			var ny: int = clampi(floori((normalized.v + 1.0) / step), 0, side - 1)
			var id: String = "%s:land1:%d:%d:%d:%d" % [descriptor.id, level, normalized.face, nx, ny]
			if cells.has(id): continue
			var d: Array = Cube.direction(normalized.face, -1.0 + (nx + 0.5) * step, -1.0 + (ny + 0.5) * step)
			var distance: float = Cube.local_position(d, origin).length() * descriptor.radius
			if distance > RADIUS + step * descriptor.radius: continue
			cells[id] = {"id": id, "level": level, "face": normalized.face, "x": nx, "y": ny, "step": step, "distance": distance}
	return cells


func run() -> void:
	var started: int = Time.get_ticks_usec()
	var cells: Dictionary = cells_within(body, focus)
	# Supported body sizes fit this bound; never silently publish a partial cap.
	if cells.size() > MAX_CELLS:
		result = {"error": "Scenery cell budget exceeded", "cells": cells.size()}
		return
	var anchor: Array = Cube.cartesian(focus, body.radius)
	var batches: Dictionary = {}
	var ids: Array = cells.keys()
	ids.sort()
	var instances: int = 0
	for index in range(ids.size()):
		var job := Placement.new()
		job.body = body
		job.cell = cells[ids[index]]
		job.surface = surface
		job.scenery_only = true
		job.run()
		var offset: Vector3 = Cube.local_position(job.result.anchor, anchor)
		for batch: Dictionary in job.result.batches:
			var key: String = batch.species.species_id
			if not batches.has(key):
				batches[key] = {"asset_id": batch.asset_id, "species": batch.species, "transforms": [], "custom": []}
			for i in range(batch.transforms.size()):
				var transform: Transform3D = batch.transforms[i]
				transform.origin += offset
				if transform.origin.length() > RADIUS: continue
				var reserved: bool = false
				for exclusion: Dictionary in exclusions:
					if transform.origin.distance_to(Cube.local_position(exclusion.point, anchor)) < exclusion.radius:
						reserved = true
						break
				if reserved: continue
				var shade: Color = batch.custom[i]
				# Blue selects a canonical cell in the published ownership texture.
				batches[key].transforms.append(transform)
				# Integer / 2048 survives half-float custom-data storage exactly.
				# Add the texel-centre offset in the shader, after decoding.
				batches[key].custom.append(Color(shade.r, shade.g, float(index) / MAX_CELLS, 1.0))
				instances += 1
	result = {"focus": focus, "anchor": anchor, "cell_ids": ids, "batches": batches.values(), "instances": instances}
	elapsed_usec = Time.get_ticks_usec() - started
