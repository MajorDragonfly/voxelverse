extends SceneTree
const Picker = preload("res://ui/blueprints/creature_library_panel.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("SaveGameService")._loaded_once = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not "--capture" in args or DisplayServer.get_name() == "headless":
		push_error("Protected receiver capture requires a display and --capture directory")
		quit(1)
		return
	var directory: String = args[args.find("--capture") + 1]
	DirAccess.make_dir_recursive_absolute(directory)
	var messages: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/int30-design-library/catalog-append.json"))
	for locale: String in ["de", "en"]:
		var translation := Translation.new()
		translation.set_locale(locale)
		for row: Dictionary in messages: translation.add_message(row.key, row[locale])
		TranslationServer.add_translation(translation)
	await _frames(3)
	var current: Dictionary = Picker.Package.Creature.create_default()
	current["_protected_design_source"] = {"future": "preserve-original"}
	var original: Dictionary = current.duplicate(true)
	var state: Dictionary = root.get_node("GameState").export_state()
	var progress: Dictionary = root.get_node("ProgressionService").export_state()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.get_node("LocaleManager")._apply("de")
	var panel := Picker.new()
	panel.library_path = "user://protected-empty-library.json"
	panel.capture_current = func() -> Dictionary: return current.duplicate(true)
	panel.prepare_template = func(package: Dictionary) -> Dictionary: return Picker.Starter.prepare(package, current)
	root.add_child(panel)
	await _frames(4)
	print("INT30_PROTECTED_READY")
	if not panel._use.disabled or not panel._requirements.text.contains(Picker.Text.text("BP_ERROR_TARGET")):
		failures.append("Protected target status or adoption gate is missing")
	if not panel._comparison.text.contains(Picker.Text.text("BP_COMPARE_UNAVAILABLE")):
		failures.append("Protected target comparison is not unavailable")
	await _capture(directory.path_join("protected-receiver-de.png"))
	root.size = Vector2i(800, 600)
	root.content_scale_size = root.size
	root.content_scale_factor = 1.5
	panel._show_detail = true
	panel._layout()
	await _frames(4)
	await _capture(directory.path_join("protected-receiver-de-150.png"))
	root.get_node("LocaleManager")._apply("en")
	await _frames(3)
	await _capture(directory.path_join("protected-receiver-en-150.png"))
	if current != original or root.get_node("GameState").export_state() != state or root.get_node("ProgressionService").export_state() != progress:
		failures.append("Protected original or campaign/progression changed")
	panel.queue_free()
	await _frames(3)
	for failure: String in failures: push_error(failure)
	print("INT30_PROTECTED_RECEIVER_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for frame in range(count): await process_frame

func _capture(path: String) -> void:
	await _frames(2)
	RenderingServer.force_draw()
	RenderingServer.sync()
	if root.get_texture().get_image().save_png(path) != OK: failures.append("Cannot save " + path)
