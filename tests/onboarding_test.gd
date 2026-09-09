extends SceneTree

const Progress = preload("res://core/onboarding_progress.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := Progress.new()
	_expect(model.current_step().is_empty(), "Legacy/default progress unexpectedly starts a tutorial.")
	model.reset(true)
	_expect(not model.record("unknown") and not model.record("move", NAN) and not model.record("move", -1), "Invalid evidence completed a step.")
	model.record("move", 1.25)
	model.record("jump")
	model.record("look", 0.2)
	var restored := Progress.new()
	restored.import_state(Atomic.parse_dictionary(JSON.stringify(model.export_state())))
	_expect(is_equal_approx(restored.amount("move"), 1.25) and restored.done("jump") and restored.current_step() == "look", "Partial and out-of-order progress was not restored.")
	restored.record("look", 0.4)
	_expect(restored.current_step() == "move" and not restored.done("move"), "Partial walking was treated as completed.")
	restored.skip()
	var skipped: Dictionary = restored.export_state()
	_expect(not restored.record("inspect") and restored.export_state() == skipped, "Skipped tutorial accepted new evidence.")
	restored.reset(true)
	for step in Progress.STEPS:
		restored.record(step, 1000)
	_expect(restored.completed_count() == 4 and restored.current_step().is_empty(), "Finished tutorial is still active.")
	var future: Dictionary = {"schema": 99, "future_steps": ["preserve me"]}
	restored.import_state(future)
	restored.skip()
	_expect(not restored.supported() and not restored.record("jump") and restored.export_state() == future, "Future optional progress was modified.")
	restored.import_state({"schema": 1, "skipped": false, "progress": {"look": "invalid", "move": INF, "jump": -3}})
	_expect(restored.completed_count() == 0, "Malformed progress incorrectly completed tasks.")
	restored.import_state({"schema": [], "progress": {}})
	_expect(restored.current_step().is_empty(), "Malformed optional version started an introduction.")
	var saves: Node = root.get_node("SaveGameService")
	saves.session_managed = true
	saves.autosave_enabled = false
	var original: String = saves.create_slot("Einführung", 15838)
	_expect(saves.guidance.current_step() == "look", "New adventure did not enable the guide.")
	saves.guidance.record("look", 0.25)
	saves.guidance.record("move", 1.75)
	saves.guidance.record("jump")
	_expect(saves.save_now(), "Could not save partial tutorial progress.")
	var partial: Dictionary = saves.guidance.export_state()
	var original_bytes: String = FileAccess.get_file_as_string(original)
	saves.guidance.reset(true)
	_expect(saves.load_now() and saves.guidance.export_state() == partial, "Save/load did not resume partial tutorial progress.")
	saves.session_active = false
	var copied: String = saves.duplicate_slot(original)
	_expect(saves.select_slot(copied) and saves.guidance.export_state() == partial, "Copy lost tutorial progress.")
	saves.guidance.skip()
	_expect(saves.save_now(), "Could not save skipped introduction.")
	_expect(FileAccess.get_file_as_string(original) == original_bytes, "Skipping in a copy changed the original.")
	_expect(saves.load_now() and saves.guidance.current_step().is_empty(), "Skipped state reappeared after loading.")
	saves.session_active = false
	var history: Array = saves.list_slot_history(copied)
	var recovered: String = saves.restore_slot_copy(copied, history[0].source)
	_expect(saves.select_slot(recovered) and saves.guidance.export_state() == partial, "Recovery did not restore the selected tutorial state.")
	var legacy: Dictionary = Atomic.parse_dictionary(original_bytes)
	legacy.erase("onboarding")
	Atomic.write(original, legacy, false)
	_expect(saves.select_slot(original) and saves.guidance.current_step().is_empty(), "Old save was forced through the tutorial.")
	legacy.onboarding = future
	Atomic.write(original, legacy, false)
	_expect(saves.load_now() and saves.save_now(), "Future optional guide data blocked the campaign.")
	_expect(Atomic.parse_dictionary(FileAccess.get_file_as_string(original)).onboarding == Atomic.parse_dictionary(JSON.stringify(future)), "Saving discarded future guide data.")
	var next: String = saves.create_slot("Neues Abenteuer", 23757)
	_expect(not next.is_empty() and saves.guidance.completed_count() == 0 and saves.guidance.current_step() == "look", "New adventure inherited old tutorial progress.")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("ONBOARDING_PASSED: partial progress, any order, skip, restart, save/load, independent copies, selected recovery, legacy and future guide data.")
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
