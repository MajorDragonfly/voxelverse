extends "res://creatures/editor/creature_editor_joint_studio.gd"
## Scoped workshop extension for body fittings; no taming or economy controls.
const AttachmentData = preload("res://assembly/core/creature_body_attachments.gd")
const AttachmentContract = preload("res://creatures/runtime/creature_body_contract.gd")
const BodyFit = preload("res://creatures/runtime/creature_body_fit.gd")
var _attachment_panel: VBoxContainer
var _attachment_fields: VBoxContainer
var _attachment_status: Label
var _attachment_choice: OptionButton
var _attachment_enabled: CheckButton
var _attachment_spins: Dictionary = {}
var _show_fittings: bool = false
var _fitting_id: String = "saddle.primary"
var _syncing_attachments: bool = false
var _fit_actions: VBoxContainer
var _fit_findings: VBoxContainer
var _fit_proposal_button: Button
var _fit_report: Dictionary = {}
var _fit_proposal: Dictionary = {}


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
	_attachment_status = _label(_attachment_panel, "", 12)
	_attachment_status.name = "BodyFitStatus"
	_attachment_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_actions = VBoxContainer.new()
	_attachment_panel.add_child(_fit_actions)
	_button(_fit_actions, "Anhalten & jetzt prüfen", _check_fit_now).name = "CheckBodyFit"
	_button(_fit_actions, "Freiraum am Anschluss suchen", _find_fit_proposal).name = "FindBodyFit"
	_fit_proposal_button = _button(_fit_actions, "Vorschlag übernehmen", _apply_fit_proposal)
	_fit_proposal_button.name = "ApplyBodyFit"
	_fit_proposal_button.visible = false
	_fit_findings = VBoxContainer.new()
	_fit_actions.add_child(_fit_findings)
	_attachment_fields = VBoxContainer.new()
	_attachment_panel.add_child(_attachment_fields)
	_attachment_choice = OptionButton.new()
	_attachment_choice.name = "BodySocketChoice"
	for label in ["Sattel / Reitersitz", "Geschirr links", "Geschirr rechts"]:
		_attachment_choice.add_item(label)
	_attachment_choice.item_selected.connect(func(index: int) -> void:
		_end_gesture()
		_fit_proposal.clear()
		_fit_proposal_button.visible = false
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
		_fit_actions.get_node("FindBodyFit").disabled = not socket["enabled"]
	_fit_actions.visible = _show_fittings
	_fit_actions.get_node("FindBodyFit").visible = _studio_mode == "body" and valid
	if _show_fittings and _studio_mode in ["body", "test"]:
		if _studio_mode == "body" or _course_paused:
			if _fit_report.is_empty():
				_fit_report = BodyFit.inspect(_preview)
			_show_fit_report()
		else:
			_attachment_status.text = "Passprobe in Bewegung. Anhalten & jetzt prüfen untersucht die aktuelle Pose."
	_syncing_attachments = false


func _toggle_fittings(enabled: bool) -> void:
	_show_fittings = enabled
	_refresh_preview()
	_refresh_attachment_controls()


func _refresh_preview() -> void:
	_fit_report.clear()
	_fit_proposal.clear()
	if is_instance_valid(_fit_proposal_button):
		_fit_proposal_button.visible = false
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


func _check_fit_now() -> void:
	if _studio_mode == "test" and not _course_paused:
		_toggle_course_pause()
	_fit_report = BodyFit.inspect(_preview)
	_show_fit_report()


func _show_fit_report() -> void:
	for child in _fit_findings.get_children():
		_fit_findings.remove_child(child)
		child.queue_free()
	var hits: Array = _fit_report["collisions"]
	var legs: Array = _fit_report["stretched_legs"]
	var state: String = "Keine Überschneidung" if hits.is_empty() else "%d Überschneidungen · rot markiert" % hits.size()
	if not _fit_report["complete"]:
		state = "Prüfung unvollständig · Anschlusslage oder Geometrie prüfen"
	elif _fit_report["checked_sockets"].is_empty():
		state = "Keine aktiven Anschlüsse geprüft"
	_attachment_status.text = "%s\nFeste Probereitergröße · %s · %d stark gestreckte Beine (>20%%)." % [state,
		"Ruhepose" if _studio_mode == "body" else "angehaltene Momentaufnahme", legs.size()]
	if _studio_mode == "body":
		var rest: Dictionary = AttachmentContract.inspect_rest(_preview)
		_attachment_status.text += "\n%d Füße · Bodenabweichung %.3f" % [rest["leg_count"], rest["max_contact_error"]]
	var listed: Dictionary = {}
	for hit: Dictionary in hits:
		var key: String = str(hit["socket_id"]) + ":" + str(hit["part_uid"])
		if listed.has(key):
			continue
		listed[key] = true
		var socket_label: String = {"saddle.primary": "Sattel / Reiter", "harness.left": "Geschirr links", "harness.right": "Geschirr rechts"}[hit["socket_id"]]
		var target: String = "Rumpf" if hit["part_uid"] == "body" else "Anbauteil"
		var button := _button(_fit_findings, socket_label + " ↔ " + target, _edit_fit_collision.bind(hit["part_uid"], hit["socket_id"]))
		button.add_theme_font_size_override("font_size", 12)
	var seen: Dictionary = {}
	for leg: Dictionary in legs:
		var uid: String = leg["part_uid"]
		if seen.has(uid):
			continue
		seen[uid] = true
		_button(_fit_findings, "Beinpaar +%.0f%% · Gelenk bearbeiten" % ((float(leg["stretch"]) - 1.0) * 100), _edit_fit_part.bind(uid, true)).add_theme_font_size_override("font_size", 12)
		if _studio_mode == "body":
			_button(_fit_findings, "Segmentlängen übernehmen", _fit_leg_lengths.bind(uid)).add_theme_font_size_override("font_size", 12)
	_paint_fit_report()


func _paint_fit_report() -> void:
	_clear_fit_marks()
	var marks := Node3D.new()
	marks.name = "BodyFitFindings"
	marks.set_meta("editor_guide", true)
	_preview.add_child(marks)
	for hit: Dictionary in _fit_report["collisions"]:
		var guide: MeshInstance3D = _preview.get_node_or_null("BodyV4/BodyAttachments/" + str(hit["socket_id"]).replace(".", "_") + "/FitGuide/" + str(hit["shape_id"]))
		if guide != null:
			if not guide.has_meta("fit_material"):
				guide.set_meta("fit_material", guide.material_override)
			guide.material_override = AttachmentContract.Surface.material(Color("ff5c64"))
		_fit_dot(marks, AttachmentContract._vector(hit["position"]), Color("ff5c64"))
	for leg: Dictionary in _fit_report["stretched_legs"]:
		_fit_dot(marks, AttachmentContract._vector(leg["position"]), Color("ffc45c"))


func _fit_dot(parent: Node3D, point: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.045 * Blueprint.get_body_scale(blueprint)
	mesh.height = mesh.radius * 2
	node.mesh = mesh
	node.position = point
	var material := AttachmentContract.Surface.material(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func _clear_fit_marks() -> void:
	var marks: Node = _preview.get_node_or_null("BodyFitFindings")
	if marks != null:
		_preview.remove_child(marks)
		marks.queue_free()
	for guide in _preview.find_children("*", "MeshInstance3D", true, false):
		if guide.has_meta("fit_material"):
			guide.material_override = guide.get_meta("fit_material")


func _process(delta: float) -> void:
	super._process(delta)
	if _studio_mode == "test" and not _course_paused and not _fit_report.is_empty():
		_fit_report.clear()
		_clear_fit_marks()
		for child in _fit_findings.get_children():
			_fit_findings.remove_child(child)
			child.queue_free()
		_attachment_status.text = "Passprobe in Bewegung. Anhalten & jetzt prüfen untersucht die aktuelle Pose."


func _find_fit_proposal() -> void:
	if _studio_mode != "body":
		return
	_fit_proposal.clear()
	_fit_proposal_button.visible = false
	var current: Dictionary = BodyFit.inspect(_preview)
	var collides: bool = false
	for hit: Dictionary in current["collisions"]:
		collides = collides or hit["socket_id"] == _fitting_id
	if current["complete"] and _fitting_id in current["checked_sockets"] and not collides:
		_attachment_status.text = "Gewählte Passprobe ist in dieser Pose bereits frei."
		return
	_fit_proposal = BodyFit.socket_proposal(_preview, _fitting_id)
	_fit_proposal_button.visible = not _fit_proposal.is_empty()
	if _fit_proposal.is_empty():
		_attachment_status.text = "Kein freier Vorschlag im Suchbereich. Lage/Drehung oder das markierte Anbauteil bearbeiten."
	else:
		_fit_proposal["source"] = var_to_str(blueprint)
		var socket: Dictionary = _fit_proposal["socket"]
		_attachment_status.text = "Freiraumvorschlag: Rücken %.0f%% · Versatz %.0f / %.0f / %.0f%%.\nFür die feste Passprobe geprüft; Sattelauflage anschließend ansehen." % [float(socket["t"]) * 100,
			float(socket["offset"][0]) * 100, float(socket["offset"][1]) * 100, float(socket["offset"][2]) * 100]


func _apply_fit_proposal() -> void:
	if _studio_mode != "body" or _fit_proposal.is_empty() or _fit_proposal.get("source", "") != var_to_str(blueprint):
		return
	var proposal: Dictionary = _fit_proposal.duplicate(true)
	_end_gesture()
	_store_fitting(proposal["socket_id"], proposal["socket"])


func _edit_fit_part(uid: String, joint: bool = false) -> void:
	if uid == "body":
		_set_mode("body")
		_set_builder_status("Rückenform oder Anschlusslage ändern; rote Passprobe erneut prüfen.")
		return
	for index in range(blueprint.get("parts", []).size()):
		if blueprint["parts"][index].get("uid", "") == uid:
			_select_part_by_index(index)
			if joint:
				_choose_tool("joint")
			return


func _edit_fit_collision(uid: String, socket_id: String) -> void:
	_fitting_id = socket_id
	_attachment_choice.select(AttachmentData.IDS.find(socket_id))
	_edit_fit_part(uid)


func _fit_leg_lengths(uid: String) -> bool:
	if _studio_mode != "body":
		return false
	var candidate: Dictionary = BodyFit.leg_candidate(blueprint, BodyFit.inspect(_preview), uid)
	if candidate.is_empty():
		_set_builder_status("Segmentgrenze erreicht. Gelenk, Größe oder Beinansatz dieses Paars bearbeiten.")
		return false
	var trial: Node3D = _preview.get_script().new()
	trial.visible = false
	add_child(trial)
	trial.call("set_editor_state", candidate, -1, -1, false)
	var before: Dictionary = AttachmentContract.inspect_rest(_preview)
	var after: Dictionary = AttachmentContract.inspect_rest(trial)
	var improved: bool = after["all_feet_on_plane"] and after["leg_count"] == before["leg_count"] and float(after["max_rest_stretch"]) <= float(before["max_rest_stretch"]) + 0.001
	for foot: Dictionary in after["feet"]:
		if foot["part_uid"] == uid and float(foot["rest_stretch"]) > BodyFit.STRETCH_NOTICE:
			improved = false
		for original: Dictionary in before["feet"]:
			if original["part_uid"] == foot["part_uid"] and original["side"] == foot["side"] and float(foot["rest_stretch"]) > maxf(float(original["rest_stretch"]), BodyFit.STRETCH_NOTICE) + 0.001:
				improved = false
	trial.free()
	if not improved:
		_set_builder_status("Keine sichere Längenanpassung gefunden. Gelenk und Beinansatz dieses Paars bearbeiten.")
		return false
	_end_gesture()
	_record_before_edit("Beinpaar an Bodenabstand anpassen")
	blueprint = candidate
	_refresh_all()
	_set_builder_status("Segmentlängen dieses Paars übernommen · Fußkontakt erneut geprüft.")
	return true
