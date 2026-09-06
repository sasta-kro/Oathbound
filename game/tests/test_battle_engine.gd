extends GutTest
## Turn resolution, statuses, cooldowns, fainting, binding and running
## (Specification 11 to 15), driven through the engine's event log.

const EMBERLING := &"creature_fire_01"
const CINDERCLAW := &"creature_fire_02"
const LOAMBUCK := &"creature_earth_01"
const RILLFIN := &"creature_water_01"
const GUSTPIP := &"creature_wind_01"

## Forced rolls: 0.0 makes every chance succeed, 0.99 makes only sure things
## succeed (see [member BattleEngine.forced_roll]).
const ALWAYS := 0.0
const NEVER := 0.99


func _party(entries: Array) -> Array[CreatureInstance]:
	var out: Array[CreatureInstance] = []
	for entry: Array in entries:
		out.append(Content.spawn_creature(entry[0], entry[1]))
	return out


func _wild(player_entries: Array, enemy_id: StringName, enemy_level: int) -> BattleConfig:
	var config := BattleConfig.wild(
		_party(player_entries), Content.spawn_creature(enemy_id, enemy_level), Content.type_chart
	)
	config.binding_scrolls = 5
	config.rng_seed = 7
	return config


func _trainer(player_entries: Array, enemy_entries: Array) -> BattleConfig:
	var config := BattleConfig.trainer(
		_party(player_entries), _party(enemy_entries), "Bandit Rook", Content.type_chart
	)
	config.rng_seed = 7
	return config


func _start(config: BattleConfig, forced_roll: float) -> BattleEngine:
	var engine := BattleEngine.new(config)
	engine.forced_roll = forced_roll
	engine.start()
	return engine


func _move(id: StringName) -> MoveData:
	return Content.get_move(id)


func _kinds(events: Array[BattleEvent]) -> Array[int]:
	var out: Array[int] = []
	for event: BattleEvent in events:
		out.append(event.kind)
	return out


func _first_of(events: Array[BattleEvent], kind: BattleEvent.Kind) -> BattleEvent:
	for event: BattleEvent in events:
		if event.kind == kind:
			return event
	return null


func _all_of(events: Array[BattleEvent], kind: BattleEvent.Kind) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	for event: BattleEvent in events:
		if event.kind == kind:
			out.append(event)
	return out


## A test-only move so a rule can be isolated from the shipped content.
func _custom_move(
	power: int, type: Elements.Type, priority: int = 0, status: StatusIds.Status = StatusIds.NONE
) -> MoveData:
	var move := MoveData.new()
	move.id = &"move_test_%d_%d" % [power, priority]
	move.display_name = "Test Move"
	move.type = type
	move.power = power
	move.accuracy = 100
	move.priority = priority
	if status != StatusIds.NONE:
		move.status = status
		move.status_chance = 100
		move.status_duration_turns = 3
	return move


# --- Setup and order ---------------------------------------------------------


func test_start_sends_out_the_enemy_then_the_player() -> void:
	var engine := BattleEngine.new(_wild([[EMBERLING, 5]], LOAMBUCK, 4))
	var events := engine.start()
	assert_eq(_kinds(events), [BattleEvent.Kind.SEND_OUT, BattleEvent.Kind.SEND_OUT])
	assert_eq(events[0].side, BattleTeam.Side.ENEMY)
	assert_eq(events[1].side, BattleTeam.Side.PLAYER)
	assert_string_contains(events[0].text, "wild Loambuck")
	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING)


func test_faster_creature_acts_first() -> void:
	var engine := _start(_wild([[GUSTPIP, 5]], LOAMBUCK, 5), NEVER)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_gust_01")))
	assert_eq(_first_of(events, BattleEvent.Kind.MOVE_USED).side, BattleTeam.Side.PLAYER)

	var reversed := _start(_wild([[LOAMBUCK, 5]], GUSTPIP, 5), NEVER)
	var reversed_events := reversed.take_turn(BattleAction.use_move(_move(&"move_stone_toss_01")))
	assert_eq(
		_first_of(reversed_events, BattleEvent.Kind.MOVE_USED).side, BattleTeam.Side.ENEMY
	)


