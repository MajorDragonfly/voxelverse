extends Node3D
## Explicit standalone scene: no main-scene, autoload or campaign-schema edits.
const State = preload("res://world/domestication/animal_state.gd")
const Controller = preload("res://world/domestication/domestication_controller.gd")
const Store = preload("res://world/domestication/lab/lab_store.gd")
const Fixture = preload("res://world/domestication/lab/lab_fixture.gd")
const Animal = preload("res://world/domestication/lab/lab_animal.gd")
var fixture = Fixture
var controller = Controller.new()
var store = Store.new()
var snapshot: Dictionary = {}
var handler: CharacterBody3D
var animal: CharacterBody3D
var grid := AStarGrid2D.new()
var info: Label
var message: Label
var progress: ProgressBar
var buttons: Dictionary = {}
var selected_food: String = "roots"
var autosave_timer: float = 0.0
var message_text: String = "Vier Futtergaben bauen Vertrauen auf. Jede kostet eine Wurzel."
var last_write_ok: bool = true
var load_failed: bool = false
var booted: bool = false

func _enter_tree() -> void:
	var saves := get_node("/root/SaveGameService")
	saves.session_managed = true
	saves.session_active = false
	saves.autosave_enabled = false
	saves._loaded_once = true

func _ready() -> void:
	# Autoloads already exist in this project. Their campaign state is never used
	# by the probe, and autosaves must not touch the user's campaign on exit.
	get_node("/root/SaveGameService").autosave_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().auto_accept_quit = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--d2-save" in args:
		store.path = args[args.find("--d2-save") + 1]
	snapshot = store.load_snapshot()
	if snapshot.is_empty():
		load_failed = store.blocked
		snapshot = Fixture.create()
		if load_failed: message_text = store.error + " Nur schreibgeschützte Vorschau."
	controller.configure(snapshot["registry"], _commit, Fixture.policy)
	_build_world()
	_build_ui()
	_spawn_animal()
	booted = true
	if not load_failed and not FileAccess.file_exists(store.path): controller.checkpoint()

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("152638")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("becfe1")
	settings.ambient_light_energy = 0.7
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	static_box(Vector3(27, 0.5, 21), Vector3(0, -0.25, 0), Color("476752"))
	static_box(Vector3(1.5, 2.5, 6.0), Vector3(-2.5, 1.25, -2.0), Color("7b8591"))
	for z in [-10.5, 10.5]: static_box(Vector3(28, 1.0, 0.5), Vector3(0, 0.5, z), Color("a28464"))
	for x in [-13.5, 13.5]: static_box(Vector3(0.5, 1.0, 21), Vector3(x, 0.5, 0), Color("a28464"))
	box_mesh(self, Vector3(3.5, 0.06, 3.5), Fixture.HOME + Vector3(0, 0.03, 0), Color("d2b262"))
	var home_label := Label3D.new()
	home_label.text = "HEIMATPLATZ"
	home_label.position = Fixture.HOME + Vector3(0, 2.7, 0)
	home_label.font_size = 38
	home_label.pixel_size = 0.007
	home_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(home_label)
	grid.region = Rect2i(-12, -9, 25, 19)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(-4, 0):
		for z in range(-6, 3): grid.set_point_solid(Vector2i(x, z))
	handler = CharacterBody3D.new()
	handler.name = "TribalHandlerProbe"
	handler.collision_layer = 4
	handler.collision_mask = 1
	handler.floor_snap_length = 0.5
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	handler.add_child(shape)
	box_mesh(handler, Vector3(0.65, 1.15, 0.55), Vector3(0, 0.75, 0), Color("65c5d0"))
	box_mesh(handler, Vector3(0.55, 0.5, 0.5), Vector3(0, 1.57, 0), Color("ddc1a4"))
	add_child(handler)
	handler.position = State.vector(snapshot["handler_position"])
	var camera := Camera3D.new()
	camera.position = Vector3(8, 24, 25)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 29
	add_child(camera)
	camera.look_at(Vector3(2.5, 0, 0))
	camera.current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size.x = 370
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.11, 0.96)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "VOXELVERSE · ZÄHMUNG"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "D2-Prüfszene · D1-Vertrag 1 · Testtier\nKampagnenanschluss wartet auf aktive Stammesfauna."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color("8fafc3")
	column.add_child(subtitle)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 17)
	column.add_child(info)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 22
	progress.show_percentage = false
	column.add_child(progress)
	_add_row(column, [["offer", "Futter anbieten", _offer], ["cancel", "Abbrechen", _cancel]])
	_add_row(column, [["follow", "Folgen", func(): _command("follow")], ["wait", "Warten", func(): _command("wait")], ["home", "Heimkehr", func(): _command("home")]])
	_add_row(column, [["save", "Speichern", save_probe], ["load", "Laden", load_probe]])
	var controls := Label.new()
	controls.text = "WASD / Pfeiltasten: Betreuer bewegen\nBeim Füttern 2 Sekunden in Reichweite und Sicht bleiben.\nGrauer Fels blockiert Sicht und Weg. Gelb = Heimat."
	controls.add_theme_font_size_override("font_size", 14)
	column.add_child(controls)
	var checks := Label.new()
	checks.text = "PRÜFFÄLLE"
	checks.modulate = Color("d2b262")
	column.add_child(checks)
	_add_row(column, [["phase", "Phase wechseln", _phase], ["food", "Futter wechseln", _food]])
	_add_row(column, [["friend", "Befreunden", _friend], ["flee", "Flucht auslösen", _flee], ["hurt", "Schaden: 50", _hurt]])
	_add_row(column, [["abandon", "Zähmung aufgeben", _abandon], ["reset", "Prüfstand zurücksetzen", reset_probe]])
	message = Label.new()
	message.custom_minimum_size = Vector2(365, 66)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 15)
	message.modulate = Color("eed89e")
	column.add_child(message)

