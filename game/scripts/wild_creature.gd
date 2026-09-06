@tool
class_name WildCreature
extends WorldActor
## A visible wild creature in the overworld (Specification 7).
##
## Interacting with it starts a wild battle. Once defeated or bound it leaves
## the map; respawning is normal wild behaviour (Specification 7.2) but is not
## implemented yet.
##
## Tool script only so the Inspector can list the species' abilities by name;
## nothing here runs in the editor otherwise.

## Inspector value of [member ability_index] meaning "roll one per encounter".
const RANDOM_ABILITY := -1

@export var species: CreatureSpecies:
	set(value):
		species = value
		notify_property_list_changed()
@export_range(1, 40) var level: int = 4
## Slot in the species ability pool, or [constant RANDOM_ABILITY] to roll one
## per encounter. Shown as a dropdown of the species' ability names.
@export var ability_index: int = RANDOM_ABILITY

var defeated: bool = false


## Replaces the plain integer field with a dropdown of the current species'
## abilities. With no species or an empty pool only "Random" is offered.
func _validate_property(property: Dictionary) -> void:
	if property.name != &"ability_index":
		return
	var options: PackedStringArray = ["Random:%d" % RANDOM_ABILITY]
	if species != null:
		for index: int in species.ability_pool.size():
			var ability: AbilityData = species.ability_pool[index]
			var label: String = ability.display_name if ability != null else "(empty)"
			options.append("%s:%d" % [label.replace(",", " "), index])
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(options)


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
