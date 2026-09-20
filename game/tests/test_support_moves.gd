extends GutTest
## Support moves that land on the user's own party, benched or fighting, and
## the guided "Field Mending" battle that teaches them.

const SCENE: PackedScene = preload("res://scenes/battle_scene.tscn")
const EMBERLING := &"creature_fire_01"
const LOAMBUCK := &"creature_earth_01"
const MEND := &"move_mend_01"
const BOLSTER := &"move_bolster_01"
const ALWAYS := 0.0


func before_each() -> void:
	GameState.new_game()


func _mend() -> MoveData:
	return Content.get_move(MEND)


## Loambuck fighting, Emberling hurt on the bench.
func _loambuck_leading(enemy_level: int = 3) -> BattleEngine:
	var party: Array[CreatureInstance] = [
		Content.spawn_creature(LOAMBUCK, 5), Content.spawn_creature(EMBERLING, 7)
	]
	party[1].set_hp(5)
	var config := BattleConfig.wild(
		party, Content.spawn_creature(EMBERLING, enemy_level), Content.type_chart
	)
	config.rng_seed = 11
	var engine := BattleEngine.new(config)
	engine.start()
	return engine


func _first(
	events: Array[BattleEvent], kind: BattleEvent.Kind, side: int = BattleTeam.Side.PLAYER
) -> BattleEvent:
	for event: BattleEvent in events:
		if event.kind == kind and event.side == side:
			return event
	return null


# --- Content -----------------------------------------------------------------


func test_loambuck_is_a_healer_and_buffer() -> void:
	var young: CreatureInstance = Content.spawn_creature(LOAMBUCK, 3)
	assert_true(young.knows_move(_mend()), "A wild Loambuck can already mend.")
	var grown: CreatureInstance = Content.spawn_creature(LOAMBUCK, 5)
	assert_true(grown.knows_move(Content.get_move(BOLSTER)), "Bolster comes at level 5.")
	assert_true(_mend().targets_ally())
	assert_true(_mend().heals())
	assert_eq(_mend().validate(), [] as Array[String])
	assert_eq(Content.get_move(BOLSTER).validate(), [] as Array[String])


func test_heal_amount_is_a_share_of_max_hp_capped_by_what_is_missing() -> void:
	var target: CreatureInstance = Content.spawn_creature(EMBERLING, 7)
	assert_eq(BattleRules.heal_amount(_mend(), target), 0, "Nothing to heal at full HP.")
	target.set_hp(1)
	var share: int = int(ceil(target.max_hp() * _mend().heal_percent / 100.0))
	assert_eq(BattleRules.heal_amount(_mend(), target), share)
	target.set_hp(target.max_hp() - 2)
	assert_eq(BattleRules.heal_amount(_mend(), target), 2)


# --- Engine ------------------------------------------------------------------


func test_a_healer_mends_a_benched_ally() -> void:
	var engine := _loambuck_leading()
	var benched: CreatureInstance = engine.player.battlers[1].creature
	var before: int = benched.current_hp
	var events := engine.take_turn(BattleAction.use_move(_mend(), 1))
	var healed := _first(events, BattleEvent.Kind.HEALED)
	assert_not_null(healed, "The heal is reported.")
	assert_eq(int(healed.data["target_index"]), 1)
	assert_false(bool(healed.data["on_field"]), "The ally was on the bench.")
	assert_eq(benched.current_hp, before + int(healed.data["amount"]))
	assert_gt(benched.current_hp, before)
	assert_string_contains(_first(events, BattleEvent.Kind.MOVE_USED).text, "on Emberling")
	assert_eq(engine.player.active_index, 0, "Healing does not switch anyone in.")


func test_a_support_move_never_misses() -> void:
	var engine := _loambuck_leading()
	engine.forced_roll = 0.999
	var events := engine.take_turn(BattleAction.use_move(_mend(), 1))
	# A miss is reported on the side that was aimed at.
	assert_null(_first(events, BattleEvent.Kind.MISSED, BattleTeam.Side.ENEMY))
	assert_not_null(_first(events, BattleEvent.Kind.HEALED))


