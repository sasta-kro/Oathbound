extends GutTest
## The five lessons the Scout gives between the mend and the ruined road: the
## overworld strike, the ambush and the rout, staged at his fire
## ([FieldStrike], [FieldAmbush], [FieldRout]), and the errands that send the
## player back to the town for a bed and a satchel.

const SCRATCH_DIR := "user://gut_scratch/test_field_lessons"
const AREA_ONE := "res://areas/area_one.tscn"
const SALVE := &"item_healing_herb"
const KEEPING_QUEST_ID := &"quest_main_01b_room_for_more"
const LEAD_QUEST_ID := &"quest_main_01d_who_walks_in_front"
const BED_QUEST_ID := &"quest_main_01h_a_bed_at_the_hearthside"
const SATCHEL_QUEST_ID := &"quest_main_01i_a_stocked_satchel"
const BACK_QUEST_ID := &"quest_main_01j_the_road_is_waiting"
const ROAD_QUEST_ID := &"quest_main_02_the_ruined_road"
## A little longer than the beat a staged creature takes to appear.
const ENTRANCE_WAIT: float = 0.5
## How long a line of the Scout's is waited on before the test gives up.
const LINE_WAIT_FRAMES := 120

var _original_dir: String


func before_each() -> void:
	_original_dir = SaveService.save_dir
	SaveService.save_dir = SCRATCH_DIR
	SaveService.erase_all()
	GameState.new_game()


func after_each() -> void:
	SaveService.erase_all()
	SaveService.save_dir = _original_dir
	GameState.new_game()
	await get_tree().process_frame


# --- The chain ---------------------------------------------------------------


func _quest(id: StringName) -> QuestData:
	return Content.get_quest(id)


## Puts everything [param id] is built on behind the player.
func _reach(id: StringName) -> QuestData:
	var earlier: Array[QuestData] = []
	var walker: QuestData = _quest(id)
	while walker != null and walker.requires != &"":
		walker = _quest(walker.requires)
		if walker != null:
			earlier.push_front(walker)
	for quest: QuestData in earlier:
		GameState.quests.accept(quest)
		for objective: QuestObjective in quest.objectives:
			for _step: int in objective.required():
				GameState.quests.report(objective.kind, objective.target)
		assert_true(GameState.quests.complete(quest), "%s can be finished." % quest.id)
	var target: QuestData = _quest(id)
	assert_true(GameState.quests.accept(target), "%s can be taken." % id)
	return target


func test_the_lessons_run_in_order_from_the_fire_to_the_town_and_back() -> void:
	var order: Array[StringName] = [
		FieldMending.QUEST_ID,
		LEAD_QUEST_ID,
		FieldStrike.QUEST_ID,
		FieldAmbush.QUEST_ID,
		FieldRout.QUEST_ID,
		BED_QUEST_ID,
		SATCHEL_QUEST_ID,
		BACK_QUEST_ID,
		ROAD_QUEST_ID,
	]
	# Each errand is given by whoever the player is already standing in front
	# of, so the tutorial never sends anyone back across the map to be told
	# the next thing.
	var givers: Dictionary = {
		LEAD_QUEST_ID: &"scout",
		FieldStrike.QUEST_ID: &"scout",
		FieldAmbush.QUEST_ID: &"scout",
		FieldRout.QUEST_ID: &"scout",
		BED_QUEST_ID: &"scout",
		SATCHEL_QUEST_ID: &"innkeeper",
		BACK_QUEST_ID: &"apothecary",
	}
	for index: int in range(1, order.size()):
		var quest: QuestData = _quest(order[index])
		assert_not_null(quest, "%s ships." % order[index])
		assert_eq(quest.requires, order[index - 1], "%s follows %s." % [order[index], order[index - 1]])
		assert_true(quest.is_main(), "%s is part of the story." % order[index])
		if givers.has(quest.id):
			assert_eq(quest.giver, givers[quest.id], "%s is given where the player is." % quest.id)


