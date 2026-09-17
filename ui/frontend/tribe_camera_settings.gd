extends VBoxContainer
## Draft controls participate in the existing atomic input-preference write.
var pan_speed: HSlider
var tilt: HSlider
signal changed

func _ready() -> void:
	add_child(HSeparator.new())
	var title := Label.new()
	title.text = "TRIBE_CAMERA_SETTINGS"
	add_child(title)
	pan_speed = _slider("TRIBE_CAMERA_SPEED", 0.5, 3.0, 0.1, true)
	tilt = _slider("TRIBE_CAMERA_TILT", 30.0, 80.0, 1.0, false)
	var note := Label.new()
	note.text = "TRIBE_CAMERA_SETTINGS_HINT"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 16)
	add_child(note)

func _slider(key: String, minimum: float, maximum: float, step: float, percent: bool) -> HSlider:
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	label.text = key
	label.custom_minimum_size.x = 245
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size.x = 185
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 72
	row.add_child(value)
	slider.value_changed.connect(func(number: float) -> void:
		value.text = "%d%%" % roundi(number * 100) if percent else "%d°" % roundi(number)
		changed.emit())
	return slider

func refresh(values: Dictionary) -> void:
	pan_speed.value = values.pan_speed
	pan_speed.value_changed.emit(pan_speed.value)
	tilt.value = values.tilt
	tilt.value_changed.emit(tilt.value)

func values() -> Dictionary:
	return {"pan_speed": pan_speed.value, "tilt": tilt.value}
