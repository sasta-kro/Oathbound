extends GutTest
## Quests (Specification 17): the log's rules, the rewards GameState pays,
## the save round trip, the shipped quest content, and the dialogue that
## offers, turns in and drops a quest in the field.

const SCRATCH_DIR := "user://gut_scratch/test_quest_system"
const MAIN_QUEST_ID := &"quest_main_01_beyond_the_walls"
const SECOND_MAIN_QUEST_ID := &"quest_main_02_the_ruined_road"
const CHILD_QUEST_ID := &"quest_side_leaf_hat"
const MERCHANT_QUEST_ID := &"quest_side_the_crossing"
const AREA_ONE := "res://areas/area_one.tscn"

var _original_dir: String
var _log: QuestLog


func before_each() -> void:
	_original_dir = SaveService.save_dir
	SaveService.save_dir = SCRATCH_DIR
	SaveService.erase_all()
	GameState.new_game()
	_log = GameState.quests


func after_each() -> void:
	SaveService.erase_all()
	SaveService.save_dir = _original_dir
	GameState.new_game()
	await get_tree().process_frame


func _objective(kind: QuestObjective.Kind, target: StringName, count: int = 1) -> QuestObjective:
	var objective := QuestObjective.new()
	objective.kind = kind
	objective.target = target
	objective.count = count
	objective.description = "%s %s x%d" % [objective.kind_name(), target, count]
	return objective


func _quest(id: StringName, objectives: Array[QuestObjective], requires: StringName = &"") -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id).capitalize()
	quest.giver = &"tester"
	quest.offer_line = "Will you?"
	quest.requires = requires
	quest.objectives = objectives
	return quest


func _content(id: StringName) -> QuestData:
	var quest: QuestData = Content.get_quest(id)
	assert_not_null(quest, "The shipped quest %s must load." % id)
	return quest


# --- Content -----------------------------------------------------------------


func test_shipped_quests_load_and_validate() -> void:
	assert_true(Content.has_quest(MAIN_QUEST_ID))
	assert_true(Content.has_quest(SECOND_MAIN_QUEST_ID))
	assert_true(Content.has_quest(CHILD_QUEST_ID))
	assert_true(Content.has_quest(MERCHANT_QUEST_ID))
	assert_eq(Content.validate(), [] as Array[String], "Quest content must reference real species, areas and quests.")
	assert_true(_content(MAIN_QUEST_ID).is_main())
	assert_false(_content(CHILD_QUEST_ID).is_main())
	assert_eq(_content(SECOND_MAIN_QUEST_ID).requires, MAIN_QUEST_ID, "The main story is a chain.")


