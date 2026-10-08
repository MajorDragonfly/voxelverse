extends RefCounted
const Model = preload("res://world/surface/campaign_population_state.gd")
const Surface = preload("res://creatures/editor/creature_sculpt_surface.gd")
const Species = preload("res://creatures/wildlife/species_assembly_factory_v7.gd")
const Preview = preload("res://creatures/runtime/creature_runtime_preview.gd")
const Population = preload("res://world/surface/campaign_population.gd")
const Encoding = preload("res://world/fauna/domestication/domestication_contract.gd")
var failures: Array[String] = []
var preview_script: Script = Preview

class PendingOwner extends Population:
	var attempted: Array[String] = []
	var accept: bool = false
	func _spawn_animal(record: Dictionary) -> bool:
		attempted.append(record.id)
		if accept: _skin_ready_id = ""
		return accept
	func _spawn_plant(_record: Dictionary) -> bool: return false

func run() -> Array[String]:
	for seed_value in [15838, 9871, 32549]:
		var design: Dictionary = Encoding.decode(Encoding.encode(Species.create_species(seed_value, Vector2i.ZERO, "grazer")))
		var frozen: Dictionary = design.duplicate(true)
		var reference: ArrayMesh = Surface.build_skin(design.duplicate(true))
		var job := Model.SkinBuild.new(design)
		if job.advance(0) or job.last_units != 0: failures.append("Zero budget performed skin work.")
		var slices: int = 0
		while job.mesh == null and slices < 10000:
			job.advance(2000, 257)
			if job.last_units > 257: failures.append("Skin unit bound exceeded.")
			slices += 1
		if job.mesh == null:
			failures.append("Skin never completed.")
			continue
		if slices <= 1: failures.append("Skin did not yield.")
		if design != frozen: failures.append("Skin preparation changed the frozen input body.")
		if job.mesh.surface_get_arrays(0) != reference.surface_get_arrays(0): failures.append("Resumed geometry differs from canonical skin.")
		for key in ["voxel_size", "voxel_count", "voxel_cells"]:
			if job.mesh.get_meta(key) != reference.get_meta(key): failures.append("Skin occupancy metadata differs: " + key)
		var cancelled := Model.SkinBuild.new(design)
		cancelled.advance(2000, 100)
		cancelled.cancel()
		if cancelled.advance(2000) or cancelled.mesh != null or not cancelled.design.is_empty(): failures.append("Cancelled skin published or retained its blueprint.")
		# Exercise the real owner port when installed in the isolated QA tree.
		if preview_script.has_method("remember_species_skin"):
			preview_script.call("remember_species_skin", design, job.mesh)
			if preview_script.call("cached_species_skin", design) != job.mesh: failures.append("Complete skin was not reused.")
	var owner := PendingOwner.new()
	var job := Model.SkinBuild.new(Species.create_species(15838, Vector2i.ZERO, "grazer"))
	owner._skin_job = job
	owner._skin_record = {"id":"prepared"}
	var candidates: Array[Dictionary] = [{"id":"other"}, {"id":"prepared"}, {"id":"later"}]
	var empty: Array[Dictionary] = []
	owner._spawn_candidates(candidates, empty)
	if owner.attempted.is_empty() or owner.attempted[0] != "prepared" or owner._animal_cursor != 1:
		failures.append("Deferred skin work was rotated away as a blocked placement.")
	owner._skin_job = null
	owner._skin_record = {}
	owner._skin_ready_id = "prepared"
	owner.accept = true
	owner.attempted.clear()
	candidates.reverse()
	owner._spawn_candidates(candidates, empty)
	if owner.attempted != ["prepared"] or not owner._skin_ready_id.is_empty(): failures.append("A completed skin lost its publication turn.")
	owner._skin_job = job
	owner._skin_record = {"id":"prepared"}
	owner._spawn_candidates(empty, empty)
	if not job.cancelled or owner._skin_job != null: failures.append("Candidate retirement retained deferred skin ownership.")
	owner.free()
	if failures.is_empty(): print("R33_02_SKIN_BUILD_PASSED")
	return failures
