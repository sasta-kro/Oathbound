extends GutTest
## Items, the satchel, vendors and the inn (Specification 16), and using
## items in battle (Specification 11.2, 16.3).

const EMBERLING := &"creature_fire_01"
const LOAMBUCK := &"creature_earth_01"
const SALVE := &"item_herb_salve"
const TONIC := &"item_hearty_tonic"
const DRAUGHT := &"item_ember_draught"
const CLEARWATER := &"item_clearwater_vial"
const SCROLL := &"item_binding_scroll"
const TOWN := "res://areas/town.tscn"

var _saved: Dictionary


func before_each() -> void:
	_saved = GameState.to_dict()
	GameState.new_game()


func after_each() -> void:
	GameState.from_dict(_saved)
	await get_tree().process_frame


func _item(id: StringName) -> ItemData:
	return Content.get_item(id)


func _hurt(creature: CreatureInstance, hp: int) -> CreatureInstance:
	creature.set_hp(hp)
	return creature


func test_every_item_is_valid_content() -> void:
	assert_eq(Content.all_items().size(), 5)
	for item: ItemData in Content.all_items():
		assert_eq(item.validate(), [] as Array[String], "%s must be valid." % item.id)
		assert_gt(item.price, 0, "%s needs a price." % item.id)


func test_buying_spends_coins_and_fills_the_satchel() -> void:
	GameState.currency = 50
	assert_true(GameState.buy_item(_item(SALVE)))
	assert_eq(GameState.currency, 30)
	assert_eq(GameState.item_count(SALVE), 1)


func test_buying_a_scroll_adds_to_the_binding_scrolls() -> void:
	GameState.currency = 100
	var before: int = GameState.binding_scrolls
	assert_true(GameState.buy_item(_item(SCROLL)))
	assert_eq(GameState.binding_scrolls, before + 1)
	assert_true(GameState.held_items().is_empty(), "Scrolls are not satchel items.")


func test_nothing_is_sold_on_credit() -> void:
	GameState.currency = 5
	assert_false(GameState.buy_item(_item(TONIC)))
	assert_eq(GameState.currency, 5)
	assert_eq(GameState.item_count(TONIC), 0)


func test_a_salve_heals_in_the_field_and_is_used_up() -> void:
	var lead: CreatureInstance = GameState.party[0]
	_hurt(lead, 1)
	GameState.add_item(_item(SALVE))
	var result: Dictionary = GameState.use_item_in_field(_item(SALVE), lead)
	assert_true(result.used)
	assert_gt(lead.current_hp, 1)
	assert_eq(GameState.item_count(SALVE), 0)


func test_items_refuse_pointless_targets() -> void:
	var lead: CreatureInstance = GameState.party[0]
	GameState.add_item(_item(SALVE))
	GameState.add_item(_item(DRAUGHT))
	GameState.add_item(_item(CLEARWATER))
	assert_false(GameState.use_item_in_field(_item(SALVE), lead).used, "Full HP needs no salve.")
	assert_false(GameState.use_item_in_field(_item(DRAUGHT), lead).used, "Only the fainted revive.")
	assert_false(GameState.use_item_in_field(_item(CLEARWATER), lead).used, "Clearwater is for battle.")
	lead.set_hp(0)
	assert_false(GameState.use_item_in_field(_item(SALVE), lead).used, "A salve cannot wake the fainted.")
	assert_true(GameState.use_item_in_field(_item(DRAUGHT), lead).used)
	assert_eq(lead.current_hp, ceili(lead.max_hp() * 0.5))
	assert_eq(GameState.item_count(SALVE), 1)


func test_the_satchel_survives_a_save() -> void:
	GameState.add_item(_item(SALVE), 3)
	GameState.add_item(_item(TONIC))
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game()
	GameState.from_dict(data)
	assert_eq(GameState.item_count(SALVE), 3)
	assert_eq(GameState.item_count(TONIC), 1)