func test_the_game_stays_playable_with_no_quests_at_all() -> void:
	var empty := QuestLog.new(Content)
	assert_eq(empty.active_quests(), [] as Array[QuestData])
	assert_eq(empty.completed_quests(), [] as Array[QuestData])
	assert_eq(empty.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01"), [] as Array[Dictionary])
	assert_eq(empty.to_dict(), {})


func test_validation_catches_a_broken_quest() -> void:
	var broken := _quest(&"quest_broken", [_objective(QuestObjective.Kind.DEFEAT, &"creature_nope")], &"quest_missing")
	broken.title = ""
	var problems: Array[String] = broken.validate(Content)
	assert_eq(problems.size(), 3, "No title, unknown species and unknown prerequisite: %s" % [problems])


# --- The log's rules ---------------------------------------------------------


func test_a_quest_starts_new_and_only_counts_after_acceptance() -> void:
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.DEFEAT, &"creature_fire_01", 2)])
	assert_eq(_log.status(quest.id), QuestLog.Status.NEW)
	assert_true(_log.can_offer(quest))

	assert_eq(_log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01").size(), 0, "Nothing counts before acceptance.")
	assert_true(_log.accept(quest))
	assert_eq(_log.status(quest.id), QuestLog.Status.ACTIVE)
	assert_eq(_log.progress(quest, 0), 0)
	assert_false(_log.can_offer(quest), "An active quest is not offered again.")
	assert_false(_log.accept(quest), "Nor accepted twice.")


func test_events_advance_the_matching_objective_until_it_is_met() -> void:
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.DEFEAT, &"creature_fire_01", 2), _objective(QuestObjective.Kind.TALK, &"scout")])
	_log.accept(quest)

	var steps: Array[Dictionary] = _log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01")
	assert_eq(steps.size(), 1)
	assert_eq(steps[0].index, 0)
	assert_false(steps[0].done)
	assert_eq(_log.report(QuestObjective.Kind.DEFEAT, &"creature_earth_01").size(), 0, "The wrong species does not count.")
	assert_eq(_log.report(QuestObjective.Kind.BIND, &"creature_fire_01").size(), 0, "Nor the wrong kind of event.")
	steps = _log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01")
	assert_true(steps[0].done)
	assert_eq(_log.progress(quest, 0), 2)
	assert_false(_log.is_ready(quest), "The talk is still owed.")
	assert_eq(_log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01").size(), 0, "A met objective stops counting.")
	assert_eq(_log.progress(quest, 0), 2)

	_log.report(QuestObjective.Kind.TALK, &"scout")
	assert_true(_log.is_ready(quest))
	assert_true(_log.complete(quest))
	assert_eq(_log.status(quest.id), QuestLog.Status.COMPLETED)
	assert_false(_log.can_offer(quest), "Done is done.")


func test_a_quest_cannot_be_turned_in_early() -> void:
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.REACH, StringName(AREA_ONE))])
	assert_false(_log.complete(quest), "Not even accepted.")
	_log.accept(quest)
	assert_false(_log.complete(quest), "Accepted but not done.")
	assert_eq(_log.status(quest.id), QuestLog.Status.ACTIVE)


func test_one_action_progresses_every_quest_that_asks_for_it() -> void:
	var first := _quest(&"q1", [_objective(QuestObjective.Kind.DEFEAT, &"creature_fire_01")])
	var second := _quest(&"q2", [_objective(QuestObjective.Kind.DEFEAT, &"creature_fire_01", 3)])
	_log.accept(first)
	_log.accept(second)

	var steps: Array[Dictionary] = _log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01")
	assert_eq(steps.size(), 2)
	assert_true(_log.is_ready(first))
	assert_eq(_log.progress(second, 0), 1)


func test_refusing_leaves_the_quest_offerable_and_remembered() -> void:
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.TALK, &"scout")])
	assert_false(_log.was_declined(quest.id))
	assert_true(_log.refuse(quest))
	assert_eq(_log.status(quest.id), QuestLog.Status.REFUSED)
	assert_true(_log.was_declined(quest.id), "So the giver can ask whether the player changed their mind.")
	assert_true(_log.can_offer(quest))
	assert_true(_log.accept(quest))
	assert_eq(_log.status(quest.id), QuestLog.Status.ACTIVE)


func test_abandoning_resets_progress_and_allows_reacceptance() -> void:
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.DEFEAT, &"creature_fire_01", 3)])
	assert_false(_log.abandon(quest), "Only an active quest can be dropped.")
	_log.accept(quest)
	_log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01")
	_log.report(QuestObjective.Kind.DEFEAT, &"creature_fire_01")
	assert_eq(_log.progress(quest, 0), 2)

	assert_true(_log.abandon(quest))
	assert_eq(_log.status(quest.id), QuestLog.Status.ABANDONED)
	assert_true(_log.was_declined(quest.id))
	assert_eq(_log.active_quests(), [] as Array[QuestData])
	assert_true(_log.accept(quest))
	assert_eq(_log.progress(quest, 0), 0, "Objectives count only while the quest is accepted.")


