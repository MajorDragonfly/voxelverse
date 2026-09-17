extends SceneTree

const Trace = preload("res://core/diagnostics/startup_trace.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var trace := Trace.new()
	if trace.snapshot(1000).status != "idle": failures.append("Idle trace is not empty.")
	trace.begin(1000)
	trace.phase("threaded_load", 2000)
	trace.phase("threaded_load", 2500)
	var context: Dictionary = {"seed": 42, "nested": {"id": "original"}}
	trace.set_context(context)
	context.nested.id = "modified"
	var loading: Dictionary = trace.snapshot(5000)
	if loading.total_ms != 4.0 or loading.last_phase != "threaded_load" or loading.segments.size() != 2:
		failures.append("In-flight timing or duplicate phase is incorrect.")
	if loading.segments[1].completed or loading.segments[1].duration_ms != 3.0:
		failures.append("In-flight segment was reported as completed.")
	loading.segments.clear()
	loading.context.nested.id = "caller"
	if trace.snapshot(5000).segments.size() != 2 or trace.snapshot(5000).context.nested.id != "original":
		failures.append("Diagnostic readers mutated the trace.")
	trace.phase("scene_instantiation", 5000)
	trace.finish("failed", "fixture failure", 8000)
	trace.finish("ready", "", 9000)
	trace.phase("unexpected", 10000)
	var finished: Dictionary = trace.snapshot(12000)
	var total: float = 0.0
	for segment in finished.segments: total += segment.duration_ms
	if finished.total_ms != 7.0 or total != 7.0 or finished.last_phase != "scene_instantiation" or finished.status != "failed":
		failures.append("Failure lost its last phase or completed timings kept growing.")
	trace.begin(20000)
	trace.finish("ready", "", 23000)
	var next: Dictionary = trace.snapshot(50000)
	if next.sequence != 2 or next.total_ms != 3.0 or next.segments.size() != 1 or not next.context.is_empty() or not next.error.is_empty():
		failures.append("Next load reused a previous failure, context or timing.")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("STARTUP_TRACE_PASSED")
	quit(0 if failures.is_empty() else 1)
