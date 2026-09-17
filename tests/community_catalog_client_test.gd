extends SceneTree

const Client = preload("res://assembly/exchange/community_catalog_client.gd")
const Contract = Client.Contract
const Library = Client.Library
const Package = Contract.Package
const Starter = preload("res://assembly/exchange/creature_start_templates.gd")
const Creature = Package.Creature
const Atomic = Package.Atomic
const Fixture = preload("res://tests/fixtures/community_catalog_fixture.gd")
const LIBRARY_PATH: String = "user://catalog-library.json"
var failures: Array[String] = []
var checks: int = 0
var fixture: Fixture
var client: Client
var events: Array[Dictionary] = []
var packages: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	if "--catalog-offline" in OS.get_cmdline_user_args():
		_offline()
	else:
		packages = Starter.packages()
		for package: Dictionary in packages:
			package.design_id = "community_" + package.design_id
			package.author = "Fixture author"
		_contract()
		fixture = Fixture.new()
		root.add_child(fixture)
		var endpoint: String = fixture.start()
		_expect(not endpoint.is_empty(), "Loopback fixture failed to bind")
		client = Client.new()
		root.add_child(client)
		client.completed.connect(func(id: int, result: Dictionary): events.append({"id": id, "result": result}))
		_expect(client.search().code == "not_configured", "Client connected without explicit configuration")
		_expect(not client.configure(endpoint).ok, "Plain HTTP enabled without fixture opt-in")
		for invalid in ["http://example.com", "http://127.0.0.1.example.com:80", "https://user:pass@example.com", "https://example.com/path", "https://example.com?q=x", "https://example.com#fragment"]:
			_expect(not client.configure(invalid, true).ok, "Invalid endpoint accepted: " + invalid)
		_expect(client.configure(endpoint, true).ok, "Loopback client configuration failed")
		await _catalog()
		await _downloads()
		await _lifecycle()
		fixture.stop()
		var requests_before: int = fixture.requests.size()
		var offline_error: Dictionary = await _result(client.download(_entry(packages[0])))
		_expect(not offline_error.ok and fixture.requests.size() == requests_before, "Offline service unexpectedly downloaded data")
		var output: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/community_catalog_client_test.gd", "--", "--catalog-offline"], output, true)
		_expect(code == 0 and str(output).contains("COMMUNITY_CATALOG_CLIENT_PASSED") and not str(output).contains("ERROR:"), "Offline cold process failed: " + str(output))
		client.queue_free()
		fixture.queue_free()
		await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("COMMUNITY_CATALOG_CLIENT_PASSED: %d checks" % checks)
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)


func _contract() -> void:
	var entry: Dictionary = _entry(packages[0])
	_expect(Contract.inspect_entry(entry).ok, "Valid entry rejected")
	for field in ["bytes", "revision"]:
		for bad in [-1, 0.5, "1", INF]:
			var changed: Dictionary = entry.duplicate(true)
			changed[field] = bad
			_expect(not Contract.inspect_entry(changed).ok, "Invalid numeric metadata accepted")
	for id in ["..", ".", "../escape", "https://example.com", "a?b", "a%2fb"]:
		var changed: Dictionary = entry.duplicate(true)
		changed.design_id = id
		_expect(not Contract.inspect_entry(changed).ok, "Unsafe design identity accepted")
	var changed: Dictionary = entry.duplicate(true)
	changed["url"] = "https://example.com/other"
	_expect(not Contract.inspect_entry(changed).ok, "Server-provided download URL accepted")
	changed = entry.duplicate(true)
	changed.bytes = Package.Schema.MAX_BYTES + 1
	_expect(not Contract.inspect_entry(changed).ok, "Oversized download descriptor accepted")
	_expect(Contract.decode_package(_bytes(packages[0]), entry).ok, "Exact package rejected")


