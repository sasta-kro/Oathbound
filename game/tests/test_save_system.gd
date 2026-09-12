extends GutTest
## Save slots: the service that keeps them on disk, the GameState dictionary
## that goes into them, and the rule that the autosave never touches a slot
## the player saved by hand.

const SCRATCH_DIR := "user://gut_scratch/test_save_system"

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


func _slot_file(slot: int) -> String:
	return SaveService.slot_path(slot)


# --- SaveService -------------------------------------------------------------


func test_every_slot_starts_empty() -> void:
	assert_false(SaveService.has_any_save())
	assert_eq(SaveService.latest_slot(), SaveService.NO_SLOT)
	for slot: int in SaveService.all_slots():
		assert_false(SaveService.has_save(slot))
		assert_eq(SaveService.read(slot), {}, "Slot %d reads as an empty dictionary." % slot)


func test_slots_are_the_autosave_plus_the_manual_ones() -> void:
	assert_eq(SaveService.all_slots(), PackedInt32Array([0, 1, 2, 3]))
	assert_false(SaveService.is_manual_slot(SaveService.AUTOSAVE_SLOT))
	assert_true(SaveService.is_manual_slot(1))
	assert_true(SaveService.is_manual_slot(SaveService.SLOT_COUNT))
	assert_false(SaveService.is_valid_slot(SaveService.SLOT_COUNT + 1))
	assert_false(SaveService.write(SaveService.SLOT_COUNT + 1, {"currency": 1}), "No slot beyond the last.")


func test_a_save_round_trips_through_disk() -> void:
	assert_true(SaveService.write(2, {"currency": 12, "party": []}))

	assert_true(SaveService.has_save(2))
	assert_false(SaveService.has_save(1), "Other slots stay empty.")
	var loaded: Dictionary = SaveService.read(2)
	assert_eq(int(loaded.get("currency", -1)), 12)
	assert_eq(int(loaded.get(SaveService.VERSION_KEY, -1)), SaveService.FORMAT_VERSION)
	assert_false(FileAccess.file_exists(_slot_file(2) + SaveService.TEMP_SUFFIX), "No temp file is left over.")


func test_the_previous_contents_of_a_slot_become_its_backup() -> void:
	SaveService.write(1, {"currency": 1})
	SaveService.write(1, {"currency": 2})

	assert_eq(int(SaveService.read(1).get("currency", -1)), 2, "The newest save is the slot.")
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveService.backup_path(1)))
	assert_eq(int(backup.get("currency", -1)), 1, "The one before it is kept as the backup.")


