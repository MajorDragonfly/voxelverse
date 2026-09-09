extends Node
## Host-bound presentation only. D2 owns actions, eligibility, trust and persistence.
## Success comes only from animal_changed; the host forwards failed return values.
signal feedback_changed(text: String, severity: String)
const Reader = preload("res://ui/discovery/owned_animal_reader.gd")
const MAX_RECEIPTS := 256
const REASONS := {
	"wrong_food": "Dieses Tier nimmt das gewählte Futter nicht an.",
	"out_of_range": "Geh mit dem Betreuer näher an das Tier.",
	"no_line_of_sight": "Sorge für freie Sicht zwischen Betreuer und Tier.",
	"fleeing": "Das Tier flieht. Warte, bis es ruhig ist.",
	"insufficient_food": "Im gemeinsamen Vorrat fehlt das benötigte Futter.",
	"save_failed": "Speichern fehlgeschlagen. Die Aktion wurde nicht übernommen.",
	"paused": "Das Spiel ist pausiert. Setze es vor der nächsten Tieraktion fort.",
	"tribal_age_required": "Zähmung und Tierbefehle sind erst ab der Stammesphase verfügbar.",
	"own_species": "Die eigene Art kann nicht als Tier gezähmt werden.",
	"not_owner": "Du kannst nur deinen eigenen Tieren Aufträge geben.",
	"claimed_by_other": "Ein anderer Stamm hat die Zähmung dieses Tiers begonnen.",
	"not_claimant": "Für dieses Tier läuft keine Zähmung deines Stamms.",
	"already_tamed": "Dieses Tier ist bereits gezähmt.",
	"already_offering": "Eine Futtergabe läuft bereits. Bleibe in Reichweite.",
	"no_offer": "Es läuft gerade keine Futtergabe.",
	"capacity_full": "Dein Stamm hat keinen freien Platz für ein weiteres Tier.",
	"dead": "Dieses Tier ist verstorben.",
	"unknown_animal": "Dieses Tier ist nicht mehr verfügbar.",
	"wrong_world": "Dieses Tier ist in deiner aktuellen Welt nicht verfügbar.",
	"handler_changed": "Der Betreuer hat gewechselt. Beginne die Futtergabe erneut.",
	"invalid_handler": "Wähle einen lebenden Bewohner als Betreuer.",
	"d1_unavailable": "Für diese Art ist derzeit keine Zähmung möglich.",
	"unsuitable": "Diese Art eignet sich derzeit nicht zur Zähmung.",
}
var message := ""
var severity := "info"
var _source: WeakRef
var _context: Callable
var _names: Callable
var _validator: Script
var _scope: Array = []
var _participants: Dictionary = {}
var _receipts: Dictionary = {}
var _sequence := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind_source(source: Object, context: Callable, names: Callable = Callable()) -> bool:
	unbind()
	if not is_instance_valid(source) or not context.is_valid() or not source.has_method("record") or not source.has_signal("animal_changed") or not ResourceLoader.exists(Reader.STATE_PATH):
		return false
	_source = weakref(source)
	_context = context
	_names = names
	_validator = load(Reader.STATE_PATH) as Script
	source.connect("animal_changed", _on_changed)
	_sync_scope()
	return true

func unbind() -> void:
	var source := _controller()
	if source != null and source.is_connected("animal_changed", _on_changed):
		source.disconnect("animal_changed", _on_changed)
	_source = null
	_context = Callable()
	_names = Callable()
	_validator = null
	_scope = []
	_participants.clear()
	_receipts.clear()
	clear_after_load()

func clear_after_load() -> void:
	# configure/load is deliberately silent. Do not inspect/replay last_result here.
	message = ""
	severity = "info"
	_participants.clear()
	if _valid_scope():
		for animal: Dictionary in _registry().get("animals", {}).values():
			if _belongs(animal): _participants[animal["object_id"]] = true
	feedback_changed.emit(message, severity)

func report_result(object_id: String, result: Dictionary, request_id: String) -> bool:
	# Called once by the host for the actual action return. Successful return values
	# are ignored: the same action already emitted its confirmed D2 event.
	_sync_scope()
	if not result.get("ok") is bool or result["ok"] or not result.get("code") is String or request_id.is_empty() or request_id.length() > 64 or object_id.is_empty() or not _valid_scope():
		return false
	if _receipts.has(request_id): return false
	if _receipts.size() >= MAX_RECEIPTS: _receipts.erase(_receipts.keys()[0])
	_receipts[request_id] = true
	var code: String = result["code"]
	_publish("Nicht ausgeführt · " + REASONS.get(code, "Diese Tieraktion ist derzeit nicht möglich."), "error", &"feed", false)
	return true

