class_name BattleAction
extends RefCounted
## One action chosen for a battle turn (Specification 11.2).
##
## Non-move actions carry provisional priorities (Specification 11.4) so a
## switch, scroll or escape attempt always resolves before either creature's
## move. Those values are tunable and nothing else depends on them.

enum Kind { MOVE, WAIT, SWITCH, ITEM, BIND, RUN }

const SWITCH_PRIORITY := 6
const ITEM_PRIORITY := 6
const BIND_PRIORITY := 6
const RUN_PRIORITY := 7

var kind: Kind = Kind.MOVE
## The move to use, for [constant Kind.MOVE].
var move: MoveData
## Party slot to bring in, for [constant Kind.SWITCH].
var party_index: int = -1
## Party slot of the user's own side a support move lands on, for a
## [constant Kind.MOVE] whose move targets an ally. -1 means the user itself.
var target_index: int = -1
## The item to use, for [constant Kind.ITEM]. It lands on [member target_index].
var item: ItemData


## [param ally_index] only matters for a move that targets an ally
## ([method MoveData.targets_ally]): the party slot, benched or active, it
## lands on. Left at -1 the user targets itself.
static func use_move(chosen: MoveData, ally_index: int = -1) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.MOVE
	action.move = chosen
	action.target_index = ally_index
	return action


## Used when every move is on cooldown: the creature does nothing this turn.
static func wait() -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.WAIT
	return action


static func switch_to(index: int) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.SWITCH
	action.party_index = index
	return action


## Uses [param chosen] on party slot [param index] (Specification 16.3).
static func use_item(chosen: ItemData, index: int) -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.ITEM
	action.item = chosen
	action.target_index = index
	return action


static func bind() -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.BIND
	return action


static func run() -> BattleAction:
	var action := BattleAction.new()
	action.kind = Kind.RUN
	return action


## Resolution priority. Moves use their own value (Specification 11.4).
func priority() -> int:
	match kind:
		Kind.MOVE:
			return move.priority if move != null else 0
		Kind.SWITCH:
			return SWITCH_PRIORITY
		Kind.ITEM:
			return ITEM_PRIORITY
		Kind.BIND:
			return BIND_PRIORITY
		Kind.RUN:
			return RUN_PRIORITY
	return 0
