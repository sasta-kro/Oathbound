class_name BattleEvent
extends RefCounted
## One thing that happened during battle resolution.
##
## The [BattleEngine] emits these instead of touching nodes, so the battle
## scene can animate them at its own pace (Specification 11.12) and tests can
## assert on exactly what happened.

enum Kind {
	MESSAGE,
	SEND_OUT,
	MOVE_USED,
	HIT,
	MISSED,
	STUNNED,
	STATUS_APPLIED,
	STATUS_BLOCKED,
	STATUS_DAMAGE,
	STATUS_ENDED,
	STAT_CHANGED,
	FAINTED,
	XP_GAINED,
	LEVEL_UP,
	MOVE_LEARNED,
	MOVE_LEARN_SKIPPED,
	BIND_ATTEMPT,
	BIND_SUCCESS,
	BIND_FAILED,
	RUN_SUCCESS,
	RUN_FAILED,
	NEEDS_REPLACEMENT,
	BATTLE_ENDED,
}

## Marks an event about the battle as a whole rather than one side.
const NO_SIDE := -1

var kind: Kind = Kind.MESSAGE
## The [enum BattleTeam.Side] the event is about, or [constant NO_SIDE].
var side: int = NO_SIDE
## Player-facing text, ready to display.
var text: String = ""
## Kind-specific details, for example damage dealt or the new HP.
var data: Dictionary = {}


static func create(
	of_kind: Kind, about_side: int, with_text: String, details: Dictionary = {}
) -> BattleEvent:
	var event := BattleEvent.new()
	event.kind = of_kind
	event.side = about_side
	event.text = with_text
	event.data = details
	return event


static func message(with_text: String) -> BattleEvent:
	return create(Kind.MESSAGE, NO_SIDE, with_text)


func is_about(which_side: int) -> bool:
	return side == which_side
