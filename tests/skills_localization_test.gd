extends "behavior_skill_tree_test.gd"
## Real player GUI route: translate live purchases, errors and future previews.
const Presentation = preload("res://ui/skills_presentation.gd")
const Text = preload("res://core/localization/ui_text.gd")
var checks: int = 0

func _initialize() -> void:
	if "--skills-restart" in OS.get_cmdline_user_args():
		call_deferred("_restart")
	else:
		super._initialize()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	super._expect(condition, message)

func _click(control: Control) -> void:
	var purchase: bool = ui != null and control == ui._purchase
	if purchase:
		root.get_node("LocaleManager")._apply("en")
		await _settle()
	await super._click(control)
	if purchase:
		_expect("saved" in ui._message.text or "rolled back" in ui._message.text, "Real English purchase did not report success/rollback")
		await _language_cycles()
		root.get_node("LocaleManager")._apply("de")
		await _settle()

func _screenshot(filename: String) -> void:
	if filename == "skilltree_empty.png":
		await _language_cycles()
	elif filename == "skilltree_available.png":
		await _language_cycles()
	# Capture is handled by the complete layout matrix below.

func _language_cycles() -> void:
	var locale: Node = root.get_node("LocaleManager")
	var selected: String = ui._selected
	var phase: int = ui._view_phase
	var scroll: int = ui._scroll.scroll_vertical
	var focus: Control = root.gui_get_focus_owner()
	var cards: Array = ui._cards.values().map(func(card: Dictionary) -> Button: return card.button)
	var path_children: Array = ui._development.get_children()
	var campaign: Dictionary = state.export_state()
	var progress: Dictionary = progression.export_state()
	var saved: String = FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else ""
	var result: Dictionary = ui._last_result.duplicate(true)
	for language: String in ["de", "en", "de"]:
		scroll = ui._scroll.scroll_vertical
		_expect(locale.save_preference(language) == OK, "Language preference write failed")
		await _settle()
		_expect(ui.visible and paused and ui._owns_pause, "Translation released the owned pause")
		_expect(ui._selected == selected and ui._view_phase == phase and ui._phase_choice.selected == phase, "Translation lost skill/phase selection")
		var bar: VScrollBar = ui._scroll.get_v_scroll_bar()
		var expected_scroll := mini(scroll, maxi(0, int(bar.max_value - bar.page)))
		_expect(root.gui_get_focus_owner() == focus and ui._scroll.scroll_vertical == expected_scroll, "Translation lost focus/scroll: %d -> %d" % [scroll, ui._scroll.scroll_vertical])
		_expect(cards == ui._cards.values().map(func(card: Dictionary) -> Button: return card.button), "Translation rebuilt skill cards")
		_expect(path_children == ui._development.get_children(), "Translation rebuilt development-path controls")
		_expect(state.export_state() == campaign and progression.export_state() == progress, "Translation changed game data or spent points")
		_expect(ui._last_result == result, "Translation changed the last purchase receipt")
		_expect((FileAccess.get_file_as_string(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else "") == saved, "Translation wrote gameplay to disk")
		_expect(ui._close.text == ("Close · Esc" if language == "en" else "Schließen · Esc"), "Close label is untranslated")
		_expect(ui._tree_tab.text == ("Skills" if language == "en" else "Fähigkeiten"), "Skill tab is untranslated")
		if not result.is_empty():
			_expect(("saved" if language == "en" else "gespeichert") in ui._message.text if result.ok else ("rolled back" if language == "en" else "zurückgesetzt") in ui._message.text, "Existing purchase result did not translate")

func _capture_if_requested() -> void:
	# All real catalog nodes and all six planning phases must be translated.
	for language: String in ["en", "de"]:
		root.get_node("LocaleManager")._apply(language)
		await _settle()
		for phase in range(6):
			ui._select_phase(phase)
			await _settle()
			var source: Dictionary = Presentation.Phases.phase(phase)
			for field: String in ["name", "scope", "control", "social", "aggression", "next"]:
				var translated := Presentation.phase_text(phase, field)
				_expect(not translated.begins_with("SKILLS_") and not translated.is_empty(), "Missing phase field: %d %s" % [phase, field])
				if language == "de": _expect(translated == source[field], "German preview changed the source plan")
			for index in range(source.loop.size()):
				var key := "SKILLS_PHASE_%d_LOOP_%d" % [phase, index]
				_expect(Text.text(key) != key, "Missing planned activity")
			if phase > 1:
				_expect(not ui._details.get_parent().visible and ui._cards.values().all(func(card: Dictionary) -> bool: return not card.button.visible), "Future preview exposed purchasable skills")
			for node: Dictionary in progression.get_behavior_nodes(phase):
				ui._select(node.id)
				await _settle()
				for field: String in ["name", "description"]:
					var key := "SKILLS_NODE_" + str(node.id).replace(".", "_").to_upper() + "_" + field.to_upper()
					_expect(Text.text(key) != key, "Untranslated real skill field: " + key)
					_expect(Presentation.node_text(node.id, field) == Text.text(key), "Skill mapping differs from real catalog")
				_expect(ui._title.text == Presentation.node_text(node.id, "name") and ui._description.text == Presentation.node_text(node.id, "description"), "Selected skill detail not refreshed")
				for id: String in node.requires:
					_expect(Presentation.node_text(id, "name") in ui._requirements.text, "Prerequisite name not translated")
			await _language_cycles()
			root.get_node("LocaleManager")._apply(language)
			await _settle()
	ui._show_development()
	await _language_cycles()
	_expect(ui._development.visible and not ui._body.visible, "Translation switched away from development path")
	ui._show_tab(false)
	ui._select_phase(0)
	await _layouts()
	# The same save loads in a fresh process. Language is a device preference.
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/skills_localization_test.gd", "--", "--skills-restart"], output, true)
	_expect(exit_code == 0 and "SKILLS_RESTART_OK" in "\n".join(output), "Fresh-process purchase reload failed: " + "\n".join(output))
	await _display(Vector2i(1920, 1080), 1.0, "de")
	ui._select_phase(0)
	ui._scroll.scroll_vertical = 0

func _layouts() -> void:
	for size_value in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(800, 600)]:
		for scale_value in [1.0, 1.5]:
			for language: String in ["de", "en"]:
				await _display(size_value, scale_value, language)
				ui._select_phase(0)
				ui._select("creature.social.support")
				await _settle()
				_expect(ui._panel.size.x <= size_value.x + 1 and ui._panel.size.y <= size_value.y + 1, "Book exceeds viewport")
				_expect(ui._close.get_global_rect().end.x <= size_value.x + 1, "Close button leaves viewport")
				_expect(ui._scroll.size.y >= 80, "No usable scroll viewport remains")
				for card: Dictionary in ui._cards.values():
					if card.button.visible:
						_expect(card.content.get_combined_minimum_size().y <= card.button.size.y + 1, "Skill text overflows its card")
				await _image("skills-%s-%dx%d-%d" % [language, size_value.x, size_value.y, roundi(scale_value * 100)])
				ui._purchase.grab_focus()
				await _settle()
				ui._scroll.ensure_control_visible(ui._purchase)
				await _settle()
				await _language_cycles()
				root.get_node("LocaleManager")._apply(language)
				await _settle()
				await _image("skills-%s-%dx%d-%d-details" % [language, size_value.x, size_value.y, roundi(scale_value * 100)])
	await _display(Vector2i(800, 600), 1.5, "en")
	ui._select_phase(1)
	await _settle()
	await _image("skills-en-800x600-150-tribe")
	ui._select_phase(4)
	await _settle()
	await _image("skills-en-800x600-150-future")

func _display(size_value: Vector2i, scale_value: float, language: String) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = size_value
	root.get_node("DisplaySettings").ui_scale = scale_value
	root.get_node("LocaleManager")._apply(language)
	ui._layout()
	await _settle()

func _settle() -> void:
	for i in range(6): await process_frame

func _image(label: String) -> void:
	var args := OS.get_cmdline_user_args()
	if not "--capture" in args: return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func _restart() -> void:
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	saves.save_path = SAVE_PATH
	saves._loaded_once = true
	_expect(saves.load_now(), "Restart could not load saved purchases")
	progression = root.get_node("ProgressionService")
	_expect(progression.get_behavior_nodes(0).all(func(node: Dictionary) -> bool: return node.purchased), "Restart lost purchased creature nodes")
	root.get_node("LocaleManager")._apply("en")
	_expect(Presentation.node_text("creature.social.approach", "name") == "Openness", "Restart did not load English catalog")
	if failures.is_empty(): print("SKILLS_RESTART_OK")
	await _finish()

func _finish() -> void:
	print("SKILLS_LOCALIZATION_CHECKS: %d passed=%s" % [checks, failures.is_empty()])
	await super._finish()
