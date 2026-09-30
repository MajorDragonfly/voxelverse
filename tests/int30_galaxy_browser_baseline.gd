extends SceneTree
## Capture the exact fixed-basis panel from an external, unmodified source file.
const Catalog = preload("res://world/space/galaxy_catalog.gd")
var browser: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("LocaleManager")._apply("de")
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var slot: int = arguments.find("--baseline-path")
	if slot < 0 or slot + 1 >= arguments.size():
		quit(1)
		return
	var script: Script = load(arguments[slot + 1])
	var catalog := Catalog.new("9007199254740993")
	browser = script.new()
	browser.catalog = catalog
	browser.initial_system_id = catalog.sector_at([0, 0, 0]).systems[0].id
	browser.journal_directory = "user://int30_galaxy_browser_baseline"
	root.add_child(browser)
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = size
		DisplayServer.window_set_size(size)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("user://galaxy-%dx%d-baseline.png" % [size.x, size.y]) != OK:
			quit(1)
			return
	browser.queue_free()
	for frame in range(3): await process_frame
	await preload("res://core/runtime_shutdown.gd").finish(self, 0)
