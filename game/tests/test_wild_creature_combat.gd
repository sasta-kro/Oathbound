extends GutTest
## A wild creature as an overworld combatant: the damage it carries, the
## telegraph before it strikes, and what interrupts that telegraph
## (Specification 7.3, extended).

const CREATURE_SCENE: PackedScene = preload("res://scenes/wild_creature.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const SPECIES_ID := &"creature_earth_01"

## Well clear of the sample map, so nothing else can wander into these tests.
const TEST_ORIGIN := Vector2(4000, 4000)
## Physics frames to give a 0.45 s windup room to finish.
const WINDUP_FRAMES := 45


func after_each() -> void:
	await get_tree().process_frame


func _creature(disposition: WildCreature.Disposition = WildCreature.Disposition.NEUTRAL) -> WildCreature:
	var creature: WildCreature = autofree(CREATURE_SCENE.instantiate())
	creature.species = Content.get_species(SPECIES_ID)
	creature.level = 4
	creature.disposition = disposition
	creature.detection_radius = 300.0
	creature.leash_radius = 300.0
	add_child(creature)
	creature.global_position = TEST_ORIGIN
	creature.home_position = TEST_ORIGIN
	return creature


## A player parked just inside the creature's reach.
func _player_in_reach(creature: WildCreature) -> Player:
	var player: Player = autofree(PLAYER_SCENE.instantiate())
	add_child(player)
	player.movement_enabled = false
	player.global_position = creature.global_position + Vector2(creature.strike_reach() - 4.0, 0.0)
	return player


# --- The damage a creature carries --------------------------------------------


func test_a_creature_keeps_one_instance_so_overworld_damage_sticks() -> void:
	var creature: WildCreature = _creature()

	var first: CreatureInstance = creature.encounter_instance()

	assert_eq(first, creature.encounter_instance(), "The same creature fights the same instance.")


func test_a_hit_wounds_the_creature_without_putting_it_down() -> void:
	var creature: WildCreature = _creature()
	var instance: CreatureInstance = creature.encounter_instance()

	var routed: bool = creature.take_overworld_hit(1, creature.global_position + Vector2.LEFT)

	assert_false(routed, "One point of damage cannot rout a healthy creature.")
	assert_eq(instance.current_hp, instance.max_hp() - 1)
	assert_true(creature.is_interactable(), "A wounded creature is still an encounter.")


func test_a_lethal_hit_reports_the_rout() -> void:
	var creature: WildCreature = _creature()
	var instance: CreatureInstance = creature.encounter_instance()

	var routed: bool = creature.take_overworld_hit(
		instance.max_hp(), creature.global_position + Vector2.LEFT
	)

	assert_true(routed, "A hit that empties the HP bar skips the battle.")
	assert_true(instance.is_fainted())


func test_a_routed_creature_leaves_the_map() -> void:
	var creature: WildCreature = _creature()
	watch_signals(creature)

	await creature.play_rout()

	assert_true(creature.was_defeated)
	assert_false(creature.is_interactable(), "A routed creature cannot be fought again.")
	assert_signal_emitted(creature, "defeated")


# --- The telegraph ------------------------------------------------------------


func test_a_hostile_creature_winds_up_before_its_blow_lands() -> void:
	var creature: WildCreature = _creature(WildCreature.Disposition.HOSTILE)
	_player_in_reach(creature)
	watch_signals(creature)

	for _frame: int in 4:
		await get_tree().physics_frame

	assert_true(creature.is_winding_up(), "Reaching the player must telegraph, not hit.")
	assert_eq(
		get_signal_emit_count(creature, "reached_player"),
		0,
		"Nothing has landed while the creature is still winding up.",
	)

	for _frame: int in WINDUP_FRAMES:
		await get_tree().physics_frame
		if get_signal_emit_count(creature, "reached_player") > 0:
			break
	assert_signal_emitted(creature, "reached_player")


func test_stepping_out_of_reach_during_the_windup_dodges_the_blow() -> void:
	var creature: WildCreature = _creature(WildCreature.Disposition.HOSTILE)
	var player: Player = _player_in_reach(creature)
	watch_signals(creature)

	for _frame: int in 4:
		await get_tree().physics_frame
	assert_true(creature.is_winding_up(), "The creature must have committed to a strike.")

	player.global_position = creature.global_position + Vector2(1200.0, 0.0)
	for _frame: int in WINDUP_FRAMES:
		await get_tree().physics_frame

	assert_signal_not_emitted(
		creature, "reached_player", "A telegraph the player answers must miss."
	)


func test_freezing_the_world_cancels_a_windup() -> void:
	var creature: WildCreature = _creature(WildCreature.Disposition.HOSTILE)
	_player_in_reach(creature)
	watch_signals(creature)

	for _frame: int in 4:
		await get_tree().physics_frame
	assert_true(creature.is_winding_up())

	creature.set_roaming(false)

	assert_false(creature.is_winding_up(), "A half-finished strike must not survive a battle.")
	for _frame: int in WINDUP_FRAMES:
		await get_tree().physics_frame
	assert_signal_not_emitted(creature, "reached_player")


func test_a_hit_interrupts_a_windup() -> void:
	var creature: WildCreature = _creature(WildCreature.Disposition.HOSTILE)
	_player_in_reach(creature)
	watch_signals(creature)

	for _frame: int in 4:
		await get_tree().physics_frame
	assert_true(creature.is_winding_up())

	creature.take_overworld_hit(1, creature.global_position + Vector2.LEFT)

	assert_false(creature.is_winding_up(), "Being hit must break the strike, not delay it.")


func test_backing_a_creature_off_buys_the_player_time() -> void:
	var creature: WildCreature = _creature(WildCreature.Disposition.HOSTILE)
	_player_in_reach(creature)
	watch_signals(creature)

	creature.back_off(1.0)
	for _frame: int in 20:
		await get_tree().physics_frame

	assert_signal_not_emitted(
		creature, "reached_player", "Leaving a battle must not walk straight into the next."
	)
