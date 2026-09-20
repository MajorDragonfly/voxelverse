extends CanvasLayer
## Shared modal audio page; the settings host retains its pause and navigation.

const Style = preload("res://ui/frontend/menu_style.gd")
const Text = preload("res://core/localization/ui_text.gd")
const LABELS := {&"master": "AUDIO_MASTER", &"music": "AUDIO_MUSIC",
	&"ambience": "AUDIO_AMBIENCE", &"effects": "AUDIO_EFFECTS", &"ui": "AUDIO_UI"}

var _audio: Node
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _mutes: Dictionary = {}
var _preferences: Dictionary = {}
var _audible_values: Dictionary = {}
var _panel: PanelContainer
var _scroll: ScrollContainer
var _status: Label
var _preview_channel: StringName = &""


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	var background := ColorRect.new()
	background.color = Color(0.015, 0.025, 0.035, 0.92)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_panel = PanelContainer.new()
	_panel.name = "AudioPanel"
	_panel.theme = Style.theme()
	for type in ["HSlider", "CheckButton"]:
		_panel.theme.set_stylebox("focus", type, _panel.theme.get_stylebox("focus", "Button"))
	add_child(_panel)
	var rows := VBoxContainer.new()
	_panel.add_child(rows)
	Style.label(rows, "AUDIO_TITLE", 27, Style.ACCENT)
	Style.paragraph(rows, "AUDIO_HINT", 18)
	_scroll = ScrollContainer.new()
	_scroll.name = "AudioScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	rows.add_child(_scroll)
	var channels := VBoxContainer.new()
	channels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	channels.add_theme_constant_override("separation", 16)
	_scroll.add_child(channels)
	for channel in LABELS:
		_add_channel(channels, channel)
	for item in [[&"night_mode", "AUDIO_NIGHT"], [&"mute_in_background", "AUDIO_BACKGROUND"]]:
		var row := HBoxContainer.new()
		channels.add_child(row)
		var label := Style.paragraph(row, item[1], 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key := StringName(item[0])
		var option := CheckButton.new()
		option.name = String(key)
		option.tooltip_text = item[1]
		option.custom_minimum_size.y = 44
		option.button_pressed = _audio.get_preference(key)
		option.toggled.connect(func(enabled: bool): _audio.set_preference(key, enabled))
		row.add_child(option)
		_preferences[key] = option
	_audio.preference_changed.connect(_preference_changed)
	_status = Style.paragraph(rows, "AUDIO_TEST_HINT", 16)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	rows.add_child(buttons)
	_add_button(buttons, "AUDIO_RESET", func():
		_audio.stop_settings_preview()
		_audio.reset_settings(), "ResetAudio")
	_add_button(buttons, "AUDIO_BACK", func(): _audio.close_settings(), "CloseAudio")
	_audio.settings_changed.connect(_sync)
	_audio.settings_preview_changed.connect(_preview_changed)
	get_node("/root/LocaleManager").language_changed.connect(func(_locale: String): _update_status())
	get_viewport().size_changed.connect(_resize)
	_resize()
	_sliders[&"master"].grab_focus()


func _add_channel(parent: Control, channel: StringName) -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	parent.add_child(rows)
	var heading := HBoxContainer.new()
	rows.add_child(heading)
	var label := Style.label(heading, LABELS[channel], 20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := Style.label(heading, "", 20)
	value.custom_minimum_size.x = 60
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_values[channel] = value
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	rows.add_child(controls)
	var slider := HSlider.new()
	slider.name = String(channel) + "Volume"
	slider.tooltip_text = LABELS[channel]
	slider.custom_minimum_size = Vector2(120, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.max_value = 100
	slider.step = 1
	controls.add_child(slider)
	_sliders[channel] = slider
	slider.value_changed.connect(func(volume: float): _audio.set_volume(channel, volume / 100.0))
	var mute := _add_button(controls, "AUDIO_MUTE", func(): _toggle_mute(channel), String(channel) + "Mute")
	mute.size_flags_horizontal = Control.SIZE_FILL
	mute.toggle_mode = true
	_mutes[channel] = mute
	var preview := _add_button(controls, "AUDIO_TEST", func(): _audio.play_settings_preview(channel), String(channel) + "Preview")
	preview.size_flags_horizontal = Control.SIZE_FILL
	_sync(channel, _audio.get_volume(channel))


func _add_button(parent: Control, text: String, callback: Callable, id: String) -> Button:
	var button := Style.button(parent, text, callback, id)
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button


func _resize() -> void:
	var available := get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(760.0, available.x - 24.0), minf(730.0, available.y - 24.0))
	_panel.position = (available - _panel.size) * 0.5


func _toggle_mute(channel: StringName) -> void:
	var volume: float = _audio.get_volume(channel)
	_audio.set_volume(channel, 0.0 if volume > 0.0 else float(_audible_values.get(channel, _audio.DEFAULTS[channel])))


func _sync(channel: StringName, value: float) -> void:
	if _sliders.has(channel):
		_sliders[channel].set_value_no_signal(value * 100.0)
		_values[channel].text = "%d %%" % roundi(value * 100.0)
		_mutes[channel].set_pressed_no_signal(value <= 0.0)
		if value > 0.0:
			_audible_values[channel] = value
	_update_status()


func _preference_changed(key: StringName, enabled: bool) -> void:
	if _preferences.has(key):
		_preferences[key].set_pressed_no_signal(enabled)
	_update_status()


func _preview_changed(channel: StringName) -> void:
	_preview_channel = channel
	_update_status()


func _update_status() -> void:
	if _status == null:
		return
	if _preview_channel.is_empty():
		_status.text = "AUDIO_TEST_HINT"
		return
	var muted: bool = _audio.get_volume(&"master") <= 0.0 or _audio.get_volume(_preview_channel) <= 0.0
	muted = muted or (_audio.get_preference(&"mute_in_background") and not _audio.is_window_focused())
	_status.text = Text.format_text("AUDIO_TEST_MUTED" if muted else "AUDIO_TEST_PLAYING", {"channel": Text.text(LABELS[_preview_channel])})
