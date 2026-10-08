extends Control
const Design = preload("res://ui/design/design_system.gd")
const RADIUS: float = 26.0

var progress: float = 0.0
var known: bool = false
var has_target: bool = false
var target_pixel: Vector2 = Vector2.ZERO

func scan_circle() -> Dictionary:
	var transform: Transform2D = get_global_transform_with_canvas()
	return {"center": transform * (size * 0.5),
		"radius": minf(transform.basis_xform(Vector2(RADIUS, 0)).length(),
			transform.basis_xform(Vector2(0, RADIUS)).length())}

func _draw() -> void:
	var center := size * 0.5
	var color := Design.SOCIAL if known else Design.ACCENT
	draw_arc(center, RADIUS, 0, TAU, 64, Color(Design.INK, 0.9), 8, true)
	draw_arc(center, RADIUS, 0, TAU, 64, Color(Design.MUTED, 0.5), 2, true)
	if has_target and progress > 0.0:
		draw_arc(center, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, color, 4, true)
	if has_target:
		draw_circle(target_pixel, 4, Color(Design.INK, 0.85))
		draw_arc(target_pixel, 4, 0, TAU, 16, color, 2, true)
	draw_line(center - Vector2(4, 0), center + Vector2(4, 0), color if has_target else Color.WHITE, 1.5, true)
	draw_line(center - Vector2(0, 4), center + Vector2(0, 4), color if has_target else Color.WHITE, 1.5, true)
