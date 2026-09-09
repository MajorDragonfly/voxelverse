extends CanvasLayer

const Style = preload("res://ui/frontend/menu_style.gd")
var _saves: Node
var _flow: Node
var _label: Label
var _timer: float = 0.0
var _preview_timer: float = 0.0
var _world_frames: int = 0
var _world_identity: String = ""

func _ready() -> void:
	name = "SaveFeedback"
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saves = get_node("/root/SaveGameService")
	_flow = get_node("/root/SessionFlow")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.offset_left = -460
	margin.offset_top = -74
	margin.offset_right = -28
	margin.offset_bottom = -24
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_label = Label.new()
	_label.name = "SaveStatus"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Style.TEXT)
	_label.add_theme_color_override("font_shadow_color", Style.INK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)
	_saves.save_started.connect(_started)
	_saves.game_saved.connect(_saved)
	_saves.save_failed.connect(_failed)
	_saves.game_loaded.connect(func(_path: String): _timer = 0.0)
	hide()

func _process(delta: float) -> void:
	_timer = maxf(0.0, _timer - delta)
	visible = _timer > 0.0 and _flow.can_pause() and not _flow.loading and (not get_tree().paused or _flow.pause_open)
	if not _can_capture():
		_world_frames = 0
		return
	var identity: String = str(get_node("/root/GameState").campaign.data.id) + ":" + str(get_node("/root/GameState").world_seed)
	if identity != _world_identity:
		_world_identity = identity
		_world_frames = 0
		_preview_timer = 0.0
	_world_frames += 1
	_preview_timer -= delta
	if _world_frames >= 5 and _preview_timer <= 0.0 and _timer <= 0.0:
		_capture_preview()
		_preview_timer = 5.0

func _can_capture() -> bool:
	return DisplayServer.get_name() != "headless" and _saves.session_active and _flow.can_pause() and not _flow.loading and not get_tree().paused and not get_node("/root/DisplaySettings").is_menu_open()

func _capture_preview() -> void:
	if not _can_capture() or _world_frames < 5:
		return
	var picture: Image = get_viewport().get_texture().get_image()
	if picture == null or picture.is_empty():
		return
	# Keep aspect ratio; the browser may crop its display without stretching.
	var scale: float = minf(384.0 / picture.get_width(), 216.0 / picture.get_height())
	picture.resize(maxi(1, roundi(picture.get_width() * scale)), maxi(1, roundi(picture.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	_saves.cache_slot_preview(picture.save_png_to_buffer(), int(get_node("/root/GameState").world_seed))

func _started(_path: String) -> void:
	_capture_preview()
	_show_status("Wird gespeichert …", Style.MUTED, 30.0)

func _saved(_path: String) -> void:
	_show_status("✓ Gespeichert", Style.ACCENT, 3.0)

func _failed(_message: String) -> void:
	_show_status("Speichern fehlgeschlagen", Color("f2b09b"), 8.0)

func _show_status(message: String, color: Color, seconds: float) -> void:
	if not _flow.can_pause() or _flow.loading:
		_timer = 0.0
		hide()
		return
	_label.text = message
	_label.add_theme_color_override("font_color", color)
	_timer = seconds
	visible = _flow.can_pause() and not _flow.loading and (not get_tree().paused or _flow.pause_open)
