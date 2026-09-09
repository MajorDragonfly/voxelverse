extends "res://creatures/editor/creature_editor_attachment_studio.gd"
const RiderProfile = preload("res://assembly/core/creature_rider_profile.gd")
const SaddleSupport = preload("res://creatures/runtime/creature_saddle_support.gd")
const MotionReview = preload("res://creatures/runtime/creature_fit_motion_review.gd")
var _rider_fields: VBoxContainer
var _rider_spins: Dictionary = {}
var _seat_apply: Button
var _seat_proposal: Dictionary = {}
var _review_button: Button
var _review_label: Label
var _review_results: VBoxContainer
var _review: RefCounted
var _review_report: Dictionary = {}


func _build_inspector() -> void:
	super._build_inspector()
	var section := VBoxContainer.new()
	_attachment_fields.add_child(section)
	_attachment_fields.move_child(section, 2)
	var toggle := _button(section, "Reitermaße", func() -> void: _rider_fields.visible = not _rider_fields.visible)
	toggle.toggle_mode = true
	toggle.name = "ShowRiderDimensions"
	_rider_fields = VBoxContainer.new()
	_rider_fields.visible = false
	section.add_child(_rider_fields)
	for field in ["rider_scale", "leg_spacing", "seat_height"]:
		var row := HBoxContainer.new()
		_rider_fields.add_child(row)
		_label(row, {"rider_scale": "Reitergröße", "leg_spacing": "Beinabstand", "seat_height": "Sitzhöhe"}[field], 12).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		spin.name = "Rider_" + field
		spin.min_value = float(RiderProfile.LIMITS[field][0]) * 100
		spin.max_value = float(RiderProfile.LIMITS[field][1]) * 100
		spin.step = 2
		spin.suffix = "%"
		spin.custom_minimum_size.x = 106
		spin.get_line_edit().focus_entered.connect(_begin_gesture)
		spin.get_line_edit().focus_exited.connect(_end_gesture)
		spin.value_changed.connect(_change_rider.bind(field))
		row.add_child(spin)
		_rider_spins[field] = spin
	var fit := _button(_fit_actions, "Sitz an Rücken anpassen", _find_seat_proposal)
	fit.name = "FindSupportedSeat"
	_fit_actions.move_child(fit, 1)
	_seat_apply = _button(_fit_actions, "Sitzvorschlag übernehmen", _apply_seat_proposal)
	_seat_apply.name = "ApplySupportedSeat"
	_seat_apply.visible = false
	_fit_actions.move_child(_seat_apply, 2)
	_review_button = _button(_fit_actions, "Laufen, Rampe & Stufen prüfen", _start_motion_review)
	_review_button.name = "ReviewBodyMotion"
	_review_label = _label(_fit_actions, "", 12)
	_review_label.name = "BodyMotionStatus"
	_review_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_results = VBoxContainer.new()
	_fit_actions.add_child(_review_results)


func _refresh_attachment_controls() -> void:
	super._refresh_attachment_controls()
	if _rider_fields == null:
		return
	var profile: Dictionary = RiderProfile.read(blueprint)
	var valid: bool = RiderProfile.validate(profile).is_empty()
	for field in _rider_spins:
		_rider_spins[field].editable = valid
		if valid:
			_rider_spins[field].set_value_no_signal(float(profile[field]) * 100)
	_fit_actions.get_node("FindSupportedSeat").visible = _studio_mode == "body" and valid


func _change_rider(value: float, field: String) -> void:
	if _syncing_ui or _syncing_attachments or _studio_mode != "body":
		return
	var profile: Dictionary = RiderProfile.read(blueprint)
	if not RiderProfile.validate(profile).is_empty():
		return
	profile[field] = value / 100.0
	_record_before_edit("Reitermaße einstellen")
	if RiderProfile.store_in(blueprint, profile):
		_refresh_all()


func _show_fit_report() -> void:
	super._show_fit_report()
	var skin: MeshInstance3D = _preview.get_node_or_null("BodyV4/SculptedSkin")
	if skin == null:
		return
	var support: Dictionary = SaddleSupport.inspect(blueprint, skin.mesh)
	if not support["complete"]:
		_attachment_status.text += "\nSitzprüfung nicht verfügbar: Anschluss oder Reitermaße prüfen."
		return
	if not support["active"]:
		_attachment_status.text += "\nSattel deaktiviert."
		return
	_attachment_status.text += "\nAuflage %d/9 · größter Abstand %.1f%%" % [support["supported_samples"], float(support["max_gap"]) * 100]
	if not support["supported"]:
		_attachment_status.text += " · Sitz an Rücken anpassen"
	if not support["rider_seated"]:
		_attachment_status.text += "\nReiterkontakt prüfen · Abstand %.1f%%" % (float(support["rider_seat_gap"]) * 100)
	var marks: Node3D = _preview.get_node_or_null("BodyFitFindings")
	if marks != null:
		var body: Node3D = _preview.get_node("BodyV4")
		for sample: Dictionary in support["samples"]:
			_fit_dot(marks, body.transform * AttachmentContract._vector(sample["underside"]), Color("a6ebcc") if sample["supported"] else Color("ffc45c"))


func _refresh_preview() -> void:
	_clear_seat_review()
	super._refresh_preview()


