class_name SupportTutorialGuide
extends BattleGuide
## The handheld battle that teaches support moves (the "Field Mending" main
## quest). The player's hurt striker faces a wild creature; the guide has them
## switch to their healer, mend the striker on the bench, switch back and
## finish the fight.
##
## Each step is read off the battle as it stands rather than counted, so a
## turn that goes differently (a faint, a miss) cannot leave the guide stuck:
## once nothing matches, it lets go and the battle plays normally.

enum Step { TO_HEALER, MEND, TO_STRIKER, FINISH, FREE }

const TO_HEALER_TEXT := "%s is hurt. Choose SWITCH and send in %s."
const MEND_TEXT := "Supports pick their target. Choose FIGHT, then %s, and aim it at %s on the bench."
const TO_STRIKER_TEXT := "%s is patched up. SWITCH back to it."
const FINISH_TEXT := "Now finish it. Choose FIGHT and attack!"

## Party slots, in the battle's own party order.
var striker_index: int = 0
var healer_index: int = 1
## The healing move the healer is expected to use.
var mend: MoveData
var _mended: bool = false


func _init(striker: int, healer: int, heal_move: MoveData) -> void:
	striker_index = striker
	healer_index = healer
	mend = heal_move


func step(engine: BattleEngine) -> Step:
	if engine == null or engine.player == null or engine.phase == BattleEngine.Phase.ENDED:
		return Step.FREE
	var team: BattleTeam = engine.player
	if striker_index >= team.battlers.size() or healer_index >= team.battlers.size():
		return Step.FREE
	var striker: Battler = team.battlers[striker_index]
	var healer: Battler = team.battlers[healer_index]
	if striker.is_fainted() or healer.is_fainted():
		return Step.FREE
	var on_striker: bool = team.active_index == striker_index
	var on_healer: bool = team.active_index == healer_index
	if not _mended:
		if on_striker:
			return Step.TO_HEALER
		if on_healer and healer.is_move_ready(mend):
			return Step.MEND
		return Step.FREE
	if on_healer:
		return Step.TO_STRIKER
	if on_striker:
		return Step.FINISH
	return Step.FREE


func instruction(engine: BattleEngine) -> String:
	var team: BattleTeam = engine.player
	match step(engine):
		Step.TO_HEALER:
			return TO_HEALER_TEXT % [_name(team, striker_index), _name(team, healer_index)]
		Step.MEND:
			return MEND_TEXT % [mend.display_name, _name(team, striker_index)]
		Step.TO_STRIKER:
			return TO_STRIKER_TEXT % _name(team, striker_index)
		Step.FINISH:
			return FINISH_TEXT
	return ""


func allows_command(engine: BattleEngine, command: StringName) -> bool:
	match step(engine):
		Step.TO_HEALER, Step.TO_STRIKER:
			return command == SWITCH
		Step.MEND, Step.FINISH:
			return command == FIGHT
	return true


func allows_move(engine: BattleEngine, move: MoveData) -> bool:
	match step(engine):
		Step.MEND:
			return move == mend
		Step.FINISH:
			return move.is_damaging()
	return true


func allows_switch(engine: BattleEngine, index: int) -> bool:
	match step(engine):
		Step.TO_HEALER:
			return index == healer_index
		Step.TO_STRIKER:
			return index == striker_index
	return true


func allows_target(engine: BattleEngine, move: MoveData, index: int) -> bool:
	if step(engine) == Step.MEND and move == mend:
		return index == striker_index
	return true


func observe(engine: BattleEngine, events: Array[BattleEvent]) -> void:
	for event: BattleEvent in events:
		if (
			event.kind == BattleEvent.Kind.HEALED
			and event.side == BattleTeam.Side.PLAYER
			and int(event.data.get("target_index", -1)) == striker_index
		):
			_mended = true


func has_mended() -> bool:
	return _mended


func _name(team: BattleTeam, index: int) -> String:
	return team.battlers[index].display_name()
