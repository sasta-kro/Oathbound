class_name AbilityData
extends Resource
## An innate passive a creature has simply by being itself, independent of its
## moves (Specification 9.9).
##
## Abilities are declarative content, not scripts. An ability may only use the
## approved effect categories of Specification 9.9.4, each built from a
## mechanic the game already has: passive stat modifiers (11.9), damage
## multipliers (10, 11.8) and status interaction (12). Introducing a genuinely
## new effect category is a deliberate specification decision.
##
## This resource never applies anything. The battle system reads these values
## through the query methods below and decides when they matter.

## Stable content id, independent of [member display_name] (Specification 25.2).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Passive Stats")
## Always active while the creature is the active battler. Modifiers here are
## permanent for the battle, so their duration is ignored and their target is
## always the ability's owner.
@export var passive_stat_modifiers: Array[StatModifier] = []

@export_group("Damage Dealt")
## Multiplier applied to damage this creature deals. 1.0 changes nothing.
@export_range(0.0, 4.0, 0.05) var damage_dealt_multiplier: float = 1.0
## Restricts the multiplier to one move type instead of all of them.
@export var has_dealt_type_filter: bool = false
@export var dealt_type_filter: Elements.Type = Elements.Type.FIRE

@export_group("Damage Taken")
## Multiplier applied to damage this creature receives. 1.0 changes nothing.
@export_range(0.0, 4.0, 0.05) var damage_taken_multiplier: float = 1.0
## Restricts the multiplier to one move type instead of all of them.
@export var has_taken_type_filter: bool = false
@export var taken_type_filter: Elements.Type = Elements.Type.FIRE

@export_group("Status")
## Statuses this creature cannot be given. See [StatusIds].
@export var immune_status_ids: Array[StringName] = []
## Percentage points added to the chance of statuses this creature inflicts.
@export_range(-100, 100) var inflicted_status_chance_bonus: int = 0


## Multiplier for damage this creature deals with a move of [param move_type].
func outgoing_damage_multiplier(move_type: Elements.Type) -> float:
	if has_dealt_type_filter and int(move_type) != int(dealt_type_filter):
		return 1.0
	return damage_dealt_multiplier


## Multiplier for damage this creature takes from a move of [param move_type].
func incoming_damage_multiplier(move_type: Elements.Type) -> float:
	if has_taken_type_filter and int(move_type) != int(taken_type_filter):
		return 1.0
	return damage_taken_multiplier


func blocks_status(status_id: StringName) -> bool:
	return immune_status_ids.has(status_id)


func has_any_effect() -> bool:
	return (
		not passive_stat_modifiers.is_empty()
		or not is_equal_approx(damage_dealt_multiplier, 1.0)
		or not is_equal_approx(damage_taken_multiplier, 1.0)
		or not immune_status_ids.is_empty()
		or inflicted_status_chance_bonus != 0
	)


## Content problems for this ability, empty when valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("Ability at '%s' has no id." % resource_path)
	if display_name.is_empty():
		problems.append("Ability '%s' has no display name." % id)
	if not has_any_effect():
		problems.append("Ability '%s' has no effect." % id)
	for status_id: StringName in immune_status_ids:
		if not StatusIds.is_known(status_id):
			problems.append(
				"Ability '%s' grants immunity to unknown status '%s'." % [id, status_id]
			)
	for modifier: StatModifier in passive_stat_modifiers:
		if modifier == null:
			problems.append("Ability '%s' has an empty stat modifier row." % id)
		elif modifier.percent == 0:
			problems.append("Ability '%s' has a stat modifier of 0%%." % id)
	return problems
