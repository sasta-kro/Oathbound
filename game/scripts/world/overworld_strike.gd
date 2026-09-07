class_name OverworldStrike
extends RefCounted
## The blow that lands before a battle starts (Specification 7.3, extended).
##
## Visible creatures can be hit where they stand. A swing from the player is
## resolved with the lead Oathbound's best move against that creature: a weak
## creature falls in the overworld and never gets a battle screen, a stronger
## one is dragged into a battle it enters already wounded. A hostile creature
## that lands its own contact attack first does the same to the player's lead,
## and the encounter opens against them instead.
##
## Pure rules: no nodes, no timing, no global state. Every number comes from
## [BattleRules], so an overworld hit and a battle hit can never drift apart.

## A player strike lands the full damage its move would do in battle.
const PLAYER_STRIKE_MULTIPLIER := 1.0
## A creature's ambush hits softer, because it also steals the first turn.
const AMBUSH_MULTIPLIER := 0.6
## A connecting hit always does something, so a swing is never wasted.
const MINIMUM_DAMAGE := 1
## An ambush leaves the player's lead at least this much HP. The player has no
## way to answer a blow landed before the battle screen opens, so it must not
## be the thing that knocks them out.
const AMBUSH_HP_FLOOR := 1


## The move the attacker would open with: whichever of its moves does the most
## damage to this defender. Null when it knows no damaging move.
static func best_move_against(
	attacker: CreatureInstance, defender: CreatureInstance, chart: TypeChart
) -> MoveData:
	if attacker == null or defender == null:
		return null
	var best: MoveData = null
	var best_damage: int = -1
	for move: MoveData in attacker.moves:
		if move == null or not move.is_damaging():
			continue
		var amount: int = _battle_damage(move, attacker, defender, chart)
		if amount > best_damage:
			best = move
			best_damage = amount
	return best


## Damage one creature lands on another outside a battle. [param multiplier]
## separates a deliberate swing from an ambush.
static func damage(
	attacker: CreatureInstance,
	defender: CreatureInstance,
	chart: TypeChart,
	multiplier: float,
) -> int:
	if attacker == null or defender == null:
		return 0
	var move: MoveData = best_move_against(attacker, defender, chart)
	# A creature with nothing but support moves still connects, just barely.
	if move == null:
		return MINIMUM_DAMAGE
	# Immunity survives the trip out of battle: a move that cannot touch this
	# defender cannot touch it in the overworld either.
	if BattleRules.type_multiplier(move.type, defender, chart) <= 0.0:
		return 0
	var scaled: float = float(_battle_damage(move, attacker, defender, chart)) * multiplier
	return maxi(MINIMUM_DAMAGE, int(floor(scaled)))


## Damage the player's lead lands by swinging at a creature.
static func player_strike_damage(
	attacker: CreatureInstance, defender: CreatureInstance, chart: TypeChart
) -> int:
	return damage(attacker, defender, chart, PLAYER_STRIKE_MULTIPLIER)


## Damage a hostile creature lands by reaching the player first.
static func ambush_damage(
	attacker: CreatureInstance, defender: CreatureInstance, chart: TypeChart
) -> int:
	return damage(attacker, defender, chart, AMBUSH_MULTIPLIER)


## Whether a swing would drop [param defender] where it stands, in which case
## no battle happens at all and the rewards are paid out in the overworld.
static func routs(
	attacker: CreatureInstance, defender: CreatureInstance, chart: TypeChart
) -> bool:
	if defender == null or defender.is_fainted():
		return false
	return player_strike_damage(attacker, defender, chart) >= defender.current_hp


## HP the player's lead is left on after being ambushed, never below
## [constant AMBUSH_HP_FLOOR].
static func hp_after_ambush(defender: CreatureInstance, incoming: int) -> int:
	return maxi(AMBUSH_HP_FLOOR, defender.current_hp - incoming)


## [BattleRules.damage] works on [Battler]s because battle damage reads
## cooldowns and stat modifiers. Neither exists in the overworld, so the
## wrappers here are bare and the result is the creature's unmodified damage.
static func _battle_damage(
	move: MoveData, attacker: CreatureInstance, defender: CreatureInstance, chart: TypeChart
) -> int:
	return BattleRules.damage(
		move,
		Battler.wrap(attacker, BattleTeam.Side.PLAYER),
		Battler.wrap(defender, BattleTeam.Side.ENEMY),
		chart,
	)
