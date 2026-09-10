extends SceneTree

const Behavior = preload("res://core/progression/behavior_progression.gd")
const Catalog = preload("res://core/progression/behavior_catalog.gd")
const GameEvent = preload("res://core/campaign/game_event.gd")
const Atomic = preload("res://core/persistence/atomic_json.gd")
const Creature = preload("res://creatures/editor/creature_assembly_blueprint_v7.gd")
const TEST_SAVE: String = "user://behavior_m2_test.json"

var failures: Array[String] = []
var saves: Node
var state: Node
var progression: Node
var purchase_notifications: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	saves = root.get_node("SaveGameService")
	state = root.get_node("GameState")
	progression = root.get_node("ProgressionService")
	saves.set("autosave_enabled", false)
	saves.set("save_path", TEST_SAVE)
	saves.set("_loaded_once", true)
	if "--restart-check" in OS.get_cmdline_user_args():
		_verify_restart()
		_finish()
		return
	_model_rewards()
	_model_purchases_and_effects()
	_model_validation()
	state.call("start_world_with_seed", 12345)
	await process_frame
	_migrate_schema_three()
	_service_transactions()
	_restart_process()
	_phase_legacy()
	_invalid_saves()
	var previous_id: String = state.get("campaign").data["id"]
	state.call("start_world_with_seed", 12345)
	_expect(previous_id != state.get("campaign").data["id"], "New game retained campaign identity.")
	_expect(_wallet(0)["earned"] == {"social": 0, "aggression": 0}, "New game retained behavior earnings.")
	_expect(_behavior_state()["purchased_nodes"].is_empty(), "New game retained purchased skills.")
	await process_frame
	_finish()


func _model_event(target: String, outcome: String = "befriended", encounter: String = "") -> GameEvent:
	var event := GameEvent.new()
	event.kind = GameEvent.Kind.CONFLICT_RESULT if outcome in ["won", "lost"] else GameEvent.Kind.INTERACTION
	event.campaign_id = "campaign_test"
	event.source_id = "player_test"
	event.target_id = target
	event.sequence = 1
	event.outcome = outcome
	event.encounter_id = "encounter_" + target if encounter.is_empty() else encounter
	event.behavior_context = {"target_relation": "hostile" if event.kind == GameEvent.Kind.CONFLICT_RESULT else "neutral",
		"need_origin": "environment", "conflict_reason": "self_defense"}
	return event


func _apply(model: Behavior, event: GameEvent, phase: int = 0) -> Dictionary:
	return model.apply_event(event, "campaign_test", "player_test", phase)


func _model_rewards() -> void:
	var model := Behavior.new()
	var event := _model_event("friend")
	_expect(_apply(model, event).get("amount") == 3, "Completed befriending did not earn social points.")
	_expect(not _apply(model, event)["ok"], "Repeated event earned twice.")
	event.sequence += 1
	event.encounter_id = "respawned_encounter"
	_expect(_apply(model, event).get("reason") == "target_already_rewarded", "New sequence/encounter bypassed target protection.")
	_expect(_apply(model, _model_event("different_target", "won", "encounter_friend")).get("reason") == "encounter_already_rewarded", "One encounter paid both tracks.")
	for origin in ["player", "ally", ""]:
		var harmful := _model_event("hurt_heal_" + origin, "helped")
		harmful.behavior_context["need_origin"] = origin
		_expect(not _apply(model, harmful)["ok"], "Manufactured or unknown need earned points.")
	var friendly_conflict := _model_event("ally_target", "won")
	friendly_conflict.behavior_context["target_relation"] = "ally"
	_expect(not _apply(model, friendly_conflict)["ok"], "Attacking an ally earned aggression points.")
	_expect(not _apply(model, _model_event("loss", "lost"))["ok"], "Lost conflict earned points.")
	var incomplete := _model_event("incomplete")
	incomplete.encounter_id = ""
	_expect(not _apply(model, incomplete)["ok"], "Legacy event without stable encounter earned points.")
	incomplete.encounter_id = "valid"
	incomplete.behavior_context = {}
	_expect(not _apply(model, incomplete)["ok"], "Event without completion context earned points.")
	var foreign := _model_event("foreign")
	foreign.campaign_id = "different_campaign"
	_expect(not _apply(model, foreign)["ok"], "Foreign campaign earned points.")
	foreign.campaign_id = "campaign_test"
	foreign.source_id = "other_animal"
	_expect(not _apply(model, foreign)["ok"], "NPC event earned player points.")
	_expect(not _apply(model, _model_event("player_test"))["ok"], "Self-interaction earned points.")
	var next_phase := _model_event("future")
	next_phase.phase = 1
	_expect(not _apply(model, next_phase, 1)["ok"], "Unimplemented phase silently reused creature earnings.")
	_expect(not _apply(model, next_phase, 0)["ok"], "Wrong-phase event earned points.")
	_expect(_apply(model, _model_event("help", "helped")).get("amount") == 2, "Independent help did not earn two points.")
	for index in range(100):
		_apply(model, _model_event("social_%d" % index))
		_apply(model, _model_event("combat_%d" % index, "won"))
	_expect(model.wallet(0)["earned"] == {"social": 24, "aggression": 24}, "Phase budgets did not stop repeated farming.")
	_expect(model.export_state()["phases"]["0"]["rewards"].size() <= 48, "Reward ledger grew beyond bounded wallets.")
	_expect(Behavior.validate_state(model.export_state()).is_empty(), "Partial final reward did not balance the ledger.")
	var restored := Behavior.new()
	_expect(restored.import_state(_json_value(model.export_state())), "Reward ledger did not survive JSON roundtrip.")
	_expect(not _apply(restored, _model_event("friend"))["ok"], "Reload reopened a paid target.")