func test_a_fainted_ally_cannot_be_targeted() -> void:
	var engine := _loambuck_leading()
	engine.player.battlers[1].creature.set_hp(0)
	var events := engine.take_turn(BattleAction.use_move(_mend(), 1))
	assert_eq(events.size(), 1, "The turn is refused.")
	assert_eq(engine.turn_number, 0)


func test_no_target_means_the_user_itself() -> void:
	var engine := _loambuck_leading()
	# Hurt, but not so close to fainting that the foe's turn could end it
	# before the mend lands.
	engine.player.active().creature.set_hp(30)
	var events := engine.take_turn(BattleAction.use_move(_mend()))
	var healed := _first(events, BattleEvent.Kind.HEALED)
	assert_eq(int(healed.data["target_index"]), 0)
	assert_true(bool(healed.data["on_field"]))


func test_a_buff_on_a_benched_ally_is_waiting_when_it_comes_in() -> void:
	var engine := _loambuck_leading()
	engine.player.battlers[1].creature.heal_full()
	engine.take_turn(BattleAction.use_move(Content.get_move(BOLSTER), 1))
	var emberling: Battler = engine.player.battlers[1]
	assert_true(emberling.has_modifier_for(Stats.Stat.ATTACK))
	assert_false(engine.player.active().has_modifier_for(Stats.Stat.ATTACK))
	engine.take_turn(BattleAction.switch_to(1))
	assert_gt(emberling.stat_percent(Stats.Stat.ATTACK), 100)


func test_the_enemy_heals_itself_when_badly_hurt() -> void:
	# A sturdy earth foe, so the Loambuck's own attack is not worth more.
	var config := BattleConfig.wild(
		[Content.spawn_creature(LOAMBUCK, 20)] as Array[CreatureInstance],
		Content.spawn_creature(LOAMBUCK, 3),
		Content.type_chart,
	)
	var engine := BattleEngine.new(config)
	engine.start()
	engine.enemy.active().creature.set_hp(2)
	var action: BattleAction = engine.ai.choose_action(engine)
	assert_eq(action.move, _mend())
	engine.enemy.active().creature.heal_full()
	assert_eq(
		engine.ai._support_score(_mend(), engine.enemy.active()),
		BattleAI.USELESS_SCORE,
		"A heal at full HP is worth nothing.",
	)


# --- Binding -----------------------------------------------------------------


func test_a_healthy_creature_binds_at_its_species_rate_and_a_spent_one_at_95() -> void:
	var loambuck: CreatureInstance = Content.spawn_creature(LOAMBUCK, 3)
	assert_almost_eq(BattleRules.bind_chance(loambuck), loambuck.species.base_bind_chance, 0.0001)
	assert_almost_eq(BattleRules.bind_chance(loambuck), 0.4, 0.0001)
	loambuck.set_hp(1)
	assert_gt(BattleRules.bind_chance(loambuck), 0.85)
	loambuck.set_hp(loambuck.max_hp() / 2)
	assert_between(BattleRules.bind_chance(loambuck), 0.6, 0.75)


# --- The Field Mending lesson ------------------------------------------------


func _lesson_party() -> Array[CreatureInstance]:
	return [Content.spawn_creature(EMBERLING, 7), Content.spawn_creature(LOAMBUCK, 3)]


func test_roles_pick_the_healer_and_the_striker() -> void:
	var party := _lesson_party()
	var cast: Dictionary = FieldMending.roles(party)
	assert_eq(cast.striker, party[0])
	assert_eq(cast.healer, party[1])
	assert_eq(cast.mend, _mend())
	assert_eq(FieldMending.roles([party[0]] as Array[CreatureInstance]), {}, "No healer, no lesson.")


