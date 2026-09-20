extends GutTest
## The opening (Specification 4.5): the prologue, the scene with the Elder by
## the well that hands over the starter and the first main quest, and the
## quest marks over NPCs' heads that point the way afterwards.

const SCRATCH_DIR := "user://gut_scratch/test_opening"
const PROLOGUE_SCENE := "res://scenes/prologue.tscn"
const MAIN_QUEST_ID := &"quest_main_01_beyond_the_walls"
const CHILD_QUEST_ID := &"quest_side_leaf_hat"
const AREA_ONE := "res://areas/area_one.tscn"
## A little longer than the field's pause while the starter arrives.
const STARTER_ENTRANCE_WAIT: float = 0.7

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


func _load_main() -> Node2D:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	main.get_node("ScreenTransition").instant = true
	add_child(main)
	return main


## Reads past the current line the way the interact key does.
func _read_on(main: Node2D) -> void:
	main._interact()


func test_a_journey_with_an_opening_starts_empty_handed() -> void:
	GameState.new_game(true)
	assert_true(GameState.party.is_empty(), "The Elder hands the starter over in the opening.")
	assert_eq(GameState.binding_scrolls, GameState.STARTING_BINDING_SCROLLS)
	assert_true(GameState.take_opening_request())
	assert_false(GameState.take_opening_request(), "The request is used up once the field takes it.")


func test_a_plain_new_game_still_grants_the_starter() -> void:
	GameState.new_game()
	assert_eq(GameState.party.size(), 1)
	assert_false(GameState.take_opening_request())


func test_the_field_plays_the_opening_with_the_elder_by_the_well() -> void:
	GameState.new_game(true)
	var main: Node2D = _load_main()
	await get_tree().process_frame

	var elder: WorldActor = main.area.get_node("Actors/Elder")
	assert_eq(main.player.global_position, main.area.entrance_position(GameOpening.PLAYER_SPOT))
	assert_eq(main.player.facing_direction, GameOpening.facing_toward(main.player.global_position, elder.global_position))
	assert_true(main.is_in_opening())
	assert_false(main.player.movement_enabled, "The world holds still for the scene.")
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(GameOpening.WELCOME[0]))
	assert_false(SaveService.has_save(SaveService.AUTOSAVE_SLOT), "Nothing is saved before the starter is in hand.")

	for _line: String in GameOpening.WELCOME:
		_read_on(main)
	assert_eq(GameState.party.size(), 1, "The Elder hands over the starter.")
	assert_eq(GameState.party[0].species_id(), GameState.STARTER_SPECIES_ID)
	await get_tree().create_timer(STARTER_ENTRANCE_WAIT).timeout
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(GameOpening.STARTER_EXPLAINED[0]))

	for _index: int in GameOpening.STARTER_EXPLAINED.size() + GameOpening.THREAT.size():
		_read_on(main)
	assert_true(main.dialogue_panel.is_asking(), "The Elder asks the player to go.")
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(GameOpening.ASK))

	main.dialogue_panel._confirm(1)
	await get_tree().process_frame
	assert_true(GameState.quests.is_active(MAIN_QUEST_ID), "Either reply sends the player to the scout.")
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(GameOpening.SEND_OFF[1]))

	_read_on(main)
	assert_false(main.is_in_opening())
	assert_true(main.player.movement_enabled)
	assert_true(SaveService.has_save(SaveService.AUTOSAVE_SLOT), "The journey is saved once the scene is over.")


func test_the_opening_cannot_be_talked_over() -> void:
	GameState.new_game(true)
	var main: Node2D = _load_main()
	await get_tree().process_frame
	for _line: String in GameOpening.WELCOME:
		_read_on(main)
	# The starter is arriving and no line is up, but the Elder is in reach.
	assert_false(main.dialogue_panel.is_open())
	main._interact()
	assert_false(main.dialogue_panel.is_open(), "The Elder is not talked to over the scene.")
	await get_tree().create_timer(STARTER_ENTRANCE_WAIT).timeout
	assert_eq(main.dialogue_panel.dialogue_text.text, DialoguePanel.body_of(GameOpening.STARTER_EXPLAINED[0]))
	main.dialogue_panel.close()


func test_a_field_without_the_request_skips_the_opening() -> void:
	var main: Node2D = _load_main()
	await get_tree().process_frame
	assert_false(main.is_in_opening())
	assert_eq(main.player.global_position, main.area.player_start_position())
	assert_true(main.player.movement_enabled)


func test_the_prologue_reads_page_by_page() -> void:
	var prologue: Control = autofree((load(PROLOGUE_SCENE) as PackedScene).instantiate())
	add_child(prologue)
	assert_eq(prologue.current_page(), 0)
	prologue.advance()
	assert_eq(prologue.current_page(), 0, "The first press finishes the line being written.")
	prologue.advance()
	assert_eq(prologue.current_page(), 1)


# --- Quest marks --------------------------------------------------------------


func _actor(actor_name: String, quest_ids: Array[StringName] = []) -> WorldActor:
	var actor := WorldActor.new()
	actor.name = actor_name
	actor.quest_ids = quest_ids
	add_child_autofree(actor)
	return actor


func test_quest_givers_are_marked_by_the_kind_of_quest() -> void:
	var elder := _actor("Elder", [MAIN_QUEST_ID])
	var child := _actor("Child", [CHILD_QUEST_ID])
	var knight := _actor("Knight")

	assert_eq(elder.quest_marker(GameState.quests, Content), {"marker": WorldActor.QuestMarker.AVAILABLE, "main": true})
	assert_eq(child.quest_marker(GameState.quests, Content), {"marker": WorldActor.QuestMarker.AVAILABLE, "main": false})
	assert_eq(knight.quest_marker(GameState.quests, Content).marker, WorldActor.QuestMarker.NONE)
	assert_eq(elder.quest_marker_text(), "!")
	assert_eq(knight.quest_marker_text(), "")


func test_the_mark_follows_the_quest_to_the_scout_who_takes_it_in() -> void:
	var elder := _actor("Elder", [MAIN_QUEST_ID])
	var scout := _actor("Scout")
	GameState.accept_quest(Content.get_quest(MAIN_QUEST_ID))
	assert_eq(elder.quest_marker_text(), "", "Nothing to say to the Elder while the scout is unfound.")
	assert_eq(scout.quest_marker_text(), "!", "The scout is who the quest asks for.")
	assert_true(scout.quest_marker(GameState.quests, Content).main)

	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(AREA_ONE))
	GameState.report_quest_event(QuestObjective.Kind.TALK, &"scout")
	assert_eq(scout.quest_marker_text(), "?", "The scout takes it in on the spot.")
	assert_eq(elder.quest_marker_text(), "", "No walk back to the Elder.")

	GameState.complete_quest(Content.get_quest(MAIN_QUEST_ID))
	assert_eq(elder.quest_marker_text(), "")
	assert_eq(scout.quest_marker_text(), "")


func test_a_main_quest_outranks_a_side_quest_on_the_same_npc() -> void:
	var elder := _actor("Elder", [CHILD_QUEST_ID, MAIN_QUEST_ID])
	assert_true(elder.quest_marker(GameState.quests, Content).main)