func _model_purchases_and_effects() -> void:
	var model := Behavior.new()
	_expect(model.purchase("missing", 0).get("reason") == "unknown_node", "Unknown skill was accepted.")
	_expect(model.purchase("creature.social.approach", 0).get("reason") == "insufficient_points", "Empty wallet purchased a skill.")
	for index in range(3):
		_apply(model, _model_event("social_%d" % index))
		_apply(model, _model_event("combat_%d" % index, "won"))
	_expect(model.purchase("creature.social.legacy", 0).get("reason") == "prerequisite_missing", "Skill prerequisite was skipped.")
	_expect(model.purchase("creature.social.approach", -1).get("reason") == "future_phase", "Future-phase purchase accepted.")
	for node_id in Catalog.NODES:
		_expect(model.purchase(node_id, 0)["ok"], "Could not purchase valid node " + node_id)
	var before: Dictionary = model.export_state()
	_expect(not model.purchase("creature.social.approach", 0)["ok"], "Purchased skill could be bought twice.")
	_expect(before == model.export_state(), "Rejected purchase mutated balances.")
	_expect(model.wallet(0)["available"] == {"social": 0, "aggression": 0}, "Mixed build did not use separate point balances.")
	_expect(is_equal_approx(model.calculate_effect("befriend_efficiency", 0)["value"], 1.15), "Creature social effect is wrong.")
	_expect(is_equal_approx(model.calculate_effect("attack_efficiency", 0)["value"], 1.1), "Creature attack effect is wrong.")
	_expect(is_equal_approx(model.calculate_effect("ally_support_efficiency", 0)["value"], 1.15), "Creature support effect is wrong.")
	_expect(is_equal_approx(model.calculate_effect("stamina_recovery", 0)["value"], 1.15), "Creature stamina effect is wrong.")
	_expect(is_equal_approx(model.calculate_effect("group_cooperation", 0)["value"], 1.0), "Legacy activated before tribe phase.")
	_expect(is_equal_approx(model.calculate_effect("befriend_efficiency", 1)["value"], 1.0), "Creature-only effect leaked into tribe phase.")
	for phase in range(1, 6):
		_expect(is_equal_approx(model.calculate_effect("group_cooperation", phase)["value"], 1.1), "Social legacy disappeared in a later phase.")
		_expect(is_equal_approx(model.calculate_effect("group_defense", phase)["value"], 1.1), "Aggression legacy disappeared in a later phase.")
	for repeat in range(20):
		_expect(is_equal_approx(model.calculate_effect("group_defense", 1)["value"], 1.1), "Repeated effect query compounded the bonus.")
	_expect(is_equal_approx(model.calculate_effect("attack_efficiency", 0, 1.2, 0.3)["value"], 1.6), "Body, technology and skill did not combine additively.")
	_expect(model.calculate_effect("attack_efficiency", 0, 20.0, 30.0)["value"] == 2.0, "Effect cap failed.")
	_expect(not model.calculate_effect("attack_efficiency", 0, NAN)["ok"], "Nonfinite effect input accepted.")
	_expect(not model.calculate_effect("unknown", 0)["ok"], "Unknown effect accepted.")
	_expect(before == model.export_state(), "Reading effects mutated persistent skills.")
	var copied_nodes: Array[Dictionary] = model.nodes_for_phase(0, 0)
	copied_nodes[0]["effects"].clear()
	_expect(not Catalog.node("creature.social.approach")["effects"].is_empty(), "UI view modified the shared catalog.")


