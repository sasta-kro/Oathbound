extends GutTest
## The provisional battle formulas (Specification 11.8, 15.3), checked with
## hand-computed numbers so a retune shows up as a deliberate test change.

const EMBERLING := "res://content/creatures/creature_fire_01.tres"
const LOAMBUCK := "res://content/creatures/creature_earth_01.tres"
const RILLFIN := "res://content/creatures/creature_water_01.tres"
const EMBER := "res://content/moves/move_ember_01.tres"
const VENOM_SPIT := "res://content/moves/move_venom_spit_01.tres"
const WATER_JET := "res://content/moves/move_water_jet_01.tres"


## A level-1 battler with no ability, so only the formula itself is measured.
func _plain_battler(species_path: String, side: int) -> Battler:
	var creature := CreatureInstance.create(load(species_path) as CreatureSpecies, 1)
	creature.ability = null
	return Battler.wrap(creature, side)


func test_damage_follows_the_provisional_formula() -> void:
	var attacker := _plain_battler(EMBERLING, BattleTeam.Side.PLAYER)
	var defender := _plain_battler(LOAMBUCK, BattleTeam.Side.ENEMY)
	# Base 20 + 48 - 58 = 10, level x1.0, STAB x1.5, Fire vs Earth x1.0.
	assert_eq(BattleRules.damage(load(EMBER), attacker, defender, Content.type_chart), 15)


func test_type_chart_and_stab_multiply_into_damage() -> void:
	var attacker := _plain_battler(RILLFIN, BattleTeam.Side.PLAYER)
	var defender := _plain_battler(EMBERLING, BattleTeam.Side.ENEMY)
	# Base 20 + 44 - 36 = 28, STAB x1.5, Water vs Fire x2.0.
	assert_eq(BattleRules.damage(load(WATER_JET), attacker, defender, Content.type_chart), 84)


func test_damage_never_goes_below_zero() -> void:
	var attacker := _plain_battler(LOAMBUCK, BattleTeam.Side.PLAYER)
	var defender := _plain_battler(LOAMBUCK, BattleTeam.Side.ENEMY)
	# Base 10 + 46 - 58 < 0 clamps to 0 (Specification 11.8).
	assert_eq(BattleRules.damage(load(VENOM_SPIT), attacker, defender, Content.type_chart), 0)


func test_level_multiplier_scales_with_attacker_level() -> void:
	var attacker := _plain_battler(EMBERLING, BattleTeam.Side.PLAYER)
	var defender := _plain_battler(LOAMBUCK, BattleTeam.Side.ENEMY)
	attacker.creature.level = 11
	# Attack at level 11 is floor(48 x 1.6) = 76: base 20 + 76 - 58 = 38,
	# level x1.2, STAB x1.5 -> floor(68.4).
	assert_eq(BattleRules.damage(load(EMBER), attacker, defender, Content.type_chart), 68)


func test_abilities_multiply_damage_dealt_and_taken() -> void:
	var attacker := Battler.wrap(
		CreatureInstance.create(load(EMBERLING) as CreatureSpecies, 1), BattleTeam.Side.PLAYER
	)
	var defender := _plain_battler(LOAMBUCK, BattleTeam.Side.ENEMY)
	# Ember Body: Fire damage dealt x1.2 -> floor(15 x 1.2).
	assert_eq(attacker.creature.ability.id, &"ability_ember_body")
	assert_eq(BattleRules.damage(load(EMBER), attacker, defender, Content.type_chart), 18)


func test_effectiveness_text_matches_the_multiplier() -> void:
	assert_eq(BattleRules.effectiveness_text(2.0), BattleRules.SUPER_EFFECTIVE_TEXT)
	assert_eq(BattleRules.effectiveness_text(0.5), BattleRules.NOT_VERY_EFFECTIVE_TEXT)
	assert_eq(BattleRules.effectiveness_text(1.0), "")


func test_hit_chance_applies_accuracy_modifiers() -> void:
	var attacker := _plain_battler(EMBERLING, BattleTeam.Side.PLAYER)
	var ember: MoveData = load(EMBER)
	assert_eq(BattleRules.hit_chance(ember, attacker), 95)
	var penalty := StatModifier.new()
	penalty.stat = Stats.Stat.ACCURACY
	penalty.percent = -50
	attacker.add_modifier(penalty)
	assert_eq(BattleRules.hit_chance(ember, attacker), 48)


