extends Node
## Independent campaign child: does not own Environment, sun, shader or audio state.
## Group `campaign_weather`, snapshot() and weather_changed are the presentation port.
signal weather_changed(snapshot: Dictionary)
const Climate = preload("res://world/weather/planet_climate.gd")
const Model = preload("res://world/weather/weather_model.gd")
const Regional = preload("res://world/weather/regional_weather.gd")
const View = preload("res://world/weather/weather_view.gd")
const StormNotice = preload("res://world/weather/storm_preview_notice.gd")
const ForecastPanel = preload("res://world/weather/forecast_panel.gd")
const Space = preload("res://world/surface/gameplay_space.gd")
const Assets = preload("res://world/visuals/scenery/authored_environment_assets.gd")
@export var clouds_enabled: bool = true
@export var precipitation_enabled: bool = true
var _view: Node3D
var _storm_notice: CanvasLayer
var _forecast_panel: CanvasLayer
var _snapshot: Dictionary = {}
var _body_id: String = ""
var _preview_condition: String = ""
var _probe_elapsed: float = 1.0
var _notice_elapsed: float = 1.0
var _forecast_elapsed: float = 1.0
var _covered: bool = false
var _underwater: bool = false
var _climate_sample: Dictionary = {}
var _forecast_context: Dictionary = {}
var _last_camera: Camera3D
var _vegetation_motion: bool = true

func _ready() -> void:
	process_priority = 110 # Camera-owned underwater presentation samples first.
	add_to_group(&"campaign_weather")
	var settings: Node = get_node_or_null("/root/DisplaySettings")
	if settings != null: apply_graphics(settings.graphics_values)
	_view = View.new()
	_view.name = "WeatherView"
	add_child(_view)
	_storm_notice = StormNotice.new()
	_storm_notice.name = "StormPreviewNotice"
	add_child(_storm_notice)
	_forecast_panel = ForecastPanel.new()
	_forecast_panel.name = "WeatherForecast"
	add_child(_forecast_panel)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--weather-preview="):
			set_preview_condition(argument.trim_prefix("--weather-preview="))

## Session-only diagnostic selection. Never stored in the campaign or climate.
func set_preview_condition(condition: String) -> void:
	_preview_condition = condition if Model.supports_preview(condition) else ""
	_forecast_elapsed = 1.0
	if is_instance_valid(_storm_notice): _storm_notice.present({}, null)
	if is_instance_valid(_forecast_panel): _forecast_panel.present({}, [], null)

func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func apply_graphics(values: Dictionary) -> void:
	_vegetation_motion = bool(values.get("vegetation_motion", true))
	Assets.set_weather_motion(_snapshot, _campaign_clock(), _vegetation_motion)

func _campaign_clock() -> float:
	var state: Node = get_node_or_null("/root/GameState")
	return float(state.campaign.data.elapsed_seconds) if state != null and not state.campaign.data.is_empty() else 0.0

func forecast() -> Array[Dictionary]:
	if _snapshot.is_empty() or _forecast_context.is_empty(): return []
	if bool(_snapshot.get("preview", false)): return []
	return Regional.forecast(_body_id, int(_snapshot.seed), float(_snapshot.elapsed_seconds),
		_forecast_context.address, float(_forecast_context.radius), _forecast_context.climate)

func _available() -> bool:
	var host: Node = get_parent()
	var flow: Node = get_node("/root/SessionFlow")
	return bool(host.get("world_initialized")) and not flow.loading and Space.adapter(self) != null

func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not _available() or camera == null:
		_view.hide_weather()
		_snapshot = {}
		Assets.set_weather_motion({}, _campaign_clock(), false)
		_forecast_context = {}
		_forecast_elapsed = 1.0
		_storm_notice.present({}, null)
		_forecast_panel.present({}, [], null)
		return
	var state: Node = get_node("/root/GameState")
	var body: Dictionary = state.get_current_body_record()
	if _body_id != str(body.id):
		_body_id = str(body.id)
		_view.configure(int(body.seed))
		_probe_elapsed = 1.0
		_forecast_elapsed = 1.0
		_covered = true
		_climate_sample = Space.sample(self, camera.global_position)
	if camera != _last_camera:
		_last_camera = camera
		_probe_elapsed = 1.0
		_covered = true
		_view.invalidate_cover()
		_forecast_elapsed = 1.0
	var previous_condition: String = str(_snapshot.get("condition", ""))
	var previous_storm_phase: String = str(_snapshot.get("storm_phase", ""))
	var previous_clock: float = float(_snapshot.get("elapsed_seconds", 0.0))
	# Combine saved body climate with local biome samples; never infer hazards.
	var adapter: RefCounted = Space.adapter(self)
	var climate: Dictionary = _climate_sample.duplicate()
	climate.atmosphere = adapter.terrain.surface.body.get("atmosphere", "temperate")
	if body.has(Climate.FIELD): climate[Climate.FIELD] = body[Climate.FIELD].duplicate(true)
	var address: Dictionary = Space.address(self, camera.global_position)
	var radius: float = float(adapter.terrain.surface.body.radius)
	_snapshot = Regional.sample(_body_id, int(body.seed), float(state.campaign.data.elapsed_seconds), address, radius, climate)
	if _snapshot.is_empty():
		Assets.set_weather_motion({}, _campaign_clock(), false)
		_forecast_context = {}
		_forecast_elapsed = 1.0
		_view.hide_weather()
		_storm_notice.present({}, null)
		_forecast_panel.present({}, [], null)
		return
	_forecast_context = {"address": address, "radius": radius, "climate": climate}
	# Refresh immediately on a warning/entry/decay or a loaded clock rewind.
	# The ordinary one-second cadence must not leave stale windows on those edges.
	if previous_storm_phase != str(_snapshot.get("storm_phase", "")) or float(_snapshot.elapsed_seconds) < previous_clock:
		_forecast_elapsed = 1.0
	if not _preview_condition.is_empty():
		_snapshot = Regional.preview(_snapshot, _preview_condition)
	Assets.set_weather_motion(_snapshot, _campaign_clock(), _vegetation_motion)
	_snapshot.sheltered = _covered
	_snapshot.underwater = _underwater
	_view.clouds_enabled = clouds_enabled
	_view.precipitation_enabled = precipitation_enabled
	_view.position_at(camera.global_position, Space.up(self, camera.global_position))
	_view.present(_snapshot, _underwater, _covered)
	var player: Node = get_parent().get("player")
	_storm_notice.present(_snapshot, player)
	_forecast_elapsed += delta
	if _forecast_elapsed >= 1.0 or _forecast_panel._player != player:
		_forecast_elapsed = 0.0
		_forecast_panel.present(_snapshot, forecast(), player)
	else:
		_forecast_panel.present_current(_snapshot, player)
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
	_climate_sample = water
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
	if not _underwater and not _covered and maxf(float(_snapshot.precipitation), float(_snapshot.get("storm_particle_intensity", 0.0))) > 0.0:
		_view.probe_cover(excluded)
