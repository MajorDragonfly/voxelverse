extends RefCounted
## Shared physical-pixel measurements for the gameplay HUD and minimap.
## Menu canvases keep their own scaling and ownership.
const MARGIN := 16.0
const GAP := 10.0

static func canvas_scale(control: Node) -> float:
	return control.get_viewport().get_visible_rect().size.x / maxf(control.get_window().size.x, 1.0)

static func screen_size(control: Node) -> Vector2:
	return control.get_viewport().get_visible_rect().size / canvas_scale(control)

static func dock_width(control: Node) -> float:
	return 292.0 if screen_size(control).x >= 1000.0 else 248.0

static func place(control: Control, rect: Rect2) -> void:
	var factor := canvas_scale(control)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.scale = Vector2.ONE * factor
	control.position = rect.position * factor
	control.size = rect.size