func _clear_seat_review() -> void:
	_seat_proposal.clear()
	if is_instance_valid(_seat_apply):
		_seat_apply.visible = false
	if _review != null:
		_review.cancel()
		_review = null
	_review_report.clear()
	if is_instance_valid(_review_label):
		_review_label.text = ""
		_review_button.text = "Laufen, Rampe & Stufen prüfen"
		for child in _review_results.get_children():
			_review_results.remove_child(child)
			child.queue_free()


func _find_seat_proposal() -> void:
	if _studio_mode != "body":
		return
	_seat_proposal = SaddleSupport.proposal(_preview)
	_seat_apply.visible = not _seat_proposal.is_empty()
	if _seat_proposal.is_empty():
		_attachment_status.text = "Keine passende Auflage gefunden. Rückenform, Anschlussneigung oder markierte Anbauteile bearbeiten."
		return
	_seat_proposal["source"] = var_to_str(blueprint)
	var socket: Dictionary = _seat_proposal["socket"]
	var profile: Dictionary = _seat_proposal["rider_profile"]
	_attachment_status.text = "Sitzvorschlag: Rücken %.0f%% · Höhe %+.1f%%\nBeinabstand %.0f%% · Sitzhöhe %.0f%%\n9/9 Auflagepunkte und Freiraum in Ruhe geprüft." % [float(socket["t"]) * 100, float(socket["offset"][1]) * 100,
		float(profile["leg_spacing"]) * 100, float(profile["seat_height"]) * 100]


func _apply_seat_proposal() -> void:
	if _studio_mode != "body" or _seat_proposal.is_empty() or _seat_proposal.get("source", "") != var_to_str(blueprint):
		return
	var candidate: Dictionary = blueprint.duplicate(true)
	if not RiderProfile.store_in(candidate, _seat_proposal["rider_profile"]) or not AttachmentData.set_socket(candidate, "saddle.primary", _seat_proposal["socket"]):
		return
	_end_gesture()
	_record_before_edit("Sitzauflage und Reiter anpassen")
	blueprint = candidate
	_refresh_all()


func _start_motion_review() -> void:
	if _review != null and _review.report.get("status") == "running":
		_review.cancel()
		_show_motion_review()
		return
	_clear_seat_review()
	_review = MotionReview.new()
	_review.start(self, blueprint)
	_review_button.text = "Prüfung abbrechen"
	_show_motion_review()


func _process(delta: float) -> void:
	super._process(delta)
	if _review != null and _review.report.get("status") == "running":
		if _review.report["source_fingerprint"] != var_to_str(blueprint).sha256_text():
			_clear_seat_review()
			return
		_review.step()
		_show_motion_review()


func _show_motion_review() -> void:
	_review_report = _review.report.duplicate(true)
	if _review_report["status"] == "running":
		_review_label.text = "Prüfe an einer Kopie · %d Posen · %d/6 Strecken fertig" % [_review_report["samples_checked"], _review_report["scenarios"].size()]
		return
	_review_button.text = "Laufen, Rampe & Stufen prüfen"
	_review_label.text = "%d Posen geprüft · keine durchgehende Bewegungsfreigabe." % _review_report["samples_checked"]
	if not _review_report["complete"]:
		_review_label.text = "Prüfung abgebrochen oder unvollständig · keine Freigabe."
	for scenario: Dictionary in _review_report["scenarios"]:
		var label: String = {"flat": "Ebene", "slope": "Rampe", "steps": "Stufen"}[scenario["course"]] + " · " + ("Laufen" if scenario["mode"] == "walk" else "Rennen")
		if not scenario["first_collision"].is_empty():
			_label(_review_results, label + " · %d Trefferposen" % scenario["collision_samples"], 12)
			var seen: Dictionary = {}
			for finding: Dictionary in scenario["findings"]:
				var uid: String = finding["collision"]["part_uid"]
				if seen.has(uid):
					continue
				seen[uid] = true
				var pose: Dictionary = scenario.duplicate(true)
				pose["first_collision"] = {"time": finding["time"]}
				_button(_review_results, ("Rumpftreffer" if uid == "body" else "Anbauteiltreffer") + " bei %.2f s ansehen" % finding["time"], _show_motion_collision.bind(pose)).add_theme_font_size_override("font_size", 12)
		else:
			_label(_review_results, label + " · keine Treffer in %d Posen" % scenario["sample_count"], 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label(_review_results, "Bodenkontakt ≥%d Füße · Dehnung bis +%.0f%%" % [scenario["minimum_supporting_feet"], (float(scenario["max_total_stretch"]) - 1.0) * 100], 12)


func _show_motion_collision(scenario: Dictionary) -> void:
	var time: float = scenario["first_collision"]["time"]
	_set_mode("test")
	_choose_course(scenario["course"])
	_choose_motion(scenario["mode"])
	_course_paused = true
	_preview.set_process(false)
	_preview.set("_motion_time", time)
	_preview.get("_motion").sample(scenario["mode"], time)
	_refresh_part_palette()
	_check_fit_now()
	_set_builder_status("Trefferpose bei %.2f s · %s" % [time, scenario["course"]])


func _exit_tree() -> void:
	if _review != null:
		_review.cancel()
