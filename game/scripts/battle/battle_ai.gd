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
## A heal is only worth a turn once its target is at least this far down.
const HEAL_THRESHOLD := 0.4
## HP restored is weighed against HP a damaging move would take off.
const HEAL_WEIGHT := 1.2

var profile: Profile = Profile.ORDINARY


func choose_action(engine: BattleEngine) -> BattleAction:
	var user: Battler = engine.enemy.active()
	var target: Battler = engine.player.active()
	var best_move: MoveData = null
	var best_ally: int = -1
	var best_score: float = -INF
	for move: MoveData in user.creature.moves:
		if not user.is_move_ready(move):
			continue
		if engine.config.enemy_attacks_only and not move.is_damaging():
			continue
		var ally: int = -1
		var score: float
		if move.targets_ally():
			ally = _best_ally_for(move, engine.enemy)
			score = _support_score(move, engine.enemy.battlers[ally])
		else:
			score = _score(move, user, target, engine)
		var wins_tie: bool = is_equal_approx(score, best_score) and engine.roll() < 0.5
		if score > best_score or wins_tie:
			best_score = score
			best_move = move
			best_ally = ally
	if best_move == null:
		return BattleAction.wait()
	return BattleAction.use_move(best_move, best_ally)


## The party slot a support move helps most: the conscious member it scores
## highest on, the active creature winning ties.
func _best_ally_for(move: MoveData, team: BattleTeam) -> int:
	var best: int = team.active_index
	var best_score: float = _support_score(move, team.active())
	for index: int in team.battlers.size():
		var battler: Battler = team.battlers[index]
		if battler.is_fainted():
			continue
		var score: float = _support_score(move, battler)
		if score > best_score:
			best = index
			best_score = score
	return best


func _support_score(move: MoveData, ally: Battler) -> float:
	var score: float = USELESS_SCORE
	if move.heals() and ally.creature.missing_hp_fraction() >= HEAL_THRESHOLD:
		score = float(BattleRules.heal_amount(move, ally.creature)) * HEAL_WEIGHT
	for modifier: StatModifier in move.stat_modifiers:
		if modifier != null and modifier.target == StatModifier.Target.SELF:
			if not ally.has_modifier_for(modifier.stat):
				score = maxf(score, USEFUL_BUFF_SCORE)
	return score


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