func test_a_chained_quest_waits_for_the_one_before_it() -> void:
	var first := _quest(&"q1", [_objective(QuestObjective.Kind.TALK, &"scout")])
	var second := _quest(&"q2", [_objective(QuestObjective.Kind.TALK, &"scout")], &"q1")
	assert_false(_log.can_offer(second))
	assert_false(_log.accept(second))
	_log.accept(first)
	assert_false(_log.can_offer(second), "Accepting is not completing.")
	_log.report(QuestObjective.Kind.TALK, &"scout")
	_log.complete(first)
	assert_true(_log.can_offer(second))


func test_active_quests_list_the_main_story_first() -> void:
	GameState.accept_quest(_content(CHILD_QUEST_ID))
	GameState.accept_quest(_content(MAIN_QUEST_ID))
	GameState.accept_quest(_content(MERCHANT_QUEST_ID))
	var active: Array[QuestData] = _log.active_quests()
	assert_eq(active.size(), 3)
	assert_eq(active[0].id, MAIN_QUEST_ID)
	assert_eq(active[1].id, CHILD_QUEST_ID)
	assert_eq(active[2].id, MERCHANT_QUEST_ID)


# --- GameState: rewards, signals, saves --------------------------------------


func test_completing_a_quest_pays_its_rewards_once() -> void:
	watch_signals(GameState)
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.TALK, &"scout")])
	quest.reward_currency = 40
	quest.reward_binding_scrolls = 2
	quest.reward_xp = 10
	var coins_before: int = GameState.currency
	var scrolls_before: int = GameState.binding_scrolls
	var xp_before: int = GameState.party[0].total_xp

	assert_eq(GameState.complete_quest(quest), PackedStringArray(), "Nothing is paid for a quest that is not ready.")
	assert_true(GameState.accept_quest(quest))
	assert_signal_emitted_with_parameters(GameState, "quest_changed", [quest, QuestLog.Status.ACTIVE])
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	assert_signal_emitted_with_parameters(GameState, "quest_objective_advanced", [quest, 0, true])

	var lines: PackedStringArray = GameState.complete_quest(quest)
	assert_eq(GameState.currency, coins_before + 40)
	assert_eq(GameState.binding_scrolls, scrolls_before + 2)
	assert_eq(GameState.party[0].total_xp, xp_before + 10)
	assert_true("+40 coins" in lines)
	assert_true("+2 Binding Scrolls" in lines)
	assert_signal_emitted_with_parameters(GameState, "quest_changed", [quest, QuestLog.Status.COMPLETED])
	assert_eq(GameState.complete_quest(quest), PackedStringArray(), "Rewards are paid once.")
	assert_eq(GameState.currency, coins_before + 40)


func test_quest_state_survives_a_save_and_load() -> void:
	var main_quest := _content(MAIN_QUEST_ID)
	var child_quest := _content(CHILD_QUEST_ID)
	var merchant_quest := _content(MERCHANT_QUEST_ID)
	GameState.accept_quest(main_quest)
	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(AREA_ONE))
	GameState.refuse_quest(child_quest)
	GameState.accept_quest(merchant_quest)
	GameState.report_quest_event(QuestObjective.Kind.DEFEAT, &"creature_water_01")
	assert_true(GameState.save_game(1))

	GameState.new_game()
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.NEW, "A new game forgets every quest.")
	assert_true(GameState.load_game(1))
	_log = GameState.quests
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.ACTIVE)
	assert_true(_log.is_objective_done(main_quest, 0), "The meadow was reached.")
	assert_false(_log.is_objective_done(main_quest, 1), "The scout was not.")
	assert_eq(_log.status(CHILD_QUEST_ID), QuestLog.Status.REFUSED)
	assert_eq(_log.progress(merchant_quest, 0), 1)


