extends "home_group_test.gd"
## Extends real GUI commands, resident physics, rollback and cold restart.
const Presentation = preload("res://ui/home_group/home_group_presentation.gd")
const NAMES := ["HOME_FOLLOW {name}", "Schließen"]
var checks: int = 0

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _capture(label: String) -> void:
	if label == "01_empty":
		var rejected: Dictionary = home.issue_order("follow")
		_expect(rejected.code == "home.required" and not rejected.ok, "Missing home lacks stable result")
		home.panel._result(rejected)
		for language: String in ["de", "en"]:
			await _display(Vector2i(800, 600), 1.5, language)
			_expect(home.group_state().is_empty() and home.actors.is_empty(), "Translation created a nest group")
			_expect(("Establish a home first" if language == "en" else "Lege zuerst") in home.panel._message.text, "Missing-home result did not refresh")
			await _image("home-%s-800x600-150-empty" % language)
		await _display(Vector2i(1280, 800), 1.0, "de")
	elif label == "02_group":
		await _language_changes()
		await _layouts()
		await _invalid_and_recovery()
		await _display(Vector2i(1280, 800), 1.0, "de")
		home.panel._surface.get_node("Centre/Panel/Stack/Scroll").scroll_vertical = 0
		await _frames(3)

func _language_changes() -> void:
	var panel: CanvasLayer = home.panel
	var group: Dictionary = home.group_state()
	for i in range(2): group.members[i].name = NAMES[i]
	# Install named fixture actors before observing the language-only operation.
	home._refresh_runtime()
	panel._refresh_members()
	_expect(saves.save_now(), "Could not persist named residents")
	await _display(Vector2i(800, 600), 1.5, "de")
	var scroll: ScrollContainer = panel._surface.get_node("Centre/Panel/Stack/Scroll")
	var focus: Button = panel.find_child("FollowMember", true, false)
	focus.grab_focus()
	await _frames(3)
	scroll.scroll_vertical = 80
	await _frames(3)
	var old_scroll: int = scroll.scroll_vertical
	var rows: Array = panel._list.get_children()
	var actors: Array = home.actors.values()
	var campaign: Dictionary = state.campaign.export_state()
	var progress: Dictionary = root.get_node("ProgressionService").export_state()
	var saved: String = FileAccess.get_file_as_string(SAVE)
	var result: Dictionary = panel._last_result.duplicate(true)
	var locale: Node = root.get_node("LocaleManager")
	for language: String in ["en", "de", "en", "de"]:
		_expect(locale.save_preference(language) == OK, "Language preference could not be saved")
		await _frames(5)
		_expect(panel.is_open and paused and panel._owns_pause, "Language change released the modal pause")
		_expect(focus.has_focus() and scroll.scroll_vertical == old_scroll, "Language change lost focus/scroll: %s %d -> %d" % [language, old_scroll, scroll.scroll_vertical])
		_expect(panel._list.get_children() == rows and home.actors.values() == actors, "Language change rebuilt rows or residents")
		_expect(state.campaign.export_state() == campaign and root.get_node("ProgressionService").export_state() == progress, "Language change mutated campaign or progression")
		_expect(FileAccess.get_file_as_string(SAVE) == saved and panel._last_result == result, "Language change saved gameplay or replaced the command result")
		_expect(("Home saved" if language == "en" else "Heimatplatz gespeichert") in panel._message.text, "Success message did not refresh")
		for i in range(2):
			var member: Dictionary = group.members[i]
			var actor: Node = actors[i]
			_expect(member.name == NAMES[i] and actor._label.text == NAMES[i] and actor._label.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED, "Resident name was translated or interpolated")
			_expect(Presentation.member_text(member) == NAMES[i] + (" · Wait" if language == "en" else " · Warten"), "Member command/name presentation is wrong")
		for code: String in Presentation.RESULT_KEYS:
			_expect(not Presentation.result_text({"code": code}).begins_with("HOME_"), "Untranslated group result: " + code)
		_expect(Presentation.hud_text(12.4, 2, 2).begins_with("Home: 12 m" if language == "en" else "Heimat: 12 m"), "Group HUD is untranslated")
		_expect(Presentation.hud_text(12, 1, 2).ends_with("1 waiting along the route" if language == "en" else "1 wartet am Weg"), "Single waiting companion has wrong grammar")
	# A real failed write keeps commands and the previous save, then its message
	# changes language without retrying the write or issuing another command.
	var old_path: String = saves.save_path
	saves.save_path = "user://missing_group_locale_dir/save.json"
	var failure: Dictionary = home.issue_order("follow")
	_expect(not failure.ok and failure.code == "home.save_failed", "Save failure lacks stable result")
	panel._result(failure)
	for language: String in ["en", "de"]:
		locale._apply(language)
		await _frames(4)
		_expect(("Saving failed" if language == "en" else "Speichern fehlgeschlagen") in panel._message.text, "Save failure did not refresh")
		_expect(state.campaign.export_state() == campaign and FileAccess.get_file_as_string(SAVE) == saved, "Failed write or translation changed the previous state")
	saves.save_path = old_path
	_expect(home.issue_order("wait", "missing-member").code == "home.member_unavailable", "Unknown resident accepted")
	_expect(home.issue_order("invalid").code == "home.order_unavailable", "Unknown command accepted")
	home._transaction = true
	_expect(home.establish_home().code == "home.unavailable", "Reentrant home operation accepted")
	home._transaction = false
	panel._result(home.issue_order("wait"))
	_expect(panel._last_result.code == "home.order_saved", "Valid command did not recover after write failure")

