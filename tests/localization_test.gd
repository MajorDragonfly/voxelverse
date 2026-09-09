extends SceneTree

const Text = preload("res://core/localization/ui_text.gd")
const Locale = preload("res://core/localization/locale_manager.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func _run() -> void:
	await process_frame
	var manager := root.get_node("LocaleManager")
	if "--localization-read" in OS.get_cmdline_user_args():
		expect(manager.preference == "en" and manager.locale == "en", "Fresh process restores saved language")
		expect(Text.text("Neues Spiel") == "New game", "Catalog is available before the first scene")
		await finish()
		return
	var state := root.get_node("GameState")
	var saves := root.get_node("SaveGameService")
	saves.autosave_enabled = false
	var slot_path: String = saves.create_slot("Beenden", 15838)
	expect(not slot_path.is_empty(), "Create an actual campaign for localization checks")
	saves.session_active = false
	var saved_bytes := FileAccess.get_file_as_string(slot_path)
	var original_campaign: Dictionary = state.campaign.data.duplicate(true)
	var original_actions := InputMap.action_get_events("jump")
	for value in ["de-DE", "de_AT", " DE "]:
		expect(Locale.resolve_language(value) == "de", "Regional German: " + value)
	for value in ["en-GB", "en_US"]:
		expect(Locale.resolve_language(value) == "en", "Regional English: " + value)
	expect(Locale.resolve_language("ja_JP") == "de", "Unsupported locale falls back to German")
	manager.load_saved("user://missing-language-test.cfg", "de_DE")
	expect(manager.locale == "de", "First launch uses supported system language")
	var translated_label := Label.new()
	translated_label.text = "Beenden"
	root.add_child(translated_label)
	var name_label := Label.new()
	name_label.text = "Beenden"
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.add_child(name_label)
	await process_frame
	var german_width := translated_label.get_minimum_size().x
	var name_width := name_label.get_minimum_size().x
	expect(Text.number(12.5) == "12,5", "German decimal separator")
	expect(Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", 1) == "1 Sicherung", "German singular")
	expect(Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", 0) == "0 Sicherungen", "German zero plural")
	expect(manager.save_preference("en") == OK, "Language can be saved")
	await process_frame
	expect(translated_label.get_minimum_size().x < german_width, "Native Label refreshes its translated text and layout")
	expect(name_label.get_minimum_size().x == name_width, "Names opt out of automatic translation")
	translated_label.queue_free()
	name_label.queue_free()
	expect(Text.number(12.5) == "12.5", "English decimal separator")
	expect(Text.number(NAN) == "—", "Unavailable numeric data remains unavailable")
	expect(Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", 1) == "1 backup", "English singular")
	expect(Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", 2) == "2 backups", "English plural")
	expect(Text.format_text("BIND_CONFLICT", {"key": "{action}", "action": "Jump"}) == "{action} is already assigned to “Jump”.", "Inserted values are not interpreted as placeholders")
	var fallback := Translation.new()
	fallback.locale = "de"
	fallback.add_message("TEST_GERMAN_FALLBACK", "Deutscher Rückfall")
	TranslationServer.add_translation(fallback)
	expect(Text.text("TEST_GERMAN_FALLBACK") == "Deutscher Rückfall", "Missing English entry uses German")
	TranslationServer.remove_translation(fallback)
	expect(manager.save_preference("xx") == ERR_INVALID_PARAMETER and manager.locale == "en", "Invalid selection does not change language")
	expect(manager.save_preference("de", "user://missing-directory/settings.cfg") != OK and manager.locale == "en", "Failed write retains live language")
	var config := ConfigFile.new()
	config.set_value("language", "schema", 99)
	config.set_value("language", "preference", "en")
	config.save("user://future-language-test.cfg")
	manager.load_saved("user://future-language-test.cfg", "de_DE")
	expect(manager.load_problem == "LANGUAGE_NEWER_SETTINGS", "Unknown schema is reported")
	expect(manager.save_preference("de", "user://future-language-test.cfg") == ERR_UNAVAILABLE, "Unknown schema is not overwritten")
	config.load("user://future-language-test.cfg")
	expect(config.get_value("language", "schema") == 99, "Unknown schema is preserved")
	config.set_value("language", "schema", 1)
	config.set_value("language", "preference", ["invalid"])
	config.save("user://invalid-language-test.cfg")
	manager.load_saved("user://invalid-language-test.cfg", "en_GB")
	expect(manager.locale == "en" and not manager.load_problem.is_empty(), "Malformed preference safely uses system language")
	manager.load_saved()
	expect(state.campaign.data == original_campaign, "Campaign identity/data are unchanged")
	expect(InputMap.action_get_events("jump") == original_actions, "Language change does not rebind inputs")
	change_scene_to_file("res://ui/frontend/main_menu.tscn")
	await scene_changed
	var menu := current_scene
	var settings := root.get_node("DisplaySettings")
	menu._show_new()
	menu._title_input.text = "Beenden {phase}"
	menu._seed_input.text = "15838"
	settings.open_menu()
	var selector: Control = settings._language_settings
	settings._tabs.current_tab = 2
	selector.choice.select(1)
	settings.close_menu()
	expect(manager.locale == "en", "Closing the menu discards the language draft")
	settings.open_menu()
	settings._tabs.current_tab = 2
	expect(selector.choice.get_selected_metadata() == "en", "Reopening restores saved selection")
	selector.choice.select(1)
	settings._apply_menu_selection()
	await process_frame
	expect(manager.locale == "de", "Settings Apply changes language while paused")
	expect(paused and settings.is_menu_open(), "Language change preserves pause ownership")
	expect(menu._title_input.text == "Beenden {phase}" and menu._seed_input.text == "15838", "Language change preserves entered name and seed")
	selector.choice.select(2)
	settings._apply_menu_selection()
	await process_frame
	expect(manager.locale == "en", "Switch back to English")
	expect("Move" in root.get_node("SessionFlow").controls_text() and "Space" in root.get_node("SessionFlow").controls_text(), "Dynamic help and bound keys are translated")
	settings.close_menu()
	expect(not paused, "Closing settings restores the previous pause state")
	menu._show_slots()
	var browser: Control = menu._save_browser
	browser.select_slot(slot_path)
	browser._name_input.text = "Unfertiger Name {key}"
	manager.save_preference("de")
	await process_frame
	expect(browser._name_input.text == "Unfertiger Name {key}" and browser.selected_path == slot_path, "Language change preserves the selected save and unfinished rename")
	manager.save_preference("en")
	await process_frame
	expect(FileAccess.get_file_as_string(slot_path) == saved_bytes, "Language changes leave actual save bytes unchanged")
	expect(saves.inspect_slot(slot_path).name == "Beenden", "An adventure name matching a translation key stays unchanged")
	menu._show_home()
	if DisplayServer.get_name() != "headless":
		await screenshot("user://localization-main-en.png")
		settings.open_menu()
		settings._tabs.current_tab = 2
		await screenshot("user://localization-settings-en.png")
		settings.close_menu()
	await finish()

func screenshot(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func finish() -> void:
	print("LOCALIZATION_TEST: ", checks, " checks; failures=", failures)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