func test_an_old_save_without_items_loads_with_an_empty_satchel() -> void:
	GameState.add_item(_item(SALVE))
	var data: Dictionary = GameState.to_dict()
	data.erase("items")
	GameState.from_dict(data)
	assert_true(GameState.held_items().is_empty())


# --- Battle ------------------------------------------------------------------


func _battle(party: Array[CreatureInstance], items: Dictionary) -> BattleEngine:
	var config := BattleConfig.wild(party, Content.spawn_creature(LOAMBUCK, 3), Content.type_chart)
	config.rng_seed = 7
	config.items = items
	for item: ItemData in Content.all_items():
		config.item_catalog[item.id] = item
	var engine := BattleEngine.new(config)
	engine.forced_roll = 0.99
	engine.start()
	return engine


func test_the_item_command_opens_only_when_an_item_would_help() -> void:
	var party: Array[CreatureInstance] = [Content.spawn_creature(EMBERLING, 10)]
	var engine := _battle(party, {SALVE: 2})
	assert_false(bool(engine.options()["can_item"]), "Nobody is hurt yet.")
	_hurt(party[0], 5)
	assert_true(bool(engine.options()["can_item"]))


func test_a_salve_in_battle_heals_and_takes_the_turn() -> void:
	var party: Array[CreatureInstance] = [_hurt(Content.spawn_creature(EMBERLING, 10), 5)]
	var engine := _battle(party, {SALVE: 2})
	var events: Array[BattleEvent] = engine.take_turn(BattleAction.use_item(_item(SALVE), 0))
	var healed: bool = false
	for event: BattleEvent in events:
		healed = healed or event.kind == BattleEvent.Kind.HEALED
	assert_true(healed)
	assert_eq(engine.items[SALVE], 1)
	assert_eq(engine.turn_number, 1, "Using an item spends the turn.")


func test_a_draught_revives_a_benched_companion_mid_battle() -> void:
	var party: Array[CreatureInstance] = [
		Content.spawn_creature(EMBERLING, 10), _hurt(Content.spawn_creature(LOAMBUCK, 10), 0)
	]
	var engine := _battle(party, {DRAUGHT: 1})
	assert_ne(engine.item_refusal(_item(DRAUGHT), 0), "", "The conscious lead needs no reviving.")
	engine.take_turn(BattleAction.use_item(_item(DRAUGHT), 1))
	assert_false(party[1].is_fainted())
	assert_false(engine.items.has(DRAUGHT) and int(engine.items[DRAUGHT]) > 0)


func test_clearwater_clears_battle_statuses() -> void:
	var party: Array[CreatureInstance] = [Content.spawn_creature(EMBERLING, 10)]
	var engine := _battle(party, {CLEARWATER: 1})
	assert_ne(engine.item_refusal(_item(CLEARWATER), 0), "", "Nothing to cure yet.")
	engine.player.active().apply_status(StatusIds.POISON, 3)
	engine.take_turn(BattleAction.use_item(_item(CLEARWATER), 0))
	assert_false(engine.player.active().has_status(StatusIds.POISON))


# --- The town ----------------------------------------------------------------


func test_the_town_has_an_inn_and_two_vendors() -> void:
	var area: Node = autofree((load(TOWN) as PackedScene).instantiate())
	add_child(area)
	var innkeeper: WorldActor = area.get_node("Actors/Innkeeper")
	assert_true(innkeeper.runs_inn)
	var scribe: WorldActor = area.get_node("Actors/Scribe")
	assert_eq(scribe.stock(Content), [_item(SCROLL)] as Array[ItemData])
	var apothecary: WorldActor = area.get_node("Actors/Apothecary")
	var sold: Array[ItemData] = apothecary.stock(Content)
	assert_true(sold.has(_item(SALVE)) and sold.has(_item(DRAUGHT)))
	var wanderers: int = 0
	for actor: WorldActor in area.find_children("*", "WorldActor", true, false):
		if actor.wander_radius_cells > 0.0:
			wanderers += 1
			assert_false(actor.is_vendor() or actor.runs_inn, "Service NPCs stay put (Specification 6.2).")
	assert_gte(wanderers, 2, "Some townsfolk stroll about.")


