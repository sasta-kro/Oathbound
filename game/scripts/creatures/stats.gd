class_name Stats
extends RefCounted
## Combat stat identifiers shared by creatures, moves and battle modifiers.
##
## HP is listed because creatures own a max-HP value, but HP is not a
## modifiable battle stat (Specification 11.9).

enum Stat { HP, ATTACK, DEFENSE, SPEED, ACCURACY }

const DISPLAY_NAMES: Dictionary = {
	Stat.HP: "HP",
	Stat.ATTACK: "Attack",
	Stat.DEFENSE: "Defense",
	Stat.SPEED: "Speed",
	Stat.ACCURACY: "Accuracy",
}

## Stats that temporary battle modifiers may target (Specification 11.9).
const MODIFIABLE := [Stat.ATTACK, Stat.DEFENSE, Stat.SPEED, Stat.ACCURACY]


static func display_name(stat: Stat) -> String:
	return String(DISPLAY_NAMES.get(stat, "Unknown"))