func _add_row(column: VBoxContainer, entries: Array) -> void:
	var row := HBoxContainer.new()
	column.add_child(row)
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[2])
		row.add_child(button)
		buttons[entry[0]] = button

func _physics_process(delta: float) -> void:
	if not booted: return
	if not load_failed:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)), 0,
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))).normalized()
		handler.velocity = Vector3(direction.x * 5.0, -0.5 if handler.is_on_floor() else maxf(-15, handler.velocity.y - delta * 24), direction.z * 5.0)
		handler.move_and_slide()
		var a: Dictionary = controller.record(Fixture.ANIMAL)
		if not a.get("pending", {}).is_empty():
			var result: Dictionary = controller.advance_offer(Fixture.ANIMAL, minf(delta, 0.25), live_context())
			if result["code"] != "offering": _show(result)
		autosave_timer += delta
		if autosave_timer >= 3.0:
			autosave_timer = 0.0
			if not controller.checkpoint(): message_text = "Speichern fehlgeschlagen. Fortschritt ist noch nicht gesichert."
	_update_ui()

func live_context() -> Dictionary:
	var c: Dictionary = Fixture.context(snapshot)
	c["actor_position"] = handler.global_position
	c["paused"] = get_tree().paused
	c["threatened"] = animal.fleeing > 0.0
	var query := PhysicsRayQueryParameters3D.create(handler.global_position + Vector3.UP, animal.global_position + Vector3.UP, 1)
	c["line_of_sight"] = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	return c

func _commit(registry: Dictionary, cost: Dictionary) -> bool:
	if load_failed: return false
	var proposed: Dictionary = snapshot.duplicate(true)
	proposed["registry"] = registry.duplicate(true)
	if is_instance_valid(handler): proposed["handler_position"] = State.point_array(handler.global_position)
	for food: String in cost:
		if not State.integer(cost[food], 0, 1000) or int(proposed["stock"].get(food, 0)) < int(cost[food]): return false
		proposed["stock"][food] -= int(cost[food])
	last_write_ok = store.write_snapshot(proposed)
	if last_write_ok: snapshot = proposed
	return last_write_ok

func route_direction(from: Vector3, to: Vector3) -> Vector3:
	var start := Vector2i(roundi(from.x), roundi(from.z))
	var target := Vector2i(roundi(to.x), roundi(to.z))
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(target) or grid.is_point_solid(start) or grid.is_point_solid(target): return Vector3.ZERO
	var route: Array[Vector2i] = grid.get_id_path(start, target)
	if route.is_empty(): return Vector3.ZERO
	var waypoint: Vector3 = to if route.size() == 1 else Vector3(route[1].x, from.y, route[1].y)
	return Vector3(waypoint.x - from.x, 0, waypoint.z - from.z).normalized()

func _spawn_animal() -> void:
	if is_instance_valid(animal):
		remove_child(animal)
		animal.queue_free()
	animal = Animal.new()
	animal.name = "IndividualAnimal"
	animal.setup(self, Fixture.ANIMAL)
	add_child(animal)
	animal.set_physics_process(not load_failed)

func _offer() -> void: _show(controller.begin_offer(Fixture.ANIMAL, selected_food, live_context()))
func _cancel() -> void: _show(controller.interrupt_offer(Fixture.ANIMAL))
func _command(order: String) -> void: _show(controller.command(Fixture.ANIMAL, order, live_context()))
func _abandon() -> void: _show(controller.abandon_claim(Fixture.ANIMAL, live_context()))
func _hurt() -> void: _show(controller.damage(Fixture.ANIMAL, 50.0))
func _flee() -> void:
	animal.fleeing = 4.0
	if not controller.record(Fixture.ANIMAL)["pending"].is_empty(): _show(controller.interrupt_offer(Fixture.ANIMAL, "fleeing"))
func _food() -> void: selected_food = "meat" if selected_food == "roots" else "roots"
func _phase() -> void:
	var before: int = snapshot["phase"]
	snapshot["phase"] = 1 - before
	if not controller.checkpoint(): snapshot["phase"] = before
