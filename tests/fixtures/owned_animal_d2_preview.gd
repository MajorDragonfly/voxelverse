extends Node3D
## Explicit integration fixture. Reuses the unmodified, separately supplied D2 lab.
## It must never be installed as a campaign host or save adapter.
const LAB_PATH := "res://world/domestication/lab/domestication_lab.tscn"
var lab: Node3D
var journal: CanvasLayer

func _enter_tree() -> void:
	var saves := get_node("/root/SaveGameService")
	saves.session_managed = true
	saves.session_active = false
	saves.autosave_enabled = false
	saves._loaded_once = true

func _ready() -> void:
	if ResourceLoader.exists(LAB_PATH):
		lab = load(LAB_PATH).instantiate()
		add_child(lab)
	journal = preload("res://ui/discovery/discovery_journal.gd").new()
	add_child(journal)
	journal._heading.get_child(0).text = "BUCH · D2-PRÜFANSICHT"
	journal._hint_enabled = false
	if lab != null:
		journal.bind_owned_animals(lab.controller, _context, _names)
		# D2 configure/load is intentionally silent; the host refreshes after loading.
		lab.buttons["load"].pressed.disconnect(lab.load_probe)
		lab.buttons["load"].pressed.connect(load_probe)
		lab.buttons["reset"].pressed.disconnect(lab.reset_probe)
		lab.buttons["reset"].pressed.connect(reset_probe)
	journal.open_journal()
	journal._tabs.current_tab = journal.ANIMALS_TAB

func load_probe() -> void:
	lab.load_probe()
	journal.refresh_owned_animals()

func reset_probe() -> void:
	lab.reset_probe()
	journal.refresh_owned_animals()

func _context() -> Dictionary:
	return {"campaign_id": lab.fixture.CAMPAIGN, "body_id": lab.fixture.BODY, "faction_id": lab.fixture.FACTION}

func _names(kind: String, id: String) -> String:
	# Display labels belong only to this labelled test scene, never the registry.
	var labels := {"animal": {lab.fixture.ANIMAL: "Prüftier mit einem besonders langen Anzeigenamen"},
		"species": {lab.fixture.FOREIGN: "D1-Begleiter · Beispielart"},
		"faction": {lab.fixture.FACTION: "Prüfstamm"}, "handler": {lab.fixture.ACTOR: "Prüfbetreuer"},
		"body": {lab.fixture.BODY: "D2-Prüfebene"}}
	return labels.get(kind, {}).get(id, "")