func _lesson_engine(seed: int) -> Dictionary:
	var staged: Dictionary = FieldMending.stage(FieldMending.roles(_lesson_party()))
	var enemy: CreatureInstance = Content.spawn_creature(
		FieldMending.ENEMY_SPECIES_ID, FieldMending.ENEMY_LEVEL, 0
	)
	FieldMending.wear_down(enemy)
	var config := BattleConfig.wild(staged.party, enemy, Content.type_chart)
	FieldMending.prepare(config, "Emberling")
	config.rng_seed = seed
	var engine := BattleEngine.new(config)
	engine.start()
	return {"engine": engine, "guide": staged.guide}


func test_the_lesson_walks_switch_mend_switch_finish_and_nobody_faints() -> void:
	for seed: int in 40:
		var run: Dictionary = _lesson_engine(seed)
		var engine: BattleEngine = run.engine
		var guide: SupportTutorialGuide = run.guide
		assert_eq(guide.step(engine), SupportTutorialGuide.Step.TO_HEALER)
		assert_false(guide.allows_command(engine, BattleGuide.FIGHT))
		assert_false(guide.allows_command(engine, BattleGuide.BIND))
		assert_true(guide.allows_command(engine, BattleGuide.SWITCH))
		guide.observe(engine, engine.take_turn(BattleAction.switch_to(1)))

		assert_eq(guide.step(engine), SupportTutorialGuide.Step.MEND)
		assert_true(guide.allows_target(engine, _mend(), 0))
		assert_false(guide.allows_target(engine, _mend(), 1), "Aim it at the benched striker.")
		guide.observe(engine, engine.take_turn(BattleAction.use_move(_mend(), 0)))
		assert_true(guide.has_mended())

		assert_eq(guide.step(engine), SupportTutorialGuide.Step.TO_STRIKER)
		guide.observe(engine, engine.take_turn(BattleAction.switch_to(0)))

		var turns: int = 0
		while engine.phase == BattleEngine.Phase.CHOOSING and turns < 6:
			assert_eq(guide.step(engine), SupportTutorialGuide.Step.FINISH)
			var attack: MoveData = null
			for move: MoveData in engine.player.active().ready_moves():
				if move.is_damaging():
					attack = move
					break
			guide.observe(engine, engine.take_turn(BattleAction.use_move(attack)))
			turns += 1
		assert_eq(engine.outcome, BattleEngine.Outcome.VICTORY, "Seed %d is won." % seed)
		assert_lte(turns, 2, "Seed %d: the striker finishes it quickly." % seed)
		for battler: Battler in engine.player.battlers:
			assert_false(battler.is_fainted(), "Seed %d: nobody faints in the lesson." % seed)


func test_the_battle_screen_only_offers_what_the_lesson_wants() -> void:
	var scene: BattleScene = SCENE.instantiate()
	scene.skip_presentation = true
	add_child_autofree(scene)
	var staged: Dictionary = FieldMending.stage(FieldMending.roles(_lesson_party()))
	var enemy: CreatureInstance = Content.spawn_creature(EMBERLING, 3, 0)
	var config := BattleConfig.wild(staged.party, enemy, Content.type_chart)
	config.rng_seed = 5
	FieldMending.prepare(config, "Emberling")
	scene.start_battle(config, staged.guide)
	await wait_frames(2)

	assert_eq(scene.current_menu(), BattleScene.Menu.COMMAND)
	assert_string_contains(scene.guide_text(), "SWITCH")
	scene.press_entry(0)
	assert_eq(scene.current_menu(), BattleScene.Menu.COMMAND, "FIGHT is held back.")
	scene.press_entry(1)
	assert_eq(scene.current_menu(), BattleScene.Menu.PARTY)
	scene.press_entry(1)
	await wait_frames(2)

	assert_string_contains(scene.guide_text(), "Mend")
	scene.press_entry(0)
	assert_eq(scene.current_menu(), BattleScene.Menu.MOVES)
	var labels: PackedStringArray = scene.menu_labels()
	scene.press_entry(labels.find("Mend"))
	assert_eq(scene.current_menu(), BattleScene.Menu.TARGET, "A support move asks who it is for.")
	scene.press_entry(1)
	assert_eq(scene.current_menu(), BattleScene.Menu.TARGET, "The healer itself is held back.")
	scene.press_entry(0)
	await wait_frames(2)

	assert_string_contains(scene.guide_text(), "SWITCH back")
	scene.press_entry(1)
	scene.press_entry(0)
	await wait_frames(2)
	assert_string_contains(scene.guide_text(), "finish")


