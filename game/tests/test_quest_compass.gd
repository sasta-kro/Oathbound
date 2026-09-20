extends GutTest
## The arrow on the field HUD: who it points at, and which way out of the
## area that is (see [QuestCompass]).

const TOWN := "res://areas/town.tscn"
const AREA_ONE := "res://areas/area_one.tscn"
const AREA_TWO := "res://areas/area_two.tscn"
const BED_QUEST_ID := &"quest_main_01f_a_bed_at_the_hearthside"

var _log: QuestLog


func before_each() -> void:
	_log = QuestLog.new(Content)


func _quest(id: StringName) -> QuestData:
	return Content.get_quest(id)


func _accept(id: StringName) -> QuestData:
	var quest: QuestData = _quest(id)
	var earlier: Array[QuestData] = []
	var walker: QuestData = quest
	while walker != null and walker.requires != &"":
		walker = _quest(walker.requires)
		if walker != null:
			earlier.push_front(walker)
	for before: QuestData in earlier:
		_log.accept(before)
		for objective: QuestObjective in before.objectives:
			for _step: int in objective.required():
				_log.report(objective.kind, objective.target)
		_log.complete(before)
	_log.accept(quest)
	return quest


# --- Who the arrow points at --------------------------------------------------


func test_nothing_is_pointed_at_with_no_quests() -> void:
	assert_eq(QuestCompass.target_actor(_log), &"")


func test_a_finished_quest_points_at_whoever_takes_it_in() -> void:
	var quest: QuestData = _accept(BED_QUEST_ID)
	assert_eq(QuestCompass.target_actor(_log), &"", "A night's sleep is not a walk to somebody.")

	_log.report(QuestObjective.Kind.EVENT, GameState.EVENT_RESTED_AT_INN)

	assert_true(_log.is_ready(quest))
	assert_eq(QuestCompass.target_actor(_log), &"innkeeper", "The bed is reported at the bed.")


func test_an_errand_to_go_and_see_somebody_points_at_them() -> void:
	_accept(&"quest_main_01h_the_road_is_waiting")
	assert_eq(QuestCompass.target_actor(_log), &"scout", "Walking back up is the whole errand.")


## The story is what the player is following, so it wins the arrow.
func test_the_main_story_is_pointed_at_before_a_side_errand() -> void:
	var side: QuestData = _quest(&"quest_side_leaf_hat")
	_log.accept(side)
	for objective: QuestObjective in side.objectives:
		for _step: int in objective.required():
			_log.report(objective.kind, objective.target)
	assert_true(_log.is_ready(side))
	_accept(&"quest_main_01h_the_road_is_waiting")

	assert_eq(QuestCompass.target_actor(_log), &"scout")


# --- Which way that is --------------------------------------------------------


func test_an_area_knows_who_stands_in_it_and_where_its_doors_go() -> void:
	var town: Dictionary = QuestCompass.area(TOWN)
	assert_true("innkeeper" in town["actors"], "The Innkeeper is in the town.")
	assert_true("apothecary" in town["actors"])
	assert_false("scout" in town["actors"], "The Scout is not.")
	assert_true(AREA_ONE in town["exits"], "The town opens onto the meadow.")


func test_an_actor_in_this_area_is_pointed_at_directly() -> void:
	assert_eq(QuestCompass.area_of(&"innkeeper", TOWN), TOWN)
	assert_eq(QuestCompass.step_toward(&"innkeeper", TOWN), TOWN, "No doorway is needed.")


func test_an_actor_one_area_away_is_pointed_at_through_the_door() -> void:
	assert_eq(QuestCompass.area_of(&"scout", TOWN), AREA_ONE)
	assert_eq(QuestCompass.step_toward(&"scout", TOWN), AREA_ONE)
	assert_eq(QuestCompass.step_toward(&"innkeeper", AREA_ONE), TOWN, "And back again.")


## Two areas away the answer is still the first door, not the last.
func test_a_far_off_actor_is_pointed_at_through_the_first_door() -> void:
	var deep: Dictionary = QuestCompass.area(AREA_TWO)
	if deep["actors"].is_empty():
		return
	var somebody: StringName = StringName(deep["actors"][0])
	assert_eq(QuestCompass.area_of(somebody, TOWN), AREA_TWO)
	assert_eq(
		QuestCompass.step_toward(somebody, TOWN),
		AREA_ONE,
		"The way to the deep areas starts with the meadow.",
	)


## "Get to Area One" is a walk too, so it gets an arrow: at the doorway out
## of here, and at nothing once the player is standing in the place.
func test_an_errand_to_reach_an_area_points_at_the_area() -> void:
	var quest: QuestData = _quest(&"quest_main_01_beyond_the_walls")
	_log.accept(quest)

	assert_eq(QuestCompass.destination(_log), {"area": AREA_ONE})
	assert_eq(QuestCompass.target_actor(_log), &"", "The step is a place, not a person.")
	assert_eq(QuestCompass.step_toward_area(AREA_ONE, TOWN), AREA_ONE, "Out through the gate.")
	assert_eq(QuestCompass.step_toward_area(AREA_ONE, AREA_ONE), AREA_ONE, "And nowhere once there.")

	_log.report(QuestObjective.Kind.REACH, StringName(AREA_ONE))

	assert_eq(QuestCompass.destination(_log), {"actor": &"scout"}, "Then it is the Scout.")


func test_nobody_findable_points_nowhere() -> void:
	assert_eq(QuestCompass.area_of(&"nobody_at_all", TOWN), "")
	assert_eq(QuestCompass.step_toward(&"nobody_at_all", TOWN), "")
	assert_eq(QuestCompass.area("res://areas/not_a_scene.tscn")["actors"], PackedStringArray())
