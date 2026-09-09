extends RefCounted
## Shared glyphs for the minimap, atlas and atlas legend.
const OWN := Color("e2c99d")
const FRIEND := Color("94cbb8")
const OUTLINE := Color("081820")

static func draw_place(canvas: CanvasItem, point: Vector2, kind: String, selected: bool = false, scale: float = 1.0) -> void:
	if selected: canvas.draw_arc(point, 13 * scale, 0, TAU, 24, Color("c6df91"), 2)
	canvas.draw_circle(point, 10 * scale, OUTLINE)
	if kind in ["friend_habitat", "friend_nest"]:
		var diamond := PackedVector2Array([point + Vector2(0, -8) * scale, point + Vector2(8, 0) * scale, point + Vector2(0, 8) * scale, point + Vector2(-8, 0) * scale])
		canvas.draw_colored_polygon(diamond, FRIEND)
		canvas.draw_circle(point, 2.5 * scale, OUTLINE)
	elif kind == "nest":
		canvas.draw_arc(point, 7 * scale, 0, PI, 16, OWN, 3 * scale)
		canvas.draw_line(point + Vector2(-7, -2) * scale, point + Vector2(7, -2) * scale, OWN, 2 * scale)
		canvas.draw_circle(point + Vector2(-2, 0) * scale, 2 * scale, OWN)
	else:
		var roof := PackedVector2Array()
		for offset in [Vector2(-7, -1), Vector2(0, -8), Vector2(7, -1), Vector2(5, -1), Vector2(5, 6), Vector2(-5, 6), Vector2(-5, -1)]: roof.append(point + offset * scale)
		canvas.draw_colored_polygon(roof, OWN)
		canvas.draw_rect(Rect2(point + Vector2(-1, 1) * scale, Vector2(3, 5) * scale), OUTLINE)