# --- Quests ------------------------------------------------------------------


func test_a_loambuck_already_in_the_party_counts_for_the_bind_quest() -> void:
	GameState.add_to_party(Content.spawn_creature(LOAMBUCK, 3))
	var quest: QuestData = Content.get_quest(&"quest_main_01a_a_second_oath")
	GameState.quests.accept(Content.get_quest(&"quest_main_01_beyond_the_walls"))
	for objective: QuestObjective in Content.get_quest(&"quest_main_01_beyond_the_walls").objectives:
		GameState.quests.report(objective.kind, objective.target)
	GameState.quests.complete(Content.get_quest(&"quest_main_01_beyond_the_walls"))
	assert_true(GameState.accept_quest(quest))
	assert_true(GameState.quests.is_ready(quest), "No second Loambuck is needed.")


func test_winning_the_lesson_readies_its_quest() -> void:
	var log: QuestLog = GameState.quests
	for id: StringName in [
		&"quest_main_01_beyond_the_walls",
		&"quest_main_01a_a_second_oath",
		&"quest_main_01b_room_for_more",
	]:
		var quest: QuestData = Content.get_quest(id)
		log.accept(quest)
		for objective: QuestObjective in quest.objectives:
			log.report(objective.kind, objective.target)
		assert_true(log.complete(quest))
	var lesson: QuestData = Content.get_quest(FieldMending.QUEST_ID)
	assert_true(log.can_offer(lesson))
	log.accept(lesson)
	GameState.report_quest_event(QuestObjective.Kind.EVENT, FieldMending.EVENT_ID)
	assert_true(log.is_ready(lesson))
	var next_lesson: QuestData = Content.get_quest(&"quest_main_01d_who_walks_in_front")
	assert_true(log.can_offer(next_lesson) == false)
	log.complete(lesson)
	assert_true(log.can_offer(next_lesson))


# --- The binding lesson ------------------------------------------------------


func _binding_engine(lead_level: int, seed: int) -> Dictionary:
	var party: Array[CreatureInstance] = [Content.spawn_creature(EMBERLING, lead_level)]
	var enemy: CreatureInstance = Content.spawn_creature(
		FieldBinding.SPECIES_ID, FieldBinding.LEVEL, 0
	)
	var lesson: Dictionary = FieldBinding.stage()
	var config := BattleConfig.wild(party, enemy, Content.type_chart)
	config.binding_scrolls = 5
	config.rng_seed = seed
	(lesson.prepare as Callable).call(config, enemy, party)
	var engine := BattleEngine.new(config)
	engine.start()
	return {"engine": engine, "guide": lesson.guide}


func test_the_lesson_loambuck_keeps_mend_but_never_uses_it() -> void:
	var run: Dictionary = _binding_engine(7, 1)
	var engine: BattleEngine = run.engine
	var loambuck: CreatureInstance = engine.enemy.active().creature
	assert_true(loambuck.knows_move(_mend()), "Once bound it is the player's healer.")
	loambuck.set_hp(2)
	assert_ne(engine.ai.choose_action(engine).move, _mend(), "In the lesson it only attacks.")


func test_the_lesson_scroll_always_takes() -> void:
	var run: Dictionary = _binding_engine(7, 1)
	var engine: BattleEngine = run.engine
	engine.forced_roll = 0.999
	assert_eq(engine.bind_chance(), 1.0)
	engine.take_turn(BattleAction.bind())
	assert_eq(engine.outcome, BattleEngine.Outcome.BOUND)
	var bound: CreatureInstance = engine.bound_creature
	assert_false(FieldMending.roles([Content.spawn_creature(EMBERLING, 7), bound] as Array[CreatureInstance]).is_empty(), "The bound Loambuck can teach the next lesson.")


