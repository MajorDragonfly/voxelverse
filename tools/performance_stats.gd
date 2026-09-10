extends RefCounted
## Nearest-rank p95/p99; ordinary median. Empty/unavailable is null, never 0 FPS.
static func distribution(values: Array) -> Variant:
	if values.is_empty(): return null
	var ordered: Array = values.duplicate()
	ordered.sort()
	var count: int = ordered.size()
	var middle: int = count / 2
	return {"count": count, "median": (ordered[middle - 1] + ordered[middle]) / 2.0 if count % 2 == 0 else ordered[middle],
		"p95": ordered[ceili(count * 0.95) - 1], "p99": ordered[ceili(count * 0.99) - 1], "max": ordered[-1]}

static func metric_notes() -> Dictionary:
	return {"frame_ms": "Wall-clock process-frame intervals, including physics, waits, probe cost and configured cap; not CPU busy time.",
		"process_monitor_ms": "Godot's coarse TIME_PROCESS monitor, repeated between refreshes; not independent per-frame CPU samples.",
		"physics_monitor_ms": "Godot's coarse TIME_PHYSICS_PROCESS monitor, repeated between refreshes.",
		"render_cpu_ms": "Viewport render CPU plus engine frame setup; excludes gameplay CPU. Null when headless.",
		"render_gpu_ms": "Godot viewport GPU timestamps; null when unavailable. Software rendering is not target hardware.",
		"render_memory_bytes": "Godot-reported rendering allocation, not measured physical VRAM residency; null when headless.",
		"static_bytes": "Godot static allocator, not total process RAM. Process RSS is sampled from the Godot process itself on Linux.",
		"terrain_upload_max_ms": "CPU upload/build submission wall time, not GPU transfer latency. Maxima are scene-lifetime counters.",
		"raw": "frames.csv contains every sampled frame; snapshots sample object/queue/memory state once per second."}

static func process_memory() -> Dictionary:
	var result := {"rss_bytes": null, "peak_rss_bytes": null}
	# Self resolves correctly even if /proc and OS process IDs use different
	# namespaces. Never look up an unrelated host process by a reused PID.
	if OS.get_name() != "Linux" or not FileAccess.file_exists("/proc/self/status"): return result
	var file := FileAccess.open("/proc/self/status", FileAccess.READ)
	if file == null: return result
	# procfs advertises a zero file length; read lines until actual EOF.
	while not file.eof_reached():
		var line: String = file.get_line()
		for pair in [["VmRSS:", "rss_bytes"], ["VmHWM:", "peak_rss_bytes"]]:
			if line.begins_with(pair[0]):
				var fields: PackedStringArray = line.substr(pair[0].length()).strip_edges().split(" ", false)
				if fields.size() >= 2 and fields[1] == "kB" and fields[0].is_valid_int():
					result[pair[1]] = fields[0].to_int() * 1024
	file.close()
	return result
