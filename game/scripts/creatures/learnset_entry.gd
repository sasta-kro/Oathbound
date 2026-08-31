class_name LearnsetEntry
extends Resource
## One "species learns move at level" row of a [CreatureSpecies] learnset
## (Specification 9.8).

## Level at which the move becomes available. 1 means known from creation.
@export_range(1, 100) var level: int = 1
@export var move: MoveData
