class_name XpResult
extends RefCounted
## Outcome of awarding XP to a [CreatureInstance].
##
## The instance reports what happened and never drives the follow-up flow
## itself: move learning, evolution prompts and Experience Vessel storage are
## owned by their own systems (Specification 9.6, 9.7, 9.8).

## XP the caller offered.
var requested: int = 0
## XP actually added to the creature.
var applied: int = 0
## XP that could not be applied because the level cap was reached. The
## Experience Vessel decides what happens to it (Specification 9.6).
var excess: int = 0
var starting_level: int = 1
var new_level: int = 1
## Moves that became available through the levels just gained, in learn order.
var learnable_moves: Array[MoveData] = []
## True when the creature now meets its evolution level.
var evolution_ready: bool = false


func levels_gained() -> int:
	return new_level - starting_level


func leveled_up() -> bool:
	return levels_gained() > 0
