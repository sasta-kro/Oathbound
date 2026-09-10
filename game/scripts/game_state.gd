extends Node
## Player-owned progression shared by the overworld and battles: the active
## party, Binding Scrolls, currency and the story level cap.
##
## Autoloaded as [code]GameState[/code]. Saving and loading (Specification 21)
## will serialise this node; until then it lives for one session.

signal experience_awarded(creature: CreatureInstance, before_xp: int, before_level: int, applied: int)
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

var seen_species: Dictionary = {}
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
		seen_species[starter.species_id()] = true
		party.append(starter)
		party_changed.emit()


func party_is_full() -> bool:
	return party.size() >= PARTY_CAPACITY


## Adds a creature to the party. Returns false when it is full; the Creature
## Hotel (Specification 9.3) is the destination in that case once it exists.
func add_to_party(creature: CreatureInstance) -> bool:
	if creature == null or party_is_full():
		return false
	seen_species[creature.species_id()] = true
	party.append(creature)
	party_changed.emit()
	return true


## The party member that fights first, and the one that lands and takes blows
## in the overworld. Null when nothing in the party can fight.
func lead_creature() -> CreatureInstance:
	for creature: CreatureInstance in party:
		if not creature.is_fainted():
			return creature
	return null


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


## Pays out a creature defeated outside a battle, such as one routed by an
## overworld strike, and returns the player-facing lines describing it.
##
## Battles award XP through [BattleEngine] instead, because the battle screen
## needs one event per beat to pace them. Both paths share the wording in
## [BattleRules], so the two accounts of the same reward stay identical.
func award_defeat_rewards(defeated: CreatureInstance) -> PackedStringArray:
	var lines: PackedStringArray = []
	if defeated == null:
		return lines
	currency += BattleRules.currency_for_defeating(defeated)
	var xp: int = BattleRules.xp_for_defeating(defeated)
	for creature: CreatureInstance in party:
		if creature.is_fainted():
			continue
		lines.append_array(_award_xp(creature, xp))
	party_changed.emit()
	return lines


func _award_xp(creature: CreatureInstance, xp: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var before_xp := creature.total_xp
	var before_level := creature.level
	var result: XpResult = creature.gain_xp(xp, level_cap)
	experience_awarded.emit(creature, before_xp, before_level, result.applied)
	lines.append(BattleRules.XP_GAINED_TEXT % [creature.display_name(), result.applied])
	if not result.leveled_up():
		return lines
	lines.append(BattleRules.LEVEL_UP_TEXT % [creature.display_name(), result.new_level])
	var known_before: Array[MoveData] = creature.moves.duplicate()
	var needs_choice: Array[MoveData] = creature.resolve_new_moves(result)
	for move: MoveData in creature.moves:
		if not known_before.has(move):
			lines.append(BattleRules.MOVE_LEARNED_TEXT % [creature.display_name(), move.display_name])
	# The replace-or-refuse menu does not exist yet (Specification 9.8), so an
	# overspilling move is reported and can be relearned in Hub 1.
	for move: MoveData in needs_choice:
		lines.append(
			BattleRules.MOVE_LEARN_SKIPPED_TEXT % [creature.display_name(), move.display_name]
		)
	if result.evolution_ready:
		lines.append(BattleRules.EVOLUTION_READY_TEXT % creature.display_name())
	return lines


func apply_defeat_penalty() -> void:
	currency = maxi(0, currency - DEFEAT_CURRENCY_PENALTY)
