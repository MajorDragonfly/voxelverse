extends VBoxContainer

const Style = preload("res://ui/progression_style.gd")
const Parts = preload("res://creatures/editor/creature_part_library.gd")
const PAGE_SIZE: int = 30
const ROLES := {"grazer": "Pflanzenfresser", "herbivore": "Pflanzenfresser", "predator": "Räuber", "omnivore": "Allesfresser", "scavenger": "Aasfresser", "unknown": "Unbekannt"}

var _search: LineEdit
var _category: OptionButton
var _summary: Label
var _entries: VBoxContainer
var _previous: Button
var _next: Button
var _page_label: Label
var _page: int = 0
var _records: Array[Dictionary] = []


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	add_child(Style.label("Deine Entdeckungen", 28))
	add_child(Style.label("Entdeckte Arten, besuchte Regionen und deine freigeschalteten Körperteile.", 17, Style.MUTED))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 14)
	add_child(filters)
	_category = OptionButton.new()
	_category.name = "Category"
	for title in ["Arten", "Regionen", "Körperteile"]:
		_category.add_item(title)
	_category.custom_minimum_size = Vector2(170, 46)
	_category.item_selected.connect(func(_index: int) -> void: refresh())
	filters.add_child(_category)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "Entdeckungen durchsuchen …"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _page = 0; _render())
	filters.add_child(_search)
	_summary = Style.label("", 17, Style.MUTED)
	add_child(_summary)
	_entries = Style.column(self, 8)
	var paging := HBoxContainer.new()
	paging.add_theme_constant_override("separation", 16)
	add_child(paging)
	_previous = Style.button("Zurück")
	_previous.pressed.connect(func() -> void: _page -= 1; _render())
	paging.add_child(_previous)
	_page_label = Style.label("", 17, Style.MUTED)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paging.add_child(_page_label)
	_next = Style.button("Weiter")
	_next.pressed.connect(func() -> void: _page += 1; _render())
	paging.add_child(_next)
	refresh()


func refresh() -> void:
	if _category == null:
		return
	_records.clear()
	_page = 0
	var progression := get_node("/root/ProgressionService")
	var data: Dictionary = progression.call("export_state")
	match _category.selected:
		0:
			for entry: Dictionary in data.get("discovered_species", {}).values():
				var role: String = str(entry.get("role", "unknown"))
				_records.append({"title": str(entry.get("name", "Unbekannte Art")),
					"detail": "%s · %s" % [str(ROLES.get(role, role)), _world(entry)]})
		1:
			for entry: Dictionary in data.get("discovered_regions", {}).values():
				_records.append({"title": "Region %d / %d" % [int(entry.get("x", 0)), int(entry.get("z", 0))], "detail": _world(entry)})
		2:
			for part_id: String in data.get("unlocked_parts", {}):
				var definition: Dictionary = Parts.get_part(part_id)
				_records.append({"title": str(definition.get("name", part_id)),
					"detail": "Freigeschaltet · " + Parts.get_category_name(str(definition.get("category", ""))) if not definition.is_empty() else "Gespeicherte Freischaltung · Teil derzeit nicht im Katalog"})
	_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["title"]).naturalnocasecmp_to(str(b["title"])) < 0)
	_summary.text = "%d Arten · %d Regionen · %d Körperteile · %d Insight" % [data.get("discovered_species", {}).size(), data.get("discovered_regions", {}).size(), data.get("unlocked_parts", {}).size(), int(data.get("discovery_points", 0))]
	_render()


func _render() -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	var found: Array[Dictionary] = []
	var query: String = _search.text.strip_edges().to_lower()
	for record in _records:
		if query.is_empty() or (str(record["title"]) + " " + str(record["detail"])).to_lower().contains(query):
			found.append(record)
	var pages: int = maxi(1, ceili(float(found.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, pages - 1)
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, found.size())):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Style.box())
		_entries.add_child(panel)
		var content := Style.column(panel, 4)
		content.add_child(Style.label(str(found[index]["title"]), 21))
		content.add_child(Style.label(str(found[index]["detail"]), 16, Style.MUTED))
	if found.is_empty():
		_entries.add_child(Style.label("Keine passenden Einträge." if not query.is_empty() else "Hier sind noch keine Entdeckungen gespeichert. Beobachte Arten und erkunde die Welt.", 20, Style.MUTED))
	_previous.disabled = _page == 0
	_next.disabled = _page + 1 >= pages
	_page_label.text = "%d Einträge · Seite %d / %d" % [found.size(), _page + 1, pages]


func _world(entry: Dictionary) -> String:
	# Legacy discoveries retain a seed, not a player-facing planet name.
	return "Welt %d" % int(entry.get("world_seed", 0))