func test_small_talk_moves_on_each_visit() -> void:
	var actor := WorldActor.new()
	autofree(actor)
	actor.dialogue_line = "one"
	actor.chatter = PackedStringArray(["two", "three"])
	assert_eq([actor.next_small_talk(), actor.next_small_talk(), actor.next_small_talk(), actor.next_small_talk()], ["one", "two", "three", "one"])


# --- Shop and inn quests -----------------------------------------------------


func _accept(id: StringName) -> QuestData:
	var quest: QuestData = Content.get_quest(id)
	assert_true(GameState.accept_quest(quest), "%s can be taken." % id)
	return quest


## Puts everything [param id] is built on behind the player, so a quest from
## the middle of the main chain can be taken the way they would have taken it.
func _reach(id: StringName) -> QuestData:
	var earlier: Array[QuestData] = []
	var walker: QuestData = Content.get_quest(id)
	while walker != null and walker.requires != &"":
		walker = Content.get_quest(walker.requires)
		if walker != null:
			earlier.push_front(walker)
	for quest: QuestData in earlier:
		GameState.quests.accept(quest)
		for objective: QuestObjective in quest.objectives:
			for _step: int in objective.required():
				GameState.quests.report(objective.kind, objective.target)
		assert_true(GameState.quests.complete(quest), "%s can be finished." % quest.id)
	return _accept(id)


func test_buying_a_salve_stocks_the_satchel_quest_and_pays_an_item() -> void:
	var quest := _reach(&"quest_main_01g_a_stocked_satchel")
	GameState.currency = 100
	assert_false(GameState.quests.is_ready(quest))
	GameState.buy_item(_item(SALVE))
	assert_true(GameState.quests.is_ready(quest), "The Apothecary's counter is the lesson.")
	var lines: PackedStringArray = GameState.complete_quest(quest)
	assert_eq(GameState.item_count(CLEARWATER), 1)
	assert_true("+1 Clearwater Vial" in lines)


func test_buying_scrolls_earns_a_free_one() -> void:
	var quest := _accept(&"quest_side_ink_and_oath")
	GameState.currency = 80
	var before: int = GameState.binding_scrolls
	GameState.buy_item(_item(SCROLL))
	GameState.buy_item(_item(SCROLL))
	GameState.complete_quest(quest)
	assert_eq(GameState.binding_scrolls, before + 3)


func test_a_salve_used_in_the_field_or_a_battle_counts_for_field_medicine() -> void:
	var quest := _accept(&"quest_side_field_medicine")
	GameState.add_item(_item(SALVE))
	_hurt(GameState.party[0], 1)
	GameState.use_item_in_field(_item(SALVE), GameState.party[0])
	assert_true(GameState.quests.is_ready(quest))
	var engine := _battle([_hurt(Content.spawn_creature(EMBERLING, 10), 5)] as Array[CreatureInstance], {SALVE: 1})
	engine.take_turn(BattleAction.use_item(_item(SALVE), 0))
	assert_eq(engine.items_used, [SALVE] as Array[StringName], "The battle keeps a record for the quest log.")


func test_a_night_at_the_inn_counts_for_the_scouts_errand() -> void:
	var quest := _reach(&"quest_main_01f_a_bed_at_the_hearthside")
	GameState.report_quest_event(QuestObjective.Kind.EVENT, GameState.EVENT_RESTED_AT_INN)
	assert_true(GameState.quests.is_ready(quest))
	assert_eq(quest.turn_in_actor(), &"innkeeper", "The Innkeeper takes it in where the bed is.")
	GameState.complete_quest(quest)
	assert_eq(GameState.item_count(SALVE), 1)
