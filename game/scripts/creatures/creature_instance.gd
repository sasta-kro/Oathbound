class_name CreatureInstance
extends RefCounted
## A single live creature: a wild creature, an enemy's Oathbound, or one of the
## player's (Specification 9).
##
## The species owns all baseline identity; this object owns only per-individual
## runtime state (level, XP, current HP, equipped moves). There is no hidden
## per-individual stat variation in the MVP, so stats are a pure function of
## species, growth curve and level.

signal leveled_up(new_level: int)
signal evolved(from_species: CreatureSpecies, to_species: CreatureSpecies)

var species: CreatureSpecies
var level: int = 1
## Total accumulated XP, not XP into the current level.
var total_xp: int = 0
var current_hp: int = 0
## Equipped moves, at most [constant CreatureRules.MAX_MOVE_SLOTS].
var moves: Array[MoveData] = []
## The one innate passive this creature has, drawn from its species' ability
## pool (Specification 9.9). Null when the species has no abilities.
var ability: AbilityData


## Creates a creature at [param at_level] with its default moves and full HP.
##
## The ability comes from the species pool slot [param ability_index], which
## defaults to the first slot so creation stays deterministic. Callers that
## want variety, such as wild encounters, pass an index or call
## [method randomize_ability].
static func create(
	from_species: CreatureSpecies, at_level: int = 1, ability_index: int = 0
) -> CreatureInstance:
	var instance := CreatureInstance.new()
	instance.species = from_species
	instance.level = clampi(at_level, 1, CreatureRules.GLOBAL_MAX_LEVEL)
	if from_species != null:
		instance.total_xp = from_species.growth_curve().total_xp_for_level(instance.level)
		instance.moves = from_species.default_moves_at(instance.level)
		var chosen := from_species.ability_at(ability_index)
		instance.ability = chosen if chosen != null else from_species.default_ability()
	instance.current_hp = instance.max_hp()
	return instance


func display_name() -> String:
	return species.display_name if species != null else "Unknown Creature"


func species_id() -> StringName:
	return species.id if species != null else &""


func types() -> Array[int]:
	return species.types() if species != null else []


# --- Stats -------------------------------------------------------------------


func max_hp() -> int:
	if species == null:
		return 1
	return maxi(1, species.growth_curve().hp_at_level(species.base_hp, level))


func attack() -> int:
	return _stat(species.base_attack if species != null else 1)


func defense() -> int:
	return _stat(species.base_defense if species != null else 1)


func speed() -> int:
	return _stat(species.base_speed if species != null else 1)


func is_fainted() -> bool:
	return current_hp <= 0


func hp_fraction() -> float:
	return float(current_hp) / float(max_hp())


## Used by the binding chance formula (Specification 15.3).
func missing_hp_fraction() -> float:
	return 1.0 - hp_fraction()


func heal_full() -> void:
	current_hp = max_hp()


func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp())


# --- Experience --------------------------------------------------------------


## Total XP needed to reach the next level, or 0 at the global maximum.
func xp_to_next_level() -> int:
	if species == null or level >= CreatureRules.GLOBAL_MAX_LEVEL:
		return 0
	return maxi(0, species.growth_curve().total_xp_for_level(level + 1) - total_xp)


## XP earned since reaching the current level.
func xp_into_current_level() -> int:
	if species == null:
		return 0
	return total_xp - species.growth_curve().total_xp_for_level(level)


## Awards XP, stopping at [param level_cap] (Specification 9.4, 9.5).
##
## XP that cannot be applied because the cap is reached is reported as
## [member XpResult.excess] rather than stored, so the Experience Vessel rule
## stays outside this class.
func gain_xp(amount: int, level_cap: int = CreatureRules.GLOBAL_MAX_LEVEL) -> XpResult:
	var result := XpResult.new()
	result.requested = amount
	result.starting_level = level
	result.new_level = level
	if species == null or amount <= 0:
		return result

	var cap: int = clampi(level_cap, 1, CreatureRules.GLOBAL_MAX_LEVEL)
	if level >= cap:
		result.excess = amount
		result.evolution_ready = can_evolve()
		return result

	var curve := species.growth_curve()
	total_xp += amount
	while level < cap and total_xp >= curve.total_xp_for_level(level + 1):
		_apply_level_up()
		result.learnable_moves.append_array(species.moves_learned_at(level))

	var cap_total := curve.total_xp_for_level(cap)
	if level >= cap and total_xp > cap_total:
		result.excess = total_xp - cap_total
		total_xp = cap_total

	result.applied = amount - result.excess
	result.new_level = level
	result.evolution_ready = can_evolve()
	return result


# --- Moves -------------------------------------------------------------------


func has_free_move_slot() -> bool:
	return moves.size() < CreatureRules.MAX_MOVE_SLOTS


func knows_move(move: MoveData) -> bool:
	return move != null and moves.has(move)


## Learns [param move] into a free slot. Returns false when the move is already
## known, invalid, or all slots are full; the caller then offers a replacement
## choice (Specification 9.8).
func learn_move(move: MoveData) -> bool:
	if move == null or knows_move(move) or not has_free_move_slot():
		return false
	moves.append(move)
	return true


## Replaces the move in [param slot] with [param move].
func replace_move(slot: int, move: MoveData) -> bool:
	if move == null or knows_move(move) or slot < 0 or slot >= moves.size():
		return false
	moves[slot] = move
	return true