func test_a_save_naming_a_quest_that_no_longer_exists_loads_without_it() -> void:
	var data: Dictionary = GameState.to_dict()
	data["quests"] = {
		"quest_that_was_cut": {"status": QuestLog.Status.ACTIVE, "progress": [1]},
		String(MAIN_QUEST_ID): {"status": QuestLog.Status.COMPLETED, "progress": [1]},
		String(CHILD_QUEST_ID): {"status": 99, "progress": []},
	}
	GameState.from_dict(data)
	assert_eq(_log.active_quests(), [] as Array[QuestData])
	assert_true(_log.is_completed(MAIN_QUEST_ID))
	assert_true(_log.is_objective_done(_content(MAIN_QUEST_ID), 1), "Progress is resized to the quest's objectives.")
	assert_eq(_log.status(CHILD_QUEST_ID), QuestLog.Status.NEW, "A nonsense status is dropped.")


# --- Actors and the field ----------------------------------------------------


func test_an_actor_talks_about_the_quest_that_matters_most() -> void:
	var actor := WorldActor.new()
	actor.name = "Elder"
	actor.quest_ids = [MAIN_QUEST_ID, CHILD_QUEST_ID]
	assert_eq(actor.actor_id(), &"elder")
	assert_eq(actor.current_quest(_log, Content).id, MAIN_QUEST_ID, "The first offerable quest.")
	GameState.accept_quest(_content(CHILD_QUEST_ID))
	assert_eq(actor.current_quest(_log, Content).id, CHILD_QUEST_ID, "One in progress comes before a new offer.")
	GameState.accept_quest(_content(MAIN_QUEST_ID))
	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(AREA_ONE))
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	assert_eq(actor.current_quest(_log, Content).id, MAIN_QUEST_ID, "One ready to turn in comes first of all.")
	GameState.complete_quest(_content(MAIN_QUEST_ID))
	GameState.report_quest_event(QuestObjective.Kind.BIND, &"creature_earth_01")
	GameState.complete_quest(_content(CHILD_QUEST_ID))
	assert_null(actor.current_quest(_log, Content), "Everything done: small talk only.")
	actor.free()


func test_the_town_npcs_carry_their_quests() -> void:
	var town: Node = autofree((load("res://areas/town.tscn") as PackedScene).instantiate())
	var elder: WorldActor = town.get_node("Actors/Elder")
	assert_eq(elder.quest_ids, [MAIN_QUEST_ID] as Array[StringName])
	assert_eq((town.get_node("Actors/Child") as WorldActor).quest_ids, [CHILD_QUEST_ID] as Array[StringName])
	assert_eq((town.get_node("Actors/Merchant") as WorldActor).quest_ids, [MERCHANT_QUEST_ID] as Array[StringName])
	var meadow: Node = autofree((load(AREA_ONE) as PackedScene).instantiate())
	assert_eq((meadow.get_node("Actors/Scout") as WorldActor).quest_ids, [SECOND_MAIN_QUEST_ID] as Array[StringName])


func _load_main() -> Node2D:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main)
	return main


func test_a_quest_is_accepted_through_the_givers_dialogue() -> void:
	var main: Node2D = _load_main()
	var elder: WorldActor = main.area.get_node("Actors/Elder")
	main._talk_to(elder)
	assert_true(main.dialogue_panel.is_asking(), "The Elder puts the question.")
	assert_false(main.player.movement_enabled, "The world waits on the reply.")
	assert_eq(main.dialogue_panel.selected_index(), 0)
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.NEW, "Nothing changes until the player answers.")

	main.dialogue_panel._confirm(0)
	await get_tree().process_frame
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.ACTIVE)
	assert_true(main.dialogue_panel.is_open(), "The Elder answers the acceptance.")
	assert_false(main.dialogue_panel.is_asking())
	assert_eq(main.dialogue_panel.dialogue_text.text, _content(MAIN_QUEST_ID).accepted_line)
	assert_true(_log.is_objective_done(_content(MAIN_QUEST_ID), 0) == false, "The town is not the meadow.")


