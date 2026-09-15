extends "res://world/planet_lab/surface_adapter_lab.gd"

const LivingSurface = preload("res://world/surface/living_planet_surface.gd")
const LivingStore = preload("res://world/surface/living_planet_store.gd")
const Ecosystem = preload("res://world/surface/surface_ecosystem.gd")
const Domestic = preload("res://world/fauna/domestication/domestic_surface_runtime.gd")
const BIOME_NAMES: Dictionary = {"grassland": "Wiese", "savanna": "Savanne", "desert": "Wüste",
	"forest": "Wald", "dense_forest": "Dichter Wald", "rocky_highlands": "Felsiges Hochland",
	"alpine": "Gebirge", "snow": "Schneeland", "coast": "Küste", "ocean": "Meer"}
var ecosystem: Node
var underwater: Node
var map_atlases: Dictionary = {}
var fauna_error: String = ""
var minimap: CanvasLayer


func _init() -> void:
	store_path = LivingStore.PATH
	save_backend = LivingStore
	for id in System.REAL_LANDABLE:
		system.bodies[id]["surface_generation"] = LivingSurface.GENERATION
		system.bodies[id]["surface_mode"] = Cube.MODE
		system.bodies[id]["inhabited"] = true


func _build_view() -> void:
	super._build_view()
	help_label.text = "WASD Bewegen · Maus Umsehen · Leertaste Springen · Esc Pause / Maus\nF5 Sichern · F9 Laden · M Weltkarte · P Planet wechseln · R Zum Startort zurück"
	leave_without_saving.text = "Ohne Sicherung zurück"


func save_lab() -> bool:
	if is_instance_valid(minimap): minimap.atlas_window.tracker.update_exploration(true)
	var success: bool = super.save_lab()
	if success:
		status.text = "Planet, Spieler und Tiere gesichert."
	return success


func load_lab() -> bool:
	var success: bool = super.load_lab()
	if not fauna_error.is_empty():
		status.text = fauna_error + " Vorhandener Spielstand bleibt geschützt."
		return false
	return success


func _ready() -> void:
	super._ready()
	minimap = preload("res://ui/minimap/minimap_hud.gd").new()
	minimap.lab = self
	add_child(minimap)
	underwater = preload("res://world/visuals/underwater_view.gd").new()
	underwater.sample_water = _sample_water
	add_child(underwater)
	status.text = "Bewege dich frei über den Planeten. Pflanzen und Tiere werden unterwegs nachgeladen." if not read_only else "Vorhandener Planetenstand geschützt; Speichern nicht möglich."


func _new_record() -> Dictionary:
	var record: Dictionary = super._new_record()
	var best: Dictionary = record.spawn
	var score: float = INF
	for face in range(6):
		for index in range(-12, 13):
			var candidate: Dictionary = Cube.address(body_id, face, 1.0 - 96.0 / float(system.bodies[body_id].radius), index / 14.0)
			var sample: Dictionary = adapter.sample(candidate)
			if sample.height < 3.0 or sample.height > 50.0 or sample.normal.dot(adapter.up_at(candidate)) < 0.97:
				continue
			var cost: float = absf(sample.height - 12.0) + absf(sample.canopy - 0.55) * 25.0
			if cost < score:
				score = cost
				best = candidate
	best.height = adapter.sample(best).height + 1.1
	var frame: Basis = adapter.frame_at(best)
	record.spawn = best
	record.player = _pose(best, -frame.z)
	record.tree.merge(_pose(adapter.offset(best, -frame.z * 13.0), -frame.z), true)
	var home: Dictionary = adapter.offset(best, frame.x * 6.0 - frame.z * 6.0, 1.1)
	record.creature.merge(_pose(home, -frame.z), true)
	record.creature.home = home.duplicate(true)
	record.creature.goal = adapter.offset(home, -frame.z * 8.0, 1.1)
	record.fauna = {}
	return record


func stream_objects() -> void:
	super.stream_objects()
	if not is_instance_valid(ecosystem):
		ecosystem = Ecosystem.new()
		ecosystem.adapter = adapter
		ecosystem.player = walker
		ecosystem.spawn = records[body_id].spawn.duplicate(true)
		ecosystem.paused = paused
		ecosystem.domestic = Domestic.new()
		# The legacy catalog still derives exclusions from inline fauna before
		# that bounded source is replaced by its immutable archive manifest.
		ecosystem.domestic.configure(system.bodies[body_id], records[body_id], terrain.surface)
		if not read_only:
			if ecosystem.configure_fauna(body_id, records[body_id]):
				_capture_fauna()
			else:
				_fauna_failed()
		ecosystem.wildlife_enabled = not read_only
		add_child(ecosystem)


