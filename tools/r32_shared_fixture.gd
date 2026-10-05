extends RefCounted
## Native review tools already declare a real window before public entry.
## Headless desktop dimensions are 64x64; declare the same fixture explicitly.
static func window(tree: SceneTree, dimensions: Vector2i) -> void:
	var display: Node = tree.root.get_node("DisplaySettings")
	display.display_mode = 0
	display.resolution = dimensions
	display.ui_scale = 1.0
	display._apply_settings(false)
	tree.root.content_scale_size = Vector2i.ZERO
	tree.root.content_scale_factor = 1.0
	tree.root.size = dimensions
	print("R32_01_SOURCE_WINDOW: ", dimensions)
