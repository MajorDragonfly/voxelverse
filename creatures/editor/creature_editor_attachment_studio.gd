extends "res://creatures/editor/creature_editor_joint_studio.gd"
## Scoped workshop extension for body fittings; no taming or economy controls.
const AttachmentData = preload("res://assembly/core/creature_body_attachments.gd")
const AttachmentContract = preload("res://creatures/runtime/creature_body_contract.gd")
var _attachment_panel: VBoxContainer
var _attachment_fields: VBoxContainer
var _attachment_status: Label
var _attachment_choice: OptionButton
var _attachment_enabled: CheckButton
var _attachment_spins: Dictionary = {}
var _show_fittings: bool = false
var _fitting_id: String = "saddle.primary"
var _syncing_attachments: bool = false


func _build_inspector() -> void:
	super._build_inspector()
	_attachment_panel = VBoxContainer.new()
	_attachment_panel.name = "BodyFittings"
	_inspector.add_child(_attachment_panel)
	_inspector.move_child(_attachment_panel, 3)
	var show := CheckButton.new()
	show.name = "ShowBodyFittings"
	show.text = "Sattel & Geschirr prüfen"
	show.add_theme_font_size_override("font_size", 14)
	show.toggled.connect(_toggle_fittings)
	_attachment_panel.add_child(show)
	_attachment_fields = VBoxContainer.new()
	_attachment_panel.add_child(_attachment_fields)
	_attachment_choice = OptionButton.new()
	_attachment_choice.name = "BodySocketChoice"
	for label in ["Sattel / Reitersitz", "Geschirr links", "Geschirr rechts"]:
		_attachment_choice.add_item(label)
	_attachment_choice.item_selected.connect(func(index: int) -> void:
		_end_gesture()
		_fitting_id = AttachmentData.IDS[index]
		_refresh_attachment_controls())
	_attachment_fields.add_child(_attachment_choice)
	_attachment_enabled = CheckButton.new()
	_attachment_enabled.name = "BodySocketEnabled"
	_attachment_enabled.text = "Anschluss aktiv"
	_attachment_enabled.toggled.connect(_set_fitting_enabled)
	_attachment_fields.add_child(_attachment_enabled)
	_add_fitting_spin("t", -1, "Lage am Rücken", 12, 88, 1, "%")
	for axis in range(3):
		_add_fitting_spin("offset", axis, ["Versatz rechts", "Versatz oben", "Versatz hinten"][axis], -50, 50, 1, "%")
	for axis in range(3):
		_add_fitting_spin("rotation_degrees", axis, ["Neigung", "Drehung", "Seitneigung"][axis], -180, 180, 5, "°")
	var mirror := _button(_attachment_fields, "Geschirr auf Gegenseite spiegeln", _mirror_fitting)
	mirror.name = "MirrorBodyHarness"
	mirror.add_theme_font_size_override("font_size", 12)
	_attachment_status = _label(_attachment_panel, "", 12)
	_attachment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _add_fitting_spin(field: String, axis: int, label: String, minimum: float, maximum: float, step: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	_attachment_fields.add_child(row)
	_label(row, label, 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin := SpinBox.new()
	var key: String = field if axis < 0 else "%s_%d" % [field, axis]
	spin.name = "BodySocket_" + key
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.suffix = suffix
	spin.custom_minimum_size.x = 106
	spin.get_line_edit().add_theme_font_size_override("font_size", 12)
	spin.get_line_edit().focus_entered.connect(_begin_gesture)
	spin.get_line_edit().focus_exited.connect(_end_gesture)
	spin.value_changed.connect(_change_fitting.bind(field, axis))
	row.add_child(spin)
	_attachment_spins[key] = spin


func _refresh_design_controls() -> void:
	super._refresh_design_controls()
	_refresh_attachment_controls()


func _refresh_attachment_controls() -> void:
	if _attachment_panel == null:
		return
	_syncing_attachments = true
	_attachment_panel.visible = _studio_mode in ["body", "test"]
	var data: Dictionary = AttachmentData.read(blueprint)
	var valid: bool = AttachmentData.validate(data).is_empty()
	_attachment_fields.visible = _show_fittings and _studio_mode == "body" and valid
	_attachment_status.visible = _show_fittings
	if valid:
		var socket: Dictionary = data["sockets"][_fitting_id]
		_attachment_enabled.set_pressed_no_signal(socket["enabled"])
		_attachment_spins["t"].set_value_no_signal(float(socket["t"]) * 100)
		for field in ["offset", "rotation_degrees"]:
			for axis in range(3):
				_attachment_spins["%s_%d" % [field, axis]].set_value_no_signal(float(socket[field][axis]) * (100.0 if field == "offset" else 1.0))
		_attachment_fields.get_node("MirrorBodyHarness").disabled = _fitting_id == "saddle.primary"
	if is_instance_valid(_preview) and not _preview.get("body_attachment_errors").is_empty():
		_attachment_status.text = "Anschluss nicht nutzbar: Daten oder Lage im Körper prüfen."
	elif _studio_mode == "test":
		_attachment_status.text = "Probereiter und Zugleinen folgen dem Körper. Lage im Reiter Körper einstellen."
	else:
		var rest: Dictionary = AttachmentContract.inspect_rest(_preview)
		_attachment_status.text = "%d Füße · Bodenabweichung %.3f\nProbereiter zeigt Lage und Richtung. Größe und Freiraum am Tier prüfen." % [rest["leg_count"], rest["max_contact_error"]]
	_syncing_attachments = false


func _toggle_fittings(enabled: bool) -> void:
	_show_fittings = enabled
	_refresh_preview()
	_refresh_attachment_controls()


func _refresh_preview() -> void:
	if is_instance_valid(_preview):
		_preview.set("show_body_attachments", _show_fittings and _studio_mode in ["body", "test"])
	super._refresh_preview()


func _change_fitting(value: float, field: String, axis: int) -> void:
	if _syncing_ui or _syncing_attachments or _studio_mode != "body":
		return
	var data: Dictionary = AttachmentData.read(blueprint)
	if not AttachmentData.validate(data).is_empty():
		return
	var socket: Dictionary = data["sockets"][_fitting_id]
	if axis < 0:
		socket[field] = value / 100.0
	else:
		socket[field][axis] = value / (100.0 if field == "offset" else 1.0)
	_store_fitting(_fitting_id, socket)


func _set_fitting_enabled(enabled: bool) -> void:
	if _syncing_attachments or _studio_mode != "body":
		return
	var data: Dictionary = AttachmentData.read(blueprint)
	if not AttachmentData.validate(data).is_empty():
		return
	var socket: Dictionary = data["sockets"][_fitting_id]
	socket["enabled"] = enabled
	_store_fitting(_fitting_id, socket)


func _mirror_fitting() -> void:
	if _fitting_id == "saddle.primary" or _studio_mode != "body":
		return
	var data: Dictionary = AttachmentData.read(blueprint)
	if not AttachmentData.validate(data).is_empty():
		return
	var socket: Dictionary = data["sockets"][_fitting_id]
	socket["offset"][0] *= -1.0
	socket["rotation_degrees"][1] *= -1.0
	socket["rotation_degrees"][2] *= -1.0
	_store_fitting("harness.right" if _fitting_id == "harness.left" else "harness.left", socket)


func _store_fitting(id: String, socket: Dictionary) -> void:
	_record_before_edit("Körperanschluss einstellen")
	if AttachmentData.set_socket(blueprint, id, socket):
		_refresh_preview()
		_refresh_attachment_controls()
		_update_builder_toolbar()