func test_a_corrupt_slot_falls_back_to_its_backup() -> void:
	SaveService.write(1, {"currency": 7})
	SaveService.write(1, {"currency": 8})
	var file: FileAccess = FileAccess.open(_slot_file(1), FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()

	assert_eq(int(SaveService.read(1).get("currency", -1)), 7)


func test_erasing_one_slot_leaves_the_others() -> void:
	SaveService.write(1, {"currency": 1})
	SaveService.write(1, {"currency": 2})
	SaveService.write(3, {"currency": 3})

	SaveService.erase(1)

	assert_false(SaveService.has_save(1))
	assert_false(FileAccess.file_exists(SaveService.backup_path(1)), "The backup goes with it.")
	assert_true(SaveService.has_save(3))


func test_continue_picks_the_most_recent_slot() -> void:
	SaveService.write(2, {SaveService.SAVED_AT_KEY: 100})
	SaveService.write(SaveService.AUTOSAVE_SLOT, {SaveService.SAVED_AT_KEY: 300})
	SaveService.write(1, {SaveService.SAVED_AT_KEY: 200})

	assert_eq(SaveService.latest_slot(), SaveService.AUTOSAVE_SLOT)


func test_durations_read_as_hours_and_minutes() -> void:
	assert_eq(SaveService.describe_duration(0), "0m")
	assert_eq(SaveService.describe_duration(59), "0m")
	assert_eq(SaveService.describe_duration(25 * 60), "25m")
	assert_eq(SaveService.describe_duration(84 * 60 + 30), "1h 24m")


# --- GameState ---------------------------------------------------------------


func test_the_journey_survives_a_save_and_load() -> void:
	var lead: CreatureInstance = GameState.party[0]
	lead.gain_xp(500, GameState.level_cap)
	lead.set_hp(3)
	var second: CreatureInstance = Content.spawn_creature(&"creature_fire_01", 4)
	GameState.add_to_party(second)
	GameState.currency = 230
	GameState.binding_scrolls = 2
	GameState.seen_species[&"creature_fire_01"] = true
	GameState.record_location("res://areas/area_one.tscn", Vector2(96, -48), Vector2i.LEFT)
	GameState.play_seconds = 125.0
	var expected_level: int = lead.level
	var expected_xp: int = lead.total_xp
	var expected_moves: int = lead.moves.size()

	assert_true(GameState.save_game(2))
	assert_gt(GameState.last_saved_at, 0, "A successful save is stamped.")
	assert_eq(GameState.active_slot, 2, "A manual save makes its slot the active one.")
	GameState.new_game()
	assert_eq(GameState.currency, 0, "new_game clears the session first.")
	assert_eq(GameState.active_slot, SaveService.NO_SLOT)
	assert_true(GameState.load_game(2))

	assert_eq(GameState.active_slot, 2)
	assert_eq(GameState.party.size(), 2)
	var restored: CreatureInstance = GameState.party[0]
	assert_eq(restored.level, expected_level)
	assert_eq(restored.total_xp, expected_xp)
	assert_eq(restored.current_hp, 3, "Current HP is kept, not refilled.")
	assert_eq(restored.moves.size(), expected_moves)
	assert_eq(GameState.party[1].level, 4)
	assert_eq(GameState.currency, 230)
	assert_eq(GameState.binding_scrolls, 2)
	assert_true(GameState.seen_species.has(&"creature_fire_01"))
	assert_eq(GameState.area_path, "res://areas/area_one.tscn")
	assert_eq(GameState.player_position, Vector2(96, -48))
	assert_eq(GameState.player_facing, Vector2i.LEFT)
	assert_eq(int(GameState.play_seconds), 125)


func test_the_autosave_never_overwrites_a_manual_slot() -> void:
	GameState.currency = 5
	GameState.save_game(1)
	GameState.currency = 9

	assert_true(GameState.autosave())

	assert_eq(int(SaveService.read(1).get("currency", -1)), 5, "Slot 1 keeps what the player saved.")
	assert_eq(int(SaveService.read(SaveService.AUTOSAVE_SLOT).get("currency", -1)), 9)
	assert_eq(GameState.active_slot, 1, "Autosaving does not change the active slot.")


func test_loading_the_autosave_has_no_active_manual_slot() -> void:
	GameState.save_game(3)
	GameState.autosave()

	GameState.load_game(SaveService.AUTOSAVE_SLOT)

	assert_eq(GameState.active_slot, SaveService.NO_SLOT)


func test_only_a_loaded_journey_asks_the_field_to_resume() -> void:
	GameState.record_location("res://areas/area_one.tscn", Vector2(10, 10), Vector2i.UP)
	assert_false(GameState.take_resume_request(), "Recording a spot during play is not a resume.")

	GameState.save_game(1)
	GameState.load_game(1)
	assert_true(GameState.take_resume_request(), "Loading a slot resumes there once.")
	assert_false(GameState.take_resume_request(), "The request is consumed.")


func test_load_reports_nothing_when_the_slot_is_empty() -> void:
	GameState.currency = 40

	assert_false(GameState.load_game(1))
	assert_eq(GameState.currency, 40, "A failed load leaves the session alone.")


func test_a_save_naming_a_missing_area_starts_from_the_default_spot() -> void:
	var data: Dictionary = GameState.to_dict()
	data["location"] = {"area": "res://areas/gone.tscn", "x": 5, "y": 5}

	GameState.from_dict(data)

	assert_false(GameState.has_location())


func test_a_save_with_only_unknown_species_gets_the_starter_back() -> void:
	var data: Dictionary = GameState.to_dict()
	data["party"] = [{"species": "creature_that_never_was", "level": 9}]

	GameState.from_dict(data)

	assert_eq(GameState.party.size(), 1)
	assert_eq(GameState.party[0].species_id(), GameState.STARTER_SPECIES_ID)


func test_new_game_resets_the_session_but_leaves_the_slots_alone() -> void:
	GameState.currency = 99
	GameState.save_game(1)

	GameState.new_game()

	assert_eq(GameState.currency, 0)
	assert_eq(GameState.binding_scrolls, GameState.STARTING_BINDING_SCROLLS)
	assert_eq(GameState.party.size(), 1)
	assert_eq(GameState.last_saved_at, 0)
	assert_true(SaveService.has_save(1), "Starting over never erases a slot; the player does that.")


# --- Slot cards --------------------------------------------------------------


func test_slot_cards_describe_what_is_saved() -> void:
	GameState.currency = 77
	GameState.record_location("res://areas/area_one.tscn", Vector2.ZERO, Vector2i.DOWN)
	GameState.play_seconds = 62 * 60
	GameState.save_game(1)

	var line: String = SaveSlotList.summary_line(SaveService.read(1))

	assert_true(line.begins_with("Area One"), line)
	assert_true("1 companion  ·" in line, line)
	assert_true("Lead Lv %d" % GameState.party[0].level in line, line)
	assert_true("77 coins" in line, line)
	assert_true(line.ends_with("Played 1h 02m"), line)


func test_slot_cards_offer_only_the_actions_the_screen_allows() -> void:
	GameState.save_game(2)
	var list := SaveSlotList.new()
	list.can_save = true
	list.can_load = true
	list.can_erase = true
	add_child_autofree(list)

	var buttons: Array[Node] = list.find_children("*", "Button", true, false)
	var labels: Array = []
	for button: Button in buttons:
		labels.append(button.text)
	labels.sort()

	# Three manual slots can be saved to; only slot 2 can be loaded or erased.
	assert_eq(labels, ["Erase", "Load", "Save here", "Save here", "Save here"])


func test_destructive_slot_actions_ask_twice() -> void:
	GameState.save_game(1)
	var list := SaveSlotList.new()
	list.can_save = true
	add_child_autofree(list)
	watch_signals(list)
	var overwrite: Button = list.find_children("*", "Button", true, false)[0]
	assert_eq(overwrite.text, "Save here")

	overwrite.pressed.emit()
	assert_eq(overwrite.text, SaveSlotList.OVERWRITE_QUESTION, "The first press asks.")
	assert_signal_not_emitted(list, "save_requested")

	overwrite.pressed.emit()
	assert_signal_emitted_with_parameters(list, "save_requested", [1])