func test_priority_beats_speed() -> void:
	# Emberling (Speed 44) outpaces Loambuck (Speed 30) and has no priority moves.
	var engine := _start(_wild([[LOAMBUCK, 5]], EMBERLING, 5), NEVER)
	var quick := _custom_move(5, Elements.Type.EARTH, 1)
	engine.player.active().creature.learn_move(quick)
	var events := engine.take_turn(BattleAction.use_move(quick))
	assert_eq(
		_first_of(events, BattleEvent.Kind.MOVE_USED).side,
		BattleTeam.Side.PLAYER,
		"A priority move goes before a faster creature's normal move.",
	)


# --- Damage and accuracy ------------------------------------------------------


func test_damage_is_deterministic_and_matches_the_rules() -> void:
	# Rillfin is the faster side, so the first HIT is its Water Jet landing.
	var engine := _start(_wild([[RILLFIN, 5]], LOAMBUCK, 1), ALWAYS)
	var water_jet := _move(&"move_water_jet_01")
	var expected: int = BattleRules.damage(
		water_jet, engine.player.active(), engine.enemy.active(), Content.type_chart
	)
	var max_hp: int = engine.enemy.active().creature.max_hp()
	var events := engine.take_turn(BattleAction.use_move(water_jet))
	var hit := _first_of(events, BattleEvent.Kind.HIT)
	assert_not_null(hit)
	assert_eq(hit.side, BattleTeam.Side.ENEMY)
	assert_eq(int(hit.data["damage"]), expected)
	assert_gt(expected, 0)
	assert_eq(engine.enemy.active().creature.current_hp, max_hp - expected)
	assert_string_contains(hit.text, BattleRules.NOT_VERY_EFFECTIVE_TEXT)
	assert_almost_eq(float(hit.data["multiplier"]), 0.5, 0.0001)


func test_super_effective_hits_say_so() -> void:
	var engine := _start(_wild([[RILLFIN, 5]], EMBERLING, 5), ALWAYS)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_water_jet_01")))
	var hit := _first_of(events, BattleEvent.Kind.HIT)
	assert_eq(hit.side, BattleTeam.Side.ENEMY)
	assert_string_contains(hit.text, BattleRules.SUPER_EFFECTIVE_TEXT)
	assert_almost_eq(float(hit.data["multiplier"]), 2.0, 0.0001)


func test_moves_can_miss() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), NEVER)
	var max_hp: int = engine.enemy.active().creature.max_hp()
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	assert_not_null(_first_of(events, BattleEvent.Kind.MISSED), "A 95% move misses on a 99 roll.")
	assert_null(_first_of(events, BattleEvent.Kind.HIT))
	assert_eq(engine.enemy.active().creature.current_hp, max_hp)


func test_invalid_actions_do_not_spend_the_turn() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), NEVER)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_water_jet_01")))
	assert_eq(_kinds(events), [BattleEvent.Kind.MESSAGE])
	assert_eq(engine.turn_number, 0)


# --- Cooldowns (Specification 11.10) -----------------------------------------


func test_cooldown_blocks_reuse_for_the_configured_turns() -> void:
	var engine := _start(_wild([[EMBERLING, 6]], LOAMBUCK, 5), NEVER)
	var guard := _move(&"move_guard_stance_01")
	var ember := _move(&"move_ember_01")
	var battler := engine.player.active()
	assert_eq(guard.cooldown_turns, 3)

	engine.take_turn(BattleAction.use_move(guard))
	for _turn: int in 3:
		assert_false(battler.is_move_ready(guard), "Guard Stance must stay unavailable.")
		var rejected := engine.take_turn(BattleAction.use_move(guard))
		assert_eq(_kinds(rejected), [BattleEvent.Kind.MESSAGE])
		engine.take_turn(BattleAction.use_move(ember))
	assert_true(battler.is_move_ready(guard), "Guard Stance is ready again after 3 turns.")
	assert_eq(engine.turn_number, 4)


func test_cooldowns_keep_counting_while_benched() -> void:
	var engine := _start(_wild([[EMBERLING, 6], [RILLFIN, 5]], LOAMBUCK, 5), NEVER)
	var guard := _move(&"move_guard_stance_01")
	var emberling := engine.player.active()
	engine.take_turn(BattleAction.use_move(guard))
	engine.take_turn(BattleAction.switch_to(1))
	assert_eq(engine.player.active().creature.species_id(), RILLFIN)
	engine.take_turn(BattleAction.use_move(_move(&"move_water_jet_01")))
	engine.take_turn(BattleAction.use_move(_move(&"move_water_jet_01")))
	assert_true(emberling.is_move_ready(guard), "Benched cooldowns still progress.")


