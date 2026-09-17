extends Node
## No default endpoint, polling, accounts or uploads. A caller explicitly starts
## each request; imported packages use the existing atomic local library.
signal completed(request_id: int, result: Dictionary)

const Contract = preload("res://assembly/exchange/community_catalog_contract.gd")
const Library = preload("res://assembly/exchange/creature_design_library.gd")
const REQUEST_TIMEOUT: float = 10.0
var _endpoint: String = ""
var _request: HTTPRequest
var _sequence: int = 0
var _active: int = 0
var _operation: String = ""
var _entry: Dictionary = {}
var _library_path: String = ""
var _query: String = ""
var _limit: int = Contract.PAGE_SIZE
var _cursor: String = ""
var _pages: int = 0
var _seen_cursors: Dictionary = {}
var _seen_revisions: Dictionary = {}
var _closing: bool = false


func _init() -> void:
	# The library may be opened from the paused campaign menu.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	_closing = false


## Plain HTTP is available only for an explicitly enabled numeric loopback
## fixture. Production endpoints must use HTTPS with normal TLS verification.
func configure(endpoint: String, allow_loopback_http: bool = false) -> Dictionary:
	if _active != 0: return Contract.fail("busy")
	var url := RegEx.new()
	url.compile("^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$")
	var local := RegEx.new()
	local.compile("^http://127\\.0\\.0\\.1:([0-9]{1,5})$")
	var normalized: String = endpoint.trim_suffix("/")
	if url.search(normalized) == null and not (allow_loopback_http and local.search(normalized) != null):
		return Contract.fail("invalid_endpoint")
	_endpoint = normalized
	_reset_pages()
	return {"ok": true, "code": ""}


func search(query: String = "", limit: int = Contract.PAGE_SIZE) -> Dictionary:
	if _active != 0: return Contract.fail("busy")
	if query.to_utf8_buffer().size() > 120 or query.to_utf8_buffer().has(0) or limit < 1 or limit > Contract.PAGE_SIZE:
		return Contract.fail("invalid_query")
	_reset_pages()
	_query = query
	_limit = limit
	return _page()


func next_page() -> Dictionary:
	if _active != 0: return Contract.fail("busy")
	if _pages == 0 or _cursor.is_empty(): return Contract.fail("no_next_page")
	if _pages >= Contract.MAX_PAGES: return Contract.fail("page_budget")
	return _page()


func download(entry: Dictionary, library_path: String = Library.PATH) -> Dictionary:
	if _active != 0: return Contract.fail("busy")
	var checked: Dictionary = Contract.inspect_entry(entry)
	if not checked.ok: return checked
	_entry = entry.duplicate(true)
	_library_path = library_path
	return _begin("download", "/v1/creatures/%s/revisions/%d" % [str(entry.design_id).uri_encode(), int(entry.revision)], int(entry.bytes))


func cancel() -> void:
	if _active != 0: _finish(Contract.fail("cancelled"))


func _exit_tree() -> void:
	_closing = true
	cancel()


func _reset_pages() -> void:
	_query = ""
	_cursor = ""
	_pages = 0
	_seen_cursors.clear()
	_seen_revisions.clear()


func _page() -> Dictionary:
	return _begin("page", "/v1/creatures?limit=%d&q=%s&cursor=%s" % [_limit, _query.uri_encode(), _cursor.uri_encode()], Contract.MAX_PAGE_BYTES)


func _begin(operation: String, path: String, byte_limit: int) -> Dictionary:
	if _endpoint.is_empty(): return Contract.fail("not_configured")
	if _closing or not is_inside_tree() or is_queued_for_deletion(): return Contract.fail("not_active")
	_sequence += 1
	_active = _sequence
	_operation = operation
	_request = HTTPRequest.new()
	_request.body_size_limit = byte_limit
	_request.timeout = REQUEST_TIMEOUT
	_request.max_redirects = 0
	_request.accept_gzip = false
	add_child(_request)
	_request.request_completed.connect(_received.bind(_active))
	var error: Error = _request.request(_endpoint + path, PackedStringArray(["Accept: application/json"]))
	if error != OK:
		_dispose_request()
		return Contract.fail("request_failed")
	return {"ok": true, "code": "", "request_id": _active}


func _received(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray, request_id: int) -> void:
	if request_id != _active: return
	if result != HTTPRequest.RESULT_SUCCESS:
		var code: String = "network_error"
		if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: code = "response_too_large"
		elif result == HTTPRequest.RESULT_TIMEOUT: code = "timeout"
		elif result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: code = "redirect_rejected"
		_finish(Contract.fail(code))
		return
	if status != 200:
		_finish({"ok": false, "code": "http_error", "status": status})
		return
	if _operation == "download":
		var decoded: Dictionary = Contract.decode_package(body, _entry)
		_finish(Library.add(decoded.package, _library_path) if decoded.ok else decoded)
		return
	var page: Dictionary = Contract.decode_page(body, _limit)
	if not page.ok:
		_finish(page)
		return
	var next: String = page.next_cursor
	if not next.is_empty() and (next == _cursor or _seen_cursors.has(next)):
		_finish(Contract.fail("cursor_loop"))
		return
	for entry: Dictionary in page.entries:
		if _seen_revisions.has(Library.key_of(entry)):
			_finish(Contract.fail("duplicate_revision"))
			return
	for entry: Dictionary in page.entries: _seen_revisions[Library.key_of(entry)] = true
	_seen_cursors[_cursor] = true
	_cursor = next
	_pages += 1
	page["page"] = _pages
	page["can_request_more"] = not next.is_empty() and _pages < Contract.MAX_PAGES
	_finish(page)


func _dispose_request() -> void:
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
	_request = null
	_active = 0
	_entry = {}
	_library_path = ""
	_operation = ""


func _finish(result: Dictionary) -> void:
	var request_id: int = _active
	_dispose_request()
	completed.emit(request_id, result)
