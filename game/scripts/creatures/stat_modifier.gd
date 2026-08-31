class_name StatModifier
extends Resource
## A temporary percentage change to one battle stat (Specification 11.9).
##
## This resource only declares the modifier. Applying, stacking and clearing it
## is owned by the battle system; modifiers are cleared when a battle ends.

enum Target { SELF, OPPONENT }

@export var stat: Stats.Stat = Stats.Stat.ATTACK
@export var target: Target = Target.SELF
## Percentage change against the unmodified battle stat. -25 means -25%.
@export_range(-100, 100) var percent: int = 0
## Turns the modifier lasts. 0 means "until the battle ends".
@export_range(0, 10) var duration_turns: int = 0