func _model_validation() -> void:
	var model := Behavior.new()
	_apply(model, _model_event("one"))
	model.purchase("creature.social.approach", 0)
	var valid: Dictionary = model.export_state()
	for bad_balance in [-1, 0.5, true, "3", NAN, 999]:
		var damaged: Dictionary = valid.duplicate(true)
		damaged["phases"]["0"]["earned"]["social"] = bad_balance
		_expect(not model.import_state(damaged), "Invalid balance accepted: " + str(bad_balance))
		_expect(model.export_state() == valid, "Failed import replaced valid live state.")
	var overspent: Dictionary = valid.duplicate(true)
	overspent["phases"]["0"]["spent"]["social"] = 3
	_expect(not model.import_state(overspent), "Spending without a matching purchase accepted.")
	var future: Dictionary = valid.duplicate(true)
	future["rules_version"] = 2
	_expect(Behavior.has_unsupported_contract(future) and not model.import_state(future), "Unknown balancing rules were silently reinterpreted.")
	var forged: Dictionary = valid.duplicate(true)
	forged["purchased_nodes"] = {"creature.social.legacy": true}
	_expect(not model.import_state(forged), "Legacy without prerequisites accepted.")
	forged["purchased_nodes"] = {"unknown_node": true}
	_expect(not model.import_state(forged), "Unknown purchased content was discarded instead of rejected.")
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["phases"]["0"]["rewards"]["different".sha256_text()] = duplicate["phases"]["0"]["rewards"].values()[0].duplicate(true)
	_expect(not model.import_state(duplicate), "Duplicate encounter in a save was accepted.")


func _migrate_schema_three() -> void:
	var creature: Dictionary = Creature.create_default()
	creature["name"] = "M2 retained design"
	_expect(Creature.save_to_file(creature) == OK, "Could not create migration design.")
	progression.call("register_region_discovery", Vector2i(7, -2), 12345)
	_expect(bool(saves.call("save_now")), "Could not create migration fixture.")
	var legacy: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))
	legacy["schema"] = 3
	legacy.game_state.schema = 3
	legacy.game_state.erase("system_id")
	legacy.game_state.campaign.schema = 2
	legacy.game_state.campaign.erase("body_lookup")
	var old_bodies: Dictionary = {}
	for body: Dictionary in legacy.game_state.campaign.bodies.values(): old_bodies[str(int(body.seed))] = body
	legacy.game_state.campaign.bodies = old_bodies
	var old_regions: Dictionary = {}
	for region: Dictionary in legacy.regions_by_body.values(): old_regions[str(int(region.world_seed))] = region
	legacy.regions_by_world = old_regions
	legacy.erase("regions_by_body")
	legacy["progression"]["schema"] = 2
	legacy["progression"].erase("behavior")
	_expect(Atomic.write(TEST_SAVE, legacy, false) == OK, "Could not write old schema-3 fixture.")
	var old_text: String = FileAccess.get_file_as_string(TEST_SAVE)
	creature["name"] = "Different loose file"
	Atomic.write(Creature.SAVE_PATH, creature, false)
	_expect(bool(saves.call("load_now")), "M0/M1 schema-3 save failed to migrate.")
	_expect(_json_value(state.get("campaign").export_state()) == _json_value(preload("res://core/campaign/body_registry.gd").upgrade_campaign(legacy["game_state"]["campaign"]).data), "Schema 3 migration replaced IDs, clock or event cursors.")
	_expect(Creature.load_best_available()["name"] == "M2 retained design", "Migration preferred a loose editor file over the snapshot.")
	_expect(int(progression.get("discovery_points")) == 1, "Migration changed Insight.")
	_expect(_wallet(0)["earned"] == {"social": 0, "aggression": 0}, "Old discoveries became retroactive behavior points.")
	var backup: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE + ".schema3.backup.json"))
	_expect(backup.get("legacy_save_text") == old_text, "Schema 3 migration did not preserve exact original bytes.")
	_expect(backup.get("design_files") == legacy["design_files"], "Migration backup lost bundled editor data.")
	_expect(FileAccess.get_file_as_string(TEST_SAVE) == old_text, "Loading rewrote the original before an explicit save.")
	_expect(bool(saves.call("save_now")), "Migrated schema 4 could not be saved.")
	_expect(int(Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))["schema"]) == saves.SAVE_SCHEMA, "New progress is not protected from old writers.")


