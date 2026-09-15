extends Node
## Independent campaign child: does not own Environment, sun, shader or audio state.
## Group `campaign_weather`, snapshot() and weather_changed are the presentation port.
signal weather_changed(snapshot: Dictionary)
const Model = preload("res://world/weather/weather_model.gd")
const View = preload("res://world/weather/weather_view.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
@export var clouds_enabled: bool = true
@export var precipitation_enabled: bool = true
var _view: Node3D
var _snapshot: Dictionary = {}
var _body_id: String = ""
var _preview_condition: String = ""
var _probe_elapsed: float = 1.0
var _notice_elapsed: float = 1.0
var _covered: bool = false
var _underwater: bool = false

func _ready() -> void:
	process_priority = 110 # Camera-owned underwater presentation samples first.
	add_to_group(&"campaign_weather")
	_view = View.new()
	_view.name = "WeatherView"
	add_child(_view)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--weather-preview="):
			_preview_condition = argument.trim_prefix("--weather-preview=")
			if Model.preset(_preview_condition).is_empty(): _preview_condition = ""

func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func _available() -> bool:
	var host: Node = get_parent()
	var flow: Node = get_node("/root/SessionFlow")
	return bool(host.get("world_initialized")) and not flow.loading and Space.adapter(self) != null

func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not _available() or camera == null:
		_view.hide_weather()
		_snapshot = {}
		return
	var state: Node = get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	if _body_id != str(body.id):
		_body_id = str(body.id)
		_view.configure(int(body.seed))
		_probe_elapsed = 1.0
		_covered = true
	var previous_condition: String = str(_snapshot.get("condition", ""))
	# All current campaign bodies remain safe; no inference of hazards from color,
	# seed or planet index. Permanent home designation belongs to WEATHER-02.
	_snapshot = Model.sample(_body_id, int(body.seed), float(state.campaign.data.elapsed_seconds))
	if not _preview_condition.is_empty():
		_snapshot.merge(Model.preset(_preview_condition), true)
		_snapshot.preview = true
	_view.clouds_enabled = clouds_enabled
	_view.precipitation_enabled = precipitation_enabled
	_view.position_at(camera.global_position, Space.up(self, camera.global_position))
	_view.present(_snapshot, _underwater, _covered)
	_notice_elapsed += delta
	if previous_condition != str(_snapshot.condition) or _notice_elapsed >= 0.25:
		_notice_elapsed = 0.0
		weather_changed.emit(snapshot())

func _physics_process(delta: float) -> void:
	if not _available() or _snapshot.is_empty(): return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	_view.position_at(camera.global_position, Space.up(self, camera.global_position))
	var water: Dictionary = Space.sample(self, camera.global_position)
	_underwater = bool(water.water) and float(water.altitude) < float(water.water_level)
	_probe_elapsed += delta
	if _probe_elapsed < 0.5: return
	_probe_elapsed = 0.0
	var excluded: Array[RID] = []
	var player: Node = get_parent().get("player")
	if player is CollisionObject3D: excluded.append(player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,
		camera.global_position + Space.up(self, camera.global_position) * 22.0, 1 | 2 | 4)
	query.exclude = excluded
	_covered = not camera.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if not _underwater and not _covered and float(_snapshot.precipitation) > 0.0:
		_view.probe_cover(excluded)
