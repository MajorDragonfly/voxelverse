extends CanvasLayer
## Audio panel opened from the shared settings menu. F7 remains an optional shortcut.

var _audio: Node
var _previous_focus: Control
var _sliders: Dictionary = {}
var _preferences: Dictionary = {}



func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	_previous_focus = get_viewport().gui_get_focus_owner()
	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.035, 0.88)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.070, 0.085)
	style.border_color = Color(0.22, 0.58, 0.62)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	panel.theme = preload("res://ui/frontend/menu_style.gd").theme()
	var rows := preload("res://audio/ui/audio_settings_content.gd").new()
	panel.add_child(rows)
	_sliders = rows._sliders
	_preferences = rows._preferences
	rows._add_button(rows, "Zurück · Esc", func(): _audio.close_settings()).grab_focus()


func _exit_tree() -> void:
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus.call_deferred()
