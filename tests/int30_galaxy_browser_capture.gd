extends "int30_galaxy_browser_test.gd"
## Render only the real UI layouts; domain/lifecycle checks run in the registered test.
func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	root.get_node("LocaleManager")._apply("de")
	root.size = Vector2i(1280, 720)
	catalog = Catalog.new("9007199254740993")
	panel = BrowserPanel.new()
	panel.catalog = catalog
	panel.initial_system_id = catalog.sector_at([0, 0, 0]).systems[0].id
	panel.journal_directory = "user://int30_galaxy_capture"
	root.add_child(panel)
	await _frames(5)
	print("CAPTURE_LAYOUTS_BEGIN")
	await _captures()
	var scroll: ScrollContainer = panel.find_child("GalaxyScroll", true, false)
	scroll.scroll_vertical = 0
	await _frames(5)
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("user://galaxy-1280x720-invalid-id.png") == OK, "Visible search feedback capture failed")
	print("CAPTURE_LAYOUTS_END ", JSON.stringify({"checks": checks, "passed": failures.is_empty(), "cache": catalog.stats()}))
	panel.queue_free()
	await _frames(3)
	for failure: String in failures: push_error(failure)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func _search(query: String) -> void:
	print("CAPTURE_NAVIGATE ", query)
	await super._search(query)
