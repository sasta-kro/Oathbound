extends GutTest

const EMBERLING_PATH := "res://content/creatures/creature_fire_01.tres"

var _visual: CreatureVisual


func before_each() -> void:
	DevLog.reset()
	_visual = CreatureVisual.new()
	add_child_autofree(_visual)


func _emberling() -> CreatureSpecies:
	return load(EMBERLING_PATH) as CreatureSpecies


func test_emberling_ships_with_a_battle_sprite() -> void:
	var species: CreatureSpecies = _emberling()
	assert_not_null(species.battle_sprite, "Emberling must have battle sprite frames.")

	var frames: SpriteFrames = species.battle_sprite
	for state: StringName in [CreatureVisual.STATE_IDLE, CreatureVisual.STATE_ATTACK]:
		assert_true(frames.has_animation(state), "Battle sprite must define '%s'." % state)
		assert_gt(frames.get_frame_count(state), 1, "'%s' must be animated." % state)


func test_idle_loops_and_attack_does_not() -> void:
	var frames: SpriteFrames = _emberling().battle_sprite
	assert_true(frames.get_animation_loop(CreatureVisual.STATE_IDLE), "Idle must loop.")
	assert_false(
		frames.get_animation_loop(CreatureVisual.STATE_ATTACK),
		"Attack must play once so the caller can sequence the turn.",
	)


func test_attack_presentation_fits_the_battle_pacing_budget() -> void:
	var frames: SpriteFrames = _emberling().battle_sprite
	var frame_count: int = frames.get_frame_count(CreatureVisual.STATE_ATTACK)
	var speed: float = frames.get_animation_speed(CreatureVisual.STATE_ATTACK)
	var duration: float = float(frame_count) / speed
	assert_between(
		duration, 0.2, 0.6, "A simple attack should present in roughly 0.4 s (Specification 11.12)."
	)


func test_species_with_a_sprite_uses_real_art_and_starts_idle() -> void:
	_visual.set_species(_emberling())

	assert_false(_visual.is_using_placeholder(), "A species with art must not use a placeholder.")
	assert_eq(
		_visual.current_animation(),
		CreatureVisual.STATE_IDLE,
		"A creature idles until told otherwise.",
	)
	assert_true(_visual.is_animating(), "The idle animation must be running.")


func test_attack_plays_then_returns_to_idle() -> void:
	_visual.set_species(_emberling())
	watch_signals(_visual)

	_visual.play_attack()
	assert_eq(
		_visual.current_animation(),
		CreatureVisual.STATE_ATTACK,
		"play_attack must start the attack.",
	)

	await wait_for_signal(_visual.state_finished, 2.0)

	assert_signal_emitted_with_parameters(
		_visual, "state_finished", [CreatureVisual.STATE_ATTACK], 0
	)
	assert_eq(_visual.state, CreatureVisual.STATE_IDLE, "The creature must return to idle.")
	assert_eq(
		_visual.current_animation(), CreatureVisual.STATE_IDLE, "The idle animation must resume."
	)


func test_unknown_state_falls_back_to_idle_instead_of_breaking() -> void:
	_visual.set_species(_emberling())

	_visual.play(&"pirouette")

	assert_eq(
		_visual.current_animation(),
		CreatureVisual.STATE_IDLE,
		"Missing art must fall back to idle.",
	)


func test_species_without_a_sprite_animates_a_labelled_placeholder() -> void:
	var bare := CreatureSpecies.new()
	bare.id = &"creature_test_01"
	_visual.set_species(bare)

	assert_true(_visual.is_using_placeholder(), "A species without art must use a placeholder.")
	var placeholder := _visual.get_child(0) as PlaceholderVisual
	assert_string_contains(placeholder.placeholder_text(), "CREATURE_TEST_01")
	assert_string_contains(placeholder.placeholder_text(), "IDLE")
	assert_true(placeholder.loops, "The idle placeholder must keep cycling.")


func test_placeholder_attack_reports_completion_like_real_art() -> void:
	var bare := CreatureSpecies.new()
	bare.id = &"creature_test_01"
	_visual.set_species(bare)
	watch_signals(_visual)

	_visual.play(CreatureVisual.STATE_ATTACK)
	var placeholder := _visual.get_child(0) as PlaceholderVisual
	assert_false(placeholder.loops, "A one-shot placeholder state must not loop.")
	assert_string_contains(placeholder.placeholder_text(), "ATTACK")

	await wait_for_signal(_visual.state_finished, 2.0)

	assert_signal_emitted_with_parameters(
		_visual, "state_finished", [CreatureVisual.STATE_ATTACK], 0
	)
	assert_eq(_visual.state, CreatureVisual.STATE_IDLE, "Placeholders return to idle too.")


func test_death_holds_its_last_state() -> void:
	_visual.set_species(_emberling())

	_visual.play(CreatureVisual.STATE_DEATH)
	await wait_for_signal(_visual.state_finished, 2.0)

	assert_eq(_visual.state, CreatureVisual.STATE_DEATH, "A fainted creature must not idle again.")
