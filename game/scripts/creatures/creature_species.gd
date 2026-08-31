class_name CreatureSpecies
extends Resource
## The baseline identity of a creature species (Specification 9.1).
##
## Everything an individual creature derives from its species lives here: types,
## base stats, growth, learnable moves, evolution and binding difficulty.
## Individuals have no IVs, natures or hidden stat variation in the MVP, so two
## creatures of the same species at the same level are identical.
##
## Adding a species must not require changing battle or creature rules.

## Stable content id, independent of [member display_name] (Specification 25.2).
@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Types")
@export var primary_type: Elements.Type = Elements.Type.FIRE
## Enables [member secondary_type]. Dual-type multipliers multiply
## (Specification 10.3).
@export var has_secondary_type: bool = false
@export var secondary_type: Elements.Type = Elements.Type.EARTH

@export_group("Base Stats")
@export_range(1, 255) var base_hp: int = 40
@export_range(1, 255) var base_attack: int = 40
@export_range(1, 255) var base_defense: int = 40
@export_range(1, 255) var base_speed: int = 40

@export_group("Growth")
## Falls back to [method GrowthCurve.fallback] when unassigned so missing
## content never breaks stat calculation.
@export var growth: GrowthCurve

@export_group("Learnset")
## Moves this species can learn and the level each becomes available.
@export var learnset: Array[LearnsetEntry] = []

@export_group("Evolution")
## Target species, or null when this species does not evolve. MVP evolution is
## level-based only and has at most one path (Specification 9.7).
@export var evolves_into: CreatureSpecies
@export_range(1, 100) var evolution_level: int = 0

@export_group("Abilities")
## Innate passives this species can have (Specification 9.9). A creature
## receives exactly one of them. The pool may be empty, in which case creatures
## of this species simply have no ability.
@export var ability_pool: Array[AbilityData] = []

@export_group("Binding")
## Base binding success chance before scroll grade and missing-HP modifiers
## (Specification 15.3). Provisional value.
@export_range(0.0, 1.0, 0.01) var base_bind_chance: float = 0.4

@export_group("Presentation")
## Optional. When null, callers must fall back to a labelled placeholder
## (Specification 23).
@export var battle_sprite: SpriteFrames
@export var overworld_sprite: SpriteFrames
@export var cry: AudioStream


## The species' elemental types, one or two entries.
func types() -> Array[int]:
	var out: Array[int] = [int(primary_type)]
	if has_secondary_type and int(secondary_type) != int(primary_type):
		out.append(int(secondary_type))
	return out


func type_display_name() -> String:
	var names: PackedStringArray = []
	for type: int in types():
		names.append(Elements.display_name(type))
	return "/".join(names)


func growth_curve() -> GrowthCurve:
	return growth if growth != null else GrowthCurve.fallback()


func has_abilities() -> bool:
	return not ability_pool.is_empty()


## The ability a creature of this species gets unless a caller chooses another.
func default_ability() -> AbilityData:
	return ability_pool[0] if has_abilities() else null


func ability_at(index: int) -> AbilityData:
	if index < 0 or index >= ability_pool.size():
		return null
	return ability_pool[index]


## Slot of [param ability] in the pool, or -1 when it is not in the pool.
func ability_index_of(ability: AbilityData) -> int:
	return ability_pool.find(ability)


## Picks an ability from the pool. Pass a seeded [RandomNumberGenerator] to keep
## the result reproducible; without one the default ability is returned so
## nothing is randomised by accident.
func pick_ability(rng: RandomNumberGenerator = null) -> AbilityData:
	if not has_abilities():
		return null
	if rng == null:
		return default_ability()
	return ability_pool[rng.randi_range(0, ability_pool.size() - 1)]


func evolves() -> bool:
	return evolves_into != null and evolution_level > 0


## Every move learnable at or below [param level], in learnset order.
func moves_available_at(level: int) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for entry: LearnsetEntry in learnset:
		if entry == null or entry.move == null:
			continue
		if entry.level <= level and not out.has(entry.move):
			out.append(entry.move)
	return out


## Moves whose learnset level is exactly [param level].
func moves_learned_at(level: int) -> Array[MoveData]:
	var out: Array[MoveData] = []
	for entry: LearnsetEntry in learnset:
		if entry == null or entry.move == null:
			continue
		if entry.level == level and not out.has(entry.move):
			out.append(entry.move)
	return out


## The moves a freshly created creature of [param level] starts with: the most
## recently learnable moves, up to the move-slot limit.
func default_moves_at(level: int) -> Array[MoveData]:
	var available := moves_available_at(level)
	if available.size() <= CreatureRules.MAX_MOVE_SLOTS:
		return available
	return available.slice(available.size() - CreatureRules.MAX_MOVE_SLOTS)


## Content problems for this species, empty when valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("Species at '%s' has no id." % resource_path)
	if display_name.is_empty():
		problems.append("Species '%s' has no display name." % id)
	if has_secondary_type and int(secondary_type) == int(primary_type):
		problems.append("Species '%s' repeats its primary type as secondary." % id)
	if learnset.is_empty():
		problems.append("Species '%s' has an empty learnset." % id)
	if moves_available_at(1).is_empty():
		problems.append("Species '%s' knows no move at level 1." % id)
	for entry: LearnsetEntry in learnset:
		if entry == null:
			problems.append("Species '%s' has an empty learnset row." % id)
		elif entry.move == null:
			problems.append(
				"Species '%s' has a learnset row at level %d with no move." % [id, entry.level]
			)
	if evolves_into != null and evolution_level <= 0:
		problems.append("Species '%s' has an evolution target but no evolution level." % id)
	if evolves_into == null and evolution_level > 0:
		problems.append("Species '%s' has an evolution level but no target." % id)
	if evolves_into == self:
		problems.append("Species '%s' evolves into itself." % id)
	var seen_abilities: Array[AbilityData] = []
	for ability: AbilityData in ability_pool:
		if ability == null:
			problems.append("Species '%s' has an empty ability pool row." % id)
		elif seen_abilities.has(ability):
			problems.append("Species '%s' lists ability '%s' twice." % [id, ability.id])
		else:
			seen_abilities.append(ability)
	return problems
