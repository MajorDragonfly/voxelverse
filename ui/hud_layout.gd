extends RefCounted
## Shared physical-pixel measurements for the gameplay HUD and minimap.
## Menu canvases keep their own scaling and ownership.
const MARGIN := 16.0
const GAP := 10.0

static func physical_rect(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	var factor: float = canvas_scale(control)
	return Rect2(rect.position / factor, rect.size / factor)

static func top_dock_y(context: Node, placement: Rect2) -> float:
	# Owners publish actual painted controls, rather than guessing child names
	# or reserving a constant height that ignores locale and text scale.
	var top: float = placement.position.y
	for provider: Node in context.get_tree().get_nodes_in_group(&"hud_top_dock"):
		for rect: Rect2 in provider.hud_top_rects():
			if rect.position.x < placement.end.x and rect.end.x > placement.position.x:
				top = maxf(top, rect.end.y + GAP)
	return top

static func gameplay_entries_visible(context: Node, player: Node) -> bool:
	# Poll from always-processing UI nodes: gameplay controllers stop during a modal pause.
	return not context.get_tree().paused and is_instance_valid(player) and not bool(player.get("inspection_mode_enabled"))

static func canvas_scale(control: Node) -> float:
	return control.get_viewport().get_visible_rect().size.x / maxf(control.get_window().size.x, 1.0)

static func screen_size(control: Node) -> Vector2:
	return control.get_viewport().get_visible_rect().size / canvas_scale(control)

static func dock_width(control: Node) -> float:
	var width := 292.0 if screen_size(control).x >= 1000.0 else 248.0
	var player := control.get_tree().get_first_node_in_group(&"player")
	var presentation := player.get_node_or_null("HUDPresentation") if player != null else null
	if presentation != null and presentation.has_method("vitals_reserved_width"):
		width = maxf(width, presentation.vitals_reserved_width())
	return width

static func text_scale(control: Node) -> float:
	return clampf(float(control.get_node("/root/DisplaySettings").ui_scale), 1.0, 1.5)

static func scale_fonts(node: Node, factor: float) -> void:
	# Physical-pixel layout removes the Window canvas stretch. Apply the user's
	# text preference explicitly, without rebuilding controls or gameplay state.
	if node is Label or node is BaseButton:
		if not node.has_meta("hud_base_font_size"):
			node.set_meta("hud_base_font_size", node.get_theme_font_size("font_size"))
		var size := roundi(float(node.get_meta("hud_base_font_size")) * factor)
		if node.get_theme_font_size("font_size") != size:
			node.add_theme_font_size_override("font_size", size)
	for child: Node in node.get_children():
		scale_fonts(child, factor)

static func place(control: Control, rect: Rect2) -> void:
	var factor := canvas_scale(control)
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.scale = Vector2.ONE * factor
	control.position = rect.position * factor
	control.size = rect.size
