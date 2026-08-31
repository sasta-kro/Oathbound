class_name MoveData
extends Resource
## A move an Oathbound can equip and use (Specification 11.11).
##
## This is pure content: adding a move must not require changing creature or
## battle rules. Resolution of damage, accuracy rolls, cooldowns and status
## application belongs to the battle system.

## Stable content id, independent of [member display_name] (Specification 25.2).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var type: Elements.Type = Elements.Type.FIRE

@export_group("Combat")
## 0 marks a non-damaging move.
@export_range(0, 200) var power: int = 0
@export_range(0, 100) var accuracy: int = 100
## Turns the move is unavailable after use. 0 means usable every turn.
@export_range(0, 10) var cooldown_turns: int = 0
## Higher priority resolves first regardless of Speed (Specification 11.4).
@export_range(-5, 5) var priority: int = 0

@export_group("Status Effect")
## Status applied on hit, or an empty name for none. See [StatusIds].
@export var status_id: StringName = StatusIds.NONE
@export_range(0, 100) var status_chance: int = 0
@export_range(1, 5) var status_duration_turns: int = 3

@export_group("Stat Modifiers")
@export var stat_modifiers: Array[StatModifier] = []

@export_group("Presentation")
## Referenced by id so a missing asset degrades to a placeholder instead of
## breaking the move (Specification 23).
@export var animation_id: StringName = &""
@export var sfx_id: StringName = &""


func is_damaging() -> bool:
	return power > 0


func applies_status() -> bool:
	return status_id != StatusIds.NONE and status_chance > 0


## Content problems for this move, empty when valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("Move at '%s' has no id." % resource_path)
	if display_name.is_empty():
		problems.append("Move '%s' has no display name." % id)
	if status_id != StatusIds.NONE and not StatusIds.is_known(status_id):
		problems.append("Move '%s' applies unknown status '%s'." % [id, status_id])
	if status_id != StatusIds.NONE and status_chance <= 0:
		problems.append("Move '%s' declares a status but a 0%% chance." % id)
	if not is_damaging() and not applies_status() and stat_modifiers.is_empty():
		problems.append("Move '%s' has no damage, status or stat effect." % id)
	return problems