# --- Statuses (Specification 12) ---------------------------------------------


func test_stun_skips_exactly_one_action() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), ALWAYS)
	var stunner := _custom_move(0, Elements.Type.FIRE, 0, StatusIds.STUN)
	engine.player.active().creature.learn_move(stunner)

	var first_turn := engine.take_turn(BattleAction.use_move(stunner))
	var stunned := _first_of(first_turn, BattleEvent.Kind.STUNNED)
	assert_not_null(stunned, "The slower enemy is stunned before it can act.")
	assert_eq(stunned.side, BattleTeam.Side.ENEMY)
	for used: BattleEvent in _all_of(first_turn, BattleEvent.Kind.MOVE_USED):
		assert_eq(used.side, BattleTeam.Side.PLAYER, "A stunned creature uses no move.")
	assert_false(engine.enemy.active().has_status(StatusIds.STUN), "Stun clears when it fires.")

	var second_turn := engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	var enemy_moved := false
	for used: BattleEvent in _all_of(second_turn, BattleEvent.Kind.MOVE_USED):
		enemy_moved = enemy_moved or used.side == BattleTeam.Side.ENEMY
	assert_true(enemy_moved, "The enemy acts normally on the following turn.")


func test_poison_deals_ten_percent_per_turn_and_wears_off() -> void:
	var engine := _start(_wild([[RILLFIN, 8], [EMBERLING, 5]], LOAMBUCK, 1), ALWAYS)
	var target := engine.enemy.active()
	var expected_tick: int = int(floor(target.creature.max_hp() * 0.10))

	var first := engine.take_turn(BattleAction.use_move(_move(&"move_venom_spit_01")))
	assert_not_null(_first_of(first, BattleEvent.Kind.STATUS_APPLIED))
	var tick := _first_of(first, BattleEvent.Kind.STATUS_DAMAGE)
	assert_not_null(tick, "Poison damages at the end of the poisoned creature's turn.")
	assert_eq(int(tick.data["damage"]), expected_tick)
	assert_true(target.has_status(StatusIds.POISON))

	# Switching back and forth deals no other damage while the poison runs.
	var second := engine.take_turn(BattleAction.switch_to(1))
	assert_not_null(_first_of(second, BattleEvent.Kind.STATUS_DAMAGE))
	var third := engine.take_turn(BattleAction.switch_to(0))
	assert_not_null(_first_of(third, BattleEvent.Kind.STATUS_DAMAGE))
	assert_not_null(_first_of(third, BattleEvent.Kind.STATUS_ENDED), "Poison lasts 3 turns.")
	assert_false(target.has_status(StatusIds.POISON))


func test_ability_immunity_blocks_a_status() -> void:
	var engine := _start(_wild([[LOAMBUCK, 11]], RILLFIN, 15), ALWAYS)
	assert_eq(engine.enemy.active().creature.ability.id, &"ability_toxic_ward")
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_venom_spit_01")))
	var blocked := _first_of(events, BattleEvent.Kind.STATUS_BLOCKED)
	assert_not_null(blocked)
	assert_eq(blocked.side, BattleTeam.Side.ENEMY)
	assert_false(engine.enemy.active().has_status(StatusIds.POISON))


func test_stat_moves_raise_the_user_and_report_it() -> void:
	var engine := _start(_wild([[EMBERLING, 6]], LOAMBUCK, 5), NEVER)
	var battler := engine.player.active()
	var before: int = battler.effective_defense()
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_guard_stance_01")))
	var changed := _first_of(events, BattleEvent.Kind.STAT_CHANGED)
	assert_not_null(changed)
	assert_eq(changed.side, BattleTeam.Side.PLAYER)
	assert_eq(battler.effective_defense(), int(floor(before * 1.4)))


# --- Fainting, XP and outcomes (Specification 9.5, 11.5, 13) -----------------


