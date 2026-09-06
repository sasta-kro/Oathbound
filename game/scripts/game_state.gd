extends Node
## Player-owned progression shared by the overworld and battles: the active
## party, Binding Scrolls, currency and the story level cap.
##
## Autoloaded as [code]GameState[/code]. Saving and loading (Specification 21)
## will serialise this node; until then it lives for one session.

signal party_changed

const STARTER_SPECIES_ID := &"creature_fire_01"
## Provisional starter level: with the additive damage formula a level-7
## Emberling beats the level-3 Loambuck outside with HP to spare.
const STARTER_LEVEL := 7
## The protagonist starts with 5 basic Binding Scrolls (Specification 4.5).
const STARTING_BINDING_SCROLLS := 5
## Active party maximum (Specification 9.2).
const PARTY_CAPACITY := 3
## Level cap before the Area 1 boss falls (Specification 9.4).
const INITIAL_LEVEL_CAP := 20
## Provisional defeat penalty (Specification 20.1).
const DEFEAT_CURRENCY_PENALTY := 50

var party: Array[CreatureInstance] = []
var binding_scrolls: int = STARTING_BINDING_SCROLLS
var currency: int = 0
var level_cap: int = INITIAL_LEVEL_CAP


func _ready() -> void:
	ensure_starter()


## Gives the player their starter when the party is empty, so the game is
## playable from the first scene without an opening sequence.
func ensure_starter() -> void:
	if not party.is_empty():
		return
	var starter: CreatureInstance = Content.spawn_creature(STARTER_SPECIES_ID, STARTER_LEVEL)
	if starter != null:
		party.append(starter)
		party_changed.emit()


func party_is_full() -> bool:
	return party.size() >= PARTY_CAPACITY


## Adds a creature to the party. Returns false when it is full; the Creature
## Hotel (Specification 9.3) is the destination in that case once it exists.
func add_to_party(creature: CreatureInstance) -> bool:
	if creature == null or party_is_full():
		return false
	party.append(creature)
	party_changed.emit()
	return true


func has_usable_party_member() -> bool:
	for creature: CreatureInstance in party:
		if not creature.is_fainted():
			return true
	return false


## Full heal, as a healing service would do (Specification 16.6, 20.1).
func heal_party() -> void:
	for creature: CreatureInstance in party:
		creature.heal_full()
	party_changed.emit()


func apply_defeat_penalty() -> void:
	currency = maxi(0, currency - DEFEAT_CURRENCY_PENALTY)