func _capture() -> void:
	super._capture()
	if is_instance_valid(ecosystem) and ecosystem.fauna != null:
		_capture_fauna()


func _capture_fauna() -> void:
	var manifest: Dictionary = ecosystem.capture()
	if manifest.is_empty():
		_fauna_failed()
		return
	records[body_id].fauna_archive = manifest
	records[body_id].erase("fauna")


func _fauna_failed() -> void:
	fauna_error = ecosystem.fauna.problem()
	if fauna_error.is_empty(): fauna_error = "Labortiere konnten nicht vollständig gesichert werden."
	read_only = true
	ecosystem.wildlife_enabled = false
	for animal: Node in ecosystem.animals.values(): animal.enabled = false
	status.text = fauna_error + " Vorhandener Spielstand bleibt geschützt."
	leave_without_saving.visible = true


func open_body(id: String, capture: bool = true) -> bool:
	if id not in System.REAL_LANDABLE: return false
	if capture and is_instance_valid(ecosystem):
		_capture()
		if not fauna_error.is_empty(): return false
	return super.open_body(id, false)


func _clear_ecosystem() -> void:
	if is_instance_valid(ecosystem):
		ecosystem.close()
		remove_child(ecosystem)
		ecosystem.queue_free()
		ecosystem = null


func _clear_body() -> void:
	_clear_ecosystem()
	super._clear_body()


func return_to_marker() -> void:
	_capture()
	if not fauna_error.is_empty(): return
	_clear_ecosystem()
	super.return_to_marker()


func snapshot() -> Dictionary:
	var data: Dictionary = super.snapshot()
	if not fauna_error.is_empty(): return {}
	data.schema = LivingStore.SCHEMA
	data.surface_generation = LivingSurface.GENERATION
	data.fauna_codec = "godot_native_v1"
	data.map_atlases = map_atlases.duplicate(true)
	return data

func _restore_extensions(data: Dictionary) -> void:
	fauna_error = ""
	map_atlases = data.get("map_atlases", {}).duplicate(true)
	if is_instance_valid(minimap): minimap.atlas_window.tracker.invalidate()

func map_is_read_only() -> bool:
	return read_only

func map_snapshot() -> Dictionary:
	if not _ready_complete or paused or not is_instance_valid(walker) or not is_instance_valid(terrain): return {}
	return {"context_id": "living:" + body_id + ":" + LivingSurface.GENERATION,
		"address": walker.location(), "forward": walker.forward, "phase": 0,
		"body_radius": float(terrain.surface.body.radius), "markers": [], "group_view": false,
		"sample": preload("res://ui/minimap/minimap_source.gd").sample_sphere.bind(terrain.surface)}


func set_paused(value: bool) -> void:
	super.set_paused(value)
	if is_instance_valid(ecosystem):
		ecosystem.paused = value
		if ecosystem.domestic != null: ecosystem.domestic.set_paused(value)
		for animal: Node in ecosystem.animals.values():
			animal.enabled = not value


func _process(delta: float) -> void:
	super._process(delta)
	if not _ready_complete or not is_instance_valid(ecosystem):
		return
	if ecosystem.fauna != null and not ecosystem.fauna.problem().is_empty() and fauna_error.is_empty(): _fauna_failed()
	var sample: Dictionary = adapter.sample(walker.location())
	hud.text = "VOXELVERSE · %s\nDurchmesser %.0f km · %s\n%.1f m erkundet · %d Pflanzen/Felsen · %d Tiere\nUmgebung %d/25 · nachgeladen %d · entladen %d%s" % [
		system.bodies[body_id].name, system.bodies[body_id].radius * 0.002, BIOME_NAMES.get(sample.biome, sample.biome),
		walker.traveled, ecosystem.instance_count() + int(is_instance_valid(tree)), ecosystem.animals.size() + int(is_instance_valid(creature)),
		ecosystem.patches.size(), ecosystem.loaded, ecosystem.unloaded,
		"\nNahgelände wird vorbereitet …" if walker.waiting_for_terrain else ""]


func _sample_water(point: Vector3) -> Dictionary:
	if not is_instance_valid(terrain):
		return {}
	var here: Dictionary = Cube.from_cartesian(body_id, Cube.global_position(point, terrain.origin), terrain.surface.body.radius)
	return {"water": adapter.sample(here).water, "depth": -here.height, "color": terrain.surface.terrain.material_slots.water_deep}


func _exit_tree() -> void:
	_clear_ecosystem()
	super._exit_tree()
