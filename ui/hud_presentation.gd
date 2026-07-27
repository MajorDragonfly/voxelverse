extends Node

var _player: Node3D
var _hud: CanvasLayer
var _world_label: Label
var _update_timer: float = 0.0


func _ready() -> void:
	_player = get_parent() as Node3D
	call_deferred("_install_hud_presentation")


func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = 0.25
	_update_world_label()


func _install_hud_presentation() -> void:
	if _player == null:
		return
	_hud = _player.get_node_or_null("HUD") as CanvasLayer
	if _hud == null:
		return

	_style_status_panel()
	_create_reticle()
	_create_world_label()
	_create_shortcut_hint()

	# Runtime creature text is created deferred by another component.
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime_label := _hud.get_node_or_null("CreatureRuntimeLabel") as Label
	if runtime_label != null:
		runtime_label.offset_left = 18.0
		runtime_label.offset_top = 158.0
		runtime_label.offset_right = 620.0
		runtime_label.offset_bottom = 214.0
		runtime_label.add_theme_color_override(
			"font_color",
			Color(0.69, 0.84, 0.82, 0.92)
		)
		runtime_label.add_theme_font_size_override("font_size", 14)


func _style_status_panel() -> void:
	var status := _hud.get_node_or_null("StatusContainer") as VBoxContainer
	if status == null:
		return

	status.offset_left = 20.0
	status.offset_top = 20.0
	status.offset_right = 330.0
	status.offset_bottom = 148.0
	status.add_theme_constant_override("separation", 4)

	var background := Panel.new()
	background.name = "StatusBackground"
	background.offset_left = 10.0
	background.offset_top = 10.0
	background.offset_right = 344.0
	background.offset_bottom = 154.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.045, 0.055, 0.82)
	panel_style.border_color = Color(0.20, 0.52, 0.52, 0.68)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	panel_style.shadow_size = 8
	background.add_theme_stylebox_override("panel", panel_style)
	_hud.add_child(background)
	_hud.move_child(background, 0)

	for child in status.get_children():
		var label := child as Label
		if label != null:
			label.add_theme_color_override(
				"font_color",
				Color(0.76, 0.88, 0.85, 1.0)
			)
			label.add_theme_font_size_override("font_size", 13)
			continue

		var bar := child as ProgressBar
		if bar == null:
			continue
		bar.custom_minimum_size = Vector2(300.0, 16.0)
		var background_style := StyleBoxFlat.new()
		background_style.bg_color = Color(0.04, 0.08, 0.09, 0.95)
		background_style.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", background_style)

		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = _get_bar_color(bar.name)
		fill_style.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill_style)


func _get_bar_color(bar_name: StringName) -> Color:
	match str(bar_name):
		"HealthBar": return Color(0.35, 0.72, 0.48, 1.0)
		"HungerBar": return Color(0.82, 0.64, 0.28, 1.0)
		"ThirstBar": return Color(0.25, 0.62, 0.78, 1.0)
		_: return Color(0.42, 0.70, 0.68, 1.0)


func _create_reticle() -> void:
	var reticle := Label.new()
	reticle.name = "VoxelReticle"
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.offset_left = -12.0
	reticle.offset_top = -15.0
	reticle.offset_right = 12.0
	reticle.offset_bottom = 15.0
	reticle.text = "◇"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_theme_font_size_override("font_size", 20)
	reticle.add_theme_color_override(
		"font_color",
		Color(0.76, 0.94, 0.90, 0.76)
	)
	_hud.add_child(reticle)


func _create_world_label() -> void:
	_world_label = Label.new()
	_world_label.name = "WorldProfileLabel"
	_world_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_world_label.offset_left = -390.0
	_world_label.offset_top = 18.0
	_world_label.offset_right = -18.0
	_world_label.offset_bottom = 116.0
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_world_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_world_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_label.add_theme_font_size_override("font_size", 14)
	_world_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.87, 0.87, 0.94)
	)
	_hud.add_child(_world_label)
	_update_world_label()


func _create_shortcut_hint() -> void:
	var hint := Label.new()
	hint.name = "PresentationShortcutHint"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -560.0
	hint.offset_top = -44.0
	hint.offset_right = -18.0
	hint.offset_bottom = -16.0
	hint.text = "F2 Creature Lab  ·  F8 Display  ·  F10 Mode  ·  F11 Fullscreen"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override(
		"font_color",
		Color(0.55, 0.68, 0.69, 0.84)
	)
	_hud.add_child(hint)


func _update_world_label() -> void:
	if _world_label == null or _player == null:
		return

	var position_2d := Vector2(
		_player.global_position.x,
		_player.global_position.z
	)
	var sample: Dictionary = WorldGenerator.sample_world(
		position_2d.x,
		position_2d.y
	)

	_world_label.text = (
		"VOXELVERSE · WORLD %d\n"
		+ "%s  ·  Height %.1f  ·  Temp %d%%  ·  Moisture %d%%\n"
		+ "X %.0f  Z %.0f  ·  %d FPS"
	) % [
		int(sample.get("seed", 1)),
		str(sample.get("biome_name", "Unknown")),
		float(sample.get("height", 0.0)),
		roundi(float(sample.get("temperature", 0.0)) * 100.0),
		roundi(float(sample.get("moisture", 0.0)) * 100.0),
		position_2d.x,
		position_2d.y,
		Engine.get_frames_per_second(),
	]