func _catalog() -> void:
	_expect(client.search("x".repeat(121)).code == "invalid_query", "Query byte limit ignored")
	_expect(client.search("", Contract.PAGE_SIZE + 1).code == "invalid_query", "Requested page size limit ignored")
	_expect(client.next_page().code == "no_next_page", "Pagination started without initial page")
	fixture.enqueue(_page([_entry(packages[0])], "second"))
	var page: Dictionary = await _result(client.search("Flügel & blau", 1))
	_expect(page.ok and page.entries.size() == 1 and page.can_request_more, "First catalog page failed")
	_expect(fixture.requests[-1].contains("q=Fl%C3%BCgel%20%26%20blau"), "Query parameters not safely encoded")
	page.entries[0].title = "Changed caller copy"
	fixture.enqueue(_page([_entry(packages[1])]))
	page = await _result(client.next_page())
	_expect(page.ok and page.page == 2 and not page.can_request_more, "Second catalog page failed")
	_expect(fixture.requests[-1].contains("cursor=second"), "Server cursor not carried to next page")
	_expect(client.next_page().code == "no_next_page", "Terminal page fetched again")
	fixture.enqueue(_page([_entry(packages[0]), _entry(packages[1])]))
	_expect((await _result(client.search("", 1))).code == "page_limit", "Server exceeded requested page size")
	fixture.enqueue(_bytes({"schema": 2, "entries": [], "next_cursor": ""}))
	_expect((await _result(client.search())).code == "unsupported_service_version", "Unknown service version accepted")
	fixture.enqueue(_bytes({"schema": 1, "entries": [], "next_cursor": "", "extra": true}))
	_expect((await _result(client.search())).code == "invalid_page", "Unknown page fields accepted")
	fixture.enqueue("not-json".to_utf8_buffer())
	_expect((await _result(client.search())).code == "invalid_json", "Malformed catalog accepted")
	fixture.enqueue(_page([_entry(packages[0]), _entry(packages[0])]))
	_expect((await _result(client.search())).code == "duplicate_revision", "Duplicate revision in page accepted")
	fixture.enqueue(_page([_entry(packages[0])], "repeat"))
	await _result(client.search())
	fixture.enqueue(_page([_entry(packages[0])]))
	_expect((await _result(client.next_page())).code == "duplicate_revision", "Duplicate revision across pages accepted")
	fixture.enqueue(_page([], "repeat"))
	_expect((await _result(client.next_page())).code == "cursor_loop", "Repeated cursor accepted")
	fixture.enqueue(_page([], "third"))
	_expect((await _result(client.next_page())).ok, "Failed page could not be retried")
	fixture.enqueue(_page([], "repeat"))
	_expect((await _result(client.next_page())).code == "cursor_loop", "Multi-page cursor cycle accepted")
	for index in range(Contract.MAX_PAGES):
		fixture.enqueue(_page([], "cursor_%d" % index))
		page = await _result(client.search() if index == 0 else client.next_page())
		_expect(page.ok and page.page == index + 1, "Budgeted page failed")
	_expect(not page.can_request_more and client.next_page().code == "page_budget", "Page count budget bypassed")
	for options: Dictionary in [{"length": Contract.MAX_PAGE_BYTES + 1}, {"chunked": true}]:
		var bytes: PackedByteArray = "x".repeat(Contract.MAX_PAGE_BYTES + 1).to_utf8_buffer() if options.has("chunked") else PackedByteArray()
		fixture.enqueue(bytes, options)
		_expect((await _result(client.search())).code == "response_too_large", "HTTP body page limit ignored")
	fixture.enqueue(PackedByteArray(), {"status": 302, "location": "/redirected"})
	var count: int = fixture.requests.size()
	var redirect: Dictionary = await _result(client.search())
	_expect(not redirect.ok and fixture.requests.size() == count + 1, "Redirect was followed")
	fixture.enqueue(PackedByteArray(), {"status": 503})
	_expect((await _result(client.search())).get("status") == 503, "Service failure was not reported")