func test_refusing_then_asking_again_uses_the_reoffer_line() -> void:
	var main: Node2D = _load_main()
	var elder: WorldActor = main.area.get_node("Actors/Elder")
	main._talk_to(elder)
	main.dialogue_panel._confirm(1)
	await get_tree().process_frame
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.REFUSED)
	assert_eq(main.dialogue_panel.dialogue_text.text, _content(MAIN_QUEST_ID).refused_line)

	main.dialogue_panel.close()
	main._talk_to(elder)
	assert_true(main.dialogue_panel.is_asking())
	assert_eq(main.dialogue_panel.dialogue_text.text, _content(MAIN_QUEST_ID).reoffer_line)
	main.dialogue_panel.close()
	await get_tree().process_frame
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.REFUSED, "Walking away from the question changes nothing.")
	assert_true(main.player.movement_enabled)


func test_an_active_quest_can_be_dropped_and_turned_in_at_the_giver() -> void:
	var main: Node2D = _load_main()
	var elder: WorldActor = main.area.get_node("Actors/Elder")
	var quest := _content(MAIN_QUEST_ID)
	GameState.accept_quest(quest)

	main._talk_to(elder)
	assert_eq(main.dialogue_panel.dialogue_text.text, quest.progress_line)
	main.dialogue_panel._confirm(1)
	await get_tree().process_frame
	assert_eq(_log.status(MAIN_QUEST_ID), QuestLog.Status.ABANDONED)
	assert_eq(main.dialogue_panel.dialogue_text.text, quest.abandoned_line)
	main.dialogue_panel.close()

	GameState.accept_quest(quest)
	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(AREA_ONE))
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	var coins_before: int = GameState.currency
	main._talk_to(elder)
	await get_tree().process_frame
	assert_false(main.dialogue_panel.is_asking(), "A finished quest is turned in without a question.")
	assert_eq(main.dialogue_panel.dialogue_text.text, quest.complete_line)
	assert_true(_log.is_completed(MAIN_QUEST_ID))
	assert_eq(GameState.currency, coins_before + quest.reward_currency)


func test_talking_to_an_npc_counts_as_meeting_them() -> void:
	var main: Node2D = _load_main()
	var quest := _quest(&"q", [_objective(QuestObjective.Kind.TALK, &"knight")])
	GameState.accept_quest(quest)
	main._talk_to(main.area.get_node("Actors/Knight"))
	assert_true(_log.is_ready(quest))
	assert_false(main.dialogue_panel.is_asking(), "The Knight has no quest of his own.")


func test_the_strike_key_does_not_cancel_a_question() -> void:
	var main: Node2D = _load_main()
	main._talk_to(main.area.get_node("Actors/Elder"))
	main._strike()
	assert_true(main.dialogue_panel.is_asking())
	main.dialogue_panel.close()
	await get_tree().process_frame


func test_the_quest_log_page_lists_active_and_fulfilled_quests() -> void:
	var main: Node2D = _load_main()
	main.field_ui.open_page("quests")
	assert_true(main.field_ui.is_open())
	assert_eq(main.field_ui.body.find_children("QuestStack", "", true, false)[0].get_child_count(), 1, "An empty log explains itself.")
	main.field_ui.close()

	var main_quest := _content(MAIN_QUEST_ID)
	GameState.accept_quest(main_quest)
	GameState.accept_quest(_content(CHILD_QUEST_ID))
	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(AREA_ONE))
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	GameState.complete_quest(main_quest)
	main.field_ui.open_page("quests")
	var stack: VBoxContainer = main.field_ui.body.find_children("QuestStack", "", true, false)[0]
	assert_not_null(stack.find_child(String(CHILD_QUEST_ID), false, false), "The side quest is in progress.")
	assert_not_null(stack.find_child(String(MAIN_QUEST_ID), false, false), "The main quest is listed as fulfilled.")
	assert_lt(stack.find_child(String(CHILD_QUEST_ID), false, false).get_index(), stack.find_child(String(MAIN_QUEST_ID), false, false).get_index(), "In progress comes before fulfilled.")
	assert_false(main.player.movement_enabled)
	main.field_ui.close()
	assert_true(main.player.movement_enabled)
