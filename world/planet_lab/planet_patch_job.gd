extends RefCounted

const Layout = preload("res://world/planet_lab/planet_tile_layout.gd")
const Surface = preload("res://world/space/planet_surface.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
var body: Dictionary
var direction: Vector3
var previous_masks: Dictionary = {}
var result: Dictionary = {}
var duration_usec: int = 0


func run() -> void:
	var started: int = Time.get_ticks_usec()
	var layout := Layout.new(body.radius)
	var surface := Surface.new(body)
	result = layout.choose(direction, previous_masks)
	for tile: Dictionary in result.values():
		if previous_masks.get(tile.id, -1) == tile.mask:
			continue
		tile["anchor"] = surface.point(tile.face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		tile["arrays"] = Patch.build_arrays(tile, surface)
	duration_usec = Time.get_ticks_usec() - started