## Nobody is sent back across the map to report: every errand is taken in by
## somebody standing where the errand ends.
func test_each_errand_is_taken_in_where_it_ends() -> void:
	assert_eq(_quest(BED_QUEST_ID).turn_in_actor(), &"innkeeper", "The bed is reported at the bed.")
	assert_eq(_quest(SATCHEL_QUEST_ID).turn_in_actor(), &"apothecary", "The salve is reported at the counter.")
	assert_eq(_quest(BACK_QUEST_ID).turn_in_actor(), &"scout", "Walking back up is the errand itself.")
	assert_eq(
		_quest(BACK_QUEST_ID).objectives[0].kind,
		QuestObjective.Kind.TALK,
		"Reaching the Scout is all it asks for.",
	)


## The two errands are taught by the Scout but finished where the lesson
## actually is, so the player is not walked back up the road to say so.
func test_the_errands_are_handed_in_where_they_happen() -> void:
	assert_eq(_quest(BED_QUEST_ID).turn_in_actor(), &"innkeeper")
	assert_eq(_quest(SATCHEL_QUEST_ID).turn_in_actor(), &"apothecary")
	assert_eq(_quest(FieldStrike.QUEST_ID).turn_in_actor(), &"scout")
	assert_eq(_quest(FieldAmbush.QUEST_ID).turn_in_actor(), &"scout")
	assert_eq(_quest(FieldRout.QUEST_ID).turn_in_actor(), &"scout")


func test_each_lesson_waits_on_the_one_thing_it_teaches() -> void:
	var waits: Dictionary = {
		LEAD_QUEST_ID: GameState.EVENT_CHANGED_LEAD,
		FieldStrike.QUEST_ID: FieldStrike.EVENT_ID,
		FieldAmbush.QUEST_ID: FieldAmbush.EVENT_ID,
		FieldRout.QUEST_ID: FieldRout.EVENT_ID,
		BED_QUEST_ID: GameState.EVENT_RESTED_AT_INN,
		SATCHEL_QUEST_ID: StringName(GameState.EVENT_BOUGHT_ITEM % SALVE),
	}
	for id: StringName in waits:
		var quest: QuestData = _quest(id)
		assert_eq(quest.objectives.size(), 1, "%s asks for one thing." % id)
		var objective: QuestObjective = quest.objectives[0]
		assert_eq(objective.kind, QuestObjective.Kind.EVENT, "%s is reported by the world." % id)
		assert_eq(objective.target, waits[id])


## The paddock lesson asks for the round trip, so nobody finishes it with a
## companion still waiting in keeping.
func test_the_paddock_lesson_waits_on_sending_away_and_calling_back() -> void:
	var targets: Array[StringName] = []
	for objective: QuestObjective in _quest(KEEPING_QUEST_ID).objectives:
		assert_eq(objective.kind, QuestObjective.Kind.EVENT)
		targets.append(objective.target)
	assert_eq(
		targets,
		[GameState.EVENT_KEPT_AN_OATHBOUND, GameState.EVENT_CALLED_BACK_AN_OATHBOUND] as Array[StringName],
	)


func test_a_night_at_the_inn_and_a_salve_finish_the_two_errands() -> void:
	var bed: QuestData = _reach(BED_QUEST_ID)
	GameState.report_quest_event(QuestObjective.Kind.EVENT, GameState.EVENT_RESTED_AT_INN)
	assert_true(GameState.quests.is_ready(bed), "The bed is the whole errand.")
	GameState.complete_quest(bed)

	var satchel: QuestData = _quest(SATCHEL_QUEST_ID)
	assert_true(GameState.accept_quest(satchel), "The satchel follows the bed.")
	GameState.currency = 100
	GameState.buy_item(Content.get_item(SALVE))
	assert_true(GameState.quests.is_ready(satchel), "Buying it at the counter is the lesson.")
	GameState.complete_quest(satchel)

	var back: QuestData = _quest(BACK_QUEST_ID)
	assert_true(GameState.accept_quest(back), "The Apothecary sends the player back up the road.")
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	assert_true(GameState.quests.is_ready(back), "Reaching the Scout is the errand.")
	GameState.complete_quest(back)
	assert_true(GameState.quests.can_offer(_quest(ROAD_QUEST_ID)), "Then the road opens.")


