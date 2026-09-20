extends GutTest
## The Area 1 boss (Specification 5.2, 19): a battle that cannot be fled or
## bound, a challenge that waits for the Scout's quest, a level cap raised on
## victory, and a boss that stays beaten across saves.

const SCRATCH_DIR := "user://gut_scratch/test_boss_battle"
const EMBERLING := &"creature_fire_01"
const OATHBREAKER := &"creature_earth_05"
const BOSS_ID := &"boss_area_01"
const BOSS_QUEST_ID := &"quest_main_03_the_black_knight"
const AREA_ONE := "res://areas/area_one.tscn"

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


func _boss_config() -> BattleConfig:
	var party: Array[CreatureInstance] = [Content.spawn_creature(EMBERLING, 12)]
	var config := BattleConfig.boss(party, Content.spawn_creature(OATHBREAKER, 14), Content.type_chart)
	config.binding_scrolls = 5
	config.rng_seed = 3
	return config


func _load_main_in_area_one() -> Node2D:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main)
	main._swap_area(load(AREA_ONE))
	main._wire_area()
	return main


## Plays the main story up to the boss quest through the real quest chain.
func _reach_the_boss_quest() -> void:
	var log: QuestLog = GameState.quests
	for id: StringName in [
		&"quest_main_01_beyond_the_walls",
		&"quest_main_01a_a_second_oath",
		&"quest_main_01b_field_mending",
		&"quest_main_01c_strike_first",
		&"quest_main_01d_caught_in_the_open",
		&"quest_main_01e_no_battle_at_all",
		&"quest_main_01f_a_bed_at_the_hearthside",
		&"quest_main_01g_a_stocked_satchel",
		&"quest_main_01h_the_road_is_waiting",
		&"quest_main_02_the_ruined_road",
		&"quest_main_02_to_the_ranger",
		&"quest_main_02a_scalded_shallows",
		&"quest_main_02a_to_the_woodcutter",
		&"quest_main_02b_wings_in_the_wood",
		&"quest_main_02b_to_the_warden",
		&"quest_main_02c_the_hollow_watch",
	]:
		var quest: QuestData = Content.get_quest(id)
		assert_true(log.accept(quest), "%s can be accepted." % id)
		for objective: QuestObjective in quest.objectives:
			for _i: int in objective.count:
				log.report(objective.kind, objective.target)
		assert_true(log.complete(quest), "%s can be turned in." % id)
	assert_true(log.accept(Content.get_quest(BOSS_QUEST_ID)))


func _boss_of(main: Node2D) -> WildCreature:
	return main.area.get_node("Actors/BlackKnight") as WildCreature


# --- Battle rules ------------------------------------------------------------


func test_a_boss_battle_can_neither_be_fled_nor_bound() -> void:
	var engine := BattleEngine.new(_boss_config())
	engine.start()
	var options: Dictionary = engine.options()
	assert_false(options["can_run"], "Running is blocked.")
	assert_false(options["can_bind"], "Binding is blocked, even with scrolls in hand.")
	assert_string_contains(String(options["bind_reason"]), "Oathbreaker")


func test_a_boss_is_announced_by_name_rather_than_as_wild() -> void:
	var engine := BattleEngine.new(_boss_config())
	var events: Array[BattleEvent] = engine.start()
	assert_eq(events[0].text, BattleEngine.BOSS_INTRO_TEXT % "Oathbreaker")
	assert_eq(BattleScene.caption_for(engine.config), BattleScene.BOSS_CAPTION)


# --- Progression -------------------------------------------------------------


func test_beating_the_area_one_boss_raises_the_level_cap_once() -> void:
	assert_eq(GameState.level_cap, GameState.INITIAL_LEVEL_CAP)
	var lines: PackedStringArray = GameState.record_boss_defeat(BOSS_ID)
	assert_eq(GameState.level_cap, 30, "Specification 5.2: the first boss opens level 30.")
	assert_eq(lines.size(), 1, "The player is told the cap rose.")
	assert_true(GameState.has_defeated_boss(BOSS_ID))
	assert_eq(GameState.record_boss_defeat(BOSS_ID), PackedStringArray(), "A boss only falls once.")


func test_a_beaten_boss_survives_a_save_and_load() -> void:
	GameState.record_boss_defeat(BOSS_ID)
	assert_true(GameState.save_game(1))
	GameState.new_game()
	assert_false(GameState.has_defeated_boss(BOSS_ID), "A new journey starts with every boss standing.")
	assert_true(GameState.load_game(1))
	assert_true(GameState.has_defeated_boss(BOSS_ID))
	assert_eq(GameState.level_cap, 30)


func test_the_boss_quest_follows_the_hollow_watch() -> void:
	var quest: QuestData = Content.get_quest(BOSS_QUEST_ID)
	assert_not_null(quest)
	assert_true(quest.is_main())
	assert_eq(quest.requires, &"quest_main_02c_the_hollow_watch")
	assert_eq(quest.giver, &"warden")
	assert_eq(quest.objectives[0].target, OATHBREAKER)


# --- In the field ------------------------------------------------------------


func test_area_one_places_the_boss_at_the_altar() -> void:
	var main: Node2D = _load_main_in_area_one()
	var boss: WildCreature = _boss_of(main)
	assert_true(boss.is_boss())
	assert_eq(boss.boss_id, BOSS_ID)
	assert_eq(boss.species.id, OATHBREAKER)
	assert_eq(boss.required_quest, BOSS_QUEST_ID)
	assert_true(Content.has_quest(boss.required_quest))


func test_the_boss_will_not_fight_until_its_quest_is_active() -> void:
	var main: Node2D = _load_main_in_area_one()
	var boss: WildCreature = _boss_of(main)
	main._challenge_boss(boss)
	assert_false(main.dialogue_panel.is_asking(), "No challenge is offered yet.")
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(boss.sealed_line))
	assert_false(main.battle_scene.is_active())


func test_the_boss_lets_the_player_walk_away_from_the_challenge() -> void:
	_reach_the_boss_quest()
	assert_true(GameState.quests.is_active(BOSS_QUEST_ID))
	var main: Node2D = _load_main_in_area_one()
	var boss: WildCreature = _boss_of(main)
	main._challenge_boss(boss)
	assert_true(main.dialogue_panel.is_asking(), "The knight puts the challenge.")
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(boss.challenge_line))
	main.dialogue_panel._confirm(1)
	await get_tree().process_frame
	assert_false(main.dialogue_panel.is_open(), "Not yet closes the line.")
	assert_false(main.battle_scene.is_active(), "No battle starts.")


func test_a_beaten_boss_is_gone_when_the_area_loads() -> void:
	GameState.record_boss_defeat(BOSS_ID)
	var main: Node2D = _load_main_in_area_one()
	var boss: WildCreature = _boss_of(main)
	assert_true(boss.was_defeated)
	assert_false(boss.is_interactable())
	assert_false(boss.visible)


func test_losing_to_the_boss_restores_it_for_the_next_attempt() -> void:
	var main: Node2D = _load_main_in_area_one()
	var boss: WildCreature = _boss_of(main)
	var instance: CreatureInstance = boss.encounter_instance()
	instance.set_hp(1)
	boss.restore_encounter()
	assert_eq(boss.encounter_instance().current_hp, boss.encounter_instance().max_hp())
