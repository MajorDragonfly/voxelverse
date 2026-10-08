extends SceneTree
const Atlas = preload("res://core/map/exploration_atlas.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Source = preload("res://ui/world_map/world_map_source.gd")
const Query = preload("res://ui/world_map/atlas_place_query.gd")
const Fit = preload("res://ui/world_map/atlas_fit_query.gd")
const Chart = preload("res://ui/world_map/atlas_chart.gd")
const Canvas = preload("res://ui/world_map/world_map_canvas.gd")
const Raster = preload("res://ui/minimap/minimap_terrain.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var atlas := Atlas.new()
	atlas.bind(Atlas.create("seam", Cube.MODE, 6371000.0))
	for longitude: float in [PI - 0.00001, -PI + 0.00001]:
		var visit: Dictionary = Cube.from_direction("seam", [sin(longitude), 0, cos(longitude)])
		atlas.reveal(visit)
		print("INT30_SEAM_KNOWN_CELL ",atlas.cell_for(visit)," ",atlas.known(visit))
	print("INT30_SEAM_FOG ",JSON.stringify(atlas.data.tiles))
	var fit := Fit.new()
	var inline_before: String = JSON.stringify(atlas.data)
	fit.begin(atlas)
	await _drain_fit(fit)
	_expect(fit.bounds.size.x < 250.0 and fit.bounds.size.y < 150.0, "Two seam visits fitted nearly the whole planet: " + str(fit.bounds))
	_expect(absf(absf(fit.bounds.get_center().x) - PI * 6371000.0) < 100, "Fit did not center the longitude seam")
	_expect(JSON.stringify(atlas.data) == inline_before, "Read-only fit mutated inline fog")
	print("INT30_SEAM_FIT ", JSON.stringify({"width_m":fit.bounds.size.x,"height_m":fit.bounds.size.y,"center_x":fit.bounds.get_center().x}))
	print("INT30_SEAM_CUTS ",fit._extents)
	var chart := Chart.new()
	chart.configure(Cube.address("seam",0,0,0),6371000.0)
	print("INT30_WRAP_PRECISION ",JSON.stringify({"engine":wrapf(PI-0.00001,-PI,PI),"map":Chart.wrap_exact(PI-0.00001,PI)}))
	for side: int in [-1,1]:
		var close_to_seam := Vector2(side * (PI * 6371000.0 - 150.0),0.0)
		chart.center = chart.clamp_center(close_to_seam)
		_expect(chart.center.distance_to(close_to_seam) < 2.0, "Map center snapped an asymmetric near-seam visit to the boundary")
		var address: Dictionary = chart.address_at(close_to_seam)
		_expect(chart.project(address).distance_to(close_to_seam) < 2.0, "Map chart lost near-seam position precision")
	chart.center = chart.clamp_center(fit.bounds.get_center())
	var fitted_radius: float = maxf(maxf(fit.bounds.size.x,fit.bounds.size.y)*0.6,64.0)
	for longitude: float in [PI-0.00001,-PI+0.00001]:
		var visit: Dictionary = Cube.from_direction("seam",[sin(longitude),0,cos(longitude)])
		var delta: Vector2 = chart.project(visit)-chart.center
		print("INT30_SEAM_VISIT_DELTA ",delta)
		_expect(absf(delta.x) <= fitted_radius + Atlas.CELL_M and absf(delta.y) <= fitted_radius + Atlas.CELL_M, "Fitted view lost an actual seam visit")
	var inline_bounds: Rect2 = fit.bounds
	_expect(atlas.checkpoint(), "Cannot checkpoint seam tiles")
	var paged_before: String = JSON.stringify(atlas.data)
	fit.begin(atlas)
	await _drain_fit(fit)
	_expect(fit.bounds == inline_bounds and JSON.stringify(atlas.data) == paged_before, "Fit lost archived cells or rewrote their root")
	fit.begin(atlas)
	fit.step()
	fit.cancel()
	_expect(JSON.stringify(atlas.data) == paged_before and not fit.active, "Cancelling fit erased shared tile rows")
	fit.begin(atlas)
	atlas.bind(Atlas.create("changed", Cube.MODE, 6371000.0))
	fit.step()
	_expect(fit.invalidated and not fit.active, "Fit retained another body's work")
	atlas.bind(Atlas.create("all-longitudes", Cube.MODE, 6371000.0))
	for longitude: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		atlas.reveal(Cube.from_direction("all-longitudes", [sin(longitude), 0, cos(longitude)]))
	fit.begin(atlas)
	await _drain_fit(fit)
	_expect(fit.bounds.size.x > PI * 6371000.0, "Seam shortcut hid broad exploration")
	# Dense supported inline tiles exercise read-only fit without a tiny
	# per-frame bit quota. Completion and bounded memory remain required.
	atlas.bind(Atlas.create("dense-fit", Cube.MODE, 6371000.0))
	for tile in range(128):
		var rows: Array = []
		rows.resize(32)
		rows.fill(4294967295)
		atlas.data.tiles["0:%d:0" % tile] = rows
	var dense_before: String = JSON.stringify(atlas.data)
	fit.begin(atlas)
	await _drain_fit(fit)
	_expect(fit.bounds.position.is_finite() and fit.bounds.size.is_finite() and JSON.stringify(atlas.data) == dense_before, "Dense fit lost bounds or changed exploration")
	# Archived census scans every page, retains four counts and no result list.
	atlas.bind(Atlas.create("types", Cube.MODE, 6371000.0))
	for i in range(1025):
		atlas.remember(Source._place("type-%d" % i, "Place %d" % i, "home" if i == 1024 else "nest", "species", "", true, Cube.address("types", 0, 0, 0)))
	var before: String = JSON.stringify(atlas.data)
	var census := Query.new()
	census.begin_census(atlas, func(p: Dictionary) -> bool: return p.id != "type-0")
	await _drain_query(census)
	_expect(census.counts == {"nest": 1023, "home": 1} and census.results.is_empty() and census.scanned == 1025, "Type census skipped archived pages or counted hidden places")
	var query := Query.new()
	query.begin(atlas, "", true, true, 0, func(_p: Dictionary) -> bool: return true, func(p: Dictionary) -> String: return p.name, "home")
	await _drain_query(query)
	_expect(query.results.size() == 1 and query.results[0].id == "type-1024", "Type filter did not find the last archived page")
	_expect(JSON.stringify(atlas.data) == before and atlas.places.store.cache.size() <= 96 and atlas.places.store.pages.size() <= 128, "Census/filter changed storage or exceeded caches")
	var canvas := Canvas.new()
	canvas.size = Vector2(600, 180)
	canvas.terrain = Raster.new()
	canvas.terrain.radius = 64
	canvas.places.assign([{"id": "invisible", "position": Vector2(80, 0)}])
	_expect(canvas._hit(canvas.screen_point(Vector2(80, 0))).is_empty(), "Letterbox selected an undrawn marker")
	canvas.places.assign([{"id": "visible", "position": Vector2.ZERO}])
	_expect(canvas._hit(canvas.screen_point(Vector2.ZERO)) == "visible", "Visible marker cannot be selected")
	canvas.ui_scale = 1.5
	_expect(not canvas.marker_visible(Vector2(220, 90)), "Scaled glyph crosses the texture boundary")
	canvas.free()
	print("INT30_WORLD_MAP_MODEL_CHECKS ", checks)
	if failures.is_empty(): print("INT30_WORLD_MAP_MODEL_OK")
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
func _drain_fit(query: RefCounted) -> void:
	for tick in range(10000):
		if not query.active: break
		var before: int = query.work
		var started: int = Time.get_ticks_usec()
		query.step()
		_expect(query.work - before <= Fit.WORK_PER_STEP, "Fit exceeded per-step work")
		_expect(not query.active or query.work - before == Fit.WORK_PER_STEP or Time.get_ticks_usec() - started >= Fit.BUDGET_USEC, "Fit yielded before using either safety or time budget")
		await process_frame
	_expect(not query.active and not query.failed and not query.invalidated, "Fit failed or exceeded bounded completion")
func _drain_query(query: RefCounted) -> void:
	for tick in range(10000):
		if not query.active: break
		var before: int = query.scanned
		var started: int = Time.get_ticks_usec()
		query.step()
		_expect(query.scanned - before <= Query.RECORDS_PER_STEP and query.results.size() <= 64, "Place query exceeded bounds")
		_expect(not query.active or query.scanned - before == Query.RECORDS_PER_STEP or Time.get_ticks_usec() - started >= Query.STEP_BUDGET_USEC, "Place query yielded before using either safety or time budget")
		await process_frame
	_expect(not query.active and not query.failed, "Place query did not complete")
func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