## Forgets a move. The last remaining move cannot be forgotten.
func forget_move(move: MoveData) -> bool:
	if moves.size() <= 1:
		return false
	var index := moves.find(move)
	if index == -1:
		return false
	moves.remove_at(index)
	return true


## Learnable moves that are not currently equipped, offered by the Hub 1
## relearn service (Specification 9.8).
func relearnable_moves() -> Array[MoveData]:
	var out: Array[MoveData] = []
	if species == null:
		return out
	for move: MoveData in species.moves_available_at(level):
		if not knows_move(move):
			out.append(move)
	return out


## Learns everything from [param result] that fits in a free slot and returns
## the moves that still need a player replace-or-refuse choice.
func resolve_new_moves(result: XpResult) -> Array[MoveData]:
	var needs_choice: Array[MoveData] = []
	for move: MoveData in result.learnable_moves:
		if knows_move(move):
			continue
		if not learn_move(move):
			needs_choice.append(move)
	return needs_choice


# --- Evolution ---------------------------------------------------------------


func can_evolve() -> bool:
	return species != null and species.evolves() and level >= species.evolution_level


## Evolves into the species' evolution target (Specification 9.7).
##
## Level, XP and moves carry over and the amount of missing HP is preserved.
## Returns false when the creature cannot currently evolve; the player may
## always refuse, in which case this is simply not called.
func evolve() -> bool:
	if not can_evolve():
		return false
	var previous := species
	var missing_hp: int = max_hp() - current_hp
	var previous_ability_index := ability_index()
	species = species.evolves_into
	current_hp = maxi(0, max_hp() - missing_hp) if not is_fainted() else 0
	ability = _carry_ability_over(previous_ability_index)
	evolved.emit(previous, species)
	return true


## Keeps the same ability across an evolution when the new species can also
## have it, otherwise keeps the same pool slot, otherwise falls back to the
## default ability (Specification 9.9.3).
func _carry_ability_over(previous_index: int) -> AbilityData:
	if ability != null and species.ability_index_of(ability) != -1:
		return ability
	var same_slot := species.ability_at(previous_index)
	return same_slot if same_slot != null else species.default_ability()


# --- Ability -----------------------------------------------------------------


func has_ability() -> bool:
	return ability != null


## Slot this creature's ability occupies in its species pool, or -1.
func ability_index() -> int:
	if species == null or ability == null:
		return -1
	return species.ability_index_of(ability)


## Replaces the ability. Only abilities from the species pool are accepted, so
## a creature can never end up with an ability its species cannot have.
##
## This is a content and encounter tool. The player cannot change a creature's
## ability in the MVP (Specification 9.9.2).
func set_ability(new_ability: AbilityData) -> bool:
	if species == null or species.ability_index_of(new_ability) == -1:
		return false
	ability = new_ability
	return true


## Rerolls the ability from the species pool. Pass a seeded generator to keep
## the result reproducible.
func randomize_ability(rng: RandomNumberGenerator) -> void:
	if species == null:
		return
	ability = species.pick_ability(rng)


# --- Persistence -------------------------------------------------------------


## Save payload. Content is referenced by stable id so display names and
## resource paths can change freely (Specification 25.2).
func to_dict() -> Dictionary:
	var move_ids: Array[String] = []
	for move: MoveData in moves:
		move_ids.append(String(move.id))
	return {
		"species": String(species_id()),
		"level": level,
		"total_xp": total_xp,
		"current_hp": current_hp,
		"moves": move_ids,
		"ability": String(ability.id) if ability != null else "",
	}


## Rebuilds a creature from [method to_dict]. Returns null when the species id
## is unknown; unknown move ids are skipped so a trimmed move roster cannot
## break an existing save.
static func from_dict(data: Dictionary, registry: ContentRegistry) -> CreatureInstance:
	if registry == null:
		return null
	var found_species := registry.get_species(StringName(String(data.get("species", ""))))
	if found_species == null:
		return null
	var instance := CreatureInstance.new()
	instance.species = found_species
	instance.level = clampi(int(data.get("level", 1)), 1, CreatureRules.GLOBAL_MAX_LEVEL)
	instance.total_xp = int(data.get("total_xp", 0))
	for move_id: String in data.get("moves", []):
		var move := registry.get_move(StringName(move_id))
		if move != null:
			instance.learn_move(move)
	var saved_ability_id := StringName(String(data.get("ability", "")))
	instance.ability = _restore_ability(found_species, saved_ability_id, registry)
	instance.current_hp = clampi(int(data.get("current_hp", 0)), 0, instance.max_hp())
	return instance


## Resolves a saved ability id against the species pool. An ability that has
## been renamed away or removed from the pool falls back to the default one so
## a content change cannot invalidate an existing save.
static func _restore_ability(
	for_species: CreatureSpecies, ability_id: StringName, registry: ContentRegistry
) -> AbilityData:
	if ability_id == &"":
		return for_species.default_ability()
	var saved := registry.get_ability(ability_id)
	if saved != null and for_species.ability_index_of(saved) != -1:
		return saved
	DevLog.content_problem(
		(
			"Species '%s' can no longer have ability '%s'; using its default ability."
			% [for_species.id, ability_id]
		)
	)
	return for_species.default_ability()


func _stat(base_stat: int) -> int:
	if species == null:
		return 1
	return maxi(1, species.growth_curve().stat_at_level(base_stat, level))


func _apply_level_up() -> void:
	var previous_max_hp := max_hp()
	level += 1
	if not is_fainted():
		current_hp += max_hp() - previous_max_hp
	leveled_up.emit(level)
