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
	var party: Array[CreatureInstance] = [Content.spawn_creature(&"creature_emberling", 5)]
	# Fire against Fire is neutral both ways, so neither side is favoured by type.
	var config := BattleConfig.wild(
		party, Content.spawn_creature(&"creature_slagling", 3, 1), Content.type_chart
	)
	config.binding_scrolls = 5
	config.rng_seed = 3
	return config


## A fresh battle config with chosen parties, for the indicator tests.
func _versus(party_entries: Array, enemy_entry: Array) -> BattleConfig:
	var party: Array[CreatureInstance] = []
	for entry: Array in party_entries:
		party.append(Content.spawn_creature(entry[0], entry[1]))
	var config := BattleConfig.wild(
		party, Content.spawn_creature(enemy_entry[0], enemy_entry[1]), Content.type_chart
	)
	config.binding_scrolls = 5
	config.rng_seed = 3
	return config


## A minimal move with only the fields the hint reads, so priority wording can
## be isolated from the shipped content.
func _move_with_priority(priority: int) -> MoveData:
	var move := MoveData.new()
	move.id = &"move_test_priority_%d" % priority
	move.display_name = "Test Move"
	move.type = Elements.Type.FIRE
	move.power = 5
	move.accuracy = 100
	move.priority = priority
	return move


func test_starts_hidden() -> void:
	assert_false(_scene.is_active())


func test_battle_opens_with_both_creatures_and_the_command_menu() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	assert_true(_scene.is_active())
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND)
	assert_eq(_scene.menu_labels(), PackedStringArray(["FIGHT", "SWITCH", "ITEM", "BIND", "RUN"]))
	assert_eq(_scene.player_name.text, "EMBERLING")
	assert_eq(_scene.enemy_name.text, "SLAGLING")
	assert_eq(_scene.enemy_level.text, "Lv 3")
	assert_eq(_scene.enemy_types.text, "FIRE")
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
	assert_false(_scene.enemy_visual.is_using_placeholder(), "Slagling ships with battle art.")
	assert_true(_scene.player_visual.visible and _scene.enemy_visual.visible)


func test_fight_lists_moves_with_a_type_hint_and_resolves_a_turn() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)
	var foe: CreatureInstance = _scene.engine.enemy.active().creature
	var hp_before: int = foe.current_hp

	_scene.press_entry(0)
	assert_eq(_scene.current_menu(), BattleScene.Menu.MOVES)
	assert_eq(_scene.menu_labels(), PackedStringArray(["Ember", "BACK"]))
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
	assert_string_contains(_scene.current_message(), "no items that would help")


func test_finishing_the_battle_closes_the_screen_and_reports_the_engine() -> void:
	var config := _config()
	config.player_party = [Content.spawn_creature(&"creature_emberling", 20)]
	_scene.start_battle(config)
	await wait_frames(2)
	watch_signals(_scene)

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	_scene.press_entry(0)
	await wait_frames(2)
	assert_eq(_scene.engine.outcome, BattleEngine.Outcome.VICTORY)
	assert_false(_scene.is_active(), "Completed battles return automatically without an extra input.")
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
	config.player_party = [Content.spawn_creature(&"creature_emberling", 20)]
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


# --- Turn-order indicators (Increment 10) -------------------------------------


func test_a_neutral_battle_shows_goes_first_on_the_faster_creature_only() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)
	assert_gt(
		_scene.engine.player.active().effective_speed(),
		_scene.engine.enemy.active().effective_speed(),
		"Precondition: the player's Emberling is faster.",
	)

	assert_true(_scene.player_initiative_badge.visible)
	assert_eq(_scene.player_initiative_badge.text, "GOES FIRST")
	assert_false(_scene.enemy_initiative_badge.visible)
	assert_false(_scene.speed_tie_label.visible)


func test_equal_speed_shows_the_tie_label_and_no_side_badge() -> void:
	_scene.start_battle(_versus([[&"creature_gustpip", 5]], [&"creature_gustpip", 5]))
	await wait_frames(2)
	assert_eq(
		_scene.engine.player.active().effective_speed(),
		_scene.engine.enemy.active().effective_speed(),
		"Precondition: identical creatures are equally fast.",
	)

	assert_false(_scene.player_initiative_badge.visible)
	assert_false(_scene.enemy_initiative_badge.visible)
	assert_true(_scene.speed_tie_label.visible)
	assert_eq(_scene.speed_tie_label.text, "SPEED TIE")


func test_a_first_strike_opening_beats_the_speed_comparison() -> void:
	var config := _versus([[&"creature_loambuck", 5]], [&"creature_gustpip", 5])
	config.opening = BattleConfig.Opening.ADVANTAGE
	_scene.start_battle(config)
	await wait_frames(2)
	assert_lt(
		_scene.engine.player.active().effective_speed(),
		_scene.engine.enemy.active().effective_speed(),
		"Precondition: the opening must contradict the Speed order.",
	)

	assert_true(_scene.player_initiative_badge.visible)
	assert_eq(_scene.player_initiative_badge.text, "FIRST STRIKE")
	assert_false(_scene.enemy_initiative_badge.visible)
	assert_false(_scene.speed_tie_label.visible)