func _layouts() -> void:
	var panel: CanvasLayer = home.panel
	var scroll: ScrollContainer = panel._surface.get_node("Centre/Panel/Stack/Scroll")
	for size: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scale: float in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				await _display(size, scale, language)
				scroll.scroll_vertical = 0
				await _frames(3)
				var window := Rect2(Vector2.ZERO, Vector2(size))
				var frame: Control = panel._surface.get_node("Centre/Panel")
				_expect(window.encloses(_physical(frame)), "Group panel escaped screen: %s / %s / %s" % [size, scale, language])
				_expect(_physical(frame).encloses(_physical(panel._close)), "Close action is outside the panel")
				_expect(panel._close.get_theme_font_size("font_size") == roundi(18 * scale), "Large text preference was ignored")
				await _image("home-%s-%dx%d-%d" % [language, size.x, size.y, roundi(scale * 100)])
				var buttons: Array = panel._list.find_children("*", "Button", true, false)
				buttons.push_front(panel._establish)
				for button: Control in buttons:
					scroll.ensure_control_visible(button)
					await _frames(2)
					_expect(_physical(scroll).grow(1).encloses(_physical(button)), "Group action is unreachable: " + button.name)
				if size == Vector2i(800, 600) and scale == 1.5:
					await _image("home-%s-800x600-150-orders" % language)
	# Execute an individual command through the translated, scrolled real UI.
	var button: Button = panel.find_child("HomeMember", true, false)
	scroll.ensure_control_visible(button)
	await _frames(3)
	await _click(button)
	_expect(home.group_state().members[0].order == "home" and home.group_state().members[1].order == "wait", "Translated individual action affected the wrong members")

func _invalid_and_recovery() -> void:
	var body: Dictionary = state.get_current_body_record()
	var good: Dictionary = home.group_state().duplicate(true)
	var saved: String = FileAccess.get_file_as_string(SAVE)
	body.home_group.schema = 99
	home._refresh_runtime()
	var failure: Dictionary = home.issue_order("follow")
	_expect(failure.code == "home.unsupported_version" and not failure.ok, "Unsupported version lacks stable result")
	home.panel._result(failure)
	for language: String in ["de", "en"]:
		await _display(Vector2i(800, 600), 1.5, language)
		_expect(body.home_group.schema == 99 and home.actors.is_empty() and home.panel._establish.disabled, "Language action repaired or instantiated an unsupported group")
		_expect(("not supported yet" if language == "en" else "noch nicht unterstützt") in home.panel._summary.text, "Unsupported group warning did not refresh")
		_expect(FileAccess.get_file_as_string(SAVE) == saved, "Unsupported group overwrote the previous save")
		await _image("home-%s-800x600-150-invalid" % language)
	body.home_group = good
	home._refresh_runtime()
	home.panel._refresh_members()
	_expect(home.problem.is_empty() and home.problem_code.is_empty() and home.actors.size() == 2, "Valid group retained an old error")
	home.panel._result(home.issue_order("wait"))

func _display(size: Vector2i, scale: float, language: String) -> void:
	root.size = size
	root.get_node("DisplaySettings").ui_scale = scale
	root.get_node("LocaleManager")._apply(language)
	home.panel._layout()
	await _frames(5)

func _physical(control: Control) -> Rect2:
	return root.get_final_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _image(label: String) -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _finish() -> void:
	if "--restart-check" in OS.get_cmdline_user_args():
		var group: Dictionary = state.get_current_body_record().get("home_group", {})
		_expect(not group.is_empty() and group.members[0].name == NAMES[0] and group.members[1].name == NAMES[1], "Cold restart lost literal resident names")
	print("HOME_LOCALIZATION_CHECKS: ", checks, " PASSED: ", failures.is_empty())
	await super._finish()