func _downloads() -> void:
	var state: Node = root.get_node("GameState")
	var progression: Node = root.get_node("ProgressionService")
	var campaign_before: String = var_to_str(state.export_state())
	var progress_before: String = var_to_str(progression.export_state())
	var first: Dictionary = packages[0]
	fixture.enqueue(_bytes(first))
	var descriptor: Dictionary = _entry(first)
	var started: Dictionary = client.download(descriptor, LIBRARY_PATH)
	descriptor.title = "Caller changed pending descriptor"
	var result: Dictionary = await _result(started)
	_expect(result.ok and Library.get_package(Library.key_of(first), LIBRARY_PATH).ok, "Download did not enter existing library")
	_expect(fixture.requests[-1] == "GET /v1/creatures/%s/revisions/%d HTTP/1.1" % [first.design_id, first.revision], "Download did not request exact revision")
	var original_bytes: String = FileAccess.get_file_as_string(LIBRARY_PATH)
	fixture.enqueue(_bytes(first))
	_expect((await _result(client.download(_entry(first), LIBRARY_PATH))).code == "already_present", "Repeated revision created duplicate")
	var newer: Dictionary = first.duplicate(true)
	newer.revision += 1
	newer.blueprint.appearance.base_color = "ffffff"
	fixture.enqueue(_bytes(newer))
	_expect((await _result(client.download(_entry(newer), LIBRARY_PATH))).ok, "New revision failed")
	_expect(Library.read(LIBRARY_PATH).packages.size() == 2, "New revision replaced old revision")
	_expect(Package.same_content(Library.get_package(Library.key_of(first), LIBRARY_PATH).package, JSON.parse_string(JSON.stringify(first))), "Existing local design changed after new revision")
	original_bytes = FileAccess.get_file_as_string(LIBRARY_PATH)
	var conflict: Dictionary = first.duplicate(true)
	conflict.blueprint.appearance.base_color = "aabbcc"
	fixture.enqueue(_bytes(conflict))
	_expect((await _result(client.download(_entry(conflict), LIBRARY_PATH))).code == "revision_conflict", "Immutable revision was overwritten")
	fixture.enqueue(_bytes(conflict))
	_expect((await _result(client.download(_entry(first), LIBRARY_PATH))).code == "digest_mismatch", "Tampered body passed digest")
	fixture.enqueue(_bytes(packages[1]))
	var wrong: Dictionary = _entry(packages[1])
	wrong.design_id = first.design_id
	_expect((await _result(client.download(wrong, LIBRARY_PATH))).code == "revision_mismatch", "Package substituted a different design")
	for field in ["schema", "catalog_revision"]:
		var future: Dictionary = first.duplicate(true)
		future[field] = 99
		fixture.enqueue(_bytes(future))
		_expect(not (await _result(client.download(_entry(future), LIBRARY_PATH))).ok, "Future package accepted")
	var malicious: Dictionary = first.duplicate(true)
	malicious.blueprint["progression"] = {"unlocked_parts": ["all"]}
	fixture.enqueue(_bytes(malicious))
	_expect(not (await _result(client.download(_entry(malicious), LIBRARY_PATH))).ok, "Downloaded campaign fields accepted")
	fixture.enqueue("{".to_utf8_buffer())
	_expect((await _result(client.download(_entry(first), LIBRARY_PATH))).code == "size_mismatch", "Truncated package accepted")
	fixture.enqueue(PackedByteArray(), {"length": int(_entry(first).bytes) + 1})
	_expect((await _result(client.download(_entry(first), LIBRARY_PATH))).code == "response_too_large", "Declared download limit ignored")
	_expect(FileAccess.get_file_as_string(LIBRARY_PATH) == original_bytes, "Rejected download mutated library bytes")
	fixture.enqueue(_bytes(packages[1]))
	DirAccess.make_dir_absolute(LIBRARY_PATH + ".tmp")
	_expect((await _result(client.download(_entry(packages[1]), LIBRARY_PATH))).code == "write_failed", "Failed atomic write reported success")
	DirAccess.remove_absolute(LIBRARY_PATH + ".tmp")
	_expect(FileAccess.get_file_as_string(LIBRARY_PATH) == original_bytes, "Failed staging damaged library")
	_expect(var_to_str(state.export_state()) == campaign_before and var_to_str(progression.export_state()) == progress_before, "Catalog/download altered campaign or unlocks")
	_expect(not FileAccess.file_exists(Creature.SAVE_PATH), "Download implicitly adopted a creature")
	Atomic.write("user://catalog-expectations.json", {"old_key": Library.key_of(first), "new_key": Library.key_of(newer), "bytes": original_bytes}, false)


