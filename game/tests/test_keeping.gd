extends GutTest
## The paddock (Specification 9.3): three Oathbound walk with the player and
## everyone else is kept for them, so a full party is never a reason to walk
## past something worth binding.

const EMBERLING := &"creature_fire_01"
const LOAMBUCK := &"creature_earth_01"
const KEEPING_QUEST_ID := &"quest_main_01b_room_for_more"
const LEAD_QUEST_ID := &"quest_main_01d_who_walks_in_front"

var _saved: Dictionary


func before_each() -> void:
	_saved = GameState.to_dict()
	GameState.new_game()


func after_each() -> void:
	GameState.from_dict(_saved)
	await get_tree().process_frame


func _fill_party() -> void:
	while not GameState.party_is_full():
		GameState.add_to_party(Content.spawn_creature(LOAMBUCK, 4))


# --- Taking one in -----------------------------------------------------------


func test_a_bind_with_room_joins_the_party() -> void:
	var before: int = GameState.party.size()

	assert_eq(GameState.take_in(Content.spawn_creature(LOAMBUCK, 4)), GameState.JOINED_PARTY)

	assert_eq(GameState.party.size(), before + 1)
	assert_true(GameState.kept.is_empty(), "Nothing is kept while the party has room.")


func test_a_bind_with_a_full_party_is_kept_rather_than_refused() -> void:
	_fill_party()
	var newcomer: CreatureInstance = Content.spawn_creature(EMBERLING, 5)

	assert_eq(GameState.take_in(newcomer), GameState.WENT_TO_KEEPING)

	assert_eq(GameState.party.size(), GameState.PARTY_CAPACITY, "The party is untouched.")
	assert_eq(GameState.kept, [newcomer] as Array[CreatureInstance])
	assert_true(GameState.seen_species.has(EMBERLING), "A kept creature is still met.")


func test_an_oathbound_can_be_sent_away_and_called_back() -> void:
	GameState.add_to_party(Content.spawn_creature(LOAMBUCK, 4))
	var companion: CreatureInstance = GameState.party[1]
	companion.set_hp(1)

	assert_true(GameState.send_to_keeping(1))

	assert_false(GameState.party.has(companion))
	assert_eq(GameState.kept, [companion] as Array[CreatureInstance])
	assert_eq(companion.current_hp, companion.max_hp(), "Keeping heals what it keeps.")

	assert_true(GameState.call_out_of_keeping(0))

	assert_true(GameState.party.has(companion))
	assert_true(GameState.kept.is_empty())


func test_the_last_companion_cannot_be_sent_away() -> void:
	assert_eq(GameState.party.size(), 1, "A new journey starts with the starter alone.")

	assert_false(GameState.send_to_keeping(0), "Somebody has to walk with the player.")

	assert_eq(GameState.party.size(), 1)
	assert_true(GameState.kept.is_empty())


func test_nobody_is_called_out_into_a_full_party() -> void:
	_fill_party()
	GameState.take_in(Content.spawn_creature(EMBERLING, 5))

	assert_false(GameState.call_out_of_keeping(0), "The swap has to be deliberate.")

	assert_eq(GameState.party.size(), GameState.PARTY_CAPACITY)
	assert_eq(GameState.kept.size(), 1)


func test_the_paddock_survives_a_save_and_a_load() -> void:
	_fill_party()
	var kept_one: CreatureInstance = Content.spawn_creature(EMBERLING, 9)
	GameState.take_in(kept_one)

	var saved: Dictionary = GameState.to_dict()
	GameState.new_game()
	GameState.from_dict(saved)

	assert_eq(GameState.kept.size(), 1, "What was kept is still kept.")
	assert_eq(GameState.kept[0].species_id(), EMBERLING)
	assert_eq(GameState.kept[0].level, 9)


# --- Who walks in front -------------------------------------------------------


func test_putting_a_companion_in_front_changes_who_fights() -> void:
	var companion: CreatureInstance = Content.spawn_creature(LOAMBUCK, 4)
	GameState.add_to_party(companion)

	assert_true(GameState.set_lead(1))

	assert_eq(GameState.party[0], companion)
	assert_eq(GameState.lead_creature(), companion, "The front one fights and takes the blows.")


func test_a_fainted_companion_is_not_put_in_front() -> void:
	var companion: CreatureInstance = Content.spawn_creature(LOAMBUCK, 4)
	GameState.add_to_party(companion)
	companion.set_hp(0)

	assert_false(GameState.set_lead(1))
	assert_ne(GameState.party[0], companion)
	assert_false(GameState.set_lead(0), "The one already in front is not a change.")


# --- What the two page lessons wait for ---------------------------------------


func _accept(id: StringName) -> QuestData:
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
		GameState.quests.complete(quest)
	var target: QuestData = Content.get_quest(id)
	assert_true(GameState.quests.accept(target), "%s can be taken." % id)
	return target


func test_using_the_paddock_finishes_the_lesson_about_it() -> void:
	var quest: QuestData = _accept(KEEPING_QUEST_ID)
	GameState.add_to_party(Content.spawn_creature(LOAMBUCK, 4))
	assert_false(GameState.quests.is_ready(quest))

	assert_true(GameState.send_to_keeping(1))

	assert_true(GameState.quests.is_ready(quest), "Sending one away is the lesson.")


func test_changing_the_lead_finishes_the_lesson_about_it() -> void:
	var quest: QuestData = _accept(LEAD_QUEST_ID)
	GameState.add_to_party(Content.spawn_creature(LOAMBUCK, 4))
	assert_false(GameState.quests.is_ready(quest))

	assert_true(GameState.set_lead(1))

	assert_true(GameState.quests.is_ready(quest), "Choosing who leads is the lesson.")