func test_the_binding_lesson_is_weaken_then_bind_at_any_lead_level() -> void:
	for lead_level: int in range(7, 17):
		for seed: int in 10:
			var run: Dictionary = _binding_engine(lead_level, seed)
			var engine: BattleEngine = run.engine
			var guide: BindTutorialGuide = run.guide
			assert_eq(guide.step(engine), BindTutorialGuide.Step.WEAKEN)
			assert_true(guide.allows_command(engine, BattleGuide.FIGHT))
			assert_false(guide.allows_command(engine, BattleGuide.BIND), "No scroll on a fresh one.")
			var attacks: int = 0
			while guide.step(engine) == BindTutorialGuide.Step.WEAKEN and attacks < 8:
				var attack: MoveData = null
				for move: MoveData in engine.player.active().ready_moves():
					if move.is_damaging():
						attack = move
						break
				engine.take_turn(BattleAction.use_move(attack))
				attacks += 1
			assert_false(
				engine.enemy.active().is_fainted(),
				"Lead Lv %d seed %d: wearing it down never knocks it out." % [lead_level, seed],
			)
			assert_eq(guide.step(engine), BindTutorialGuide.Step.BIND)
			assert_false(guide.allows_command(engine, BattleGuide.FIGHT))
			engine.take_turn(BattleAction.bind())
			assert_eq(engine.outcome, BattleEngine.Outcome.BOUND, "Lv %d seed %d is bound." % [lead_level, seed])


# --- Turn-ins and idle lines -------------------------------------------------


func test_finding_the_scout_is_handed_in_to_the_scout() -> void:
	var quest: QuestData = Content.get_quest(&"quest_main_01_beyond_the_walls")
	assert_eq(quest.giver, &"elder")
	assert_eq(quest.turn_in_actor(), &"scout")
	var log := QuestLog.new(Content)
	log.accept(quest)
	for objective: QuestObjective in quest.objectives:
		log.report(objective.kind, objective.target)
	var area: Node = autofree((load("res://areas/area_one.tscn") as PackedScene).instantiate())
	var scout: WorldActor = area.get_node("Actors/Scout")
	var town: Node = autofree((load("res://areas/town.tscn") as PackedScene).instantiate())
	var elder: WorldActor = town.get_node("Actors/Elder")
	assert_eq(scout.current_quest(log, Content), quest, "The Scout takes it in.")
	assert_eq(scout.quest_marker(log, Content).marker, WorldActor.QuestMarker.TURN_IN)
	assert_ne(elder.quest_marker(log, Content).marker, WorldActor.QuestMarker.TURN_IN)


func test_the_scout_points_to_the_ranger_once_the_road_is_clear() -> void:
	var log := QuestLog.new(Content)
	for id: StringName in [
		&"quest_main_01_beyond_the_walls",
		&"quest_main_01a_a_second_oath",
		&"quest_main_01b_room_for_more",
		&"quest_main_01c_field_mending",
		&"quest_main_01d_who_walks_in_front",
		&"quest_main_01e_strike_first",
		&"quest_main_01f_caught_in_the_open",
		&"quest_main_01g_no_battle_at_all",
		&"quest_main_01h_a_bed_at_the_hearthside",
		&"quest_main_01i_a_stocked_satchel",
		&"quest_main_01j_the_road_is_waiting",
		&"quest_main_02_the_ruined_road",
		&"quest_main_02_to_the_ranger",
	]:
		var quest: QuestData = Content.get_quest(id)
		log.accept(quest)
		for objective: QuestObjective in quest.objectives:
			for _i: int in objective.required():
				log.report(objective.kind, objective.target)
		log.complete(quest)
	var area: Node = autofree((load("res://areas/area_one.tscn") as PackedScene).instantiate())
	var scout: WorldActor = area.get_node("Actors/Scout")
	assert_null(scout.current_quest(log, Content))
	assert_string_contains(scout.idle_line(log, Content), "Ranger")
	assert_string_contains(Content.get_quest(&"quest_main_02_the_ruined_road").complete_line, "north-east")
