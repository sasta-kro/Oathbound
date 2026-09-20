extends GutTest
## The title screen's dev shortcuts: dropping straight into a later area
## without playing the quests that unlock it, and leaving the player's own
## journey on disk alone while doing it.

const SCRATCH_DIR := "user://gut_scratch/test_dev_shortcuts"
const AREA_THREE := "res://areas/area_three.tscn"
const AREA_TWO := "res://areas/area_two.tscn"

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


func test_the_jump_is_taken_once() -> void:
	GameState.jump_to_area(AREA_TWO)
	assert_eq(GameState.take_jump_area(), AREA_TWO)
	assert_eq(GameState.take_jump_area(), "", "The field consumes the jump as it starts.")


func test_a_new_journey_asks_for_no_jump() -> void:
	assert_eq(GameState.take_jump_area(), "")
	assert_false(GameState.dev_jump)


func test_the_field_opens_in_the_area_the_jump_names() -> void:
	GameState.jump_to_area(AREA_THREE)
	var main: Node2D = _load_main()
	await get_tree().process_frame
	assert_eq(main.area.scene_file_path, AREA_THREE, "The jump picks the area.")
	assert_eq(
		main.player.global_position,
		main.area.player_start_position(),
		"A jump lands on the area's own PlayerStart."
	)


func test_a_dev_jump_never_reaches_the_autosave() -> void:
	GameState.jump_to_area(AREA_THREE)
	var main: Node2D = _load_main()
	await get_tree().process_frame
	assert_true(
		SaveService.read(SaveService.AUTOSAVE_SLOT).is_empty(),
		"Poking around an unfinished area must not overwrite a real journey."
	)
	assert_false(GameState.autosave(), "Autosaving stays off for the rest of the session.")


func test_an_ordinary_journey_still_autosaves() -> void:
	var main: Node2D = _load_main()
	await get_tree().process_frame
	assert_false(main.area.scene_file_path == AREA_THREE)
	assert_false(SaveService.read(SaveService.AUTOSAVE_SLOT).is_empty())


func test_a_jump_to_a_scene_that_is_not_there_falls_back_to_the_town() -> void:
	GameState.jump_to_area("res://areas/area_nine.tscn")
	var main: Node2D = _load_main()
	await get_tree().process_frame
	assert_ne(main.area.scene_file_path, "res://areas/area_nine.tscn")
	assert_false(main.area.scene_file_path.is_empty(), "The default area stays up.")
