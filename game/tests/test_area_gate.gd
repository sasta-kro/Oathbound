extends GutTest
## The stair behind the altar: sealed while the Black Knight stands, and the
## way into Area Two once it falls (Specification 19).

const SCRATCH_DIR := "user://gut_scratch/test_area_gate"
const BOSS_ID := &"boss_area_01"
const AREA_ONE := "res://areas/area_one.tscn"
const AREA_TWO := "res://areas/area_two.tscn"
## Long enough for the screen wipe to cover, swap the area and reveal again.
const TRAVEL_FRAMES: int = 240

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


func _load_main_in_area_one() -> Node2D:
	var main: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main)
	main._swap_area(load(AREA_ONE))
	main._wire_area()
	return main


func _stair_of(main: Node2D) -> AreaExit:
	return main.area.get_node("Exits/ToAreaTwo") as AreaExit


func _beacon_of(main: Node2D) -> AltarBeacon:
	return main.area.get_node("AltarBeacon") as AltarBeacon


func _beacon_intensity(beacon: AltarBeacon) -> float:
	var material := beacon.glow.material as ShaderMaterial
	return float(material.get_shader_parameter("intensity"))


## Walks the player onto [param exit] and waits for the trigger to fire.
func _step_into(main: Node2D, exit: AreaExit) -> void:
	main.player.global_position = exit.global_position
	main.player.velocity = Vector2.ZERO
	for _frame: int in 4:
		await get_tree().physics_frame


## Waits until the area stops being Area One, or the wipe has had its time.
func _settle_travel(main: Node2D) -> void:
	for _frame: int in TRAVEL_FRAMES:
		await get_tree().process_frame
		if not main._travelling and main.area.scene_file_path != AREA_ONE:
			return


func test_the_stair_turns_the_player_back_while_the_knight_stands() -> void:
	var main: Node2D = _load_main_in_area_one()
	var stair: AreaExit = _stair_of(main)
	assert_true(stair.is_locked(), "The stair starts sealed.")

	await _step_into(main, stair)

	assert_eq(main.area.scene_file_path, AREA_ONE, "A sealed stair must not travel.")
	assert_true(main.dialogue_panel.is_open(), "The player is told why the way is shut.")


func test_beating_the_knight_opens_the_stair_to_area_two() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.record_boss_defeat(BOSS_ID)
	var stair: AreaExit = _stair_of(main)
	assert_false(stair.is_locked(), "The knight's fall opens the stair.")

	await _step_into(main, stair)
	await _settle_travel(main)

	assert_eq(main.area.scene_file_path, AREA_TWO, "The stair leads into Area Two.")
	assert_false(main.dialogue_panel.is_open(), "An open way says nothing.")


func test_area_two_puts_the_player_clear_of_the_way_back() -> void:
	var main: Node2D = _load_main_in_area_one()
	GameState.record_boss_defeat(BOSS_ID)

	await _step_into(main, _stair_of(main))
	await _settle_travel(main)
	assert_eq(main.area.scene_file_path, AREA_TWO)
	if main.area.scene_file_path != AREA_TWO:
		return
	# Arriving on top of the return exit would send the player straight back.
	for _frame: int in 8:
		await get_tree().physics_frame
	assert_eq(main.area.scene_file_path, AREA_TWO, "The arrival spot must not bounce back.")


func test_the_altar_is_dark_while_the_knight_stands() -> void:
	var main: Node2D = _load_main_in_area_one()
	var beacon: AltarBeacon = _beacon_of(main)
	assert_false(beacon.is_lit(), "The altar is dark before the knight falls.")
	assert_eq(_beacon_intensity(beacon), 0.0, "A dark altar draws nothing.")
	assert_false(beacon.glow.visible, "A dark altar shows no glow.")


func test_the_altar_lights_up_when_the_knight_falls() -> void:
	var main: Node2D = _load_main_in_area_one()
	var beacon: AltarBeacon = _beacon_of(main)

	GameState.record_boss_defeat(BOSS_ID)

	assert_true(beacon.is_lit(), "The knight's fall lights the altar.")
	assert_true(beacon.glow.visible, "The light comes up where the player can see it.")
	await wait_for_signal(beacon.lit, AltarBeacon.WAKE_SECONDS + 1.0)
	assert_almost_eq(_beacon_intensity(beacon), 1.0, 0.01, "The light comes fully up.")


func test_an_altar_lit_before_arrival_is_already_burning() -> void:
	GameState.record_boss_defeat(BOSS_ID)
	var main: Node2D = _load_main_in_area_one()
	var beacon: AltarBeacon = _beacon_of(main)
	assert_eq(_beacon_intensity(beacon), 1.0, "Coming back finds the altar lit, not lighting.")