# --- What the staged battles are like ------------------------------------------


func _config_for(lesson: Dictionary) -> BattleConfig:
	var party: Array[CreatureInstance] = [Content.spawn_creature(&"creature_emberling", 5)]
	var foe: CreatureInstance = Content.spawn_creature(&"creature_loambuck", 4)
	var config := BattleConfig.wild(party, foe, Content.type_chart)
	(lesson.prepare as Callable).call(config, foe, party)
	return config


func test_a_staged_foe_fights_with_its_strength_spent() -> void:
	for lesson: Dictionary in [FieldStrike.stage(), FieldAmbush.stage()]:
		var config: BattleConfig = _config_for(lesson)
		assert_eq(config.enemy_modifiers.size(), 1, "The foe is softened for the lesson.")
		assert_lt(config.enemy_modifiers[0].percent, 0)
		assert_true(config.can_run, "A player who would rather leave has still learned it.")
		assert_true(bool(lesson.satchel), "These are fought with the player's own party.")
		var guide: BattleGuide = lesson.guide
		assert_not_null(guide, "The battle says why the first turn went the way it did.")
		assert_true(guide.allows_command(null, BattleGuide.RUN), "It explains; it does not narrow.")
		assert_eq(lesson.event, &"", "The blow in the overworld reports the quest, not the battle.")


## The lesson battles have to be winnable by the player the game has actually
## made by then: a level-7 Emberling, no items, against a foe the type chart
## is on the wrong side of. Played out move by move, the lead should win with
## most of its health still there.
func _play_out(lesson: Dictionary, foe: CreatureInstance, opening: BattleConfig.Opening) -> BattleEngine:
	var lead: CreatureInstance = Content.spawn_creature(
		GameState.STARTER_SPECIES_ID, GameState.STARTER_LEVEL
	)
	var party: Array[CreatureInstance] = [lead]
	var config := BattleConfig.wild(party, foe, Content.type_chart, opening)
	config.rng_seed = 7
	(lesson.prepare as Callable).call(config, foe, party)
	var engine := BattleEngine.new(config)
	engine.start()
	for _turn: int in 12:
		if engine.phase == BattleEngine.Phase.ENDED:
			break
		engine.take_turn(BattleAction.use_move(
			OverworldStrike.best_move_against(lead, foe, Content.type_chart)
		))
	return engine


func test_the_strike_lesson_is_a_fight_the_starter_walks_away_from() -> void:
	var foe: CreatureInstance = Content.spawn_creature(FieldStrike.SPECIES_ID, FieldStrike.LEVEL)
	FieldStrike.wear_down(foe)
	var lead: CreatureInstance = Content.spawn_creature(
		GameState.STARTER_SPECIES_ID, GameState.STARTER_LEVEL
	)
	# The swing lands before the battle, exactly as the overworld lands it.
	foe.set_hp(foe.current_hp - OverworldStrike.player_strike_damage(lead, foe, Content.type_chart))

	var engine: BattleEngine = _play_out(FieldStrike.stage(), foe, BattleConfig.Opening.ADVANTAGE)
	var survivor: Battler = engine.player.battlers[0]

	assert_eq(engine.outcome, BattleEngine.Outcome.VICTORY, "The lesson is won.")
	assert_lte(engine.turn_number, 3, "A worn-down Loambuck does not go the distance.")
	assert_gt(
		float(survivor.creature.current_hp) / float(survivor.creature.max_hp()),
		0.6,
		"A lesson the player nearly dies to has taught them the wrong thing.",
	)


func test_the_ambush_lesson_is_a_fight_the_starter_walks_away_from() -> void:
	var foe: CreatureInstance = Content.spawn_creature(FieldAmbush.SPECIES_ID, FieldAmbush.LEVEL)
	var engine: BattleEngine = _play_out(
		FieldAmbush.stage(), foe, BattleConfig.Opening.DISADVANTAGE
	)
	var survivor: Battler = engine.player.battlers[0]

	assert_eq(engine.outcome, BattleEngine.Outcome.VICTORY, "The lesson is won.")
	assert_gt(
		float(survivor.creature.current_hp) / float(survivor.creature.max_hp()),
		0.6,
		"Being ambushed is a lesson, not a near-death.",
	)


