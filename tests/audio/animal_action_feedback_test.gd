extends "res://tests/owned_animal_register_test.gd"
## Inherits only the existing fixture/test lifecycle helpers, not a D2 simulation.
const FeedbackPreview = preload("res://tests/fixtures/animal_feedback_d2_preview.gd")
var audio: Node
var heard: Array[Dictionary] = []
var reports: Array[String] = []

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		captures = args[args.find("--capture") + 1]
		DirAccess.make_dir_recursive_absolute(captures)
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves._loaded_once = true
	saves.save_path = CAMPAIGN_SENTINEL
	var sentinel := FileAccess.open(CAMPAIGN_SENTINEL, FileAccess.WRITE)
	sentinel.store_string("campaign must stay unchanged")
	sentinel.close()
	audio = root.get_node("AudioManager")
	audio.orders.automatic_binding = false
	audio.orders.feedback_played.connect(func(action: StringName, _id: String, ok: bool): heard.append({"action": action, "ok": ok}))
	var progression: String = JSON.stringify(root.get_node("ProgressionService").export_state())
	fixture = FeedbackPreview.new()
	root.add_child(fixture)
	journal = fixture.journal
	var feedback: Node = fixture.feedback
	feedback.feedback_changed.connect(func(text: String, _kind: String): reports.append(text))
	await _frames(4)
	_expect(heard.is_empty() and feedback.message.is_empty(), "Binding/book opening fabricated feedback")
	if fixture.lab == null:
		_expect(not feedback.report_result("missing", {"ok": false, "code": "save_failed"}, "absent") and heard.is_empty(), "Absent D2 produced feedback")
		await _finish(false)
		return
	var lab: Node3D = fixture.lab
	var d2: RefCounted = lab.controller
	var id: String = lab.fixture.ANIMAL
	if "--verify-reload" in args:
		_expect(d2.record(id)["status"] == "tamed" and d2.record(id)["order"] == "home" and heard.is_empty(), "Restart lost state or replayed successful taming/order")
		await _finish(true)
		return
	fixture.reset_probe()
	journal.close_journal()
	await _frames(3)
	lab.set_physics_process(false)
	lab.animal.set_physics_process(false)
	feedback.bind_source(d2, fixture._context, fixture._names)
	feedback.bind_source(d2, fixture._context, fixture._names)
	_expect(d2.get_signal_connection_list("animal_changed").size() == 2 and heard.is_empty(), "Rebinding duplicated listeners or played a cue")
	lab._friend()
	_expect(heard.is_empty(), "Friendship counted as completed taming")
	lab.selected_food = "meat"
	_expect(not fixture.perform("offer")["ok"], "D2 accepted wrong food")
	_expect(feedback.message.contains("gewählte Futter") and heard == [{"action": &"feed", "ok": false}], "Actual wrong-food rejection lost message/sound")
	var failed: Dictionary = d2.last_result.duplicate()
	var count: int = reports.size()
	_expect(not feedback.report_result(id, failed, "lab-request-1") and reports.size() == count, "Replayed failure produced a second message")
	await _gap()
	_expect(not feedback.report_result(id, failed, "lab-request-1") and heard.size() == 1, "Replayed failure sounded after throttle expired")
	lab.selected_food = "roots"
	_expect(fixture.perform("offer")["ok"] and heard.size() == 1, "Starting food offer prematurely played success")
	var stock: Dictionary = lab.snapshot["stock"].duplicate()
	lab.handler.position = Vector3(12, 0, 8)
	fixture.forward_result(d2.advance_offer(id, 0.25, lab.live_context()))
	_expect(feedback.message.contains("unterbrochen") and feedback.message.contains("kein Futter") and lab.snapshot["stock"] == stock, "First unpaid interruption lost its actual error/cost feedback")
	lab.handler.position = Vector3(0, 0, 2)
	await _gap()
	_expect(fixture.perform("offer")["ok"], "Offer after interrupted contact failed")
	for tick in range(7): d2.advance_offer(id, 0.25, lab.live_context())
	lab.store.blocked = true
	var before_failure: Dictionary = d2.registry.duplicate(true)
	# Let the unchanged lab physics finish the meal and the wrapper observe failure.
	lab.set_physics_process(true)
	await create_timer(0.4).timeout
	lab.set_physics_process(false)
	_expect(feedback.message.contains("Speichern fehlgeschlagen") and d2.record(id)["trust"] == before_failure["animals"][id]["trust"] and d2.record(id)["owner_faction_id"].is_empty() and lab.snapshot["stock"] == stock, "Failed meal save claimed paid trust/ownership")
	lab.store.blocked = false
	for meal in range(4):
		await _gap()
		if meal > 0:
			_expect(fixture.perform("offer")["ok"], "Subsequent real D2 offer failed")
			for tick in range(7): d2.advance_offer(id, 0.25, lab.live_context())
		var result: Dictionary = d2.advance_offer(id, 0.25, lab.live_context())
		var accepted_count: int = heard.size()
		var report_count: int = reports.size()
		fixture.forward_result(result)
		_expect(result["ok"] and heard.size() == accepted_count and reports.size() == report_count, "Successful return double-reported its confirmed event")
		if meal < 3:
			_expect(feedback.message.contains("%d / 100" % ((meal + 1) * 25)) and heard[-1] == {"action": &"feed", "ok": true}, "Paid trust did not use real D2 value/feed cue")
	_expect(feedback.message.contains("gehört jetzt deinem Stamm") and heard[-1] == {"action": &"tame", "ok": true}, "Tamed milestone missing")
	var tame_voice := false
	for voice in audio._ui_voices:
		tame_voice = tame_voice or (voice.playing and voice.stream == audio.get_sound_stream(&"order_tame"))
	_expect(tame_voice and audio.get_sound_stream(&"order_tame") == audio.get_sound_stream(&"discovery"), "Taming did not reuse the actual milestone stream")
	_expect(d2.record(id)["trust"] == 100.0 and lab.snapshot["stock"]["roots"] == 8, "Feedback changed D2 costs or trust")
	for action in ["follow", "wait", "home"]:
		# A fast game clock must not shorten the real-time audio interval.
		var previous_time_scale := Engine.time_scale
		if action == "follow": Engine.time_scale = 4.0
		await _gap()
		Engine.time_scale = previous_time_scale
		_expect(fixture.perform(action)["ok"] and heard[-1] == {"action": StringName(action), "ok": true}, "Confirmed order mapping failed: " + action)
		_expect(feedback.message.contains("gespeichert"), "Order claims completion rather than persistence")
		if action == "follow": _expect(feedback.message.contains("Prüfbetreuer"), "Follow feedback lost concrete handler")
	# A rejection immediately after a successful order remains audible.
	count = heard.size()
	lab.store.blocked = true
	_expect(not fixture.perform("wait")["ok"] and heard.size() == count + 1 and not heard[-1]["ok"], "Immediate failed order masked by success throttle")
	_expect(feedback.message.contains("Speichern fehlgeschlagen") and d2.record(id)["order"] == "home", "Failed command displayed an uncommitted order")
	lab.store.blocked = false
	await _gap()
	journal.open_journal()
	count = heard.size()
	_expect(not fixture.perform("follow")["ok"] and feedback.message.contains("pausiert") and heard.size() == count, "Paused command acknowledged or sounded")
	journal.refresh()
	fixture.load_probe()
	_expect(feedback.message.is_empty() and heard.size() == count, "Load/book refresh replayed prior result")
	journal.close_journal()
	await _frames(3)
	lab.animal.set_physics_process(false)
	await _gap()
	_expect(heard.size() == count, "Suppressed pause feedback replayed on resume")
	var scoped: Dictionary = fixture._context()
	feedback.bind_source(d2, func(): return scoped, fixture._names)
	scoped["faction_id"] = "foreign_faction"
	_expect(d2.command(id, "wait", lab.live_context())["ok"] and heard.size() == count, "Foreign ownership produced a success cue")
	scoped["body_id"] = "foreign_body"
	_expect(not feedback.report_result(id, failed, "foreign") and feedback.message.is_empty(), "Foreign world produced old failure feedback")
	feedback.bind_source(d2, fixture._context, fixture._names)
	await _gap()
	_expect(fixture.perform("home")["ok"], "Final restart order failed")
	var saved: String = FileAccess.get_file_as_string(lab.store.path)
	feedback.clear_after_load()
	_expect(FileAccess.get_file_as_string(lab.store.path) == saved and JSON.stringify(root.get_node("ProgressionService").export_state()) == progression, "Feedback wrote state or awarded progress")
	for extent in [Vector2i(800, 600), Vector2i(640, 480)]:
		root.size = extent
		await _frames(5)
		fixture._feedback_scroll.ensure_control_visible(lab.buttons["wait"])
		await _frames(3)
		lab.store.blocked = true
		await _click(lab.buttons["wait"])
		lab.store.blocked = false
		await _frames(4)
		_expect(lab.message.text.contains("Speichern fehlgeschlagen"), "Actual button click did not reach error feedback")
		_expect(fixture._lab_panel.get_global_rect().end.y <= root.get_visible_rect().size.y and lab.message.get_global_rect().end.y <= fixture._feedback_scroll.get_global_rect().end.y, "Feedback is outside compact preview")
		await _capture("animal_feedback_%dx%d" % [extent.x, extent.y])
	count = heard.size()
	feedback.unbind()
	d2.command(id, "wait", lab.live_context())
	_expect(heard.size() == count and feedback.message.is_empty() and d2.get_signal_connection_list("animal_changed").size() == 1, "Unbinding retained sound subscription")
	# Restore the committed home order for the independent restart process.
	_expect(lab.store.write_snapshot(JSON.parse_string(saved)), "Could not restore saved restart fixture")
	await _finish(true)

func _gap() -> void:
	audio.stop_ui()
	# Order audio throttles wall time. A SceneTree timer consumes frame delta,
	# which can expire early in real time after a slow or accelerated frame.
	var ready_at := Time.get_ticks_msec() + 230
	while Time.get_ticks_msec() < ready_at:
		await process_frame

func _finish(d2_checked: bool) -> void:
	fixture.queue_free()
	await _frames(3)
	_expect(FileAccess.get_file_as_string(CAMPAIGN_SENTINEL) == "campaign must stay unchanged", "Feedback wrote the campaign save")
	print(JSON.stringify({"test": "animal_action_feedback", "passed": failures.is_empty(), "d2_checked": d2_checked, "failures": failures, "heard": heard}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
