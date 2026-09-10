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
