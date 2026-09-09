extends RefCounted

const Surface = preload("res://world/space/planet_surface.gd")
const Patch = preload("res://world/planet_lab/planet_patch_mesh.gd")
var body: Dictionary
var tiles: Array[Dictionary] = []


func run() -> void:
	# Each worker owns its noise generators and output; no scene/render objects.
	var surface := Surface.new(body)
	for tile: Dictionary in tiles:
		tile["anchor"] = surface.point(tile.face, tile.uv.x + tile.width * 0.5, tile.uv.y + tile.width * 0.5)
		tile["arrays"] = Patch.build_arrays(tile, surface)