## Both lessons say, in the battle itself, why the first turn went the way it
## did. The banner stands while that turn is being chosen and then goes.
func test_the_opening_turn_is_explained_while_it_is_being_chosen() -> void:
	for pair: Array in [
		[FieldStrike.stage(), BattleConfig.Opening.ADVANTAGE, FieldStrike.SPECIES_ID, FieldStrike.LEVEL],
		[FieldAmbush.stage(), BattleConfig.Opening.DISADVANTAGE, FieldAmbush.SPECIES_ID, FieldAmbush.LEVEL],
	]:
		var lesson: Dictionary = pair[0]
		var lead: CreatureInstance = Content.spawn_creature(
			GameState.STARTER_SPECIES_ID, GameState.STARTER_LEVEL
		)
		var party: Array[CreatureInstance] = [lead]
		var foe: CreatureInstance = Content.spawn_creature(pair[2], pair[3])
		var config := BattleConfig.wild(party, foe, Content.type_chart, pair[1])
		(lesson.prepare as Callable).call(config, foe, party)
		var engine := BattleEngine.new(config)
		var opening: Array[BattleEvent] = engine.start()

		var guide: BattleGuide = lesson.guide
		assert_not_null(guide, "The lesson battle explains itself.")
		assert_string_contains(guide.instruction(engine).to_lower(), "first")
		assert_true(
			config.opening_text.contains(lead.display_name()),
			"The opening names who the blow handed the turn to.",
		)
		var said: String = ""
		for event: BattleEvent in opening:
			if event.kind == BattleEvent.Kind.MESSAGE:
				said += event.text
		assert_string_contains(said, config.opening_text)
		engine.take_turn(BattleAction.use_move(lead.moves[0]))
		assert_eq(guide.instruction(engine), "", "The banner goes once that turn is spent.")


# --- The lessons as the world stages them ---------------------------------------


func _load_main_in_area_one() -> Node2D:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	main.get_node("ScreenTransition").instant = true
	add_child(main)
	main._swap_area(load(AREA_ONE))
	main._wire_area()
	return main


## Plays a staging out: each of the Scout's lines is read past as it arrives,
## the way the interact key does, and the lesson is left waiting on the world.
func _stage(main: Node2D, lines: int) -> WildCreature:
	for _line: int in lines:
		var waited: int = 0
		while not main.dialogue_panel.is_open() and waited < LINE_WAIT_FRAMES:
			waited += 1
			await wait_physics_frames(1)
		assert_true(main.dialogue_panel.is_open(), "The Scout has a line to read past.")
		main._interact()
		await wait_physics_frames(1)
	await wait_seconds(ENTRANCE_WAIT)
	return main._field_lesson.get("creature") as WildCreature


func test_the_strike_lesson_puts_a_quarry_in_the_grass_and_hands_the_world_back() -> void:
	var main: Node2D = _load_main_in_area_one()
	_reach(FieldStrike.QUEST_ID)

	main._play_field_strike()
	var quarry: WildCreature = await _stage(main, FieldStrike.SIGHTING.size())

	assert_not_null(quarry, "The lesson waits on a creature of its own.")
	assert_eq(quarry.species.id, FieldStrike.SPECIES_ID)
	assert_eq(quarry.disposition, WildCreature.Disposition.NEUTRAL, "It is grazing, not hunting.")
	assert_false(main.player.movement_enabled, "The lesson is one key, not a walk.")
	assert_true(main.player.strike_enabled, "And that key is the attack key.")
	assert_true(main.player.strike_covers(quarry.global_position), "It is staged inside reach.")
	assert_true(main._field_lesson_waits_on(quarry, true), "It waits on the player's own swing.")
	assert_false(main._field_lesson_waits_on(quarry, false))