func _lifecycle() -> void:
	fixture.enqueue(PackedByteArray(), {"hold": true})
	var started: Dictionary = client.download(_entry(packages[2]), LIBRARY_PATH)
	var event_count: int = events.size()
	var count: int = fixture.requests.size()
	while fixture.requests.size() == count: await process_frame
	_expect(client.search().code == "busy" and client.configure("https://example.com").code == "busy", "Pending request overwritten")
	client.cancel()
	_expect(events.size() == event_count + 1 and events[-1].id == started.request_id and events[-1].result.code == "cancelled", "Cancellation did not settle exactly once")
	client.cancel()
	fixture.enqueue(_page([]))
	_expect((await _result(client.search())).ok, "Request after cancellation failed")
	_expect(events.size() == event_count + 2, "Cancelled request completed a second time")
	_expect(not Library.get_package(Library.key_of(packages[2]), LIBRARY_PATH).ok, "Cancelled download persisted")
	fixture.enqueue(PackedByteArray(), {"hold": true})
	_expect((await _result(client.search())).code == "timeout", "Stalled service did not time out")
	paused = true
	fixture.enqueue(_page([]))
	_expect((await _result(client.search())).ok, "Catalog stalled in paused campaign menu")
	paused = false
	fixture.enqueue(PackedByteArray(), {"hold": true})
	started = client.download(_entry(packages[2]), LIBRARY_PATH)
	var close_results: Array = []
	var reentrant: Callable = func(_id: int, result: Dictionary):
		if result.code == "cancelled": close_results.append(client.search())
	client.completed.connect(reentrant)
	root.remove_child(client)
	client.completed.disconnect(reentrant)
	_expect(events[-1].id == started.request_id and events[-1].result.code == "cancelled", "Closing client did not cancel pending download")
	_expect(close_results.size() == 1 and close_results[0].code == "not_active", "Close callback restarted the departing client")
	root.add_child(client)


func _offline() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://catalog-expectations.json"))
	_expect(not expected.is_empty(), "Cold process has no library fixture")
	if expected.is_empty(): return
	_expect(FileAccess.get_file_as_string(LIBRARY_PATH) == expected.bytes, "Offline library changed")
	for key: String in [expected.old_key, expected.new_key]:
		var local: Dictionary = Library.get_package(key, LIBRARY_PATH)
		_expect(local.ok, "Exact downloaded revision unavailable offline")
		if not local.ok: continue
		var current: Dictionary = Creature.create_default()
		var imported: Dictionary = Package.prepare_import(local.package, current, 0, local.package.required_parts)
		_expect(imported.ok and imported.blueprint.design_id == current.design_id, "Offline preparation changed receiving identity")
		_expect(not FileAccess.file_exists(Creature.SAVE_PATH), "Offline lookup implicitly adopted a design")


func _result(started: Dictionary) -> Dictionary:
	if not started.ok:
		_expect(false, "Request failed to start: " + str(started))
		return started
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		for event: Dictionary in events:
			if event.id == started.request_id: return event.result
		await process_frame
	_expect(false, "Request never completed")
	client.cancel()
	return Contract.fail("test_timeout")


func _entry(package: Dictionary) -> Dictionary:
	var body: PackedByteArray = _bytes(package)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(body)
	return {"kind": "creature", "design_id": package.design_id, "revision": package.revision,
		"title": package.title, "author": package.author, "bytes": body.size(), "sha256": hash.finish().hex_encode()}


func _page(entries: Array, cursor: String = "") -> PackedByteArray:
	return _bytes({"schema": 1, "entries": entries, "next_cursor": cursor})


func _bytes(value: Dictionary) -> PackedByteArray:
	return Atomic.stringify(value).to_utf8_buffer()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
