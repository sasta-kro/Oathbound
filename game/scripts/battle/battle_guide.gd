class_name BattleGuide
extends RefCounted
## Walks the player through a battle by narrowing what they may choose.
##
## The battle screen asks a guide, if it has one, before it enables any
## command, move, switch or support target, and shows [method instruction]
## above the menus. The base class allows everything and says nothing, so an
## unguided battle behaves as if no guide existed. Tutorials subclass it and
## read the [BattleEngine] to decide which step the player is on; a guide
## never changes the rules, only which of the legal choices are offered.

const FIGHT := &"fight"
const SWITCH := &"switch"
const ITEM := &"item"
const BIND := &"bind"
const RUN := &"run"


## What the player should do now. Empty hides the banner.
func instruction(_engine: BattleEngine) -> String:
	return ""


## [param command] is one of [constant FIGHT], [constant SWITCH],
## [constant ITEM], [constant BIND] or [constant RUN].
func allows_command(_engine: BattleEngine, _command: StringName) -> bool:
	return true


func allows_move(_engine: BattleEngine, _move: MoveData) -> bool:
	return true


## Party slot the player may switch to, or send in after a faint.
func allows_switch(_engine: BattleEngine, _index: int) -> bool:
	return true


## Party slot a support move may land on.
func allows_target(_engine: BattleEngine, _move: MoveData, _index: int) -> bool:
	return true


## Called with every batch of events the engine returns, so a guide can tell
## when a step has been done.
func observe(_engine: BattleEngine, _events: Array[BattleEvent]) -> void:
	pass
