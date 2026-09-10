extends SceneTree
const Catalog = preload("res://world/fauna/domestication/planet_fauna_catalog.gd")
const Traits = preload("res://world/fauna/domestication/domestication_contract.gd")
const Evidence = preload("res://world/fauna/domestication/domestic_body_evidence.gd")
const Checks = preload("res://tests/domestic_surface_catalog_test.gd")
const Planner = preload("res://world/fauna/domestication/domestic_surface_planner.gd")
const Anatomy = preload("res://creatures/editor/creature_anatomy.gd")
const Suitability = preload("res://ui/discovery/animal_suitability.gd")
const Taming = preload("res://world/domestication/d1_taming_policy.gd")
const Records = preload("res://core/discovery/discovery_records.gd")
var failures: Array[String] = []
var measurements: Array = []

class ActorStub extends Node:
	var catalog_species: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("SaveGameService").autosave_enabled = false
	capacity_check()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/egg_species_legacy.json"))
	expect(fixture.source == "905e524003c5f782f7b7daab09f0e23a1b632756", "Missing pre-ARCH-21 source attribution")
	for case: Dictionary in fixture.cases:
		var body: Dictionary = case.body
		var old: Dictionary = case.catalog.duplicate(true)
		var source_hash: String = signature(old)
		expect(Catalog.validate(old, body).is_empty(), "Pre-extension catalog no longer loads")
		# Frozen source bodies/evidence came from the previous executable.
		var regenerated: Dictionary = Catalog.create(body)
		for i in range(3): expect(signature(regenerated.species[i].blueprint) == signature(old.species[i].blueprint), "Old generated blueprint changed")
		var surface := Checks.FlatSphere.new(body)
		var search := Planner.new()
		search.begin(surface, old)
		while old.habitat_status == "pending": search.step(old, 4096, 0)
		old.habitats[0].generation = 7
		old.habitats[0].replacement_at = 5432.0
		old.habitats[0].food_state = {"schema": 1, "remaining": 2.0, "regrow_remaining": 17.0}
		# Maximum old habitat collection: adding the fourth species must retain
		# all 24 records, including multiple occurrences of one species.
		var full: Dictionary = old.duplicate(true)
		while full.habitats.size() < 24:
			var h: Dictionary = full.habitats[0].duplicate(true)
			h.key = "surface1:old-extra:%d" % full.habitats.size()
			full.habitats.append(h)
		var extended: Dictionary = Catalog.upgrade_surface(full, body)
		var extra := Planner.new()
		extra.begin(surface, extended)
		while extended.habitat_status == "pending": extra.step(extended, 4096, 0)
		expect(extended.habitats.size() == 25 and extended.habitat_status == "ready" and Catalog.validate(extended, body).is_empty(), "Full old habitat collection lost a role or record")
		expect(signature(extended.habitats.slice(0, 24)) == signature(full.habitats), "Full old habitat collection was rewritten")
		var before: String = signature(old)
		var upgraded: Dictionary = Catalog.upgrade_surface(old, body)
		expect(not upgraded.is_empty(), "Upgrade failed: " + Catalog.validate(old, body))
		if upgraded.is_empty(): continue
		expect(signature(old) == before, "Upgrade mutated the original catalog")
		expect(upgraded.schema == 4 and upgraded.role_policy == 2 and upgraded.species.size() == 4, "Missing explicit four-species revision")
		expect(signature(upgraded.species.slice(0, 3)) == signature(old.species), "Existing species, design IDs or evidence were replaced")
		expect(signature(upgraded.habitats) == signature(old.habitats), "Existing habitat identities/food/lifecycle were replaced")
		expect(signature(Catalog.upgrade_surface(upgraded, body)) == signature(upgraded), "Repeated upgrade changed the catalog")
		var partial := Planner.new()
		partial.begin(surface, upgraded)
		partial.step(upgraded, 7, 0)
		var resumed: Dictionary = JSON.parse_string(JSON.stringify(upgraded))
		var loaded := Planner.new()
		loaded.begin(surface, resumed)
		while resumed.habitat_status == "pending": loaded.step(resumed, 8, 0)
		expect(resumed.habitat_status == "ready" and resumed.habitats.size() == 4, "Fourth reachable habitat missing after search restart")
		expect(signature(resumed.habitats.slice(0, 3)) == signature(old.habitats), "Search modified earlier habitats")
		var egg: Dictionary = resumed.species[3]
		expect(Taming.evaluate(egg.domestication, "plant").eligible and Taming.evaluate(egg.domestication, "plant").food_allowed, "Existing D2 resolver rejected egg role")
		var egg_before: String = signature(egg.blueprint)
		Evidence.confirm(egg, root)
		expect(Evidence.approved(egg), "Generated two-legged body rejected: " + str(egg.body_evidence.errors))
		expect(egg.body_evidence.body.authored_leg_count == 2 and egg.body_evidence.rest.leg_count == 2, "Egg species is not a biped")
		expect(signature(egg.blueprint) == egg_before and Catalog.validate(resumed, body).is_empty(), "Evidence changed design or invalidated catalog: " + Catalog.validate(resumed, body) + " preserved=" + str(signature(egg.blueprint) == egg_before))
		expect(not Evidence.assess(egg.body_evidence.body, egg.body_evidence.rest, "work").is_empty(), "Biped approval weakened mount/load-bearing policy")
		var one_foot: Dictionary = egg.body_evidence.rest.duplicate(true)
		one_foot.feet.remove_at(1); one_foot.leg_count = 1
		expect(not Evidence.assess(egg.body_evidence.body, one_foot, "eggs").is_empty(), "One-foot stance accepted")
		var misplaced: Dictionary = egg.duplicate(true)
		misplaced.erase("body_evidence")
		var design: Dictionary = Traits.decode(misplaced.blueprint)
		for part: Dictionary in design.parts:
			if part.category == "legs": part.anchor_t = 0.95
		Anatomy.rebind_all_parts(design)
		misplaced.blueprint = Traits.encode(design)
		Evidence.confirm(misplaced, root)
		expect(not Evidence.approved(misplaced), "Legs behind the body accepted")
		# Retain the original plane-to-sphere archive and old body fingerprints.
		var migrated: Dictionary = old.duplicate(true)
		migrated.schema = 3
		migrated.migration_source = {"schema": 1, "catalog": regenerated}
		var copy: Dictionary = Catalog.upgrade_surface(migrated, body)
		expect(not copy.is_empty() and signature(copy.migration_source) == signature(migrated.migration_source), "Planar archive changed during additive upgrade")
		# Future policy/evidence/profile revisions must reach SaveService's
		# existing no-backup-fallback guard through has_unsupported.
		for field in ["schema", "role_policy"]:
			var future: Dictionary = resumed.duplicate(true)
			future[field] = 99
			expect(Catalog.has_unsupported(future) and Catalog.upgrade_surface(future, body).is_empty(), "Future revision migrated or accepted: " + field)
		var collision: Dictionary = Catalog.upgrade_surface(old, body, {int(egg.species_seed): true})
		expect(collision.species[3].species_seed == int(egg.species_seed) + 1, "Existing discovered seed collided")
		var scan := {"scan": {"version": 1, "complete": true}, "journal": Records.observation(Traits.decode(egg.blueprint), "Prüfplanet")}
		expect(Suitability.read(scan, Traits) == egg.domestication and Suitability.describe(egg.domestication).contains("Eiergewinnung ist noch nicht verfügbar"), "Book cannot show scanned egg role or promises production")
		scan.scan.complete = false
		expect(Suitability.read(scan, Traits).is_empty(), "Unscanned catalog leaked into the book")
		measurements.append({"body": body.id, "old_source_sha256": source_hash, "species": resumed.species.size(), "habitats": resumed.habitats.size(), "egg_id": egg.id, "body_evidence": egg.body_evidence.status, "legs": egg.body_evidence.rest.leg_count})
	var a: Dictionary = fixture.cases[0].body.duplicate(true)
	var b: Dictionary = a.duplicate(true); b.id = "same-seed-other-system"
	var catalogs: Dictionary = {}
	for body: Dictionary in [a, b, b, a]:
		var c: Dictionary = Catalog.create_surface(body, Catalog.Surface.Cube.address(body.id, 0, 0, 0, 20))
		if catalogs.has(body.id): expect(signature(c) == signature(catalogs[body.id]), "Visit order changed generated species")
		catalogs[body.id] = c
	expect(catalogs[a.id].species[3].id != catalogs[b.id].species[3].id, "Equal seeds on different bodies alias egg species")
	for field in ["egg_yield", "egg_interval"]:
		var profile: Dictionary = Traits.suitability("eggs"); profile[field] = 0
		expect(not Traits.validate(profile).is_empty(), "Zero laying capability accepted")
	var riding: Dictionary = Traits.suitability("work"); riding.anatomy.min_support_legs = 2
	expect(not Traits.validate(riding).is_empty(), "Riding policy accepted only two supporting legs")
	print("ARCH21_CONTRACT ", JSON.stringify({"cases": measurements, "failures": failures}))
	await preload("res://core/runtime_shutdown.gd").finish(self, 0 if failures.is_empty() else 1)

func signature(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value))).sha256_text()
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func capacity_check() -> void:
	for duplicates: bool in [false, true]:
		var population: Node = load("res://tests/fixtures/egg_population_harness.gd").new()
		for index in range(population.MAX_ANIMALS):
			var actor := ActorStub.new()
			if index < 3: actor.catalog_species = {"id": ["milk", "work", "companion"][index]}
			elif duplicates: actor.catalog_species = {"id": "milk"}
			population.animals[str(index)] = actor
		var candidates: Array[Dictionary] = [{"id": "ordinary"}, {"id": "new-egg", "catalog_species_id": "eggs"}]
		population._prioritize_catalog(candidates)
		expect(candidates[0].id == "new-egg" and population.animals.size() == population.MAX_ANIMALS - 1, "Full population starved missing fourth role")
		expect(population.captured.size() == 1 and population.animals.has("1") and population.animals.has("2"), "Eviction skipped capture or removed sole work/companion role")
		var milk: int = 0
		for actor: Node in population.animals.values(): milk += int(actor.catalog_species.get("id") == "milk")
		expect(milk > 0, "Eviction removed the only milk representative")
		for actor: Node in population.animals.values(): actor.free()
		population.animals.clear()
		population.free()
