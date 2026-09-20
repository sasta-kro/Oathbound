extends GutTest
## Chests on the map, and where a beaten party wakes up (Specification 16.1,
## 20.1). Both are journey state, so both are checked through a save as well.

const SCRATCH_DIR := "user://gut_scratch/test_chests_and_haven"
const CHEST_SCENE := "res://scenes/treasure_chest.tscn"
const AREA_TWO := "res://areas/area_two.tscn"
const AREA_THREE := "res://areas/area_three.tscn"
const TOWN := "res://areas/town.tscn"
const TEST_ID := &"chest_test_one"
const TONIC := &"item_hearty_tonic"

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


func _chest(properties: Dictionary = {}) -> TreasureChest:
	var chest: TreasureChest = autofree((load(CHEST_SCENE) as PackedScene).instantiate())
	chest.chest_id = TEST_ID
	for key: String in properties:
		chest.set(key, properties[key])
	add_child(chest)
	return chest


func test_a_chest_pays_out_once_and_stays_open() -> void:
	var chest: TreasureChest = _chest({"coins": 25, "binding_scrolls": 1})
	var scrolls: int = GameState.binding_scrolls
	var lines: PackedStringArray = chest.take()

	assert_eq(GameState.currency, 25, "The coins are in the purse.")
	assert_eq(GameState.binding_scrolls, scrolls + 1, "The scroll is on the pile.")
	assert_eq(lines.size(), 2, "One line per thing taken out.")
	assert_true(chest.is_open(), "The lid stays up.")

	assert_true(chest.take().is_empty(), "An open chest gives nothing.")
	assert_eq(GameState.currency, 25, "And pays out nothing either.")


func test_a_chest_hands_over_its_items() -> void:
	var chest: TreasureChest = _chest({"item_ids": [TONIC] as Array[StringName], "item_counts": [2] as Array[int]})
	chest.take()
	assert_eq(GameState.item_count(TONIC), 2, "Both tonics are in the satchel.")


func test_a_chest_behind_a_boss_stays_shut_until_it_falls() -> void:
	var chest: TreasureChest = _chest({"required_boss": &"boss_area_02", "coins": 10})
	GameState.defeated_bosses.erase(&"boss_area_02")
	assert_true(chest.is_locked(), "The chest waits on the boss.")
	GameState.defeated_bosses[&"boss_area_02"] = true
	assert_false(chest.is_locked(), "And opens once it falls.")


func test_an_emptied_chest_is_still_empty_after_a_reload() -> void:
	var chest: TreasureChest = _chest({"coins": 40})
	chest.take()
	assert_true(GameState.save_game(SaveService.AUTOSAVE_SLOT), "The journey saved.")
	GameState.new_game()
	assert_false(GameState.has_opened_chest(TEST_ID), "A fresh journey knows nothing of it.")
	assert_true(GameState.load_game(SaveService.AUTOSAVE_SLOT), "The journey loaded.")
	assert_true(GameState.has_opened_chest(TEST_ID), "The chest is remembered as opened.")


func test_every_shipped_chest_has_an_id_of_its_own() -> void:
	var seen: Dictionary = {}
	for path: String in [TOWN, "res://areas/area_one.tscn", AREA_TWO, AREA_THREE]:
		var area: WorldArea = autofree((load(path) as PackedScene).instantiate())
		add_child(area)
		for chest: TreasureChest in area.find_children("*", "TreasureChest", true, false):
			assert_ne(chest.chest_id, &"", "%s: %s needs an id." % [path, chest.name])
			assert_false(seen.has(chest.chest_id), "Two chests share the id %s." % chest.chest_id)
			seen[chest.chest_id] = true
	assert_gt(seen.size(), 0, "The maps carry chests.")


func test_the_haven_is_the_last_bed_or_healer_used() -> void:
	assert_false(GameState.has_haven(), "A fresh journey has slept nowhere.")
	GameState.record_haven(AREA_TWO, Vector2(120.0, -40.0), "THE LAMPLIGHTER")
	assert_true(GameState.has_haven())
	assert_eq(GameState.haven_area_path, AREA_TWO)
	assert_eq(GameState.haven_position, Vector2(120.0, -40.0))
	assert_eq(GameState.haven_name, "THE LAMPLIGHTER")


func test_the_haven_survives_a_save() -> void:
	GameState.record_haven(AREA_TWO, Vector2(12.0, 34.0), "THE BELLKEEPER")
	assert_true(GameState.save_game(SaveService.AUTOSAVE_SLOT))
	GameState.new_game()
	assert_false(GameState.has_haven(), "A new journey starts with none.")
	assert_true(GameState.load_game(SaveService.AUTOSAVE_SLOT))
	assert_eq(GameState.haven_area_path, AREA_TWO)
	assert_eq(GameState.haven_position, Vector2(12.0, 34.0))
	assert_eq(GameState.haven_name, "THE BELLKEEPER")


func test_a_routed_party_wakes_at_the_haven() -> void:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main)
	await get_tree().process_frame
	main._swap_area(load(AREA_THREE))
	main._wire_area()
	GameState.record_haven(AREA_TWO, Vector2(996.0, -912.0), "THE LAMPLIGHTER")

	main._wake_at_haven()

	assert_eq(main.area.scene_file_path, AREA_TWO, "The party is carried back to the camp.")
	assert_eq(main.player.global_position, Vector2(996.0, -912.0), "And wakes on the spot it used.")


func test_a_party_that_has_rested_nowhere_wakes_in_the_town() -> void:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main)
	await get_tree().process_frame
	main._swap_area(load(AREA_THREE))
	main._wire_area()
	GameState.clear_haven()

	main._wake_at_haven()

	assert_eq(main.area.scene_file_path, TOWN, "The town is where a journey starts and restarts.")
	assert_eq(
		main.player.global_position,
		main.area.player_start_position(),
		"On the town's own starting spot."
	)
