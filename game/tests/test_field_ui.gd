extends GutTest

var main: Node

func before_each() -> void:
	main = autofree(load("res://main.tscn").instantiate())
	add_child(main)

func after_each() -> void:
	await get_tree().process_frame

func test_party_and_journal_pause_world_and_close_restores_movement() -> void:
	main.field_ui.open_page("party")
	assert_true(main.field_ui.is_open())
	assert_false(main.player.movement_enabled)
	main.field_ui.open_page("journal")
	assert_false(main.player.movement_enabled)
	main.field_ui.close()
	assert_true(main.player.movement_enabled)

func test_details_and_field_guide_do_not_mutate_party() -> void:
	var original := GameState.party.duplicate()
	main.field_ui._details(GameState.party[0])
	main.field_ui._species_details(Content.all_species()[0])
	assert_eq(GameState.party, original)

func test_experience_notification_does_not_block_exploration() -> void:
	var creature := GameState.party[0]
	main.field_ui.show_xp(creature, creature.total_xp, creature.level, 0)
	assert_false(main.field_ui.is_open())
	assert_true(main.player.movement_enabled)
	assert_eq(main.field_ui.rewards.get_child_count(), 1)

func test_journal_empty_search_shows_every_species_and_clear_restores_results() -> void:
	main.field_ui.open_page("journal")
	var search: LineEdit = main.field_ui.body.find_children("*", "LineEdit", true, false)[0]
	var grid: GridContainer = main.field_ui.body.find_children("*", "GridContainer", true, false)[0]
	assert_eq(_visible_children(grid), Content.all_species().size())
	search.text = "no-such-creature"
	search.text_changed.emit(search.text)
	assert_eq(_visible_children(grid), 0)
	search.text = ""
	search.text_changed.emit("")
	assert_eq(_visible_children(grid), Content.all_species().size())

func test_journal_filters_survive_visiting_a_record() -> void:
	main.field_ui.journal_filter = "fire"
	main.field_ui.journal_element = Elements.Type.FIRE
	main.field_ui.open_page("journal")
	var grid: GridContainer = main.field_ui.body.find_children("*", "GridContainer", true, false)[0]
	assert_gt(_visible_children(grid), 0)
	assert_lt(_visible_children(grid), Content.all_species().size())
	main.field_ui._species_details(Content.all_species()[0])
	main.field_ui._go_back()
	assert_eq(main.field_ui.page, "journal")
	assert_eq(main.field_ui.journal_filter, "fire")
	assert_eq(main.field_ui.journal_element, Elements.Type.FIRE)

func test_tab_traversal_and_typing_do_not_close_the_journal() -> void:
	main.field_ui.open_page("journal")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	main.field_ui._input(tab)
	assert_true(main.field_ui.is_open())
	var search: LineEdit = main.field_ui.body.find_children("*", "LineEdit", true, false)[0]
	search.grab_focus()
	var letter := InputEventKey.new()
	letter.keycode = KEY_J
	letter.pressed = true
	main.field_ui._input(letter)
	assert_eq(main.field_ui.page, "journal")
	assert_true(main.field_ui.is_open())

func test_reward_bursts_keep_only_three_cards_visible_and_snapshot_progress() -> void:
	var creature := CreatureInstance.create(Content.all_species()[0], 4)
	for i in 5:
		main.field_ui.show_xp(creature, creature.total_xp, creature.level, 10)
	assert_eq(main.field_ui.rewards.get_child_count(), 3)
	assert_eq(main.field_ui._reward_queue.size(), 2)
	creature.gain_xp(10000)
	assert_eq(main.field_ui._reward_queue[0].level, 4, "Queued rewards keep the awarded level, even after later XP.")
	assert_true(main.player.movement_enabled)

func test_field_guide_specimens_cannot_become_party_leads() -> void:
	var original := GameState.party.duplicate()
	main.field_ui._set_lead(CreatureInstance.create(Content.all_species()[0], 1))
	assert_eq(GameState.party, original)

func test_three_companions_fit_the_logical_viewport() -> void:
	var original := GameState.party.duplicate()
	GameState.party.clear()
	for species in Content.all_species().slice(0, 3):
		GameState.party.append(CreatureInstance.create(species, 7))
	main.field_ui.open_page("party")
	await wait_frames(3)
	var minimum: Vector2 = main.field_ui.overlay.get_combined_minimum_size()
	assert_lte(minimum.x, 912.0, "Three party cards must fit the 960px canvas.")
	assert_lte(minimum.y, 500.0, "Party controls must fit the 540px canvas.")
	GameState.party.assign(original)

func _visible_children(parent: Node) -> int:
	var count := 0
	for child in parent.get_children():
		if child is Control and child.visible: count += 1
	return count