func test_defeating_the_last_enemy_awards_xp_and_wins() -> void:
	var engine := _start(_wild([[EMBERLING, 10]], GUSTPIP, 1), ALWAYS)
	var foe: CreatureInstance = engine.enemy.active().creature
	var expected_xp: int = BattleRules.xp_for_defeating(foe)
	var xp_before: int = engine.player.active().creature.total_xp

	var events := engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	assert_not_null(_first_of(events, BattleEvent.Kind.FAINTED))
	var gained := _first_of(events, BattleEvent.Kind.XP_GAINED)
	assert_not_null(gained)
	assert_eq(int(gained.data["xp"]), expected_xp)
	assert_eq(engine.player.active().creature.total_xp, xp_before + expected_xp)
	var ended := _first_of(events, BattleEvent.Kind.BATTLE_ENDED)
	assert_not_null(ended)
	assert_eq(int(ended.data["outcome"]), BattleEngine.Outcome.VICTORY)
	assert_eq(engine.outcome, BattleEngine.Outcome.VICTORY)
	assert_eq(engine.phase, BattleEngine.Phase.ENDED)
	assert_eq(engine.currency_earned, BattleRules.currency_for_defeating(foe))
	assert_eq(engine.take_turn(BattleAction.use_move(_move(&"move_ember_01"))).size(), 0)


func test_xp_stops_at_the_level_cap() -> void:
	var config := _wild([[EMBERLING, 10]], GUSTPIP, 1)
	config.level_cap = 10
	var engine := _start(config, ALWAYS)
	engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	assert_eq(engine.player.active().creature.level, 10)
	assert_gt(engine.xp_over_cap, 0, "Capped XP is reported for the Experience Vessel.")


func test_a_fainted_player_creature_is_replaced_without_losing_a_turn() -> void:
	var engine := _start(_wild([[GUSTPIP, 1], [EMBERLING, 5]], LOAMBUCK, 10), ALWAYS)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_gust_01")))
	var fainted := _first_of(events, BattleEvent.Kind.FAINTED)
	assert_not_null(fainted)
	assert_eq(fainted.side, BattleTeam.Side.PLAYER)
	assert_not_null(_first_of(events, BattleEvent.Kind.NEEDS_REPLACEMENT))
	assert_eq(engine.phase, BattleEngine.Phase.REPLACING)
	assert_eq(engine.take_turn(BattleAction.use_move(_move(&"move_ember_01"))).size(), 0)

	var replaced := engine.replace_fainted(1)
	assert_eq(_kinds(replaced), [BattleEvent.Kind.SEND_OUT])
	assert_eq(engine.player.active().creature.species_id(), EMBERLING)
	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING)
	assert_eq(engine.turn_number, 1, "Replacing does not spend a turn.")

	var next_turn := engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	var acted := false
	for used: BattleEvent in _all_of(next_turn, BattleEvent.Kind.MOVE_USED):
		acted = acted or used.side == BattleTeam.Side.PLAYER
	assert_true(acted, "The replacement gets its full next turn.")


func test_losing_every_creature_is_a_defeat() -> void:
	var engine := _start(_wild([[GUSTPIP, 1]], LOAMBUCK, 10), ALWAYS)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_gust_01")))
	assert_eq(engine.outcome, BattleEngine.Outcome.DEFEAT)
	assert_eq(int(_first_of(events, BattleEvent.Kind.BATTLE_ENDED).data["outcome"]), BattleEngine.Outcome.DEFEAT)


func test_trainers_send_out_their_next_creature() -> void:
	var engine := _start(_trainer([[EMBERLING, 10]], [[GUSTPIP, 1], [GUSTPIP, 2]]), ALWAYS)
	var events := engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	assert_not_null(_first_of(events, BattleEvent.Kind.FAINTED))
	var send_outs := _all_of(events, BattleEvent.Kind.SEND_OUT)
	assert_eq(send_outs.size(), 1)
	assert_eq(send_outs[0].side, BattleTeam.Side.ENEMY)
	assert_string_contains(send_outs[0].text, "Bandit Rook")
	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING)
	assert_eq(engine.enemy.active().creature.level, 2)


# --- Binding (Specification 15) ---------------------------------------------


func test_binding_needs_a_wild_battle_scrolls_and_a_destination() -> void:
	var trainer := _start(_trainer([[EMBERLING, 5]], [[LOAMBUCK, 5]]), ALWAYS)
	assert_false(bool(trainer.options()["can_bind"]))
	assert_eq(_kinds(trainer.take_turn(BattleAction.bind())), [BattleEvent.Kind.MESSAGE])
	assert_eq(trainer.turn_number, 0)

	var no_scrolls_config := _wild([[EMBERLING, 5]], LOAMBUCK, 5)
	no_scrolls_config.binding_scrolls = 0
	assert_false(bool(_start(no_scrolls_config, ALWAYS).options()["can_bind"]))

	var full_party_config := _wild([[EMBERLING, 5]], LOAMBUCK, 5)
	full_party_config.has_bind_destination = false
	var full := _start(full_party_config, ALWAYS)
	assert_false(bool(full.options()["can_bind"]))
	full.take_turn(BattleAction.bind())
	assert_eq(full.binding_scrolls, 5, "No scroll is wasted on an impossible binding.")


