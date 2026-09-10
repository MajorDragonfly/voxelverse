extends SceneTree
## ARCH-02 isolated spherical fixtures; never instruments/mutates the live writer.
const Surface = preload("res://core/campaign/surface_context.gd")
const Cube = preload("res://world/space/cube_sphere.gd")
const Model = preload("res://world/surface/campaign_population_state.gd")
const Foraging = preload("res://world/resources/plants/foraging_state.gd")
const Store = preload("res://core/persistence/region_store.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Shutdown = preload("res://core/runtime_shutdown.gd")
var state: Node
var saves: Node
var failures: Array[String] = []
var stores: Dictionary = {}
var descriptors: Dictionary = {}
var pending: Array = []
var references: Array = []
var flush_ms: float = 0.0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: push_error("Expected performance config path."); await Shutdown.finish(self, 1); return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	state = root.get_node("GameState")
	saves = root.get_node("SaveGameService")
	saves.autosave_enabled = false
	state.set_process(false)
	# This observer is the same synchronous boundary used by campaign population.
	saves.save_started.connect(_flush_regions)
	var rows: Array = []
	for count in [1, 10, 100]:
		for regions in [0, 10, 1000]:
			stores.clear(); descriptors.clear(); pending.clear(); references.clear()
			var disk_before: int = _directory_bytes(Store.DIRECTORY)
			if saves.create_slot("ARCH-02 save fixture", config.recipe.seed).is_empty():
				failures.append(saves.last_error); break
			for index in range(count):
				var created: Dictionary = state.get_current_body() if index == 0 else state.campaign.ensure_body(config.recipe.seed, 20000 + index)
				if created.is_empty(): failures.append(state.campaign.last_error); break
				var body: Dictionary = state.campaign.body_record(created.id)
				var descriptor: Dictionary = Surface.descriptor(body)
				descriptors[body.id] = descriptor
				var store := Store.new()
				store.validate_value = _validate_region.bind(descriptor)
				stores[body.id] = store
				body.surface_population = {"schema": Model.PAGED_SCHEMA, "body_id": body.id, "storage": store.manifest()}
			if not failures.is_empty(): break
			var ids: Array = stores.keys()
			for index in range(regions):
				var id: String = ids[index % ids.size()]
				var descriptor: Dictionary = descriptors[id]
				var point: Dictionary = Cube.address(id, index % 6, -0.8 + (index / 6 % 100) * 0.016, -0.7 + (index / 600) * 0.1)
				point.radius = descriptor.radius
				var key: String = Model.cell(descriptor, point).id
				var plant_id: String = id + ":measurement-plant:" + str(index)
				var region := {"schema": 1, "key": key, "objects": {}, "plants": {}, "generated": true}
				region.plants[plant_id] = {"id": plant_id, "food_key": plant_id, "location": point,
					"food": {"remaining": 2.0, "regrow_at": 600.0}}
				pending.append([id, "r:" + key, region])
				references.append([id, "r:" + key, plant_id])
			# Measure first dirty commit separately: cache eviction and flush are real.
			var began: int = Time.get_ticks_usec()
			var ok: bool = saves.save_now()
			var dirty_save_ms: float = (Time.get_ticks_usec() - began) / 1000.0
			if not ok: failures.append(saves.last_error); break
			var first_flush: float = flush_ms
			var snapshot: Dictionary = saves._read_save(saves.save_path)
			var raw: Array = []
			for iteration in range(3):
				var sample: Dictionary = {"iteration": iteration}
				began = Time.get_ticks_usec()
				var copied: Dictionary = snapshot.duplicate(true)
				sample.snapshot_copy_ms = (Time.get_ticks_usec() - began) / 1000.0
				began = Time.get_ticks_usec()
				var problem: String = saves._validate_save(copied)
				sample.validation_ms = (Time.get_ticks_usec() - began) / 1000.0
				if not problem.is_empty(): failures.append(problem)
				began = Time.get_ticks_usec()
				var serialized: String = JSON.stringify(copied, "\t")
				sample.serialization_ms = (Time.get_ticks_usec() - began) / 1000.0
				var path: String = "user://arch02-io-%d.json" % iteration
				began = Time.get_ticks_usec()
				var error: Error = Atomic._write_text(path + ".tmp", serialized)
				var matches: bool = FileAccess.get_file_as_string(path + ".tmp") == serialized
				if error == OK and matches: error = DirAccess.rename_absolute(path + ".tmp", path)
				sample.write_verify_rename_ms = (Time.get_ticks_usec() - began) / 1000.0
				if error != OK or not matches: failures.append("Isolated I/O did not round-trip.")
				began = Time.get_ticks_usec()
				ok = saves.save_now()
				sample.save_total_with_history_ms = (Time.get_ticks_usec() - began) / 1000.0
				if not ok: failures.append(saves.last_error)
				began = Time.get_ticks_usec()
				ok = saves.load_now()
				sample.load_total_ms = (Time.get_ticks_usec() - began) / 1000.0
				if not ok: failures.append(saves.last_error)
				sample.save_bytes = serialized.to_utf8_buffer().size()
				raw.append(sample)
			_verify_regions(count)
			var cache_peak: int = 0
			var writes: int = 0
			var io_max: float = 0.0
			for store: RefCounted in stores.values():
				cache_peak = maxi(cache_peak, store.peak_cache)
				writes += store.writes
				io_max = maxf(io_max, store.max_io_usec / 1000.0)
			var row := {"bodies": count, "changed_regions_total": regions, "plants_per_region": 1,
				"new_region_blob_bytes": _directory_bytes(Store.DIRECTORY) - disk_before,
				"dirty_save_total_ms": dirty_save_ms, "dirty_region_flush_ms": first_flush,
				"cache_peak_per_body": cache_peak, "new_blob_writes": writes, "region_io_max_ms": io_max,
				"static_allocator_bytes": OS.get_static_memory_usage(), "raw": raw}
			rows.append(row)
			print("SAVE_SCALING_CASE ", JSON.stringify(row))
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	var report := {"protocol": 2, "recipe": config.recipe, "source": config.source,
		"godot": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(),
		"renderer": "headless" if DisplayServer.get_name() == "headless" else RenderingServer.get_current_rendering_method(),
		"user_data_dir": OS.get_user_data_dir(), "target_pc_acceptance": false, "measurements": rows,
		"passed": failures.is_empty() and rows.size() == 9, "failures": failures,
		"scope": "Minimal current-schema spherical bodies with one harvested-plant delta per changed region. Actual shared slot writer/history/loader and paged region store. No terrain, rendered scene, village or FPS claim.",
		"stage_note": "Copy, validation, JSON and I/O are isolated kernels on an actual snapshot, not additive instrumentation of save_now. Total dirty save includes region insertion, eviction and flush. Repeated total saves include slot history/backups; no disk-cache purge or fsync guarantee.",
		"region_note": "0/10/1000 changed regions TOTAL distributed over 1/10/100 bodies. All records are re-read using new store instances after load and checked against original food balances. Three raw repeats are not robust p95/p99 estimates."}
	saves.save_started.disconnect(_flush_regions)
	if Atomic.write(str(config.output).path_join("capture.json"), report, false) != OK: failures.append("Could not write save report.")
	for failure in failures: push_error(failure)
	await Shutdown.finish(self, 0 if failures.is_empty() else 1)

func _flush_regions(_path: String) -> void:
	var began: int = Time.get_ticks_usec()
	for entry in pending:
		if not stores[entry[0]].put(entry[1], entry[2]): failures.append(stores[entry[0]].last_error)
	pending.clear()
	for id in stores:
		var manifest: Dictionary = stores[id].checkpoint()
		if manifest.is_empty(): failures.append(stores[id].last_error)
		else: state.campaign.body_record(id).surface_population.storage = manifest
	flush_ms = (Time.get_ticks_usec() - began) / 1000.0

func _validate_region(_key: String, region: Dictionary, descriptor: Dictionary) -> String:
	var problem: String = Model.validate_region(region, descriptor)
	if not problem.is_empty(): return problem
	for plant in region.plants.values():
		problem = Foraging.validate({"schema": 1, "body_id": descriptor.id, "animals": {}, "plants": {plant.food_key: plant.food}}, descriptor.id)
		if not problem.is_empty(): return problem
	return ""

func _verify_regions(count: int) -> void:
	if state.campaign.data.bodies.size() != count: failures.append("Body count changed during save/load.")
	var readers: Dictionary = {}
	for id in stores:
		var reader := Store.new()
		if not reader.open(state.campaign.body_record(id).surface_population.storage): failures.append(reader.last_error)
		readers[id] = reader
	for entry in references:
		var region: Dictionary = readers[entry[0]].get_value(entry[1])
		if region.is_empty() or not region.plants.has(entry[2]) or region.plants[entry[2]].food != {"remaining": 2.0, "regrow_at": 600.0}:
			failures.append("Saved regional plant balance/identity was not preserved."); return

func _directory_bytes(path: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null: return 0
	var result: int = 0
	for name in directory.get_files():
		var file := FileAccess.open(path.path_join(name), FileAccess.READ)
		if file != null: result += file.get_length(); file.close()
	for name in directory.get_directories(): result += _directory_bytes(path.path_join(name))
	return result
