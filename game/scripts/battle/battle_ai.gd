class_name BattleAI
extends RefCounted
## Enemy decision making (Specification 14).
##
## The ordinary profile only ever picks a ready move: it prefers the highest
## expected damage after type matchups, falls back to a useful status or buff
## move, and never switches or uses items. Boss behaviour (Specification 14.2)
## plugs in as another profile without changing the engine.

enum Profile { ORDINARY }

## Score given to a status move whose status the target does not yet have.
const USEFUL_STATUS_SCORE := 20.0
## Score given to a self-buff whose stat is not already modified.
const USEFUL_BUFF_SCORE := 15.0
## Score for a non-damaging move that would currently do nothing useful.
const USELESS_SCORE := 1.0

var profile: Profile = Profile.ORDINARY


func choose_action(engine: BattleEngine) -> BattleAction:
	var user: Battler = engine.enemy.active()
	var target: Battler = engine.player.active()
	var best_move: MoveData = null
	var best_score: float = -INF
	for move: MoveData in user.creature.moves:
		if not user.is_move_ready(move):
			continue
		var score: float = _score(move, user, target, engine)
		var wins_tie: bool = is_equal_approx(score, best_score) and engine.roll() < 0.5
		if score > best_score or wins_tie:
			best_score = score
			best_move = move
	if best_move == null:
		return BattleAction.wait()
	return BattleAction.use_move(best_move)


func _score(move: MoveData, user: Battler, target: Battler, engine: BattleEngine) -> float:
	if move.is_damaging():
		var expected: float = float(BattleRules.damage(move, user, target, engine.config.type_chart))
		return expected * float(BattleRules.hit_chance(move, user)) / 100.0
	var score: float = USELESS_SCORE
	if move.applies_status() and not target.has_status(move.status):
		var blocked: bool = (
			target.creature.ability != null
			and target.creature.ability.blocks_status(move.status)
		)
		if not blocked:
			score = maxf(score, USEFUL_STATUS_SCORE)
	for modifier: StatModifier in move.stat_modifiers:
		if modifier == null:
			continue
		var recipient: Battler = user if modifier.target == StatModifier.Target.SELF else target
		if not recipient.has_modifier_for(modifier.stat):
			score = maxf(score, USEFUL_BUFF_SCORE)
	return score
