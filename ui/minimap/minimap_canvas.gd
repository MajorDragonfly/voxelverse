extends Control
## Screen-only drawing. Coordinates arrive in metres in a body-local map frame.
const Style = preload("res://ui/progression_style.gd")
signal heading_requested(direction: Vector2)
var terrain: RefCounted
var position_m := Vector2.ZERO
var direction := Vector2.UP
var markers: Array[Dictionary] = []
var group_view: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	tooltip_text = "Norden ist oben. Dreieck: Blickrichtung · Haus: Heimat · Punkte: eigene Gruppe.\nTasten + / −: Kartenmaßstab ändern."
	gui_input.connect(_map_input)

func _map_input(event: InputEvent) -> void:
	accept_event()
	if not group_view or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not map_rect().has_point(event.position): return
	var offset: Vector2 = event.position - screen_point(position_m)
	if offset.length() < 12.0: return # The separate center button moves the focus.
	heading_requested.emit(offset.normalized())

func map_rect() -> Rect2:
	# A short HUD window may reduce height; do not stretch distances or headings.
	var side := minf(size.x - 24, size.y - 30)
	return Rect2(Vector2((size.x - side) * 0.5, 18), Vector2.ONE * side)

func screen_point(point: Vector2) -> Vector2:
	var area := map_rect()
	return area.get_center() + (point - terrain.center) / (terrain.radius * 2.0) * area.size

func _draw() -> void:
	if terrain == null: return
	var area := map_rect()
	draw_style_box(Style.box(Color("101e28"), Color("365363"), 0), Rect2(Vector2.ZERO, size))
	draw_texture_rect(terrain.texture, area, false)
	for index in range(1, 4):
		var fraction: float = float(index) / 4.0
		draw_line(area.position + Vector2(area.size.x * fraction, 0), area.position + Vector2(area.size.x * fraction, area.size.y), Color(0.8, 0.9, 0.9, 0.08))
		draw_line(area.position + Vector2(0, area.size.y * fraction), area.position + Vector2(area.size.x, area.size.y * fraction), Color(0.8, 0.9, 0.9, 0.08))
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.5 - 5, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Style.TEXT)
	for marker: Dictionary in markers:
		var point: Vector2 = screen_point(marker["position"])
		if not point.is_finite(): continue
		var inside: Rect2 = area.grow(-8)
		if not inside.has_point(point):
			if marker["kind"] != "home": continue
			var delta: Vector2 = point - inside.get_center()
			var factor: float = minf((inside.size.x * 0.5) / maxf(absf(delta.x), 0.001), (inside.size.y * 0.5) / maxf(absf(delta.y), 0.001))
			point = inside.get_center() + delta * factor
			draw_line(point - delta.normalized() * 12, point, Color("e5c38c"), 2)
		if marker["kind"] == "home":
			preload("res://ui/minimap/map_markers.gd").draw_place(self, point, "home")
		else:
			draw_circle(point, 4.5, Color("0d202b"))
			draw_circle(point, 3.0, Style.SOCIAL)
			if marker.get("selected", false): draw_arc(point, 6, 0, TAU, 16, Color.WHITE, 1)
	var center: Vector2 = screen_point(position_m)
	if area.has_point(center):
		var heading: Vector2 = direction if direction.length_squared() > 0.1 else Vector2.UP
		var side := Vector2(-heading.y, heading.x)
		if group_view:
			var left: Vector2 = heading.rotated(-deg_to_rad(25.0)) * 25.0
			var right: Vector2 = heading.rotated(deg_to_rad(25.0)) * 25.0
			draw_colored_polygon(PackedVector2Array([center, center + left, center + right]), Color(0.48, 0.83, 0.95, 0.22))
			draw_line(center, center + left, Color("91d9e8"), 1.5)
			draw_line(center, center + right, Color("91d9e8"), 1.5)
			draw_arc(center, 7, 0, TAU, 20, Color.WHITE, 1.5)
		else:
			draw_colored_polygon(PackedVector2Array([center + heading * 9, center - heading * 5 + side * 5, center - heading * 2, center - heading * 5 - side * 5]), Color("ffffff"))
	# The bar is one quarter of the full width, in the same projection as terrain.
	var bar_start := area.position + Vector2(5, area.size.y - 8)
	draw_line(bar_start, bar_start + Vector2(area.size.x / 4.0, 0), Color("0e202a"), 4)
	draw_line(bar_start, bar_start + Vector2(area.size.x / 4.0, 0), Color.WHITE, 2)