func _game_event(target: String, outcome: String = "befriended") -> GameEvent:
	var template := _model_event(target, outcome)
	var event = state.get("campaign").next_event(template.kind, target, int(state.get("current_phase")), outcome)
	event.encounter_id = template.encounter_id
	event.behavior_context = template.behavior_context
	return event


func _service_transactions() -> void:
	var event := _game_event("first_friend")
	_expect(not progression.call("apply_campaign_event", event)["ok"], "Unaccepted event bypassed GameState.")
	var observer := func(_event: Dictionary) -> void:
		_expect(bool(saves.call("save_now")), "Event observer could not save.")
	state.connect("campaign_event", observer)
	_expect(bool(state.call("record_campaign_event", event)), "GameState rejected completed interaction.")
	state.disconnect("campaign_event", observer)
	var checkpoint: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))
	_expect(int(checkpoint["progression"]["behavior"]["phases"]["0"]["earned"]["social"]) == 3, "Observer saved cursor without matching reward.")
	_expect(not bool(state.call("record_campaign_event", event)), "GameState rewarded the same event twice.")
	_expect(bool(saves.call("load_now")), "Reward checkpoint could not be restored.")
	_expect(not bool(state.call("record_campaign_event", event)), "Reload forgot event cursor.")
	state.call("record_campaign_event", _game_event("first_friend"))
	_expect(_wallet(0)["earned"]["social"] == 3, "Newly emitted respawn event earned duplicate points.")
	progression.connect("behavior_node_purchased", func(_node_id: String) -> void: purchase_notifications += 1)
	var before: Dictionary = _behavior_state()
	saves.set("save_path", "user://missing_m2_directory/save.json")
	_expect(progression.call("purchase_behavior_node", "creature.social.approach").get("reason") == "save_failed", "Failed purchase save reported success.")
	_expect(_behavior_state() == before and purchase_notifications == 0, "Failed purchase lost points, kept a node or announced success.")
	saves.set("save_path", TEST_SAVE)
	_expect(progression.call("purchase_behavior_node", "creature.social.approach")["ok"], "Purchase could not be retried after write failure.")
	_expect(purchase_notifications == 1, "Successful purchase did not notify exactly once.")
	_expect(not progression.call("purchase_behavior_node", "creature.social.approach")["ok"], "Duplicate purchase accepted.")
	for index in range(2):
		state.call("record_campaign_event", _game_event("friend_%d" % index))
	for index in range(3):
		state.call("record_campaign_event", _game_event("conflict_%d" % index, "won"))
	for node_id in ["creature.social.support", "creature.aggression.hunter", "creature.aggression.endurance", "creature.aggression.legacy"]:
		_expect(progression.call("purchase_behavior_node", node_id)["ok"], "Service purchase failed: " + node_id)
	_expect(_wallet(0)["available"] == {"social": 4, "aggression": 0}, "Service mixed-build balances incorrect.")
	_expect(int(progression.get("discovery_points")) == 1, "Behavior spending consumed Insight.")
	_expect(bool(saves.call("save_now")), "Could not write service checkpoint.")


func _restart_process() -> void:
	var expected: Dictionary = {"behavior": _behavior_state(), "campaign": state.get("campaign").export_state()}
	Atomic.write("user://behavior_restart_expected.json", expected, false)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/behavior_progression_test.gd", "--", "--restart-check"], output, true)
	_expect(code == 0 and str(output).contains("M2 separate-process restart passed"), "Fresh Godot process did not restore behavior state: " + str(output))


