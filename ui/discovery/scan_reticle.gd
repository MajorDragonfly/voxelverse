extends Control

var progress: float = 0.0
var known: bool = false
var has_target: bool = false

func _draw() -> void:
	var center := size * 0.5
	var color := Color("c6df91") if known else Color("82d8db")
	draw_arc(center, 26, 0, TAU, 64, Color(0.04, 0.1, 0.13, 0.9), 8, true)
	draw_arc(center, 26, 0, TAU, 64, Color(0.7, 0.8, 0.8, 0.5), 2, true)
	if has_target and progress > 0.0:
		draw_arc(center, 26, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, color, 4, true)
	draw_line(center - Vector2(4, 0), center + Vector2(4, 0), color if has_target else Color.WHITE, 1.5, true)
	draw_line(center - Vector2(0, 4), center + Vector2(0, 4), color if has_target else Color.WHITE, 1.5, true)
