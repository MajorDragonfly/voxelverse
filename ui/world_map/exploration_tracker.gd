extends Node
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Source = preload("res://ui/world_map/world_map_source.gd")
const MiniSource = preload("res://ui/minimap/minimap_source.gd")
const Surface = preload("res://core/map/surface_map_projection.gd")
var player: Node3D
var lab: Node3D
var atlas := Atlas.new()
var snapshot: Dictionary = {}
var _record: Dictionary = {}
var _timer: float = 0.0
var _last_cells: Array[Vector3i] = []
var _places_dirty: bool = true
var _place_timer: float = 0.0
var problem: String = ""
# Stable presentation result; detailed validator diagnostics remain in problem.
var problem_code: String = ""

func _ready() -> void:
	name = "ExplorationTracker"
	add_to_group(&"exploration_tracker")
	atlas.storage_failed.connect(_storage_failed)
	var saves := get_node("/root/SaveGameService")
	saves.game_loaded.connect(invalidate)
	saves.save_started.connect(func(_path: String) -> void:
		if not is_instance_valid(lab): update_exploration(true))
	get_node("/root/GameState").world_seed_changed.connect(invalidate)
	get_node("/root/ProgressionService").behavior_changed.connect(func() -> void: _places_dirty = true)

func invalidate(_value: Variant = null) -> void:
	problem = ""
	problem_code = ""
	_record = {}
	snapshot = {}
	atlas.data = {}
	atlas.last_error = ""
	problem = ""
	_last_cells.clear()
	_timer = 0
	_places_dirty = true

func _process(delta: float) -> void:
	if get_tree().paused: return
	_timer -= delta
	_place_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		update_exploration()

func update_exploration(allow_paused: bool = false) -> void:
	if get_tree().paused and not allow_paused: return
	problem = ""
	problem_code = ""
	var value: Dictionary = MiniSource.laboratory_snapshot(lab) if is_instance_valid(lab) else Source.campaign_snapshot(player, get_tree())
	if value.is_empty():
		snapshot = {}
		return
	if is_instance_valid(lab): value["explorers"] = [value.address]
	var records: Dictionary
	var key: String
	if is_instance_valid(lab):
		if (lab.map_is_read_only() if lab.has_method("map_is_read_only") else lab._save_read_only): return
		records = lab.map_atlases
		key = value.address.body_id
	else:
		var state := get_node("/root/GameState")
		records = state.get_current_body_record()
		key = "exploration_atlas"
	if not records.has(key):
		if is_instance_valid(lab) and records.size() >= 256:
			problem_code = "atlas.collection_full"
			problem = "Die Sammlung erkundeter Himmelskörper ist voll."
			snapshot = {}
			return
		records[key] = Atlas.create(value.address.body_id, value.address.mode, float(value.body_radius))
	var candidate: Variant = records[key]
	# Bind once per actual record instance; a loaded record can share body/seed.
	if not is_same(candidate, _record):
		problem = Atlas.validate(candidate, value.address.body_id)
		if not problem.is_empty():
			problem_code = "atlas.invalid_record"
			snapshot = {}
			return
		if candidate.mode != value.address.mode or float(candidate.radius) != float(value.body_radius):
			problem_code = "atlas.surface_mismatch"
			problem = "Karte und Oberfläche passen nicht zusammen."
			snapshot = {}
			return
		if not atlas.bind(candidate): snapshot = {}; return
		_record = candidate
		_last_cells.clear()
		_places_dirty = true
	snapshot = value
	if not atlas.last_error.is_empty(): return
	var cells: Array[Vector3i] = []
	for address: Dictionary in value.explorers:
		var cell: Vector3i = atlas.cell_for(address)
		cells.append(cell)
		if cell not in _last_cells: atlas.reveal(address)
	_last_cells = cells
	if not is_instance_valid(lab) and (_places_dirty or _place_timer <= 0):
		_places_dirty = false
		_place_timer = 3.0
		for place: Dictionary in Source.known_places(player, get_tree(), value):
			# Own home is known; friends require an actually explored location.
			if place.get("own", false) or atlas.known(place.get("address", {})): atlas.remember(place)

func _storage_failed(message: String) -> void:
	problem = message
	if is_instance_valid(lab):
		if lab.has_method("map_is_read_only"): lab.read_only = true
		else: lab._save_read_only = true
		lab.status.text = message
	else:
		# Existing save_started gate protects the last slot and its backup.
		get_node("/root/SaveGameService")._write_blocked = true
		if is_instance_valid(player) and player.has_method("show_gameplay_message"):
			player.show_gameplay_message(message)