func _verify_restart() -> void:
	var expected: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string("user://behavior_restart_expected.json"))
	_expect(bool(saves.call("load_now")), "Fresh process could not load schema 4.")
	_expect(_json_value(_behavior_state()) == expected.get("behavior"), "Points, ledger or nodes changed across processes.")
	_expect(_json_value(state.get("campaign").export_state()) == expected.get("campaign"), "Campaign cursors or identity changed across processes.")
	state.call("record_campaign_event", _game_event("first_friend"))
	_expect(_wallet(0)["earned"]["social"] == 9, "Respawn after process restart earned duplicate points.")
	_expect(not progression.call("purchase_behavior_node", "creature.social.approach")["ok"], "Restart forgot purchased node.")
	_expect(is_equal_approx(progression.call("get_behavior_effect", "attack_efficiency", 0)["value"], 1.1), "Reload compounded attack bonus.")
	if failures.is_empty():
		print("M2 separate-process restart passed")


func _phase_legacy() -> void:
	_expect(not bool(saves.call("request_phase_transition", 1)), "Behavior skills unlocked unfinished tribe gameplay.")
	_expect(bool(saves.call("debug_prepare_phase_transition", 1)), "Could not prepare debug tribe handoff.")
	_expect(bool(saves.call("load_now")), "Prepared phase transition failed to resume with behavior state.")
	_expect(_wallet(1)["available"] == {"social": 0, "aggression": 0}, "Creature points became tribe currency.")
	_expect(is_equal_approx(progression.call("get_behavior_effect", "group_defense", 1)["value"], 1.1), "Aggression legacy did not activate in tribe phase.")
	_expect(progression.call("purchase_behavior_node", "creature.social.legacy")["ok"], "Unspent creature points could not buy an old-phase node.")
	_expect(is_equal_approx(progression.call("get_behavior_effect", "group_cooperation", 1)["value"], 1.1), "Late legacy purchase did not apply once.")
	for repeat in range(3):
		_expect(bool(saves.call("load_now")), "Legacy save failed to reload.")
		_expect(is_equal_approx(progression.call("get_behavior_effect", "group_cooperation", 1)["value"], 1.1), "Reload multiplied inherited bonus.")
	_expect(_wallet(0)["spent"] == {"social": 9, "aggression": 9}, "Late purchase spent from the wrong phase.")


func _invalid_saves() -> void:
	_expect(bool(saves.call("save_now")), "Could not checkpoint save validation fixture.")
	var valid: Dictionary = Atomic.parse_dictionary(FileAccess.get_file_as_string(TEST_SAVE))
	for field in ["schema", "rules_version"]:
		var future: Dictionary = valid.duplicate(true)
		future["progression"]["behavior"][field] = 99
		Atomic.write(TEST_SAVE, future, false)
		var original: String = FileAccess.get_file_as_string(TEST_SAVE)
		_expect(not bool(saves.call("load_now")), "Future behavior contract fell back to old backup.")
		_expect(not bool(saves.call("save_now")), "Future behavior contract could be overwritten.")
		_expect(FileAccess.get_file_as_string(TEST_SAVE) == original, "Unsupported save bytes were modified.")
		Atomic.write(TEST_SAVE, valid, false)
		_expect(bool(saves.call("load_now")), "Compatible behavior save did not unblock writes.")
	var damaged: Dictionary = valid.duplicate(true)
	damaged["progression"]["behavior"]["phases"]["0"]["spent"]["social"] = 500
	Atomic.write(TEST_SAVE, damaged, false)
	_expect(bool(saves.call("load_now")), "Corrupt balances did not recover a complete backup.")
	_expect(_wallet(0)["spent"]["social"] == 9, "Backup recovery mixed purchases and balances.")
	_expect(Behavior.validate_state(_behavior_state()).is_empty(), "Recovered behavior state is inconsistent.")
	# A future contract in the backup must also block rewriting after a torn main file.
	var future_backup: Dictionary = valid.duplicate(true)
	future_backup["progression"]["schema"] = 99
	Atomic.write(TEST_SAVE + ".bak", future_backup, false)
	_expect(not bool(saves.call("load_now")) and not bool(saves.call("save_now")), "Unsupported backup was overwritten after primary corruption.")
	Atomic.write(TEST_SAVE, valid, false)
	_expect(bool(saves.call("load_now")), "Could not restore supported fixture.")


func _wallet(phase: int) -> Dictionary:
	return progression.call("get_behavior_wallet", phase)


func _behavior_state() -> Dictionary:
	return progression.call("export_state")["behavior"]


func _json_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("M2 behavior rewards, anti-farming, purchases, migration and legacy acceptance passed.")
		await preload("res://core/runtime_shutdown.gd").finish(self, 0)
	else:
		for failure in failures:
			push_error(failure)
		await preload("res://core/runtime_shutdown.gd").finish(self, 1)
