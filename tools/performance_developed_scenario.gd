extends "res://core/diagnostics/spherical_gameplay_probe.gd"
const Recorder = preload("res://tools/performance_developed_recorder.gd")
var recorder: Node
var config: Dictionary
var config_path: String
var process_key: String = "main"
var cycle: int = 0

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var option: int = args.find("--performance-config")
	if option < 0 or option + 1 >= args.size():
		push_error("Missing developed performance config.")
		await preload("res://core/runtime_shutdown.gd").finish(tree, 1)
		return
	config_path = args[option + 1]
	config = Atomic.parse_dictionary(FileAccess.get_file_as_string(config_path))
	option = args.find("--performance-process")
	if option >= 0 and option + 1 < args.size(): process_key = args[option + 1]
	option = args.find("--performance-cycle")
	if option >= 0 and option + 1 < args.size(): cycle = int(args[option + 1])
	production_kind = str(config.recipe.production)
	Engine.max_fps = int(config.recipe.frame_cap)
	tree.root.size = Vector2i(config.recipe.resolution[0], config.recipe.resolution[1])
	tree.root.content_scale_size = tree.root.size
	recorder = Recorder.new()
	tree.root.add_child(recorder)
	if not recorder.configure(config, process_key):
		await preload("res://core/runtime_shutdown.gd").finish(tree, 1)
		return
	var repetitions: int = int(config.recipe.cycles) if process_key == "main" else 1
	for index in range(repetitions):
		if process_key == "main": cycle = index
		recorder.cycle = cycle
		recorder.begin("process_start")
		await super._run()
		if not failures.is_empty(): break
	var passed: bool = recorder.finish(failures)
	await preload("res://core/runtime_shutdown.gd").finish(tree, 0 if passed else 1)

func _stage(label: String) -> void:
	if is_instance_valid(recorder): recorder.begin(label)
	super._stage(label)

func _open(path: String, pause_when_ready: bool = false) -> void:
	recorder.begin("load_paused_checkpoint" if pause_when_ready else "cold_world")
	await super._open(path, pause_when_ready)
	recorder.begin("checkpoint_ready" if pause_when_ready else "near_village")

func _finish() -> void:
	# The inherited scenario has completed one cycle. Only the outer driver
	# closes files/processes, so failures cannot accidentally skip the report.
	recorder.end()
	for failure in failures: push_error(failure)

func _run_fresh_process(arguments: PackedStringArray, output: Array) -> int:
	var kind: String = "far_restart" if "--animal-travel-restart" in arguments else "home_restart"
	var child_key: String = "cycle_%d_%s" % [cycle, kind]
	var command := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy"])
	if config.recipe.renderer == "headless": command.append("--headless")
	else: command.append_array(["--rendering-method", str(config.recipe.renderer)])
	command.append_array(["--script", "res://tools/performance_developed_probe.gd", "--"])
	# The normal --sphere-gameplay-smoke entry creates its own probe from the
	# frontend. This script already owns one; carry only the restart selector.
	command.append("--animal-travel-restart" if kind == "far_restart" else "--sphere-gameplay-restart")
	if production_kind == "eggs": command.append("--egg-production")
	command.append_array(["--performance-config", config_path, "--performance-process", child_key,
		"--performance-cycle", str(cycle)])
	recorder.end()
	var started: int = Time.get_ticks_usec()
	var code: int = super._run_fresh_process(command, output)
	var elapsed_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var log_file := FileAccess.open(str(config.output).path_join(child_key + "-engine.log"), FileAccess.WRITE)
	if log_file == null: failures.append("Cannot preserve the fresh-process log: " + child_key)
	else:
		log_file.store_string("\n".join(PackedStringArray(output)))
		log_file.close()
	recorder.child_process(child_key, code, elapsed_ms)
	recorder.begin(kind + "_completed")
	return code