func test_swinging_at_the_quarry_is_what_the_strike_lesson_asked_for() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _reach(FieldStrike.QUEST_ID)

	main._play_field_strike()
	var quarry: WildCreature = await _stage(main, FieldStrike.SIGHTING.size())
	# Nothing is moved into place: the staging already did that.
	await main._strike()

	assert_true(GameState.quests.is_ready(quest), "The swing is the objective.")
	assert_true(main._field_lesson.is_empty(), "A lesson that is answered stops watching.")


func test_the_ambush_lesson_sends_something_hunting_and_counts_its_blow() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _reach(FieldAmbush.QUEST_ID)

	main._play_field_ambush()
	var hunter: WildCreature = await _stage(main, FieldAmbush.CHARGE.size())

	assert_not_null(hunter, "The lesson waits on a creature of its own.")
	assert_eq(hunter.species.id, FieldAmbush.SPECIES_ID)
	assert_eq(hunter.disposition, WildCreature.Disposition.HOSTILE, "It comes to the player.")
	assert_gt(hunter.detection_radius, hunter.global_position.distance_to(main.player.global_position),
		"It notices the player from where it is put.")
	assert_true(main._field_lesson_waits_on(hunter, false), "It waits on the creature's blow.")
	assert_false(main._field_lesson_waits_on(hunter, true))
	assert_true(
		hunter.reached_player.is_connected(main._on_creature_reached_player),
		"A creature staged after the area was wired still reaches the player.",
	)

	main._on_creature_reached_player(hunter)

	assert_true(GameState.quests.is_ready(quest), "Standing still for it is the objective.")
	assert_true(main._field_lesson.is_empty(), "A lesson that is answered stops watching.")


## The rout lesson is the one swing that is meant to end without a battle, so
## what it stages has to be finishable by any lead the player might be on.
func test_the_rout_lesson_stages_something_any_lead_can_finish() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _reach(FieldRout.QUEST_ID)

	main._play_field_rout()
	var spent: WildCreature = await _stage(main, FieldRout.SIGHTING.size())

	assert_not_null(spent, "The lesson waits on a creature of its own.")
	var left: CreatureInstance = spent.encounter_instance()
	assert_lt(left.current_hp, left.max_hp(), "It has already lost a fight.")
	assert_true(
		OverworldStrike.routs(GameState.lead_creature(), left, Content.type_chart),
		"A swing has to be the end of it, whoever the player leads with.",
	)
	assert_true(bool(main._field_lesson.needs_rout), "A swing that leaves it standing is not the lesson.")
	assert_true(main._field_lesson.battle.is_empty(), "No battle is meant to open at all.")

	await main._strike()

	assert_true(GameState.quests.is_ready(quest), "Cutting it down is the objective.")
	assert_false(main.battle_scene.is_active(), "The swing that finishes it opens no battle.")
	assert_true(main._field_lesson.is_empty(), "A lesson that is answered stops watching.")


## The ambush is watched, not done. A stray step or a panicked swing used to
## be able to end the lesson with a freed creature still in its record, which
## crashed the next thing that read it.
func test_the_ambush_lesson_takes_the_players_keys_away() -> void:
	var main: Node2D = _load_main_in_area_one()
	_reach(FieldAmbush.QUEST_ID)

	main._play_field_ambush()
	var hunter: WildCreature = await _stage(main, FieldAmbush.CHARGE.size())

	assert_eq(main.lesson_lock(), main.LOCK_STILL, "Standing still is the whole lesson.")
	assert_false(main.player.movement_enabled, "The player cannot walk out of it.")
	assert_false(main.player.strike_enabled, "And cannot swing first by accident.")
	main._strike()
	await wait_physics_frames(2)
	assert_false(main.battle_scene.is_active(), "The attack key does nothing at all.")
	assert_true(is_instance_valid(hunter), "So the staged creature is still there.")
	assert_true(main._field_lesson_waits_on(hunter, false), "The lesson is still waiting on it.")
	assert_true(main.is_lesson_locked(), "And the menus stay shut with it.")


