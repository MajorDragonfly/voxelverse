extends "res://tests/settlement_collection_test.gd"
## Existing radial fixtures and authority adapters, with real arrived-work units.
const Equipment = preload("res://world/tribe/resident_equipment_model.gd")
const Participants = preload("res://core/persistence/save_participants.gd")
const View = preload("res://ui/tribe/resident_details_view.gd")
func _request(data: Dictionary, resident: String, action: String, extra: Dictionary={}) -> Dictionary:
	return {"village_id":data.id,"resident_id":resident,"action":action}.merged(extra)
func _harvest(data: Dictionary, resident: Dictionary, kind: String, count: int) -> void:
	for unit in range(count):
		resident.order=kind; resident.stage="outbound"; resident.work=0.0
		resident.position=data.deposits[kind].position.duplicate(true)
		var effects: Array=[]
		Work.step(data,resident,3.0,1.0,effects)
		_expect(resident.cargo==kind,"Radial work did not actually extract a unit")
		resident.position=data.anchor.duplicate(true)
		Work.step(data,resident,0.1,1.0,effects)
		_expect(resident.cargo=="","Radial unit not delivered")
	resident.order="wait"
func _run() -> void:
	root.get_node("SaveGameService").autosave_enabled=false
	root.get_node("GameState").set_process(false)
	var fixture: Dictionary=_legacy()
	var original: Dictionary=fixture.body
	var campaign: Dictionary=fixture.campaign
	var data: Dictionary=original.tribe
	var resident: Dictionary=data.members[1]
	_harvest(data,resident,"wood",6)
	_harvest(data,resident,"stone",4)
	var result: Dictionary=Equipment.command(data,_request(data,resident.id,"craft",{"kind":"stone_tool"}))
	_expect(result.ok,"Radial paid craft failed")
	var item: String=result.get("item_id","")
	_expect(Equipment.command(data,_request(data,resident.id,"equip",{"slot":"tool","item_id":item})).ok,"Radial equip failed")
	_local_source_balance(data,original,campaign,resident.id)
	var original_items: Dictionary=Equipment.items(data).duplicate(true)
	var prepared: Dictionary=Settlements.prepare_legacy(original,campaign)
	_expect(prepared.ok,"Existing authority migration rejected personal items: "+str(prepared))
	if not prepared.ok: await _finish(); return
	var body: Dictionary=prepared.body
	body.erase("tribal_neighbor")
	var origin: String=Settlements.origin_id(body)
	var other: String=_second(body,campaign)
	var a: Dictionary=Settlements.instance_view(body,origin)
	var b: Dictionary=Settlements.instance_view(body,other)
	_expect(Equipment.items(a.tribe)==original_items and Equipment.items(b.tribe).is_empty(),"Settlement migration copied/lost personal equipment")
	_expect(Settlements.validate(body,campaign).is_empty(),"Migrated radial equipment violated shared schema")
	_expect(Settlements.select(body,other).is_empty() and View.snapshot(Settlements.village(body),[resident.id]).is_empty(),"Different selected village exposed absent owner's inventory")
	_expect(not Equipment.command(b.tribe,_request(a.tribe,resident.id,"return",{"slot":"tool"})).ok,"Old village request changed different village")
	_expect(Settlements.select(body,origin).is_empty() and Equipment.owned(Settlements.village(body),resident.id,"tool").id==item,"Return selection lost actual owned item")
	var future: Dictionary=body.duplicate(true)
	future.settlements.entries[other].village[Equipment.FIELD].schema=2
	_expect(Settlements.unsupported(future) and Participants.unsupported_body(future),"Future empty secondary-village equipment bypassed registered guard")
	future=body.duplicate(true)
	future.settlements.entries[origin].village[Equipment.FIELD].items[item].recipe_revision=2
	_expect(Participants.unsupported_body(future),"Future secondary recipe accepted")
	# Equipped founder cannot orphan this village-owned item during a split.
	var found_body: Dictionary=body.duplicate(true)
	# Use one existing site so the preserved two-site capacity guard is not the
	# rejection under test. Reunite the unarmed fixture resident without duplication.
	var found_source: Dictionary=Settlements.instance_view(found_body,origin)
	var returned: Dictionary=Settlements.instance_view(found_body,other).tribe.members[0]
	returned.position=found_source.tribe.anchor.duplicate(true)
	returned.destination=returned.position.duplicate(true)
	found_source.tribe.members.append(returned)
	found_body.settlements.entries.erase(other)
	resident=found_source.tribe.members[1]
	resident.position=Home.offset_place(found_source.tribe.anchor,Vector3(16,0,0))
	resident.destination=resident.position.duplicate(true)
	_certify(found_source,campaign)
	var frozen: Dictionary=found_body.duplicate(true)
	var found: Dictionary=Settlements.found(found_body,campaign,resident.id,resident.position,_sites(resident.position))
	_expect(not found.ok and found.code=="settlements.founder_busy" and found_body==frozen,"Founding orphaned equipment or mutated rejected source: "+str(found))
	# Body switching uses actual CampaignState identities even with identical seeds.
	var state: Node=root.get_node("GameState")
	state.start_world_with_seed(15838)
	var first_body: Dictionary=state.get_current_body_record()
	var source_id: String=first_body.id
	var source_system: int=state.system_seed
	first_body.home_group=Home.create(first_body.id,state.campaign.data.player_species_id,Vector3.ZERO)
	first_body.tribe=Tribe.create(first_body.home_group,state.campaign.data,{"position":[0,0,0]},
		{"wood":[-5,0,-4],"stone":[5,0,-4],"food":[-5,0,4],"huts":[[5,0,4],[8,0,0]]})
	var live_village: Dictionary=first_body.tribe
	live_village.tools=1 # Explicit prebuilt-tool contract fixture, no scene acceptance.
	var live_member: Dictionary=live_village.members[1]
	_harvest(live_village,live_member,"wood",3)
	_harvest(live_village,live_member,"stone",2)
	var live_item: Dictionary=Equipment.command(live_village,_request(live_village,live_member.id,"craft",{"kind":"stone_tool"}))
	_expect(live_item.ok and Equipment.command(live_village,_request(live_village,live_member.id,"equip",{"slot":"tool","item_id":live_item.item_id})).ok,"Valid body fixture could not equip paid item")
	var body_items: Dictionary=Equipment.items(live_village).duplicate(true)
	_expect(Tribe.validate(live_village,first_body,state.campaign.data).is_empty(),"Body-switch fixture has invalid canonical identities")
	var target: Dictionary=state.campaign.ensure_body(15838,23757)
	_expect(target.id!=source_id and state.activate_body(target.id,23757,0,false),"Distinct same-seed body not activated")
	_expect(not state.get_current_body_record().has("tribe") and Equipment.items(first_body.tribe)==body_items,"Body switch leaked another body's equipment")
	_expect(state.activate_body(source_id,source_system,0,false) and Equipment.items(state.get_current_body_record().tribe)==body_items,"Body return lost source ownership")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(body))
	_expect(Equipment.inventory_snapshot(Settlements.instance_view(snapshot,origin).tribe)==Equipment.inventory_snapshot(a.tribe) and Settlements.validate(snapshot,campaign).is_empty(),"Radial JSON persistence lost items/IDs: "+Settlements.validate(snapshot,campaign)+" / "+str(Equipment.inventory_snapshot(Settlements.instance_view(snapshot,origin).tribe)==Equipment.inventory_snapshot(a.tribe)))
	print(JSON.stringify({"test":"r33_06_equipment_lifecycle","checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"radial contract adapters, body activation and settlement/future guards; no rendered travel"}))
	await _finish()

func _local_source_balance(original: Dictionary, body: Dictionary, campaign: Dictionary, resident_id: String) -> void:
	# This case runs after the serial 05->06 owner connection. The base-only
	# tree has no local-source module; no fabricated source or budget is added.
	var economic_script: Script=load("res://world/tribe/village_economy.gd")
	var constants: Dictionary=economic_script.get_script_constant_map()
	if not constants.has("LocalSources"):
		print("R33_06_LOCAL_SOURCE_SCOPE: R33-05 not applied; combined case pending")
		return
	var sources: Script=constants.LocalSources
	var data: Dictionary=original.duplicate(true)
	var admitted: Dictionary={}
	for dx in range(-3,4):
		for dy in range(-3,4):
			var candidate: Dictionary=sources.candidate(data.anchor,dx,dy)
			if candidate.resource_id=="wood" and sources.admit(data,candidate):
				admitted=sources.get_source(data,candidate.id)
				break
		if not admitted.is_empty(): break
	_expect(not admitted.is_empty(),"05/06 could not admit a genuine canonical wood source")
	if admitted.is_empty(): return
	_expect(Equipment.validate(data).is_empty(),"05/06 admitted remaining unit counted without its source budget")
	var worker: Dictionary=Equipment.member(data,resident_id)
	worker.resource_source_id=admitted.id
	worker.position=admitted.position.duplicate(true)
	worker.order="wood"; worker.stage="outbound"; worker.work=0.0
	Work.step(data,worker,3.0,1.0,[])
	_expect(admitted.remaining==0 and worker.cargo=="wood" and worker.cargo_source_id==admitted.id,"05/06 canonical source did not move into real cargo")
	worker.position=data.anchor.duplicate(true)
	Work.step(data,worker,0.1,1.0,[])
	worker.paused_order=worker.order # same stop semantics as the existing controller
	worker.order="wait"
	_expect(worker.cargo=="" and sources.withdrawn(data,"wood")==1,"05/06 source cargo not delivered once")
	var stock: Dictionary=data.stock.duplicate(true)
	var item: Dictionary=Equipment.command(data,_request(data,resident_id,"craft",{"kind":"stone_tool"}))
	_expect(item.ok and data.stock.wood==stock.wood-3 and data.stock.stone==stock.stone-2,"05/06 shared stock could not manufacture paid item")
	_expect(Equipment.validate(data).is_empty() and Tribe.validate(data,body,campaign).is_empty(),"05/06 paid ledger rejected after real source delivery: "+Tribe.validate(data,body,campaign))
	var duplicate: Dictionary=data.duplicate(true)
	duplicate.stock.wood+=1
	_expect(not Equipment.validate(duplicate).is_empty(),"05/06 duplicated source materials accepted")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(data))
	_expect(Equipment.validate(restored).is_empty() and Equipment.inventory_snapshot(restored)==Equipment.inventory_snapshot(data),"05/06 JSON restore changed paid ownership or local-source budget")
	print("R33_06_LOCAL_SOURCE_SCOPE: serial R33-05 + R33-06 case executed")