func _on_changed(object_id: String, code: String) -> void:
	_sync_scope()
	if not _valid_scope(): return
	var animal: Dictionary = _controller().call("record", object_id)
	if animal.is_empty(): return
	var released: bool = code in ["claim_abandoned", "hurt", "died"] or code.begins_with("interrupted:")
	var previous_claim: bool = released and _participants.has(object_id) and animal["owner_faction_id"].is_empty() and animal["claim_faction_id"].is_empty()
	if not _belongs(animal) and not previous_claim:
		return
	if _belongs(animal): _participants[object_id] = true
	else: _participants.erase(object_id)
	var name := _name("animal", object_id, "Das Tier")
	match code:
		"offer_started": _publish("Futter angeboten · Bleibe in Reichweite und Sicht des Tiers.")
		"trust_gained": _publish("Futter angenommen · Vertrauen: %s / 100." % Reader.number(animal["trust"]), "success", &"feed")
		"tamed": _publish("Gezähmt · %s gehört jetzt deinem Stamm." % name, "success", &"tame")
		"order_follow": _publish("Folgen gespeichert · Betreuer: " + _name("handler", animal["handler_id"], "dein ausgewählter Bewohner"), "success", &"follow")
		"order_wait": _publish("Warten gespeichert · Ziel ist der angewiesene Warteplatz.", "success", &"wait")
		"order_home": _publish("Heimkehr gespeichert · Ziel ist der Heimatplatz.", "success", &"home")
		"claim_abandoned": _publish("Zähmung aufgegeben · Bereits verbrauchtes Futter wird nicht erstattet.")
		"hurt": _publish("Das Tier wurde verletzt.")
		"died": _publish("Das Tier ist verstorben. Es bleibt in deinem Tierregister verzeichnet." if not animal["owner_faction_id"].is_empty() else "Das Tier ist verstorben. Die Zähmung ist beendet.")
		_:
			if code.begins_with("interrupted:"):
				var reason := code.trim_prefix("interrupted:")
				var detail: String = REASONS.get(reason, "Der Kontakt zum Tier wurde unterbrochen.")
				_publish("Futtergabe abgebrochen. Für diese unfertige Gabe wurde kein Futter verbraucht." if reason == "cancelled" else "Futtergabe unterbrochen · %s Für diese unfertige Gabe wurde kein Futter verbraucht." % detail,
					"info" if reason == "cancelled" else "error", &"" if reason == "cancelled" else &"feed", false)

func _publish(text: String, kind: String = "info", action: StringName = &"", accepted: bool = true) -> void:
	message = text
	severity = kind
	feedback_changed.emit(message, severity)
	if action.is_empty() or get_tree().paused: return
	_sequence += 1
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		# Existing voice pool, UI volume, receipt cache and success/error throttling.
		audio.play_group_order(action, "animal:%d:%d" % [get_instance_id(), _sequence], accepted)

func _process(_delta: float) -> void:
	_sync_scope()

func _sync_scope() -> void:
	var c := _read_context()
	var registry := _registry()
	var next := [_controller() != null, c.get("campaign_id"), c.get("body_id"), c.get("faction_id"), registry.get("schema"), registry.get("campaign_id"), registry.get("body_id")]
	if next != _scope:
		_scope = next
		clear_after_load()

func _valid_scope() -> bool:
	return _controller() != null and Reader.scope_error(_registry(), _read_context(), _validator).is_empty()

func _belongs(animal: Dictionary) -> bool:
	var faction: String = _read_context().get("faction_id", "")
	return not faction.is_empty() and (animal.get("owner_faction_id") == faction or animal.get("claim_faction_id") == faction)

func _controller() -> Object:
	return _source.get_ref() if _source != null else null

func _registry() -> Dictionary:
	var source := _controller()
	var value: Variant = source.get("registry") if source != null else null
	return value if value is Dictionary else {}

func _read_context() -> Dictionary:
	var value: Variant = _context.call() if _context.is_valid() else null
	return value if value is Dictionary else {}

func _name(kind: String, id: String, fallback: String) -> String:
	var value: Variant = _names.call(kind, id) if _names.is_valid() else null
	return value.strip_edges() if value is String and not value.strip_edges().is_empty() else fallback

func _exit_tree() -> void:
	unbind()