## Whatever happens to a staged creature, the record must never be left
## holding a freed object: reading one is a crash, not a bug report.
func test_a_staged_creature_cut_down_outside_a_battle_leaves_no_wreckage() -> void:
	var main: Node2D = _load_main_in_area_one()
	_reach(FieldRout.QUEST_ID)

	main._play_field_rout()
	var spent: WildCreature = await _stage(main, FieldRout.SIGHTING.size())
	spent.play_rout()
	await wait_seconds(1.6)

	assert_false(is_instance_valid(spent), "The creature is gone.")
	assert_true(main._field_lesson.is_empty(), "And the lesson went with it.")
	assert_false(main.is_lesson_locked(), "The player has their keys back.")
	assert_true(main.player.movement_enabled)
	# The things that read the record must survive the creature being gone.
	assert_false(main._field_lesson_waits_on(null, true))
	main._settle_field_lesson()
	main._abandon_field_lesson()


## A lesson creature belongs to the camp it was staged in. Walking off leaves
## nothing standing about, and the Scout stages another one when asked again.
func test_leaving_the_area_takes_the_staged_creature_back() -> void:
	var main: Node2D = _load_main_in_area_one()
	_reach(FieldStrike.QUEST_ID)

	main._play_field_strike()
	var quarry: WildCreature = await _stage(main, FieldStrike.SIGHTING.size())
	main._abandon_field_lesson()
	await wait_physics_frames(2)

	assert_true(main._field_lesson.is_empty())
	assert_false(is_instance_valid(quarry), "The practice creature does not outlive its lesson.")


# --- Keys the Scout teaches go through his lines ------------------------------


## Finishes everything before [param id] and leaves it waiting to be offered.
func _ready_to_offer(id: StringName) -> QuestData:
	var earlier: QuestData = _reach(_quest(id).requires)
	for objective: QuestObjective in earlier.objectives:
		for _step: int in objective.required():
			GameState.quests.report(objective.kind, objective.target)
	assert_true(GameState.quests.complete(earlier), "%s can be finished." % earlier.id)
	return _quest(id)


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


## Waits out the quarry's entrance and the deferred swing it gets.
func _await_rushed_swing(main: Node2D) -> void:
	await wait_seconds(ENTRANCE_WAIT)
	var waited: int = 0
	while not main.battle_scene.is_active() and waited < LINE_WAIT_FRAMES:
		waited += 1
		await wait_physics_frames(1)


func test_pressing_f_on_the_strike_offer_takes_the_lesson_and_swings() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _ready_to_offer(FieldStrike.QUEST_ID)

	main._offer(quest)
	await wait_physics_frames(1)
	assert_true(main.dialogue_panel.has_question(), "The Scout is asking.")
	assert_true(main.dialogue_panel.lets_through(main.TAUGHT_ATTACK), "His ask is about the attack key.")

	main._strike()
	await _await_rushed_swing(main)

	assert_true(GameState.quests.is_ready(quest), "Pressing F was a yes, and then the swing itself.")
	assert_true(main.battle_scene.is_active(), "The swing opened the lesson's battle.")
	assert_true(main._rush_key == &"", "Nothing is left waiting on a swing.")


func test_pressing_f_on_a_sighting_line_skips_to_the_swing() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _reach(FieldStrike.QUEST_ID)

	main._play_field_strike()
	await wait_physics_frames(1)
	assert_true(main.dialogue_panel.lets_through(main.TAUGHT_ATTACK), "The Scout's sighting teaches the key.")
	main._strike()
	assert_false(main.dialogue_panel.is_open(), "The rest of his lines are skipped.")
	await _await_rushed_swing(main)

	assert_true(GameState.quests.is_ready(quest), "The swing waited for the quarry, then landed.")


func test_f_is_still_ignored_on_an_ordinary_question() -> void:
	var main: Node2D = _load_main_in_area_one()
	main._ask("Fight?", PackedStringArray(["Yes", "No"]))
	await wait_physics_frames(1)
	main._strike()
	assert_true(main.dialogue_panel.has_question(), "A question nobody is teaching is never swung away from.")