func test_an_ambush_opening_beats_the_speed_comparison() -> void:
	var config := _versus([[&"creature_gustpip", 5]], [&"creature_loambuck", 5])
	config.opening = BattleConfig.Opening.DISADVANTAGE
	_scene.start_battle(config)
	await wait_frames(2)
	assert_lt(
		_scene.engine.enemy.active().effective_speed(),
		_scene.engine.player.active().effective_speed(),
		"Precondition: the opening must contradict the Speed order.",
	)

	assert_true(_scene.enemy_initiative_badge.visible)
	assert_eq(_scene.enemy_initiative_badge.text, "AMBUSHES FIRST")
	assert_false(_scene.player_initiative_badge.visible)
	assert_false(_scene.speed_tie_label.visible)


func test_after_the_forced_opening_the_indicator_falls_back_to_speed() -> void:
	# Deepcrag (Water/Earth) and Gustpip (Wind/Earth) trade neutral or resisted
	# hits, so the battle survives into turn two.
	var config := _versus([[&"creature_deepcrag", 5]], [&"creature_gustpip", 5])
	config.opening = BattleConfig.Opening.ADVANTAGE
	_scene.start_battle(config)
	await wait_frames(2)
	assert_eq(_scene.player_initiative_badge.text, "FIRST STRIKE")

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	_scene.press_entry(0)
	await wait_frames(2)

	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND)
	assert_eq(_scene.engine.turn_number, 1)
	assert_true(_scene.enemy_initiative_badge.visible)
	assert_eq(_scene.enemy_initiative_badge.text, "GOES FIRST")
	assert_false(_scene.player_initiative_badge.visible)
	assert_false(_scene.speed_tie_label.visible)


func test_switching_refreshes_the_indicator_for_the_new_active_creature() -> void:
	var config := _versus(
		[[&"creature_gustpip", 5], [&"creature_loambuck", 5]], [&"creature_gustpip", 5]
	)
	_scene.start_battle(config)
	await wait_frames(2)
	assert_true(_scene.speed_tie_label.visible, "Precondition: identical leads start tied.")

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(1)
	assert_eq(_scene.current_menu(), BattleScene.Menu.PARTY)
	_scene.press_entry(1)
	await wait_frames(2)

	assert_eq(_scene.engine.player.active().creature.species_id(), &"creature_loambuck")
	assert_true(_scene.enemy_initiative_badge.visible)
	assert_eq(_scene.enemy_initiative_badge.text, "GOES FIRST")
	assert_false(_scene.speed_tie_label.visible)


func test_move_hints_explain_nonzero_priority_with_its_limitation() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	var quick := _move_with_priority(2)
	assert_string_contains(
		_scene._move_hint(quick), "Priority +2: resolves before lower-priority actions."
	)

	var slow := _move_with_priority(-1)
	assert_string_contains(
		_scene._move_hint(slow), "Priority -1: resolves after higher-priority actions."
	)


func test_priority_zero_move_hints_make_no_priority_claim() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	var hint: String = _scene._move_hint(_move_with_priority(0))
	assert_string_contains(hint, "Power 5")
	assert_false(hint.contains("Priority"), "Zero priority needs no explanation.")


func test_closing_the_battle_hides_every_initiative_indicator() -> void:
	var config := _config()
	config.player_party = [Content.spawn_creature(&"creature_emberling", 20)]
	_scene.start_battle(config)
	await wait_frames(2)
	assert_true(_scene.player_initiative_badge.visible, "Precondition: an indicator is on screen.")

	_scene.engine.forced_roll = 0.0
	_scene.press_entry(0)
	_scene.press_entry(0)
	await wait_frames(2)

	assert_false(_scene.is_active())
	assert_false(_scene.player_initiative_badge.visible)
	assert_false(_scene.enemy_initiative_badge.visible)
	assert_false(_scene.speed_tie_label.visible)


func test_every_submenu_offers_a_way_back() -> void:
	# Two companions, so SWITCH is a command the player can actually pick.
	_scene.start_battle(_versus([[&"creature_emberling", 5], [&"creature_loambuck", 5]], [&"creature_slagling", 3]))
	await wait_frames(2)

	_scene.press_entry(0)
	assert_eq(_scene.current_menu(), BattleScene.Menu.MOVES)
	assert_eq(_scene.menu_labels()[-1], BattleScene.BACK_LABEL)
	_scene.press_entry(_scene.menu_labels().size() - 1)
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND, "BACK returns to the commands.")

	_scene.press_entry(1)
	assert_eq(_scene.current_menu(), BattleScene.Menu.PARTY)
	assert_true(_scene._cancel_menu(), "A switch chosen by mistake can be taken back.")
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND)


func test_the_command_menu_has_nowhere_to_back_out_to() -> void:
	_scene.start_battle(_config())
	await wait_frames(2)

	assert_false(
		_scene._cancel_menu(),
		"Unhandled, so the cancel key can still reach the settings screen.",
	)
	assert_eq(_scene.current_menu(), BattleScene.Menu.COMMAND)
	assert_false(_scene.menu_labels().has(BattleScene.BACK_LABEL))


func test_choosing_a_replacement_cannot_be_backed_out_of() -> void:
	var config := _config()
	config.player_party = [
		Content.spawn_creature(&"creature_emberling", 5),
		Content.spawn_creature(&"creature_loambuck", 5),
	]
	_scene.start_battle(config)
	await wait_frames(2)
	_scene.engine.player.active().creature.set_hp(0)
	_scene._open_party_menu(true)

	assert_eq(_scene.current_menu(), BattleScene.Menu.PARTY)
	assert_false(_scene.menu_labels().has(BattleScene.BACK_LABEL))
	assert_false(_scene._cancel_menu())