func test_bind_chance_rises_as_hp_falls_and_is_clamped() -> void:
	var target := CreatureInstance.create(load(EMBERLING) as CreatureSpecies, 1)
	assert_almost_eq(BattleRules.bind_chance(target), 0.45 * 0.25, 0.0001, "Full HP uses the floor.")
	target.set_hp(1)
	assert_gt(BattleRules.bind_chance(target), 0.4, "Low HP must make binding much likelier.")

	var easy := CreatureSpecies.new()
	easy.base_bind_chance = 1.0
	var easy_target := CreatureInstance.create(easy, 1)
	easy_target.set_hp(1)
	assert_almost_eq(BattleRules.bind_chance(easy_target), BattleRules.BIND_MAX_CHANCE, 0.0001)

	var hard := CreatureSpecies.new()
	hard.base_bind_chance = 0.01
	assert_almost_eq(
		BattleRules.bind_chance(CreatureInstance.create(hard, 1)), BattleRules.BIND_MIN_CHANCE, 0.0001
	)


func test_run_chance_improves_with_speed_and_retries_within_limits() -> void:
	assert_almost_eq(BattleRules.run_chance(50, 50, 0), 0.5, 0.0001)
	assert_gt(BattleRules.run_chance(80, 50, 0), BattleRules.run_chance(50, 50, 0))
	assert_gt(BattleRules.run_chance(50, 50, 1), BattleRules.run_chance(50, 50, 0))
	assert_eq(BattleRules.run_chance(1, 999, 0), BattleRules.RUN_MIN_CHANCE)
	assert_eq(BattleRules.run_chance(999, 1, 9), BattleRules.RUN_MAX_CHANCE)


func test_turn_order_prefers_priority_then_speed() -> void:
	assert_eq(BattleRules.compare_order(1, 10, 0, 99), 1, "Priority beats Speed.")
	assert_eq(BattleRules.compare_order(0, 10, 1, 1), -1)
	assert_eq(BattleRules.compare_order(0, 50, 0, 30), 1, "Equal priority falls back to Speed.")
	assert_eq(BattleRules.compare_order(0, 30, 0, 50), -1)
	assert_eq(BattleRules.compare_order(0, 40, 0, 40), 0, "Full ties are left to the caller.")


func test_rewards_scale_with_the_defeated_creature() -> void:
	var weak := CreatureInstance.create(load(LOAMBUCK) as CreatureSpecies, 1)
	var strong := CreatureInstance.create(load(LOAMBUCK) as CreatureSpecies, 10)
	assert_gt(BattleRules.xp_for_defeating(strong), BattleRules.xp_for_defeating(weak))
	assert_gt(BattleRules.currency_for_defeating(strong), BattleRules.currency_for_defeating(weak))
	assert_gt(BattleRules.xp_for_defeating(weak), 0)


func test_battler_stat_modifiers_combine_additively_and_clamp() -> void:
	var battler := _plain_battler(LOAMBUCK, BattleTeam.Side.PLAYER)
	var guard := StatModifier.new()
	guard.stat = Stats.Stat.DEFENSE
	guard.percent = 40
	for _i: int in 2:
		battler.add_modifier(guard)
	assert_eq(battler.stat_percent(Stats.Stat.DEFENSE), 180)
	battler.add_modifier(guard)
	assert_eq(
		battler.stat_percent(Stats.Stat.DEFENSE),
		Battler.STAT_CEILING_PERCENT,
		"Effective stats stop at 200% (Specification 11.9).",
	)
	assert_eq(battler.effective_defense(), 58 * 2)


func test_burn_lowers_effective_attack_by_a_quarter() -> void:
	var battler := _plain_battler(EMBERLING, BattleTeam.Side.PLAYER)
	assert_eq(battler.effective_attack(), 48)
	battler.apply_status(StatusIds.BURN, 3)
	assert_eq(battler.effective_attack(), 36)


func test_ability_passives_count_as_stat_modifiers() -> void:
	var loambuck := CreatureInstance.create(load(LOAMBUCK) as CreatureSpecies, 1)
	assert_eq(loambuck.ability.id, &"ability_stonewall")
	var battler := Battler.wrap(loambuck, BattleTeam.Side.PLAYER)
	var modifier: StatModifier = loambuck.ability.passive_stat_modifiers[0]
	assert_eq(battler.stat_percent(modifier.stat), 100 + modifier.percent)
