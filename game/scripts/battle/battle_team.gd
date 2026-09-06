class_name BattleTeam
extends RefCounted
## One side of a battle: its party wrapped as [Battler]s and which one is
## currently fighting (Specification 11.1).

enum Side { PLAYER, ENEMY }

## A [enum Side] value. Typed as int because [Battler] refers back here.
var side: int = Side.PLAYER
var battlers: Array[Battler] = []
var active_index: int = 0


static func create(creatures: Array[CreatureInstance], for_side: int) -> BattleTeam:
	var team := BattleTeam.new()
	team.side = for_side
	for creature: CreatureInstance in creatures:
		if creature != null:
			team.battlers.append(Battler.wrap(creature, for_side))
	team.active_index = maxi(0, team.first_usable_index())
	return team


func active() -> Battler:
	if battlers.is_empty():
		return null
	return battlers[clampi(active_index, 0, battlers.size() - 1)]


func has_usable() -> bool:
	return first_usable_index() != -1


func is_wiped_out() -> bool:
	return not has_usable()


## Slots that could be switched in: not fainted and not already active.
func usable_bench_indices() -> Array[int]:
	var out: Array[int] = []
	for index: int in battlers.size():
		if index != active_index and not battlers[index].is_fainted():
			out.append(index)
	return out


func first_usable_index() -> int:
	for index: int in battlers.size():
		if not battlers[index].is_fainted():
			return index
	return -1


func set_active(index: int) -> void:
	active_index = clampi(index, 0, battlers.size() - 1)
	active().participated = true
