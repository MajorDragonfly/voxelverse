extends RefCounted
## Read-only service v1. Package rules remain owned by the existing codec.
const Package = preload("res://assembly/exchange/creature_blueprint_package.gd")
const Schema = Package.Schema
const PAGE_SIZE: int = 24
const MAX_PAGES: int = 8
const MAX_PAGE_BYTES: int = 64 * 1024
const ENTRY: Dictionary = {
	"kind": ["enum", "creature"], "design_id": "id", "revision": Schema.REVISION,
	"title": ["text", 120], "author": ["text", 120],
	"bytes": ["int", 1, Schema.MAX_BYTES], "sha256": ["text", 64],
}
const PAGE: Dictionary = {
	"schema": ["int", 1, 1], "entries": ["list", ENTRY, PAGE_SIZE],
	"next_cursor": "optional_id",
}


static func inspect_entry(entry: Variant) -> Dictionary:
	if not Schema.problem(entry, ENTRY).is_empty(): return fail("invalid_entry")
	if entry.title.strip_edges().is_empty() or entry.design_id in [".", ".."]:
		return fail("invalid_entry")
	if entry.sha256.length() != 64: return fail("invalid_entry")
	for character in entry.sha256:
		if not character in "0123456789abcdef": return fail("invalid_entry")
	return {"ok": true, "code": ""}


static func decode_page(body: PackedByteArray, limit: int) -> Dictionary:
	if body.size() > MAX_PAGE_BYTES: return fail("response_too_large")
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK: return fail("invalid_json")
	var page: Variant = parser.data
	if page is Dictionary and page.has("schema") and page.schema != 1:
		return fail("unsupported_service_version")
	if not Schema.problem(page, PAGE).is_empty(): return fail("invalid_page")
	if page.entries.size() > limit: return fail("page_limit")
	var keys: Dictionary = {}
	for entry: Dictionary in page.entries:
		var checked: Dictionary = inspect_entry(entry)
		if not checked.ok: return checked
		var key: String = str(entry.design_id) + "@" + str(int(entry.revision))
		if keys.has(key): return fail("duplicate_revision")
		keys[key] = true
	return {"ok": true, "code": "", "entries": page.entries, "next_cursor": page.next_cursor}


static func decode_package(body: PackedByteArray, entry: Dictionary) -> Dictionary:
	var checked: Dictionary = inspect_entry(entry)
	if not checked.ok: return checked
	if body.size() != int(entry.bytes): return fail("size_mismatch")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(body)
	if hash.finish().hex_encode() != entry.sha256: return fail("digest_mismatch")
	var decoded: Dictionary = Package.decode(body.get_string_from_utf8())
	if not decoded.ok: return decoded
	for field in ["kind", "design_id", "revision", "title", "author"]:
		if decoded.package[field] != entry[field]: return fail("revision_mismatch")
	return decoded


static func fail(code: String) -> Dictionary:
	return {"ok": false, "code": code}
