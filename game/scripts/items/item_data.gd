class_name ItemData
extends Resource
## An ordinary item the player can carry, buy and use (Specification 16).
##
## Pure content, like [MoveData]: dropping a new [code].tres[/code] into
## [code]res://content/items[/code] adds it to the game. The rules for who an
## item may be used on live here too, so the field satchel and the battle
## screen can never disagree about them.
##
## Binding Scrolls are items in the shops but not in the satchel: buying one
## adds to [member GameState.binding_scrolls], the count binding already uses.

## What the item does. Append-only, since resources store the integer.
enum Effect {
	## Restores [member amount] percent of max HP to a conscious Oathbound.
	HEAL,
	## Brings a fainted Oathbound back with [member amount] percent of max HP.
	REVIVE,
	## Clears every status condition. Statuses only exist in battle.
	CURE,
	## A Binding Scroll (Specification 15.2).
	BINDING_SCROLL,
}

## Stable content id, independent of [member display_name] (Specification 25.2).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.HEAL
## Percent of max HP for [constant Effect.HEAL] and [constant Effect.REVIVE].
@export_range(0, 100) var amount: int = 0
## Shop price in coins.
@export_range(0, 9999) var price: int = 0
@export var usable_in_battle: bool = true
@export var usable_in_field: bool = true


func is_binding_scroll() -> bool:
	return effect == Effect.BINDING_SCROLL


## HP the item would restore to [param creature], 0 when it does nothing.
func heal_amount(creature: CreatureInstance) -> int:
	if creature == null:
		return 0
	var share: int = maxi(1, int(ceil(float(creature.max_hp()) * float(amount) / 100.0)))
	match effect:
		Effect.HEAL:
			if creature.is_fainted():
				return 0
			return clampi(share, 0, creature.max_hp() - creature.current_hp)
		Effect.REVIVE:
			return share if creature.is_fainted() else 0
	return 0


## Why the item cannot be used on [param creature], or an empty string when
## it can. [param statuses] are the creature's battle statuses; outside a
## battle there are none.
func refusal(creature: CreatureInstance, statuses: Dictionary = {}) -> String:
	if creature == null:
		return "There is nobody to use it on."
	var name: String = creature.display_name()
	match effect:
		Effect.HEAL:
			if creature.is_fainted():
				return "%s has fainted. A salve won't wake it." % name
			if creature.current_hp >= creature.max_hp():
				return "%s is already at full health." % name
		Effect.REVIVE:
			if not creature.is_fainted():
				return "%s has not fainted." % name
		Effect.CURE:
			if statuses.is_empty():
				return "%s has nothing to cure." % name
		Effect.BINDING_SCROLL:
			return "A Binding Scroll is offered to wild creatures, not companions."
	return ""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("Item at '%s' has no id." % resource_path)
	if display_name.is_empty():
		problems.append("Item '%s' has no display name." % id)
	if effect in [Effect.HEAL, Effect.REVIVE] and amount <= 0:
		problems.append("Item '%s' restores HP but its amount is 0." % id)
	return problems