func test_a_failed_binding_consumes_the_scroll_and_the_enemy_still_acts() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), NEVER)
	var events := engine.take_turn(BattleAction.bind())
	assert_not_null(_first_of(events, BattleEvent.Kind.BIND_FAILED))
	assert_eq(engine.binding_scrolls, 4)
	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING)
	var enemy_acted := _first_of(events, BattleEvent.Kind.MOVE_USED)
	assert_not_null(enemy_acted)
	assert_eq(enemy_acted.side, BattleTeam.Side.ENEMY)


func test_a_successful_binding_ends_the_battle_with_the_creature() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), ALWAYS)
	var wild: CreatureInstance = engine.enemy.active().creature
	var events := engine.take_turn(BattleAction.bind())
	assert_not_null(_first_of(events, BattleEvent.Kind.BIND_SUCCESS))
	assert_eq(engine.outcome, BattleEngine.Outcome.BOUND)
	assert_eq(engine.bound_creature, wild)
	assert_eq(engine.binding_scrolls, 4)
	assert_null(_first_of(events, BattleEvent.Kind.MOVE_USED), "Binding resolves before moves.")


# --- Running -----------------------------------------------------------------


func test_running_is_blocked_in_mandatory_trainer_battles() -> void:
	var engine := _start(_trainer([[EMBERLING, 5]], [[LOAMBUCK, 5]]), ALWAYS)
	assert_false(bool(engine.options()["can_run"]))
	assert_eq(_kinds(engine.take_turn(BattleAction.run())), [BattleEvent.Kind.MESSAGE])


func test_a_successful_escape_ends_the_battle_before_the_enemy_moves() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), ALWAYS)
	var events := engine.take_turn(BattleAction.run())
	assert_not_null(_first_of(events, BattleEvent.Kind.RUN_SUCCESS))
	assert_null(_first_of(events, BattleEvent.Kind.MOVE_USED))
	assert_eq(engine.outcome, BattleEngine.Outcome.ESCAPED)


func test_a_failed_escape_lets_the_enemy_act() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), NEVER)
	var events := engine.take_turn(BattleAction.run())
	assert_not_null(_first_of(events, BattleEvent.Kind.RUN_FAILED))
	assert_eq(engine.run_attempts, 1)
	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING)


# --- Enemy AI (Specification 14.1) ------------------------------------------


func test_ai_prefers_the_super_effective_move() -> void:
	var engine := _start(_wild([[RILLFIN, 5]], CINDERCLAW, 20), ALWAYS)
	var action := engine.ai.choose_action(engine)
	assert_eq(action.kind, BattleAction.Kind.MOVE)
	assert_eq(action.move.id, &"move_quake_step_01", "Earth beats Water; Fire does not.")


func test_ai_never_picks_a_move_on_cooldown() -> void:
	var engine := _start(_wild([[EMBERLING, 5]], LOAMBUCK, 5), NEVER)
	var foe := engine.enemy.active()
	for move: MoveData in foe.creature.moves:
		foe.cooldowns[move] = 3
	var action := engine.ai.choose_action(engine)
	assert_eq(action.kind, BattleAction.Kind.WAIT, "With nothing ready the enemy waits.")
	foe.cooldowns.clear()
	assert_eq(engine.ai.choose_action(engine).kind, BattleAction.Kind.MOVE)


func test_battle_state_is_cleared_when_the_battle_ends() -> void:
	var engine := _start(_wild([[EMBERLING, 10]], GUSTPIP, 1), ALWAYS)
	var battler := engine.player.active()
	engine.take_turn(BattleAction.use_move(_move(&"move_ember_01")))
	assert_eq(engine.outcome, BattleEngine.Outcome.VICTORY)
	assert_true(battler.cooldowns.is_empty())
	assert_true(battler.statuses.is_empty())
	assert_true(battler.modifiers.is_empty())
