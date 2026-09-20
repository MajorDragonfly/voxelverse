extends VBoxContainer
## Draft controls. No effect or config writes until the shared Apply action.
const Preferences = preload("res://core/graphics_preferences.gd")
signal preset_changed(index: int)
var draft: Dictionary = Preferences.preset(1)
var preset_index: int = 1
var controls: Dictionary = {}
var option: OptionButton
var description: Label
var _refreshing: bool = false
const GROUPS := {
	"CLOUDS": ["clouds_enabled", "cloud_quality"],
	"HAZE": ["haze_strength"],
	"FOG": ["fog_enabled", "fog_quality", "fog_strength"],
	"SHADOWS": ["shadows_enabled", "shadow_quality", "shadow_softness", "shadow_distance"],
	"SSAO": ["ssao_enabled", "ssao_quality", "ssao_strength"],
	"BLOOM": ["bloom_enabled", "bloom_strength"],
	"IMAGE": ["exposure", "contrast", "saturation"],
}

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	_label("ATMOSPHERE_TITLE", true)
	option = OptionButton.new()
	option.name = "AtmosphereQuality"
	option.custom_minimum_size.y = 38
	for key in ["ATMOSPHERE_LOW", "ATMOSPHERE_STANDARD", "ATMOSPHERE_CINEMATIC", "GRAPHICS_CUSTOM"]:
		option.add_item(key)
	option.set_item_disabled(Preferences.CUSTOM, true)
	add_child(option)
	option.item_selected.connect(select_preset)
	description = _label("ATMOSPHERE_STANDARD_DESCRIPTION")
	description.name = "AtmosphereDescription"
	_label("GRAPHICS_DRAFT_HINT")
	var reset := Button.new()
	reset.name = "ResetGraphics"
	reset.text = "GRAPHICS_RESET"
	reset.custom_minimum_size.y = 38
	reset.pressed.connect(func(): select_preset(1))
	add_child(reset)
	var renderer: String = RenderingServer.get_current_rendering_method()
	for group: String in GROUPS:
		add_child(HSeparator.new())
		_label("GRAPHICS_GROUP_" + group, true)
		if group in ["FOG", "SSAO", "BLOOM"] and renderer != "forward_plus":
			_label("GRAPHICS_UNAVAILABLE")
		for key: String in GROUPS[group]:
			var rule: Dictionary = Preferences.FIELDS[key]
			var label_key: String = "GRAPHICS_" + key.to_upper()
			var enabled: bool = Preferences.supported(key, renderer)
			var control: Control
			if rule.default is bool:
				var check := CheckButton.new()
				check.text = label_key
				check.disabled = not enabled
				check.toggled.connect(func(value: bool): _edit(key, value))
				control = check
			elif rule.default is int:
				_label(label_key)
				var quality := OptionButton.new()
				for item in ["GRAPHICS_QUALITY_LOW", "GRAPHICS_QUALITY_MEDIUM", "GRAPHICS_QUALITY_HIGH"]:
					quality.add_item(item)
				quality.disabled = not enabled
				quality.item_selected.connect(func(value: int): _edit(key, value))
				control = quality
			else:
				_label(label_key)
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 12)
				add_child(row)
				var slider := HSlider.new()
				slider.min_value = rule.min
				slider.max_value = rule.max
				slider.step = 10.0 if key == "shadow_distance" else 0.01
				slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slider.custom_minimum_size.y = 36
				slider.editable = enabled
				row.add_child(slider)
				var number := SpinBox.new()
				number.min_value = slider.min_value
				number.max_value = slider.max_value
				number.step = slider.step
				number.suffix = "m" if key == "shadow_distance" else ""
				number.custom_minimum_size = Vector2(115, 36)
				number.editable = enabled
				row.add_child(number)
				number.get_line_edit().focus_entered.connect(_reveal.bind(number))
				slider.value_changed.connect(func(value: float): number.set_value_no_signal(value); _edit(key, value))
				number.value_changed.connect(func(value: float): slider.set_value_no_signal(value); _edit(key, value))
				slider.set_meta("number", number)
				control = slider
			control.name = key
			control.tooltip_text = label_key if enabled else "GRAPHICS_UNAVAILABLE"
			if control.get_parent() == null:
				control.custom_minimum_size.y = 36
				add_child(control)
			controls[key] = control
			control.focus_entered.connect(_reveal.bind(control))
			if key == "shadow_softness" and not enabled: _label("GRAPHICS_SOFT_SHADOW_UNAVAILABLE")
	refresh(1, draft)
	option.focus_entered.connect(_reveal.bind(option))
	reset.focus_entered.connect(_reveal.bind(reset))

func _reveal(control: Control) -> void:
	# Follow after containers finish the pending preset/translation relayout too.
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := get_parent() as ScrollContainer
	if scroll != null and is_instance_valid(control):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == control or (focused != null and control.is_ancestor_of(focused)):
			# Sliders and their taller number fields share a row. Reveal both,
			# including when focus is inside the SpinBox's LineEdit.
			var row := control
			while row.get_parent() != self and row.get_parent() is Control:
				row = row.get_parent() as Control
			scroll.ensure_control_visible(row)

func _label(key: String, heading: bool = false) -> Label:
	var label := Label.new()
	label.text = key
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heading: label.add_theme_font_size_override("font_size", 21)
	add_child(label)
	return label

func select_preset(index: int) -> void:
	if index < 0 or index >= Preferences.CUSTOM: return
	refresh(index, Preferences.preset(index))
	preset_changed.emit(index)

func refresh(index: int, values: Dictionary) -> void:
	_refreshing = true
	preset_index = clampi(index, 0, Preferences.CUSTOM)
	draft = Preferences.normalize(values)
	option.select(preset_index)
	description.text = ["ATMOSPHERE_LOW_DESCRIPTION", "ATMOSPHERE_STANDARD_DESCRIPTION", "ATMOSPHERE_CINEMATIC_DESCRIPTION", "GRAPHICS_CUSTOM_DESCRIPTION"][preset_index]
	for key: String in controls:
		var control: Control = controls[key]
		if control is CheckButton: control.set_pressed_no_signal(draft[key])
		elif control is OptionButton: control.select(draft[key])
		else:
			control.set_value_no_signal(draft[key])
			control.get_meta("number").set_value_no_signal(draft[key])
	_refreshing = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused): _reveal(focused)

func _edit(key: String, value: Variant) -> void:
	if _refreshing: return
	draft[key] = value
	preset_index = Preferences.CUSTOM
	option.select(preset_index)
	description.text = "GRAPHICS_CUSTOM_DESCRIPTION"
	preset_changed.emit(preset_index)

func close_popups() -> void:
	option.get_popup().hide()
	for control: Control in controls.values():
		if control is OptionButton: control.get_popup().hide()
