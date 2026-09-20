class_name FieldRout
extends RefCounted
## The words and numbers of the rout lesson (the "No Battle At All" main
## quest), kept apart from the overworld code that stages it, the way
## [FieldStrike] is.
##
## The third lesson on the attack key, and the one that changes how the rest
## of the journey is walked: a swing bigger than what is left of the creature
## it lands on never opens a battle at all. It falls in the grass, pays what
## the battle would have paid, and the player keeps going. The Scout stages a
## creature that is already nearly spent, so the swing cannot fail to finish
## it, and the rout reports [constant EVENT_ID].

const QUEST_ID: StringName = &"quest_main_01g_no_battle_at_all"
## The story event the quest's objective waits for: a creature cut down in
## the overworld, with no battle screen in between.
const EVENT_ID: StringName = &"routed_in_the_field"

const SPECIES_ID: StringName = &"creature_fire_01"
## Small, and worn down further below, because a lesson about the blow that
## finishes something must not depend on who the player is leading with.
const LEVEL := 2
## What it has left when it wanders up: enough that the health bar over it
## reads as nearly gone, little enough that any lead routs it.
const HP_FRACTION := 0.2
## How far off it is put, in cells, on the side away from the Scout, inside
## the player's reach: they are held in place for this one too.
const DISTANCE_CELLS := 1.5

## Spoken after the quest is accepted, before it wanders up.
const SIGHTING: PackedStringArray = [
	"Scout: There. That one has been in a fight already and lost it...",
	"Scout: See how little it has left? Hit it from where you stand, and watch what does not happen.",
]
## Held on screen while the player closes. [code]%s[/code] is its name.
const PROMPT := "Press F. The %s has too little left to give you a fight."


## Leaves [param creature] nearly spent, as it wanders up: the swing has to
## be the end of it, whoever the player is leading with.
static func wear_down(creature: CreatureInstance) -> void:
	creature.set_hp(maxi(1, int(round(float(creature.max_hp()) * HP_FRACTION))))
