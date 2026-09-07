extends GutTest
## The battle screen wiring: side-view stage, status windows and menus.

const SCENE: PackedScene = preload("res://scenes/battle_scene.tscn")
const TRANSITION_SCENE: PackedScene = preload("res://scenes/screen_transition.tscn")

var _scene: BattleScene


func before_each() -> void:
	_scene = SCENE.instantiate()
	_scene.skip_presentation = true
	add_child_autofree(_scene)


func _config() -> BattleConfig:
	var party: Array[CreatureInstance] = [Content.spawn_creature(&"creature_fire_01", 5)]
	# Thick Hide rather than Stonewall, so a level-5 Ember still gets through.
	var config := BattleConfig.wild(
		party, Content.spawn_creature(&"creature_earth_01", 3, 1), Content.type_chart
	)
	config.binding_scrolls = 5
	config.rng_seed = 3
	return config


func test_starts_hidden() -> void:
	assert_false(_scene.is_active())


func test_battle_opens_with_both_creatures_and_the_command_menu() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	assert_true(_scene.is_active())
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND)
	assert_eq(_scene.menu_labels(), PackedStringArray(["FIGHT", "SWITCH", "ITEM", "BIND", "RUN"]))
	assert_eq(_scene.player_name.text, "EMBERLING")
	assert_eq(_scene.enemy_name.text, "LOAMBUCK")
	assert_eq(_scene.enemy_level.text, "Lv 3")
	assert_eq(_scene.enemy_types.text, "EARTH")
	var foe: CreatureInstance = _scene.engine.enemy.active().creature
	assert_eq(_scene.enemy_hp.text, "%d / %d" % [foe.max_hp(), foe.max_hp()])


func test_stage_is_a_side_view_with_the_enemy_mirrored() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	assert_lt(
		_scene.player_visual.position.x,
		_scene.enemy_visual.position.x,
		"The player's creature stands on the left.",
	)
	assert_eq(_scene.player_visual.position.y, _scene.enemy_visual.position.y, "Both stand on the same ground line.")
	assert_false(_scene.player_visual.flip_h, "Sprites face right by default.")
	assert_true(_scene.enemy_visual.flip_h, "The enemy faces the player.")
	assert_false(_scene.enemy_visual.is_using_placeholder(), "Loambuck ships with battle art.")
	assert_true(_scene.player_visual.visible and _scene.enemy_visual.visible)


func test_fight_lists_moves_with_a_type_hint_and_resolves_a_turn() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)
	var foe: CreatureInstance = _scene.engine.enemy.active().creature
	var hp_before: int = foe.current_hp

	_scene.press_entry(0)
	assert_eq(_scene.current_menu(), BattleScene.Menu.MOVES)
	assert_eq(_scene.menu_labels(), PackedStringArray(["Ember"]))
	assert_string_contains(_scene.current_message(), "Power 20")
	assert_string_contains(_scene.current_message(), "Accuracy 95%")

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	await wait_frames(2)
	assert_lt(foe.current_hp, hp_before, "Using Ember damages the enemy.")
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND, "Back to the command menu.")
	assert_eq(_scene.enemy_hp.text, "%d / %d" % [foe.current_hp, foe.max_hp()])


func test_unavailable_commands_explain_themselves() -> void:
	var config := _config()
	config.binding_scrolls = 0
	_scene.start_battle(config)
	await wait_frames(2)

	_scene.press_entry(3)
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND, "Nothing was chosen.")
	assert_string_contains(_scene.current_message(), "no Binding Scrolls")
	_scene.press_entry(2)
	assert_string_contains(_scene.current_message(), "no usable items")


func test_finishing_the_battle_closes_the_screen_and_reports_the_engine() -> void:
	var config := _config()
	config.player_party = [Content.spawn_creature(&"creature_fire_01", 20)]
	_scene.start_battle(config)
	await wait_frames(2)
	watch_signals(_scene)

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	_scene.press_entry(0)
	await wait_frames(2)
	assert_eq(_scene.engine.outcome, BattleEngine.Outcome.VICTORY)
	assert_true(_scene.is_active(), "The final message waits for the player.")

	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	_scene._unhandled_input(press)
	assert_false(_scene.is_active())
	assert_signal_emitted(_scene, "battle_finished")


func test_the_cursor_row_is_the_only_highlighted_one() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	var fight: Button = _scene._entries[0].button
	var switch: Button = _scene._entries[1].button
	assert_eq(fight.get_theme_stylebox("normal"), _scene._selected_row_style)
	assert_eq(switch.get_theme_stylebox("normal"), _scene._idle_row_style)

	_scene._set_cursor(1)
	assert_eq(fight.get_theme_stylebox("normal"), _scene._idle_row_style)
	assert_eq(switch.get_theme_stylebox("normal"), _scene._selected_row_style)


func test_status_conditions_show_as_badges_beside_the_types() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)
	assert_eq(_scene.enemy_statuses.get_child_count(), 0, "A healthy creature shows no badges.")

	_scene.engine.enemy.active().apply_status(StatusIds.POISON, 3)
	_scene.engine.enemy.active().apply_status(StatusIds.STUN, 1)
	_scene._refresh_panels()

	assert_eq(_scene.enemy_statuses.get_child_count(), 2)
	assert_eq((_scene.enemy_statuses.get_child(0) as Label).text, "PSN")
	assert_eq(
		(_scene.enemy_statuses.get_child(1) as Label).text, "STN", "Badges keep a stable order."
	)

	_scene.engine.enemy.active().clear_status(StatusIds.POISON)
	_scene._refresh_panels()
	assert_eq(_scene.enemy_statuses.get_child_count(), 1)
	assert_eq((_scene.enemy_statuses.get_child(0) as Label).text, "STN")
	# Replaced badges are freed on the next frame; wait so they are not counted
	# as orphans by the runner.
	await wait_frames(1)


func test_a_battle_with_a_transition_covers_the_screen_before_it_closes() -> void:
	var transition: ScreenTransition = TRANSITION_SCENE.instantiate()
	transition.instant = true
	add_child_autofree(transition)
	_scene.transition = transition

	var config := _config()
	config.player_party = [Content.spawn_creature(&"creature_fire_01", 20)]
	_scene.start_battle(config)
	await wait_frames(2)
	watch_signals(_scene)

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	_scene.press_entry(0)
	await wait_frames(2)

	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	_scene._unhandled_input(press)
	await wait_frames(2)

	assert_true(transition.root.visible, "The world is uncovered by whoever opened the battle.")
	assert_false(_scene.is_active())
	assert_signal_emitted(_scene, "battle_finished")
