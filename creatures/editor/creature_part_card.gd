extends Button
## Native, resolution-independent thumbnails generated from the part recipes.
## A cancelled palette drag never changes the creature.
const Parts = preload("res://creatures/editor/creature_part_library.gd")
var definition: Dictionary = {}
var category: String = ""


func configure(part: Dictionary, category_id: String, available: bool) -> void:
	definition = part
	category = category_id
	disabled = not available
	custom_minimum_size = Vector2(126.0, 126.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = str(part.get("description", "")) + ("\nZur Kreatur ziehen oder anklicken." if available else "\nDurch das Entdecken von Arten freischalten.")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_FORBIDDEN


func _draw() -> void:
	var tint := Color("d9eee7") if not disabled else Color("627c83")
	var font: Font = get_theme_default_font()
	var title: String = str(definition.get("name", "Teil"))
	if title.length() > 17:
		title = title.left(16) + "…"
	draw_string(font, Vector2(10, size.y - 28), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 14, tint)
	draw_string(font, Vector2(10, size.y - 10), "Gesperrt" if disabled else "%d Formpunkte" % int(definition.get("complexity", 0)), HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 11, tint.darkened(0.18))
	var center := Vector2(size.x * 0.5, 44)
	var voxels: Array = definition.get("voxels", [])
	if category in ["body", "paint"]:
		var color: Color = definition.get("color", definition.get("base_tint", Color("92c2a3")))
		if disabled:
			color = color.darkened(0.58)
		draw_set_transform(center, -0.18, Vector2(1.5, 0.85))
		draw_circle(Vector2.ZERO, 22, color)
		draw_set_transform(Vector2.ZERO)
		if category == "paint":
			for i in range(4):
				draw_circle(center + Vector2(-20 + i * 13, sin(float(i)) * 10), 4, definition.get("accent", Color("285a48")))
		return
	var projected: Array[Dictionary] = []
	var bounds := Rect2()
	for voxel: Dictionary in voxels:
		var position: Vector3 = voxel.get("position", Vector3.ZERO)
		var dimensions: Vector3 = voxel.get("size", Vector3.ONE * 0.2)
		var point := Vector2(position.x * 0.8 - position.z * 0.65, -position.y + position.z * 0.18)
		var extent := Vector2(dimensions.x * 0.8 + dimensions.z * 0.65, dimensions.y + dimensions.z * 0.18)
		var rect := Rect2(point - extent * 0.5, extent)
		bounds = rect if projected.is_empty() else bounds.merge(rect)
		projected.append({"point": point, "extent": extent, "color": voxel.get("color", tint), "depth": position.z})
	projected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] > b["depth"])
	var factor: float = minf(72.0 / maxf(bounds.size.x, 0.01), 59.0 / maxf(bounds.size.y, 0.01))
	for piece: Dictionary in projected:
		var point: Vector2 = center + (piece["point"] - bounds.get_center()) * factor
		var extent: Vector2 = piece["extent"] * factor
		var color: Color = piece["color"]
		if disabled:
			color = color.darkened(0.55)
		draw_set_transform(point, 0.0, extent * 0.5)
		draw_circle(Vector2.ZERO, 1.0, color)
		draw_set_transform(Vector2.ZERO)


func _get_drag_data(_position: Vector2) -> Variant:
	if disabled or category in ["body", "paint"]:
		return null
	var card := get_script().new() as Control
	card.call("configure", definition, category, true)
	card.modulate.a = 0.85
	set_drag_preview(card)
	return {"creature_part": str(definition.get("id", ""))}
