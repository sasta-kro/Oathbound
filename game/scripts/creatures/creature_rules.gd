class_name CreatureRules
extends RefCounted
## Hard creature-system rules that are explicitly specified rather than tuned.
##
## These are player-facing rules from the specification, not content targets.
## Roster sizes, area counts and balance numbers must never be constants here.

## An Oathbound may equip at most four moves (Specification 9.8).
const MAX_MOVE_SLOTS := 4
## Global maximum level in the MVP (Specification 9.4). Story-based caps are
## lower and are owned by the progression system, not by this constant.
const GLOBAL_MAX_LEVEL := 40
## Creatures may have one or two elemental types (Specification 10.1).
const MAX_TYPES := 2
