extends SceneTree
## Real gallery inputs + the existing loopback HTTP service, never a mock client.
const Gallery = preload("res://ui/blueprints/community_gallery_panel.gd")
const LibraryPanel = preload("res://ui/blueprints/creature_library_panel.gd")
const Fixture = preload("res://tests/fixtures/community_catalog_fixture.gd")
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Library = Gallery.Library
const Package = Library.Package
const PATH: String = "user://int30-community-gallery.json"
var failures: Array[String] = []
var checks: int = 0
var captures: Array[String] = []
var capture_dir: String = ""
var fixture: Fixture
var panel: Gallery
var packages: Array[Dictionary] = []
var imports: Array[String] = []
var progress_before: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("GALLERY_CHECK: start")
	root.get_node("SaveGameService").autosave_enabled = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--offline-reopen" in args:
		var stored: Dictionary = Library.read(PATH)
		_expect(stored.ok and stored.packages.size() == 2 and stored.favorites == ["gallery_fixture_2@%d" % int(Starter.packages()[2].revision)], "Cold process lost library entries/favorites")
		var local: Dictionary = Library.get_package("gallery_fixture_0@%d" % int(Starter.packages()[0].revision), PATH)
		_expect(local.ok and Package.inspect(local.package).ok, "Cold offline process could not validate imported package")
		for failure in failures: push_error(failure)
		if failures.is_empty(): print("INT30_COMMUNITY_GALLERY_OFFLINE_PASSED")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)
		return
	if "--capture-dir" in args: capture_dir = args[args.find("--capture-dir") + 1]
	# Integration owns the shared catalog. A focused pre-integration run can
	# install the exact delivered appendix as native Godot translations.
	if "--translation-appendix" in args:
		print("GALLERY_CHECK: translation appendix")
		var appendix: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/evidence/int30-16-community-gallery/translations.json"))
		for locale in ["de", "en"]:
			var catalog := Translation.new()
			catalog.locale = locale
			for message: Dictionary in appendix.messages: catalog.add_message(message.key, message[locale])
			TranslationServer.add_translation(catalog)
	if not capture_dir.is_empty() and DisplayServer.get_name() == "headless":
		push_error("Real renderer required for gallery captures")
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
		return
	print("GALLERY_CHECK: configured test viewport")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.get_node("LocaleManager")._apply("de")
	progress_before = root.get_node("ProgressionService").export_state()
	packages = Starter.packages()
	for index in range(packages.size()):
		packages[index].design_id = "gallery_fixture_%d" % index
		packages[index].title = "Moosläufer %d" % index
		packages[index].author = "Lokaler Prüfstand"
	var disabled := Gallery.new()
	root.add_child(disabled)
	await _frames(2)
	_expect(not disabled.visible and not disabled.is_available(), "Unconfigured gallery exposed a service")
	disabled.search()
	_expect(disabled._pending == 0, "Unconfigured gallery made a request")
	disabled.queue_free()
	await _frames(2)
	fixture = Fixture.new()
	root.add_child(fixture)
	var endpoint: String = fixture.start()
	_expect(not endpoint.is_empty(), "Existing loopback service could not start")
	panel = Gallery.new()
	panel.library_path = PATH
	panel.prepare_template = func(package: Dictionary):
		return Package.prepare_import(package, Package.Creature.create_default(), 0, [])
	_expect(not panel.configure(endpoint).ok, "Gallery accepted HTTP without explicit fixture mode")
	_expect(panel.configure(endpoint, true).ok, "Gallery explicit configuration failed")
	root.add_child(panel)
	panel.imported.connect(func(key: String): imports.append(key))
	await _frames(3)
	_expect(fixture.requests.is_empty() and panel.visible, "Opening configured gallery contacted service automatically")
	await _capture("idle-de")
	print("GALLERY_CHECK: search/paging")
	await _search_and_pages()
	print("GALLERY_CHECK: errors")
	await _errors()
	print("GALLERY_CHECK: downloads")
	await _downloads()
	print("GALLERY_CHECK: responsive")
	await _responsive()
	await _closing()
	await _launcher()
	_expect(root.get_node("ProgressionService").export_state() == progress_before, "Gallery altered campaign progression")
	fixture.stop()
	fixture.queue_free()
	await _frames(3)
	if not capture_dir.is_empty():
		var file := FileAccess.open(capture_dir.path_join("capture-manifest.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "images": captures, "checks": checks}, "\t"))
		file.close()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("INT30_COMMUNITY_GALLERY_PASSED: %d checks" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _search_and_pages() -> void:
	fixture.enqueue(_page([_entry(packages[0]), _entry(packages[1])], "next"))
	panel._search.text = "Flügel & blau"
	panel._search.grab_focus()
	_key(KEY_ENTER)
	await _done()
	_expect(panel._pages.size() == 1 and panel._entries().size() == 2 and not panel._next.disabled, "Enter did not start gallery search")
	_expect(fixture.requests[-1].contains("q=Fl%C3%BCgel%20%26%20blau"), "Gallery search was not safely encoded")
	await _click(panel.find_child("GalleryEntry_1", true, false))
	_expect(panel._name.text == packages[0].title and panel._origin.text.contains(packages[0].author) and panel._revision.text.contains(packages[0].design_id), "Gallery omitted actual provenance/revision")
	_expect(panel._requirements.text == Gallery.Text.text("CG_REQUIREMENTS_UNKNOWN"), "Requirements were invented before download")
	await _capture("results-and-origin-de")
	fixture.enqueue(_page([_entry(packages[2])]))
	await _click(panel._next)
	await _done()
	_expect(panel._page_index == 1 and panel._next.disabled and fixture.requests[-1].contains("cursor=next"), "Next page cursor/terminal controls failed")
	var count: int = fixture.requests.size()
	await _click(panel._previous)
	_expect(panel._page_index == 0 and panel._entries().size() == 2, "Previous did not restore cached page")
	await _click(panel._next)
	_expect(panel._page_index == 1 and fixture.requests.size() == count, "Cached forward navigation fetched again")
	fixture.enqueue(_page([]))
	await _click(panel._search_button)
	await _done()
	_expect(panel._entries().is_empty() and panel._download.disabled and panel._next.disabled and panel._selected.is_empty(), "Empty search retained stale selectable entries")
	await _capture("empty-de")


func _errors() -> void:
	for body in ["broken".to_utf8_buffer(), _bytes({"schema": 2, "entries": [], "next_cursor": ""})]:
		fixture.enqueue(body)
		await _click(panel._search_button)
		await _done()
		_expect(not panel._result.ok and panel._entries().is_empty() and panel._download.disabled, "Invalid service response exposed entries")
	await _capture("invalid-response-de")
	fixture.enqueue(PackedByteArray(), {"status": 503})
	await _click(panel._search_button)
	await _done()
	_expect(panel._status.text.contains("503"), "HTTP failure omitted status")
	panel._search.text = "ü".repeat(61)
	var requests: int = fixture.requests.size()
	await _click(panel._search_button)
	_expect(panel._result.code == "invalid_query" and fixture.requests.size() == requests, "Gallery bypassed UTF-8 query budget")
	panel._search.clear()
	fixture.stop()
	await _click(panel._search_button)
	await _done()
	_expect(not panel._result.ok and panel._status.text == Gallery.Text.text("CG_OFFLINE"), "Offline gallery did not offer a clear retry state")
	await _capture("offline-de")
	var endpoint: String = fixture.start()
	_expect(panel.configure(endpoint, true).ok, "Offline gallery could not be reconfigured")


func _downloads() -> void:
	# Original local design and favorite must survive cancellation and conflict.
	_expect(Library.add(packages[2], PATH).ok, "Original fixture library setup failed")
	_expect(Library.set_favorite(Library.key_of(packages[2]), true, PATH).ok, "Favorite setup failed")
	fixture.enqueue(_page([_entry(packages[0]), _entry(packages[2])], "held-next"))
	await _click(panel._search_button)
	await _done()
	await _click(panel.find_child("GalleryEntry_1", true, false))
	var before: String = FileAccess.get_file_as_string(PATH)
	fixture.enqueue(PackedByteArray(), {"hold": true})
	await _click(panel._download)
	await _accepted()
	_expect(panel._cancel.visible and panel._download.disabled and panel._search_button.disabled and panel._download_status.text == Gallery.Text.text("CG_DOWNLOADING"), "Download status/controls not bound to actual pending request")
	await _capture("download-pending-de")
	await _click(panel._cancel)
	_expect(panel._pending == 0 and panel._result.code == "cancelled" and imports.is_empty(), "Cancel failed or emitted an import")
	_expect(FileAccess.get_file_as_string(PATH) == before, "Cancelled download changed local library")
	await _capture("download-cancelled-de")
	fixture.enqueue(_bytes(packages[1]))
	await _click(panel._download)
	await _done()
	_expect(not panel._result.ok and imports.is_empty() and FileAccess.get_file_as_string(PATH) == before, "Digest/revision failure altered library")
	fixture.enqueue(_bytes(packages[0]))
	paused = true
	await _click(panel._download)
	await _done()
	paused = false
	_expect(panel._result.ok and imports == [Library.key_of(packages[0])] and Library.get_package(imports[0], PATH).ok, "Paused menu import did not reach existing local library")
	_expect(panel._requirements.text.contains(Gallery.Text.text("BP_LOCKED").get_slice("{", 0)) and not panel._requirements.text.contains("CG_"), "Validated package did not show real parts/locked requirements")
	await _capture("imported-requirements-de")
	fixture.enqueue(_bytes(packages[0]))
	await _click(panel._download)
	await _done()
	_expect(panel._result.code == "already_present" and Library.read(PATH).packages.size() == 2, "Repeat import duplicated immutable revision")
	var local_panel := LibraryPanel.new()
	local_panel.library_path = PATH
	root.add_child(local_panel)
	await _frames(3)
	local_panel.reload(Library.key_of(packages[0]))
	_expect(local_panel._entry().package.design_id == packages[0].design_id, "Existing local library could not reopen exact imported revision")
	local_panel.queue_free()
	await _frames(3)
	panel._search.grab_focus()
	await _click(panel.find_child("GalleryEntry_2", true, false))
	var changed: Dictionary = packages[2].duplicate(true)
	changed.description = "Conflicting immutable revision"
	panel._selected = _entry(changed)
	var original: String = FileAccess.get_file_as_string(PATH)
	fixture.enqueue(_bytes(changed))
	await _click(panel._download)
	await _done()
	_expect(panel._result.code == "revision_conflict" and FileAccess.get_file_as_string(PATH) == original, "Conflicting revision overwrote a local original")
	fixture.enqueue(PackedByteArray(), {"hold": true})
	await _click(panel._next)
	await _accepted()
	_key(KEY_ESCAPE)
	await _frames(2)
	_expect(panel._pending == 0 and panel._pages.size() == 1 and is_instance_valid(panel), "Escape did not cancel page while retaining cached results")
	fixture.enqueue(_page([_entry(packages[1])]))
	await _click(panel._next)
	await _done()
	_expect(panel._page_index == 1, "Cancelled next page could not be retried")


func _responsive() -> void:
	await _click(panel.find_child("GalleryEntry_1", true, false))
	var key: String = Library.key_of(panel._selected)
	for locale in ["de", "en"]:
		for window: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
			for scale in [1.0, 1.25, 1.5]:
				root.size = window
				root.content_scale_size = window
				root.content_scale_factor = scale
				root.get_node("LocaleManager")._apply(locale)
				panel._show_detail = false
				panel._layout()
				await _frames(4)
				_expect(_onscreen(panel._search) and _onscreen(panel._search_button) and _onscreen(panel._next), "Gallery list overflow at %s/%s/%s" % [locale, window, scale])
				await _capture("list-%s-%dx%d-%d" % [locale, window.x, window.y, int(scale * 100)])
				await _click(panel.find_child("GalleryEntry_1", true, false))
				_expect(_onscreen(panel._download) and _onscreen(panel.find_child("GalleryClose", true, false)), "Gallery detail controls unreachable at %s/%s/%s" % [locale, window, scale])
				_expect(Library.key_of(panel._selected) == key and panel._search.text.is_empty() and panel._status.text.find("CG_") == -1, "Locale/layout lost selection/query or untranslated key")
				await _capture("detail-%s-%dx%d-%d" % [locale, window.x, window.y, int(scale * 100)])
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _frames(4)


func _closing() -> void:
	fixture.enqueue(PackedByteArray(), {"hold": true})
	await _click(panel._download)
	await _accepted()
	var before: String = FileAccess.get_file_as_string(PATH)
	await _click(panel.find_child("GalleryClose", true, false))
	_expect(not is_instance_valid(panel) and FileAccess.get_file_as_string(PATH) == before, "Closing gallery did not cancel pending request")
	var fresh := Gallery.new()
	root.add_child(fresh)
	_expect(not fresh.visible and not fresh.is_available(), "Fresh gallery inherited endpoint configuration")
	fresh.queue_free()
	await _frames(3)


func _launcher() -> void:
	var host := LibraryPanel.new()
	host.library_path = PATH
	root.add_child(host)
	await _frames(3)
	var launcher := preload("res://ui/blueprints/community_gallery_launcher.gd").new()
	host.add_child(launcher)
	launcher.attach(host, host._tools, "")
	_expect(launcher._button == null, "Library launcher exposed unconfigured gallery")
	launcher.attach(host, host._tools, "http://127.0.0.1:80")
	_expect(launcher._button == null, "Library launcher exposed plain HTTP")
	launcher.attach(host, host._tools, "https://gallery.example.invalid")
	await _frames(3)
	var requests: int = fixture.requests.size()
	await _click(launcher._button)
	_expect(is_instance_valid(launcher._gallery) and not host.is_processing_input(), "Library opening port did not isolate child input")
	_expect(launcher._gallery._pending == 0 and fixture.requests.size() == requests, "Opening port made implicit service request")
	await _capture("library-opening-en")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(launcher._gallery == null and is_instance_valid(host) and host.is_processing_input(), "Gallery Escape closed library or failed to restore input")
	_expect(root.gui_get_focus_owner() == launcher._button, "Gallery did not restore library opening button focus")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not is_instance_valid(host), "Library did not close on subsequent Escape")


func _entry(package: Dictionary) -> Dictionary:
	var body: PackedByteArray = _bytes(package)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(body)
	return {"kind": "creature", "design_id": package.design_id, "revision": package.revision, "title": package.title,
		"author": package.author, "bytes": body.size(), "sha256": hash.finish().hex_encode()}


func _bytes(value: Dictionary) -> PackedByteArray:
	return Package.Atomic.stringify(value).to_utf8_buffer()


func _page(entries: Array, cursor: String = "") -> PackedByteArray:
	return _bytes({"schema": 1, "entries": entries, "next_cursor": cursor})


func _done() -> void:
	var deadline: int = Time.get_ticks_msec() + 15000
	while panel._pending != 0 and Time.get_ticks_msec() < deadline: await process_frame
	_expect(panel._pending == 0, "Gallery request completion timed out")
	if panel._pending != 0: panel.cancel()
	await _frames(3)


func _accepted() -> void:
	var deadline: int = Time.get_ticks_msec() + 3000
	while fixture._peers.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	await _frames(5)


func _click(control: Control) -> void:
	if not is_instance_valid(control):
		_expect(false, "Missing gallery control")
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await _frames(2)
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames(2)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)


func _onscreen(control: Control) -> bool:
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(control.get_global_rect())


func _frames(count: int) -> void:
	for index in count: await process_frame


func _capture(id: String) -> void:
	if capture_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "Renderer produced no gallery image")
	if image == null or image.is_empty(): return
	_expect(image.save_png(capture_dir.path_join(id + ".png")) == OK, "Gallery screenshot save failed")
	captures.append(id + ".png")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
