class_name TypeChart
extends Resource
## Type-effectiveness data (Specification 10).
##
## The table is content, not code: rebalancing matchups or the same-type attack
## bonus means editing this resource only. There are no type-based immunities in
## the MVP, so multipliers should stay above zero.

## Provisional same-type attack bonus (Specification 10.4).
@export var same_type_attack_bonus: float = 1.5
## Non-neutral matchups. Unlisted attacker/defender pairs resolve to 1.0x.
@export var matchups: Array[TypeMatchup] = []

var _cache: Dictionary = {}


## Rebuilds the lookup cache. Call after editing [member matchups] at runtime.
func refresh() -> void:
	_cache.clear()
	for matchup: TypeMatchup in matchups:
		if matchup == null:
			continue
		_cache[_key(matchup.attacking, matchup.defending)] = matchup.multiplier


## Multiplier for a single attacking type against a single defending type.
func matchup_multiplier(attacking: Elements.Type, defending: Elements.Type) -> float:
	if _cache.is_empty():
		refresh()
	return float(_cache.get(_key(attacking, defending), 1.0))


## Multiplier against a full defender type list. Dual types multiply
## (Specification 10.3).
func effectiveness(attacking: Elements.Type, defender_types: Array[int]) -> float:
	var total := 1.0
	for defending: int in defender_types:
		total *= matchup_multiplier(attacking, defending)
	return total


## Returns the same-type attack bonus when the move type matches one of the
## user's types, otherwise 1.0 (Specification 10.4).
func same_type_bonus(move_type: Elements.Type, attacker_types: Array[int]) -> float:
	return same_type_attack_bonus if attacker_types.has(int(move_type)) else 1.0


func _key(attacking: int, defending: int) -> int:
	return attacking * 100 + defending