func test_tab_on_the_paddock_lines_opens_the_page_and_the_lesson() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.add_to_party(Content.spawn_creature(&"creature_loambuck", 4))
	var quest: QuestData = _ready_to_offer(KEEPING_QUEST_ID)

	main._offer(quest)
	await wait_physics_frames(1)
	main.field_ui._input(_key(KEY_TAB))

	assert_true(GameState.quests.is_active(quest.id), "Tab on the ask was a yes.")
	assert_eq(main.party_lesson(), KEEPING_QUEST_ID, "The lesson is under way.")
	assert_true(main.field_ui.is_open(), "And the page it is about is open.")
	assert_eq(main.field_ui.page, "party")


func test_other_menu_keys_stay_shut_on_a_teaching_line() -> void:
	var main: Node2D = _load_main_in_area_one()
	var quest: QuestData = _ready_to_offer(KEEPING_QUEST_ID)
	main._offer(quest)
	await wait_physics_frames(1)
	main.field_ui._input(_key(KEY_I))
	assert_false(main.field_ui.is_open(), "Only the key being taught goes through.")
	assert_true(main.dialogue_panel.has_question())


# --- The party-page lessons ----------------------------------------------------


func test_the_paddock_lesson_walks_the_page_one_button_at_a_time() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.add_to_party(Content.spawn_creature(&"creature_loambuck", 4))
	var quest: QuestData = _reach(KEEPING_QUEST_ID)

	main._play_lesson(quest)
	assert_eq(main.lesson_lock(), main.LOCK_PAGE)
	assert_false(main.player.movement_enabled, "The player is held by the fire.")
	assert_false(main.player.strike_enabled)
	assert_eq(PartyLesson.step(quest.id, false), PartyLesson.Step.OPEN_PAGE)

	main.field_ui._input(_key(KEY_J))
	assert_false(main.field_ui.is_open(), "Other pages stay shut.")
	main.field_ui._input(_key(KEY_TAB))
	assert_true(main.field_ui.is_open(), "The party key opens the page.")
	assert_eq(PartyLesson.step(quest.id, true), PartyLesson.Step.SEND_TO_KEEPING)
	assert_true(main.field_ui.nav_buttons["satchel"].disabled, "The rest of the book is shut.")

	main.field_ui._send_to_keeping(1)
	assert_eq(PartyLesson.step(quest.id, true), PartyLesson.Step.CALL_OUT)
	main.field_ui._call_out(0)
	assert_eq(PartyLesson.step(quest.id, true), PartyLesson.Step.DONE)
	assert_true(GameState.quests.is_ready(quest))
	assert_eq(main.party_lesson(), KEEPING_QUEST_ID, "The lesson holds until the page is shut.")

	main.field_ui.close()
	assert_eq(main.party_lesson(), &"", "Shutting the page ends it.")
	assert_eq(main.lesson_lock(), &"")
	assert_true(main.player.movement_enabled, "The player walks again.")


func test_the_lead_lesson_points_at_walk_in_front_only() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.add_to_party(Content.spawn_creature(&"creature_loambuck", 4))
	var quest: QuestData = _reach(LEAD_QUEST_ID)

	main._play_lesson(quest)
	main.field_ui.open_page("party")
	assert_eq(PartyLesson.step(quest.id, true), PartyLesson.Step.TAKE_LEAD)
	var keep_buttons: Array = main.field_ui.body.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == "Send to keeping"
	)
	assert_false(keep_buttons.is_empty())
	for button: Button in keep_buttons:
		assert_true(button.disabled, "Keeping is not this lesson.")

	main.field_ui._take_lead(1)
	assert_true(GameState.quests.is_ready(quest))
	main.field_ui.close()
	assert_eq(main.party_lesson(), &"")


func test_shutting_the_page_early_leaves_the_lesson_waiting() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.add_to_party(Content.spawn_creature(&"creature_loambuck", 4))
	var quest: QuestData = _reach(LEAD_QUEST_ID)

	main._play_lesson(quest)
	main.field_ui.open_page("party")
	main.field_ui.close()
	assert_eq(main.party_lesson(), LEAD_QUEST_ID, "Nothing was done, so the lesson carries on.")
	assert_eq(main.lesson_lock(), main.LOCK_PAGE)
