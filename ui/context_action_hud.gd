extends Node
const KeyHints = preload("res://core/input_preferences.gd")
const Design = preload("res://ui/design/design_system.gd")
const GameSymbols = preload("res://ui/design/game_symbols.gd")
const Layout = preload("res://ui/hud_layout.gd")

var _player: Node3D
var _ray: RayCast3D
var _hud: CanvasLayer
var _label: Label
var _crosshair: Label
var _hint_panel: PanelContainer
var _hint_icon: TextureRect


func _ready() -> void:
	_player = get_parent() as Node3D
	call_deferred("_install")


func _process(_delta: float) -> void:
	_update_context()


func _install() -> void:
	if _player == null:
		return
	_ray = _player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D/InteractionRay"
	) as RayCast3D
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _ray == null or _hud == null:
		return

	_crosshair = Label.new()
	_crosshair.name = "GameplayCrosshair"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -18.0
	_crosshair.offset_top = -18.0
	_crosshair.offset_right = 18.0
	_crosshair.offset_bottom = 18.0
	_crosshair.text = "+"
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_theme_font_size_override("font_size", 20)
	_crosshair.add_theme_color_override("font_color", Color(Design.TEXT, 0.82))
	_crosshair.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_crosshair.add_theme_constant_override("shadow_offset_x", 1)
	_crosshair.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_child(_crosshair)

	_hint_panel = PanelContainer.new()
	_hint_panel.name = "ContextActionHint"
	_hint_panel.theme = Design.theme()
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", Design.box(Design.PANEL, Design.EDGE, 8))
	_hud.add_child(_hint_panel)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_child(content)
	_hint_icon = GameSymbols.view("food", 22, Design.ACCENT)
	_hint_icon.name = "ContextActionSymbol"
	content.add_child(_hint_icon)
	_label = Label.new()
	_label.name = "ContextActionLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Design.TEXT)
	content.add_child(_label)
	_hide_context()


func _hide_context() -> void:
	_label.hide()
	_hint_panel.hide()


func _show_context(text: String, symbol: String) -> void:
	_label.text = text
	_hint_icon.texture = GameSymbols.texture(symbol, Design.ACCENT)
	_label.show()
	_hint_panel.show()
	Layout.scale_fonts(_hint_panel, Layout.text_scale(self))
	var screen := Layout.screen_size(self)
	var text_width := _label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x
	var width := minf(screen.x - 32.0, maxf(220.0, text_width + 46.0))
	Layout.place(_hint_panel, Rect2(Vector2((screen.x - width) * 0.5, screen.y * 0.5 + 72.0), Vector2(width, 0)))


func _update_context() -> void:
	if _label == null or _ray == null or _player == null:
		return
	if bool(_player.get("inspection_mode_enabled")):
		_hide_context()
		if _crosshair != null:
			_crosshair.hide()
		return
	if _crosshair != null:
		_crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_hide_context()
		return

	var wildlife_target: Node = null
	if _player.has_method("get_interaction_target"):
		wildlife_target = _player.call("get_interaction_target")
	if wildlife_target != null and wildlife_target.is_in_group(&"wildlife"):
		_show_wildlife_context(wildlife_target)
		if _crosshair != null:
			_crosshair.add_theme_color_override(
				"font_color",
				Design.ACCENT
			)
		return

	if _crosshair != null:
		_crosshair.add_theme_color_override(
			"font_color",
			Color(Design.TEXT, 0.82)
		)

	if bool(_player.get("is_swimming")):
		var hint := "Schwimmen · %s auftauchen" % KeyHints.binding_label("jump")
		var swim_source: Dictionary = _player.call("reachable_drink_source", _player.global_position)
		if not swim_source.is_empty():
			hint = "Schwimmen · %s trinken · %s auftauchen" % [KeyHints.binding_label("primary_action"), KeyHints.binding_label("jump")]
		_show_context(hint, "swim")
		return
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		_hide_context()
		return
	var collider := _resolve_parent_target(_ray.get_collider())
	var point: Vector3 = _ray.get_collision_point()
	if collider != null and collider.is_in_group(&"berry_bush"):
		var depleted: bool = bool(collider.get("is_depleted"))
		_show_context("Beerenstrauch · abgeerntet" if depleted else "Beeren · %s fressen" % KeyHints.binding_label("primary_action"), "berries")
		return
	if drink_prompt_at(point):
		_show_context("Wasser · %s trinken" % KeyHints.binding_label("primary_action"), "thirst")
		return
	_hide_context()


func drink_prompt_at(point: Vector3) -> bool:
	if _player == null or not _player.has_method("reachable_drink_source"):
		return false
	var source: Dictionary = _player.call("reachable_drink_source", point)
	return not source.is_empty()


func _show_wildlife_context(target: Node) -> void:
	# Species identity, role and stats belong exclusively to the E scanner.
	# Keep the food action for a carcass without revealing species information.
	if bool(target.get("is_dead")):
		_show_context("Nahrung · %s fressen" % KeyHints.binding_label("primary_action"), "diet_meat")
	else:
		_hide_context()


func _resolve_parent_target(value: Variant) -> Node:
	var current := value as Node
	var depth: int = 0
	while current != null and depth < 8:
		if (
			current.is_in_group(&"wildlife")
			or current.is_in_group(&"berry_bush")
			or current.has_method("interact")
		):
			return current
		current = current.get_parent()
		depth += 1
	return null
