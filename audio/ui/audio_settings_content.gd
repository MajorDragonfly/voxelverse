extends VBoxContainer
## Shared controls: the in-game Audio tab and the optional F7 modal use one owner.

var _audio: Node
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _preferences: Dictionary = {}
const LABELS := {&"master": "Gesamtlautstärke", &"music": "Musik", &"ambience": "Umgebung",
	&"effects": "Spieleffekte", &"ui": "Menügeräusche"}


func _ready() -> void:
	_audio = get_node("/root/AudioManager")
	add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "PT17_AUDIO_TITLE"
	title.add_theme_font_size_override("font_size", 27)
	add_child(title)
	var hint := Label.new()
	hint.text = "Lautstärke wird automatisch gespeichert."
	add_child(hint)
	for channel in LABELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		add_child(row)
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
		add_child(option)
		_preferences[key] = option
	_audio.preference_changed.connect(func(key: StringName, enabled: bool):
		if _preferences.has(key):
			_preferences[key].set_pressed_no_signal(enabled))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	add_child(buttons)
	_add_button(buttons, "Testton", func(): _audio.play_ui())
	_add_button(buttons, "Standardwerte", func(): _audio.reset_settings())
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
