extends Node3D
## Explicit D3 fixture host only. Production code never spawns or tames animals.
const Model = preload("res://world/tribe/tribe_state.gd")
const D1 = preload("res://world/fauna/domestication/domestication_contract.gd")
const D2 = preload("res://world/domestication/animal_state.gd")
const SAVE: String = "user://d3-village-lab/campaign.json"
const ANIMAL: String = "d3-lab-animal-001"
const SPECIES: String = "d3-lab-d1-milk-fixture"
class ReadyWorld:
	extends Node
	var world_initialized: bool = true
var tribe: Node
var home: Node
var player: CharacterBody3D
var animal: Node3D
var state: Node
var saves: Node
var ready_for_entry: bool = false
var ready_for_work: bool = false
var banner: Label

func _enter_tree() -> void:
	DirAccess.make_dir_recursive_absolute("user://d3-village-lab")
	saves = get_node("/root/SaveGameService")
	saves._loaded_once = true
	saves.save_path = SAVE
	saves.autosave_enabled = false

func _ready() -> void:
	state = get_node("/root/GameState")
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var column := VBoxContainer.new()
	column.position = Vector2(20, 12)
	column.custom_minimum_size.x = 640
	layer.add_child(column)
	banner = preload("res://ui/progression_style.gd").label("D3 · Tierhaltung – Prüfszene", 20)
	column.add_child(banner)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	for title: String in ["Speichern", "Laden"]:
		var button := preload("res://ui/progression_style.gd").button(title)
		buttons.add_child(button)
		button.pressed.connect(func() -> void:
			if not ready_for_work or not tribe.is_active():
				return
			var ok: bool = saves.save_now() if title == "Speichern" else saves.load_now()
			banner.text = "D3 · Tierhaltung – Prüfszene · " + (title + " erfolgreich" if ok else saves.last_error))
	if FileAccess.file_exists(SAVE):
		if not saves.load_now():
			banner.text = "Prüfszene: Laden fehlgeschlagen · " + saves.last_error
			return
	else:
		state.start_world_with_seed(15838)
	await get_tree().process_frame
	var manager := ReadyWorld.new()
	manager.name = "WorldManager"
	add_child(manager)
	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0, 99.5, 0)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(80, 1, 80)
	floor_body.add_child(shape)
	add_child(floor_body)
	box(floor_body, Vector3.ZERO, Vector3(80, 1, 80), Color("53663f"))
	player = load("res://creatures/player/player.tscn").instantiate()
	add_child(player)
	player.position = Vector3(0, 100.05, 0)
	player.set_physics_process(false)
	player.set_process(false)
	var nest: Node3D = load("res://world/resources/nests/nest.tscn").instantiate()
	nest.name = "Nest"
	nest.snap_to_terrain = false
	add_child(nest)
	nest.position = Vector3(0, 100.02, 0)
	home = nest.get_node("HomeGroup")
	tribe = nest.get_node("Tribe")
	tribe.husbandry.configure(registry, traits, live_actor)
	saves.game_loaded.connect(_loaded)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("30403b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccdfcc")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8, 107, 14)
	camera.look_at(Vector3(0, 101, 0))
	camera.make_current()
	for i in range(25):
		await get_tree().physics_frame
	if int(state.current_phase) == 0 and home.group_state().is_empty():
		home.establish_home()
	ready_for_entry = true
	if int(state.current_phase) == 0:
		banner.text = "D3 · Tierhaltung – Prüfszene · Zuerst ins Stammeszeitalter wechseln."
	else:
		_loaded("")

func _process(_delta: float) -> void:
	if not ready_for_entry or ready_for_work or not tribe.is_active():
		return
	if not tribe.body().has("d3_lab_sources"):
		# Finite historical setup budget. All new pen costs, care and milk are real trips.
		var data: Dictionary = tribe.village()
		data["tools"] = 1
		data["garden"] = 1
		data["stock"].merge({"wood": 16, "stone": 8, "food": 12, "water": 12, "fiber": 4}, true)
		data["deposits"]["wood"]["remaining"] = 0
		data["deposits"]["stone"]["remaining"] = 0
		data["deposits"]["food"]["remaining"] = 24
		for kind: String in ["well", "fiberbed"]:
			var location: Array = [0, 100.06, -7] if kind == "well" else [-8, 100.06, 0]
			data["economy"]["stations"][kind] = {"id": Model.Ids.scoped("workplace", data["id"], kind), "position": location.duplicate()}
			data["deposits"][Model.Economy.STATIONS[kind]]["position"] = location.duplicate()
		data["economy"]["produced"].merge({"fiber": 4, "water": 12}, true)
		var book: Dictionary = D2.empty_registry(state.campaign.data["id"], data["body_id"])
		var a: Dictionary = D2.individual(ANIMAL, SPECIES, data["body_id"], {"id": "d3-lab-body", "revision": 1}, Vector3(0, 100.06, 7))
		a.merge({"status": "tamed", "trust": 100.0, "owner_faction_id": data["faction_id"]}, true)
		book["animals"][ANIMAL] = a
		tribe.body()["d3_lab_sources"] = {"scope": "explicit-d3-fixture", "registry": book, "traits": D1.suitability("milk")}
		if not saves.save_now():
			banner.text = "Prüfszene konnte nicht gespeichert werden: " + saves.last_error
			ready_for_entry = false
			return
	_loaded("")
	if ready_for_work:
		tribe._changed()
		tribe.panel._tabs.current_tab = 2
		banner.text = "D3 · Prüfszene · Tierplatz beim Testtier setzen, dann zuordnen. 2 Liter / 300 Spielsekunden."

func registry() -> Variant:
	return tribe.body().get("d3_lab_sources", {}).get("registry", {})

func traits(identity: String) -> Variant:
	return tribe.body().get("d3_lab_sources", {}).get("traits", {}) if identity == SPECIES else {}

func live_actor(identity: String) -> Node3D:
	return animal if identity == ANIMAL and is_instance_valid(animal) else null

func _loaded(_path: String) -> void:
	if is_instance_valid(animal):
		remove_child(animal)
		animal.queue_free()
	ready_for_work = false
	var fixture: Dictionary = tribe.body().get("d3_lab_sources", {})
	if fixture.get("scope") != "explicit-d3-fixture" or not D2.validate(registry()).is_empty() or not D1.validate(traits(SPECIES)).is_empty() or not registry()["animals"].has(ANIMAL):
		banner.text = "Prüfszene: gültige Testquelle fehlt."
		return
	animal = Node3D.new()
	animal.name = "ExplicitD2TestAnimal"
	add_child(animal)
	animal.position = D2.vector(registry()["animals"][ANIMAL]["position"])
	box(animal, Vector3(0, 0.95, 0), Vector3(0.7, 0.7, 1.25), Color("cbb997"))
	box(animal, Vector3(0, 1.18, -0.8), Vector3(0.5, 0.5, 0.5), Color("b9a583"))
	for x in [-1, 1]:
		for z in [-1, 1]:
			box(animal, Vector3(x * 0.24, 0.34, z * 0.43), Vector3(0.18, 0.65, 0.18), Color("76644d"))
	var label := Label3D.new()
	label.text = "D1/D2-Testtier"
	label.position.y = 2.2
	label.font_size = 26
	label.pixel_size = 0.017
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	animal.add_child(label)
	ready_for_work = true

func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = StandardMaterial3D.new()
	mesh.material_override.albedo_color = color
	mesh.material_override.roughness = 0.95
	parent.add_child(mesh)
	mesh.position = position
