class_name BindTutorialGuide
extends BattleGuide
## The handheld battle that teaches binding (the "A Second Oath" main
## quest): wear the wild creature down with an attack, then offer it a
## Binding Scroll.
##
## Like [SupportTutorialGuide], the step is read off the battle as it stands,
## and the guide lets go once nothing matches (no scrolls left, the player's
## side in trouble) so a turn that goes wrong can never trap the player.

enum Step { WEAKEN, BIND, FREE }

## The foe counts as worn down at or below this share of its HP.
const WORN_FRACTION := 0.6
const WEAKEN_TEXT := "A fresh creature shrugs off a scroll. Choose FIGHT and wear the %s down."
const BIND_TEXT := "It's worn down. Choose BIND and offer it a Binding Scroll (%d%% chance)."


func step(engine: BattleEngine) -> Step:
	if engine == null or engine.enemy == null or engine.phase != BattleEngine.Phase.CHOOSING:
		return Step.FREE
	var foe: Battler = engine.enemy.active()
	if foe == null or foe.is_fainted() or engine.player.active().is_fainted():
		return Step.FREE
	if foe.creature.hp_fraction() > WORN_FRACTION:
		return Step.WEAKEN
	if bool(engine.options()["can_bind"]):
		return Step.BIND
	return Step.FREE


func instruction(engine: BattleEngine) -> String:
	match step(engine):
		Step.WEAKEN:
			return WEAKEN_TEXT % engine.enemy.active().display_name()
		Step.BIND:
			return BIND_TEXT % int(round(engine.bind_chance() * 100.0))
	return ""


func allows_command(engine: BattleEngine, command: StringName) -> bool:
	match step(engine):
		Step.WEAKEN:
			return command == FIGHT
		Step.BIND:
			return command == BIND
	return true


func allows_move(engine: BattleEngine, move: MoveData) -> bool:
	if step(engine) == Step.WEAKEN:
		return move.is_damaging()
	return true
