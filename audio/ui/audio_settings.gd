extends CanvasLayer
## Standalone F7 panel. The menu workstream can instead reuse AudioManager's API.

var _audio: Node
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _preferences: Dictionary = {}
const LABELS := {&"master": "Gesamtlautstärke", &"music": "Musik", &"ambience": "Umgebung",
	&"effects": "Spieleffekte", &"ui": "Menügeräusche"}


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
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
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "VOXELVERSE · AUDIO"
	title.add_theme_font_size_override("font_size", 27)
	rows.add_child(title)
	var hint := Label.new()
	hint.text = "Lautstärke wird automatisch gespeichert."
	rows.add_child(hint)
	for channel in LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		rows.add_child(row)
		var label := Label.new()
		label.text = LABELS[channel]
		label.custom_minimum_size.x = 190
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(230, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.max_value = 100
		slider.step = 1
		slider.value = _audio.get_volume(channel) * 100.0
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 55
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text = "%d %%" % int(slider.value)
		row.add_child(value)
		_sliders[channel] = slider
		_values[channel] = value
		slider.value_changed.connect(_volume_changed.bind(channel))
	for item in [[&"night_mode", "Nachtmodus · große Lautstärkeunterschiede verringern"],
		[&"mute_in_background", "Stumm, wenn das Spielfenster im Hintergrund ist"]]:
		var key := StringName(item[0])
		var option := CheckButton.new()
		option.text = item[1]
		option.custom_minimum_size.y = 40
		option.button_pressed = _audio.get_preference(key)
		option.toggled.connect(func(enabled: bool): _audio.set_preference(key, enabled))
		rows.add_child(option)
		_preferences[key] = option
	_audio.preference_changed.connect(func(key: StringName, enabled: bool):
		if _preferences.has(key):
			_preferences[key].set_pressed_no_signal(enabled))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	rows.add_child(buttons)
	_add_button(buttons, "Testton", func(): _audio.play_ui())
	_add_button(buttons, "Standardwerte", func(): _audio.reset_settings())
	var close := _add_button(buttons, "Zurück · F7 / Esc", func(): _audio.close_settings())
	close.grab_focus()
	_audio.settings_changed.connect(_sync)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _volume_changed(value: float, channel: StringName) -> void:
	_audio.set_volume(channel, value / 100.0)


func _sync(channel: StringName, value: float) -> void:
	if _sliders.has(channel):
		_sliders[channel].set_value_no_signal(value * 100.0)
		_values[channel].text = "%d %%" % roundi(value * 100.0)
