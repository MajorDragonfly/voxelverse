extends HBoxContainer
## Disposable browsing preferences. No commands, animal cache or persistence.
signal changed
const Presentation = preload("res://ui/discovery/owned_animal_presentation.gd")
const SORT_KEYS := {"name": "OWNED_SORT_NAME", "species": "OWNED_SORT_SPECIES", "trust": "OWNED_SORT_TRUST", "order": "OWNED_SORT_ORDER"}
const ORDER_KEYS := {"": "OWNED_ORDERS_ALL", "follow": "OWNED_FOLLOW", "wait": "OWNED_WAIT", "home": "OWNED_HOME", "none": "OWNED_NO_ORDER"}
var order_filter := ""
var sort_code := "name"
var _order: OptionButton
var _sort: OptionButton

func _ready() -> void:
	_order = _choice("OwnedOrderFilter")
	_sort = _choice("OwnedSort")
	for code: String in SORT_KEYS:
		_sort.add_item(Presentation.text(SORT_KEYS[code]))
		_sort.set_item_metadata(_sort.item_count - 1, code)
	_sort.item_selected.connect(func(index: int) -> void:
		sort_code = str(_sort.get_item_metadata(index))
		refresh_language()
		changed.emit())
	_order.item_selected.connect(func(index: int) -> void:
		order_filter = str(_order.get_item_metadata(index))
		refresh_language()
		changed.emit())
	_orders([])
	refresh_language()

func read(reader: RefCounted, query: String, life_filter: String, observations: Dictionary) -> Dictionary:
	var result: Dictionary = reader.read(query, life_filter, sort_code, order_filter, observations)
	var previous: String = order_filter
	_orders(result.get("order_codes", []))
	if previous != order_filter:
		result = reader.read(query, life_filter, sort_code, order_filter, observations)
	return result

func _orders(present: Array) -> void:
	var codes: Array[String] = [""]
	for code: String in ["follow", "wait", "home", "none"]:
		if code in present: codes.append(code)
	if order_filter not in codes: order_filter = ""
	# Avoid rebuilding a focused dropdown when only query/selection changes.
	var existing: Array = []
	for index in _order.item_count: existing.append(_order.get_item_metadata(index))
	if existing != codes:
		_order.clear()
		for code: String in codes:
			_order.add_item(Presentation.text(ORDER_KEYS[code]))
			_order.set_item_metadata(_order.item_count - 1, code)
	_order.select(codes.find(order_filter))
	refresh_language()

func refresh_language() -> void:
	if _order == null: return
	for index in _order.item_count:
		_order.set_item_text(index, Presentation.text(ORDER_KEYS[_order.get_item_metadata(index)]))
	for index in _sort.item_count:
		_sort.set_item_text(index, Presentation.text(SORT_KEYS[_sort.get_item_metadata(index)]))
	_order.tooltip_text = Presentation.text("OWNED_ORDER_FILTER") + " · " + Presentation.text(ORDER_KEYS[order_filter])
	_sort.tooltip_text = Presentation.text("OWNED_SORT") + " · " + Presentation.text(SORT_KEYS[sort_code])

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready(): refresh_language()

func _choice(label: String) -> OptionButton:
	var button := OptionButton.new()
	button.name = label
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.fit_to_longest_item = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(button)
	return button
