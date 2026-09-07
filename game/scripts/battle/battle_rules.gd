class_name BattleRules
extends RefCounted
## The tunable formulas of the battle system (Specification 11.8, 15.3).
##
## Everything here is Provisional and stateless: the [BattleEngine] decides
## when a formula applies, this class only says what it produces. Rebalancing
## means editing constants here without touching turn flow, UI or content.

## `LevelMultiplier = 1 + (Level - 1) / 50` (Specification 11.8).
const LEVEL_MULTIPLIER_DIVISOR := 50.0

## Binding chance placeholder (Specification 15.3).
const BASIC_SCROLL_MULTIPLIER := 1.0
const BIND_HP_FLOOR := 0.25
const BIND_HP_WEIGHT := 0.75
const BIND_MIN_CHANCE := 0.05
const BIND_MAX_CHANCE := 0.95

## Escape chance placeholder. The specification only says a wild battle may
## be escaped; the odds scale with the speed ratio and improve on retries.
const RUN_BASE_CHANCE := 0.5
const RUN_RETRY_BONUS := 0.15
const RUN_MIN_CHANCE := 0.1
const RUN_MAX_CHANCE := 0.95

## Reward placeholders (Specification 13.2).
const XP_DIVISOR := 6.0
const CURRENCY_BASE := 10
const CURRENCY_PER_LEVEL := 5

const SUPER_EFFECTIVE_TEXT := "It's super effective!"
const NOT_VERY_EFFECTIVE_TEXT := "It's not very effective..."

## Reward wording, shared by the two places a creature can be defeated: the
## [BattleEngine], which reports one event per beat so the battle screen can
## pace them, and an overworld rout, which has no battle screen and prints a
## single line. Keeping the strings here stops the two from drifting apart.
const XP_GAINED_TEXT := "%s gained %d XP."
const LEVEL_UP_TEXT := "%s grew to level %d!"
const MOVE_LEARNED_TEXT := "%s learned %s!"
const MOVE_LEARN_SKIPPED_TEXT := "%s wants to learn %s, but already knows four moves."
const EVOLUTION_READY_TEXT := "%s is ready to evolve!"


static func type_multiplier(
	move_type: Elements.Type, defender: CreatureInstance, chart: TypeChart
) -> float:
	if chart == null or defender == null:
		return 1.0
	return chart.effectiveness(move_type, defender.types())


static func same_type_bonus(
	move_type: Elements.Type, attacker: CreatureInstance, chart: TypeChart
) -> float:
	if chart == null or attacker == null:
		return 1.0
	return chart.same_type_bonus(move_type, attacker.types())


## Deterministic damage for a move that has already hit (Specification 11.7,
## 11.8), including ability multipliers (Specification 9.9).
static func damage(move: MoveData, attacker: Battler, defender: Battler, chart: TypeChart) -> int:
	if move == null or not move.is_damaging():
		return 0
	var base_damage: int = maxi(
		0, move.power + attacker.effective_attack() - defender.effective_defense()
	)
	var level_multiplier: float = (
		1.0 + float(attacker.creature.level - 1) / LEVEL_MULTIPLIER_DIVISOR
	)
	var total: float = (
		float(base_damage)
		* level_multiplier
		* same_type_bonus(move.type, attacker.creature, chart)
		* type_multiplier(move.type, defender.creature, chart)
	)
	if attacker.creature.ability != null:
		total *= attacker.creature.ability.outgoing_damage_multiplier(move.type)
	if defender.creature.ability != null:
		total *= defender.creature.ability.incoming_damage_multiplier(move.type)
	return maxi(0, int(floor(total)))


## Player-facing effectiveness hint (Specification 22.5). Empty when neutral.
static func effectiveness_text(multiplier: float) -> String:
	if multiplier > 1.0:
		return SUPER_EFFECTIVE_TEXT
	if multiplier < 1.0:
		return NOT_VERY_EFFECTIVE_TEXT
	return ""


## Percent chance for [param move] to hit after the user's accuracy modifiers
## (Specification 11.6).
static func hit_chance(move: MoveData, attacker: Battler) -> int:
	var chance: float = float(move.accuracy) * float(attacker.accuracy_percent()) / 100.0
	return clampi(int(round(chance)), 0, 100)


## `Chance = Base x Scroll x (0.25 + 0.75 x MissingHP)`, clamped
## (Specification 15.3).
static func bind_chance(
	target: CreatureInstance, scroll_multiplier: float = BASIC_SCROLL_MULTIPLIER
) -> float:
	var hp_factor: float = BIND_HP_FLOOR + BIND_HP_WEIGHT * target.missing_hp_fraction()
	var chance: float = target.species.base_bind_chance * scroll_multiplier * hp_factor
	return clampf(chance, BIND_MIN_CHANCE, BIND_MAX_CHANCE)


static func run_chance(runner_speed: int, chaser_speed: int, previous_attempts: int) -> float:
	var speed_ratio: float = float(runner_speed) / float(maxi(1, chaser_speed))
	var chance: float = RUN_BASE_CHANCE * speed_ratio + RUN_RETRY_BONUS * float(previous_attempts)
	return clampf(chance, RUN_MIN_CHANCE, RUN_MAX_CHANCE)


## XP one defeated creature is worth (Specification 13.2).
static func xp_for_defeating(defeated: CreatureInstance) -> int:
	var species := defeated.species
	var stat_total: int = (
		species.base_hp + species.base_attack + species.base_defense + species.base_speed
	)
	return maxi(1, int(round(float(stat_total) * float(defeated.level) / XP_DIVISOR)))


static func currency_for_defeating(defeated: CreatureInstance) -> int:
	return CURRENCY_BASE + CURRENCY_PER_LEVEL * defeated.level


## Turn order (Specification 11.3, 11.4): 1 when the first actor goes first,
## -1 when the second does, 0 when the caller must break the tie randomly.
static func compare_order(
	first_priority: int, first_speed: int, second_priority: int, second_speed: int
) -> int:
	if first_priority != second_priority:
		return 1 if first_priority > second_priority else -1
	if first_speed != second_speed:
		return 1 if first_speed > second_speed else -1
	return 0
