class_name OpeningLessonGuide
extends BattleGuide
## Explains the turn the overworld handed over, for the lessons on the attack
## key ([FieldStrike], [FieldAmbush]).
##
## It narrows nothing: every command stays open. All it does is hold one line
## over the menus for as long as the opening turn is still being chosen, so
## the player reads why they are moving first, or why they are not, while the
## consequence is in front of them. Once the first turn is spent the banner
## goes and the battle is an ordinary one.

## The turn the overworld's blow decides. After it, initiative is speed again.
const OPENING_TURN := 0

var lesson: String


func _init(lesson_text: String) -> void:
	lesson = lesson_text


func instruction(engine: BattleEngine) -> String:
	if engine == null or engine.phase == BattleEngine.Phase.ENDED:
		return ""
	return lesson if engine.turn_number == OPENING_TURN else ""
