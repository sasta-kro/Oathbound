class_name WildCreature
extends WorldActor
## A visible wild creature in the overworld (Specification 7).
##
## Interacting with it starts a wild battle. Once defeated or bound it leaves
## the map; respawning is normal wild behaviour (Specification 7.2) but is not
## implemented yet.

@export var species: CreatureSpecies
@export_range(1, 40) var level: int = 4
## Slot in the species ability pool, or -1 to roll one per encounter.
@export_range(-1, 8) var ability_index: int = -1

var defeated: bool = false


## A fresh combat instance for this encounter. Wild creatures roll their
## ability unless the map pins one, so the same species does not always fight
## the same way.
func spawn_instance(rng: RandomNumberGenerator = null) -> CreatureInstance:
	var instance := CreatureInstance.create(species, level, maxi(0, ability_index))
	if ability_index < 0 and rng != null:
		instance.randomize_ability(rng)
	return instance


func mark_defeated() -> void:
	defeated = true
	hide()
	# Leaving the body in place but off every layer frees the tile for the
	# player without moving the node other systems still reference.
	collision_layer = 0
	collision_mask = 0
