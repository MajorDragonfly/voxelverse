extends "res://tests/village_work_observation_test.gd"
## CPU microbenchmark for synchronous observation copies, not gameplay/FPS.
const BASELINE: String = "ea900f2e09946660694a9e59399b4680a5655a85"
const BATCH: int = 500
const SAMPLES: int = 15

func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	var cases: Array = []
	for population in [3, 6]:
		for history in [0, 8, 32]:
			cases.append(measure(benchmark_fixture(population, history), "ordinary_work"))
	var construction: Dictionary = benchmark_fixture(6, 32)
	var v: Dictionary = construction.village
	v.project = Housing.site(v, "pen", [10, 0, 0], v.husbandry.pens.size())
	v.project.merge({"progress": 0.0, "materials": Housing.COSTS.pen.duplicate(), "delivered_materials": {"wood": 0, "fiber": 0}})
	cases.append(measure(construction, "construction"))
	var inbox: Dictionary = benchmark_fixture(6, 32)
	for index in range(48):
		v = inbox.village
		_expect(Economy.receive_milk(v, {"schema": 1, "source_id": "inbox-" + str(index), "body_id": v.body_id,
			"faction_id": v.faction_id, "sequence": 1, "amount": 1, "position": v.anchor.duplicate(true)}).is_empty(), "Inbox setup failed.")
	cases.append(measure(inbox, "full_inbox"))
	var report: Dictionary = {"schema": 1, "benchmark": "village_work_observation_snapshot", "baseline_commit": BASELINE,
		"passed": failures.is_empty(), "failures": failures, "engine": Engine.get_version_info().string,
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "logical_processors": OS.get_processor_count(),
		"renderer": "headless", "warmup_copies_per_implementation": 200, "copies_per_sample": BATCH, "samples": SAMPLES,
		"timing_scope": "Snapshot creation and destruction only; each sample is mean microseconds per copy. Implementations alternate order.",
		"count_scope": "Distinct newly copied Dictionary/Array containers reachable from the snapshot; excludes transient helper arrays and shared containers. Not allocator/RSS profiling.",
		"cases": cases}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = "user://village_work_snapshot_measurements.json"
	if "--report" in args and args.find("--report") + 1 < args.size(): path = args[args.find("--report") + 1]
	var file := FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Could not write benchmark report: " + path)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("VILLAGE_WORK_SNAPSHOT_BENCHMARK ", JSON.stringify(report))
	await finish()

func benchmark_fixture(population: int, history: int) -> Dictionary:
	var f: Dictionary = fixture()
	var v: Dictionary = f.village
	if population > 3:
		for index in range(3): v.housing.homes.append(Housing.site(v, "hut", [4 + index * 4, 0, -4], index))
		v.huts = 3
		v.stock.water = 18
		v.economy.produced.water = 26
		for index in range(population - 3):
			_expect(Housing.tick(v, Housing.GROW_SECONDS), "Growth fixture could not advance.")
			_expect(not Housing.add_resident(v, Vector3.ZERO).is_empty(), "Growth fixture could not admit a resident.")
	add_history(f, history)
	v.members[0].order = "wood"
	v.members[0].profession = "forester"
	return f

func measure(f: Dictionary, label: String) -> Dictionary:
	var v: Dictionary = f.village
	var actor: Dictionary = v.members[0]
	_expect(Tribe.validate(v, f.body, f.campaign).is_empty(), "Invalid benchmark fixture: " + Tribe.validate(v, f.body, f.campaign))
	var old: Dictionary = baseline_snapshot(v)
	var current: Dictionary = Work.snapshot(v, actor)
	_expect(old == v and current == v, "Benchmark copy changed data.")
	var old_containers: int = copied_containers(v, old, [])
	var current_containers: int = copied_containers(v, current, [])
	for index in range(200):
		baseline_snapshot(v)
		Work.snapshot(v, actor)
	var old_us: Array[float] = []
	var current_us: Array[float] = []
	for index in range(SAMPLES):
		for optimized in ([false, true] if index % 2 == 0 else [true, false]):
			var start: int = Time.get_ticks_usec()
			for iteration in range(BATCH):
				if optimized: Work.snapshot(v, actor)
				else: baseline_snapshot(v)
			var elapsed: float = float(Time.get_ticks_usec() - start) / BATCH
			if optimized: current_us.append(elapsed)
			else: old_us.append(elapsed)
	var old_median: float = percentile(old_us, 0.5)
	var current_median: float = percentile(current_us, 0.5)
	return {"scenario": label, "residents": v.members.size(), "production_records": v.husbandry.records.size(),
		"pens": v.husbandry.pens.size(), "homes": v.housing.homes.size(), "inbox_rows": v.economy.incoming.size(),
		"baseline_copied_containers": old_containers, "current_copied_containers": current_containers,
		"baseline_us_samples": old_us, "current_us_samples": current_us,
		"baseline_us_p50": old_median, "current_us_p50": current_median,
		"baseline_us_p95": percentile(old_us, 0.95), "current_us_p95": percentile(current_us, 0.95),
		"median_reduction_percent": 100.0 * (1.0 - current_median / old_median)}

func percentile(values: Array[float], fraction: float) -> float:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]

func copied_containers(source: Variant, copy: Variant, seen: Array) -> int:
	if not source is Dictionary and not source is Array: return 0
	if is_same(source, copy) or seen.any(func(item: Variant) -> bool: return is_same(item, copy)): return 0
	seen.append(copy)
	var count: int = 1
	if source is Dictionary:
		for key in source: count += copied_containers(source[key], copy[key], seen)
	else:
		for index in range(source.size()): count += copied_containers(source[index], copy[index], seen)
	return count

# Exact pre-change implementation from BASELINE, kept only in this benchmark.
func baseline_snapshot(data: Dictionary) -> Dictionary:
	var before: Dictionary = data.duplicate()
	for key in ["members", "stock", "deposits", "project", "housing", "husbandry"]:
		before[key] = data[key].duplicate(true)
	before.economy = data.economy.duplicate()
	before.economy.incoming = data.economy.incoming.duplicate(true)
	before.economy.stations = data.economy.stations.duplicate(true)
	return before
