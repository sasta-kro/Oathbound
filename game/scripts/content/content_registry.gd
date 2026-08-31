class_name ContentRegistry
extends Node
## Loads and indexes replaceable game content by stable id (Specification 25.2).
##
## Autoloaded as [code]Content[/code]. Adding a creature or move means dropping a
## [code].tres[/code] into the content directories; no code change is required.
## Ids come from the resource's own [code]id[/code] field, never from filenames.

const SPECIES_DIR := "res://content/creatures"
const MOVES_DIR := "res://content/moves"
const ABILITIES_DIR := "res://content/abilities"
const TYPE_CHART_PATH := "res://content/types/type_chart_mvp.tres"

var type_chart: TypeChart

var _species: Dictionary = {}
var _moves: Dictionary = {}
var _abilities: Dictionary = {}


func _ready() -> void:
	reload()


## Rebuilds the whole index from disk.
func reload() -> void:
	_species.clear()
	_moves.clear()
	_abilities.clear()
	_load_directory(SPECIES_DIR, _species, "species")
	_load_directory(MOVES_DIR, _moves, "move")
	_load_directory(ABILITIES_DIR, _abilities, "ability")
	_load_type_chart()
	DevLog.info(
		(
			"ContentRegistry loaded %d species, %d moves and %d abilities."
			% [_species.size(), _moves.size(), _abilities.size()]
		)
	)


func get_species(id: StringName) -> CreatureSpecies:
	return _species.get(id) as CreatureSpecies


func get_move(id: StringName) -> MoveData:
	return _moves.get(id) as MoveData


func get_ability(id: StringName) -> AbilityData:
	return _abilities.get(id) as AbilityData


func has_species(id: StringName) -> bool:
	return _species.has(id)


func has_move(id: StringName) -> bool:
	return _moves.has(id)


func has_ability(id: StringName) -> bool:
	return _abilities.has(id)


func all_species() -> Array[CreatureSpecies]:
	var out: Array[CreatureSpecies] = []
	for id: StringName in _species_ids_sorted():
		out.append(_species[id])
	return out


func all_moves() -> Array[MoveData]:
	var out: Array[MoveData] = []
	var ids := _moves.keys()
	ids.sort()
	for id: StringName in ids:
		out.append(_moves[id])
	return out


func all_abilities() -> Array[AbilityData]:
	var out: Array[AbilityData] = []
	var ids := _abilities.keys()
	ids.sort()
	for id: StringName in ids:
		out.append(_abilities[id])
	return out


## Creates a live creature from a species id. Returns null for unknown ids.
func spawn_creature(
	species_id: StringName, level: int = 1, ability_index: int = 0
) -> CreatureInstance:
	var found := get_species(species_id)
	if found == null:
		DevLog.content_problem("Unknown species id '%s'." % species_id)
		return null
	return CreatureInstance.create(found, level, ability_index)


## Checks every loaded resource and returns the problems found. Intended for
## tests and the headless content check in [code]tools/[/code].
func validate() -> Array[String]:
	var problems: Array[String] = []
	for species: CreatureSpecies in all_species():
		problems.append_array(species.validate())
		for entry: LearnsetEntry in species.learnset:
			if entry != null and entry.move != null and not has_move(entry.move.id):
				problems.append(
					(
						"Species '%s' references move '%s' which is not in the move registry."
						% [species.id, entry.move.id]
					)
				)
		if species.evolves_into != null and not has_species(species.evolves_into.id):
			problems.append(
				(
					"Species '%s' evolves into '%s' which is not in the species registry."
					% [species.id, species.evolves_into.id]
				)
			)
		for ability: AbilityData in species.ability_pool:
			if ability != null and not has_ability(ability.id):
				problems.append(
					(
						"Species '%s' references ability '%s' which is not in the ability registry."
						% [species.id, ability.id]
					)
				)
	for move: MoveData in all_moves():
		problems.append_array(move.validate())
	for ability: AbilityData in all_abilities():
		problems.append_array(ability.validate())
	if type_chart == null:
		problems.append("No type chart loaded from '%s'." % TYPE_CHART_PATH)
	return problems


func _species_ids_sorted() -> Array:
	var ids := _species.keys()
	ids.sort()
	return ids


func _load_directory(directory: String, into: Dictionary, kind: String) -> void:
	if not DirAccess.dir_exists_absolute(directory):
		DevLog.content_problem("Content directory '%s' does not exist." % directory)
		return
	for file_name: String in DirAccess.get_files_at(directory):
		var resource_name := file_name
		if resource_name.ends_with(".remap"):
			resource_name = resource_name.trim_suffix(".remap")
		if not (resource_name.ends_with(".tres") or resource_name.ends_with(".res")):
			continue
		var path := directory.path_join(resource_name)
		var resource := ResourceLoader.load(path)
		if resource == null:
			DevLog.content_problem("Could not load %s at '%s'." % [kind, path])
			continue
		var raw_id: Variant = resource.get("id")
		if raw_id == null or StringName(raw_id) == &"":
			DevLog.content_problem("The %s at '%s' has no id." % [kind, path])
			continue
		var id := StringName(raw_id)
		if into.has(id):
			DevLog.content_problem(
				"Duplicate %s id '%s' at '%s'; keeping the first one." % [kind, id, path]
			)
			continue
		into[id] = resource


func _load_type_chart() -> void:
	if not ResourceLoader.exists(TYPE_CHART_PATH):
		DevLog.content_problem("No type chart at '%s'; using neutral matchups." % TYPE_CHART_PATH)
		type_chart = TypeChart.new()
		return
	type_chart = ResourceLoader.load(TYPE_CHART_PATH)
	type_chart.refresh()
