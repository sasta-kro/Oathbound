extends GutTest
## The ending: the king's defeat is announced, the wood comes back to life,
## and a finished journey stays finished across a save.

const SCRATCH_DIR := "user://gut_scratch/test_ending"
const AREA_THREE := "res://areas/area_three.tscn"
## Long enough for the colour to have visibly started to move.
const GREENING_FRAMES: int = 20

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


func _wood() -> Node:
	var area: Node = autofree((load(AREA_THREE) as PackedScene).instantiate())
	add_child(area)
	return area


# --- The king ---------------------------------------------------------------


## The cap is already at the ceiling by the time the king falls, so without
## a line of his own the last boss in the game would pass in silence.
func test_the_king_announces_himself_even_though_no_cap_moves() -> void:
	GameState.level_cap = CreatureRules.GLOBAL_MAX_LEVEL
	var lines: PackedStringArray = GameState.record_boss_defeat(GameState.FINAL_BOSS_ID)
	assert_true(GameState.FINAL_BOSS_TEXT in lines, "The king's defeat is announced.")
	for line: String in lines:
		assert_false(line.contains("grow to level"), "No cap can be raised past the ceiling.")


func test_a_king_already_beaten_says_nothing_again() -> void:
	GameState.record_boss_defeat(GameState.FINAL_BOSS_ID)
	assert_eq(GameState.record_boss_defeat(GameState.FINAL_BOSS_ID).size(), 0)


func test_the_ending_hangs_off_the_last_quest_on_the_chain() -> void:
	var quest: QuestData = Content.get_quest(Epilogue.QUEST_ID)
	assert_not_null(quest, "The ending's quest ships.")
	assert_true(quest.is_main())
	for other: QuestData in Content.all_quests():
		assert_ne(other.requires, Epilogue.QUEST_ID, "Nothing follows the king.")


# --- A finished journey -----------------------------------------------------


func test_a_new_journey_has_not_finished() -> void:
	GameState.story_complete = true
	GameState.new_game()
	assert_false(GameState.story_complete)


func test_a_finished_journey_stays_finished_through_a_save() -> void:
	GameState.story_complete = true
	var data: Dictionary = GameState.to_dict()
	GameState.new_game()
	assert_false(GameState.story_complete, "A fresh journey starts unfinished.")
	GameState.from_dict(data)
	assert_true(GameState.story_complete, "The ending is not replayed on a reload.")


func test_an_old_save_without_the_flag_reads_as_unfinished() -> void:
	var data: Dictionary = GameState.to_dict()
	data.erase("story_complete")
	GameState.from_dict(data)
	assert_false(GameState.story_complete)


# --- The wood comes back ----------------------------------------------------


func test_the_ending_stops_the_wood_refilling_itself() -> void:
	var area: Node = _wood()
	var zones: Array = area.get_node("SpawnZones").get_children()
	assert_gt(zones.size(), 0, "Area Three has spawn zones to still.")
	Epilogue._still_the_wood(self)
	for zone: Node in zones:
		assert_eq(zone.process_mode, Node.PROCESS_MODE_DISABLED, "%s is stilled." % zone.name)


## Everything the king had standing goes, and goes quietly: routed rather
## than killed, so nothing plays a death.
func test_the_kings_own_thin_out_of_the_wood() -> void:
	var area: Node = _wood()
	var standing: Array[WildCreature] = []
	for actor: Node in area.get_node("Actors").get_children():
		if actor is WildCreature and not (actor as WildCreature).was_defeated:
			standing.append(actor as WildCreature)
	assert_gt(standing.size(), 0, "The wood has the king's own in it.")
	Epilogue._thin_away(self)
	await get_tree().process_frame
	for creature: WildCreature in standing:
		assert_true(creature._routed, "%s lets go." % creature.name)


func test_the_cold_light_warms_once_he_is_under() -> void:
	var area: Node = _wood()
	var tint: CanvasModulate = area.get_node("Tint") as CanvasModulate
	var was: Color = tint.color
	assert_lt(was.r, Epilogue.LIVING_LIGHT.r, "The king's wood starts colder than daylight.")
	Epilogue._green(self, area)
	for _frame: int in GREENING_FRAMES:
		await get_tree().process_frame
	assert_gt(tint.color.r, was.r, "The colour comes back.")
	assert_lt(tint.color.r, Epilogue.LIVING_LIGHT.r + 0.001, "And no further than daylight.")


## An area without a tint of its own must not take the ending down with it.
func test_an_area_with_no_tint_is_left_alone() -> void:
	var bare := Node2D.new()
	add_child_autofree(bare)
	Epilogue._green(self, bare)
	pass_test("A tintless area ends without error.")