func _friend() -> void:
	var before: bool = snapshot["friendship"]
	snapshot["friendship"] = true
	if not controller.checkpoint(): snapshot["friendship"] = before
	message_text = "Befreundet. Tierbesitz und Zähmvertrauen bleiben unverändert."
func save_probe() -> void:
	message_text = "Prüfstand gespeichert." if controller.checkpoint() else "Speichern fehlgeschlagen: " + store.error
func load_probe() -> void:
	var loaded: Dictionary = store.load_snapshot()
	if loaded.is_empty():
		load_failed = store.blocked
		animal.set_physics_process(not load_failed)
		message_text = store.error
		return
	load_failed = false
	snapshot = loaded
	controller.configure(snapshot["registry"], _commit, Fixture.policy)
	handler.position = State.vector(snapshot["handler_position"])
	_spawn_animal()
	message_text = "Prüfstand geladen. IDs, Besitz und Auftrag erhalten." + (" Sicherung wiederhergestellt." if store.recovered else "")
func reset_probe() -> void:
	if load_failed: return
	var fresh: Dictionary = Fixture.create()
	if not store.write_snapshot(fresh):
		message_text = store.error
		return
	snapshot = fresh
	controller.configure(snapshot["registry"], _commit, Fixture.policy)
	handler.position = State.vector(snapshot["handler_position"])
	_spawn_animal()
	message_text = "Nur der D2-Prüfstand wurde zurückgesetzt."

func _show(result: Dictionary) -> void:
	var names: Dictionary = {"offer_started": "Futter angeboten. Halte Reichweite und Sichtkontakt.", "trust_gained": "Futter angenommen: +25 Vertrauen, −1 Wurzel.", "tamed": "Gezähmt. Dieses Tier gehört jetzt deinem Stamm und bleibt ein Tier.",
		"tribal_age_required": "Zähmung und Tierbefehle sind erst ab Stammesphase verfügbar.", "wrong_food": "Unpassendes Futter. Dieses Testtier nimmt Wurzeln an.", "out_of_range": "Zum Füttern näher herangehen (max. 4,5 m).", "no_line_of_sight": "Der Fels verdeckt das Tier.",
		"not_owner": "Du kannst nur eigene gezähmte Tiere befehligen.", "already_tamed": "Dieses Tier ist bereits gezähmt.", "dead": "Das Tier ist verstorben.", "died": "Das Tier ist verstorben. Sein Datensatz bleibt gespeichert.", "hurt": "Tier verletzt; laufende Futtergabe unterbrochen.",
		"order_follow": "Folgen gespeichert.", "order_wait": "Warten am aktuellen Ort gespeichert.", "order_home": "Heimkehr gespeichert.", "save_failed": "Speichern fehlgeschlagen. Die Aktion wurde nicht übernommen.", "claim_abandoned": "Zähmung aufgegeben; Platz wieder frei. Verbrauchtes Futter bleibt verbraucht.", "capacity_full": "Kein freier Platz im Tierbestand.", "insufficient_food": "Nicht genug passendes Futter vorhanden.", "no_offer": "Keine laufende Futtergabe.", "already_offering": "Es läuft bereits eine Futtergabe.", "not_claimant": "Keine eigene angefangene Zähmung.", "fleeing": "Das Tier flieht. Warte, bis es ruhig ist."}
	message_text = names.get(result["code"], "Futtergabe unterbrochen; keine Kosten für die angefangene Gabe." if str(result["code"]).begins_with("interrupted:") else str(result["code"]))

func _update_ui() -> void:
	var a: Dictionary = controller.record(Fixture.ANIMAL)
	var pending: Dictionary = a.get("pending", {})
	info.text = "%s · Futter: %s\nVorrat: %d Wurzeln / %d Fleisch\nVertrauen: %d / 100 · Gesundheit: %d\nBesitzer: %s · Bürger: nein\nBefreundet: %s · Auftrag: %s" % ["Stammesphase" if snapshot["phase"] == 1 else "Kreaturenphase", "Wurzeln" if selected_food == "roots" else "Fleisch", snapshot["stock"]["roots"], snapshot["stock"]["meat"], roundi(a["trust"]), roundi(a["health"]), "dein Stamm" if a["owner_faction_id"] == Fixture.FACTION else "keiner", "ja" if snapshot["friendship"] else "nein", animal.status]
	progress.value = float(pending.get("elapsed", 0.0)) / State.OFFER_SECONDS * 100.0
	message.text = message_text
	for key: String in buttons:
		buttons[key].disabled = load_failed and key != "load"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if booted and not load_failed and not controller.checkpoint():
			message_text = "Speichern fehlgeschlagen. Szene bleibt offen; bitte Speicherort prüfen."
			return
		get_tree().quit()

func box_mesh(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func static_box(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	box_mesh(body, size, Vector3.ZERO, color)
	add_child(body)
