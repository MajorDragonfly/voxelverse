extends Control
const Style = preload("res://ui/frontend/menu_style.gd")
const Markers = preload("res://ui/minimap/map_markers.gd")
signal dragged(delta_pixels: Vector2)
signal zoomed(direction: int, point: Vector2)
signal place_selected(id: String)
var terrain: RefCounted
var places: Array[Dictionary] = []
var explorers: Array[Vector2] = []
var selected_id: String = ""
var ui_scale: float = 1.0
var _dragging: bool = false
var _moved: float = 0.0
var _hovered: String = ""
var _press := Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = FOCUS_ALL
	gui_input.connect(_input_map)
	mouse_exited.connect(func() -> void: _hovered = ""; queue_redraw())

func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)

func screen_point(point: Vector2) -> Vector2:
	return size * 0.5 + (point - terrain.center) / (2.0 * terrain.radius) * Vector2.ONE * minf(size.x, size.y)

func offset_at(point: Vector2) -> Vector2:
	return terrain.center + (point - size * 0.5) / minf(size.x, size.y) * 2.0 * terrain.radius

func _input_map(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_moved = 0
				_press = event.position
				grab_focus()
			elif _dragging:
				_dragging = false
				if _moved < 6:
					var id: String = _hit(event.position)
					if not id.is_empty(): place_selected.emit(id)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoomed.emit(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1, event.position)
	elif event is InputEventMouseMotion:
		if _dragging:
			_moved += event.relative.length()
			dragged.emit(event.relative)
		else:
			_hovered = _hit(event.position)
			queue_redraw()
	accept_event()

func _hit(point: Vector2) -> String:
	var closest: float = 16.0 * ui_scale
	var result: String = ""
	for place: Dictionary in places:
		var distance: float = screen_point(place.position).distance_to(point)
		if distance < closest:
			closest = distance
			result = place.id
	return result

func cancel_drag() -> void:
	_dragging = false

func _draw() -> void:
	if terrain == null: return
	draw_rect(Rect2(Vector2.ZERO, size), Style.INK)
	# Square texture, equal metres per pixel in both axes; letterbox instead of
	# stretching terrain and confusing distances when the window changes shape.
	var edge: float = minf(size.x, size.y)
	var area := Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)
	draw_texture_rect(terrain.texture, area, false)
	for i in range(1, 8):
		var fraction: float = float(i) / 8.0
		draw_line(area.position + Vector2(edge * fraction, 0), area.position + Vector2(edge * fraction, edge), Color(0.7, 0.85, 0.84, 0.07))
	draw_rect(area, Style.EDGE, false, 1)
	for point in explorers:
		var screen: Vector2 = screen_point(point)
		if area.grow(-10).has_point(screen):
			draw_circle(screen, 6, Style.INK)
			draw_circle(screen, 3.5, Style.TEXT)
	for place: Dictionary in places:
		var point: Vector2 = screen_point(place.position)
		if area.grow(-12).has_point(point):
			Markers.draw_place(self, point, place.kind, place.id == selected_id, ui_scale)
			if place.id in [selected_id, _hovered]:
				var font := get_theme_default_font()
				var label: String = str(place.name).left(40)
				var text_size: int = roundi(16 * ui_scale)
				var length: float = minf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 16, area.size.x - 12)
				var origin := Vector2(clampf(point.x + 14, area.position.x + 4, area.end.x - length - 4), clampf(point.y - 13, 4, size.y - 30))
				draw_rect(Rect2(origin, Vector2(length, 28 * ui_scale)), Style.PANEL)
				draw_string(font, origin + Vector2(8, 19 * ui_scale), label, HORIZONTAL_ALIGNMENT_LEFT, length - 16, text_size, Style.TEXT)
	draw_string(get_theme_default_font(), area.position + Vector2(12, 24), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.TEXT)
