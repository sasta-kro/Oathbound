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
const QUESTS_DIR := "res://content/quests"
const ITEMS_DIR := "res://content/items"
const TYPE_CHART_PATH := "res://content/types/type_chart_mvp.tres"
## Species ids from before species were named after themselves rather than
## their original type and slot. Saves written then still carry them, so every
## lookup goes through [method canonical_species_id].
const LEGACY_SPECIES_IDS := {
	&"creature_earth_01": &"creature_loambuck",
	&"creature_earth_02": &"creature_rimeshard",
	&"creature_earth_03": &"creature_hollow_squire",
	&"creature_earth_04": &"creature_bulwark",
	&"creature_earth_05": &"creature_oathbreaker",
	&"creature_earth_06": &"creature_ironhorn",
	&"creature_earth_07": &"creature_kingsworn",
	&"creature_earth_08": &"creature_tuskcalf",
	&"creature_earth_09": &"creature_frostcairn",
	&"creature_earth_10": &"creature_gravelimp",
	&"creature_earth_11": &"creature_quarrybrute",
	&"creature_earth_12": &"creature_dustmote",
	&"creature_fire_01": &"creature_emberling",
	&"creature_fire_02": &"creature_cinderclaw",
	&"creature_fire_03": &"creature_slagling",
	&"creature_fire_04": &"creature_cinderhulk",
	&"creature_fire_05": &"creature_ashhound",
	&"creature_fire_06": &"creature_wispflame",
	&"creature_fire_07": &"creature_hammerhorn",
	&"creature_fire_08": &"creature_flicker",
	&"creature_fire_09": &"creature_hellmaw",
	&"creature_nature_01": &"creature_briarback",
	&"creature_nature_02": &"creature_sproutling",
	&"creature_nature_03": &"creature_grovehulk",
	&"creature_nature_04": &"creature_thornimp",
	&"creature_nature_05": &"creature_bramblewing",
	&"creature_nature_06": &"creature_leafwing",
	&"creature_nature_07": &"creature_elderbough",
	&"creature_rot_01": &"creature_skeleton_lord",
	&"creature_rot_02": &"creature_blightmaw",
	&"creature_rot_03": &"creature_rotcrawler",
	&"creature_rot_04": &"creature_wraithling",
	&"creature_rot_05": &"creature_gravereaper",
	&"creature_rot_06": &"creature_gravewisp",
	&"creature_rot_07": &"creature_barrow_knight",
	&"creature_rot_08": &"creature_gravehound",
	&"creature_steel_01": &"creature_bastion",
	&"creature_steel_02": &"creature_mercurite",
	&"creature_steel_03": &"creature_ironhulk",
	&"creature_steel_04": &"creature_rivetimp",
	&"creature_steel_05": &"creature_razorfiend",
	&"creature_steel_06": &"creature_sentinel_eye",
	&"creature_steel_07": &"creature_forgehorn",
	&"creature_water_01": &"creature_rillfin",
	&"creature_water_02": &"creature_leechling",
	&"creature_water_03": &"creature_mirelash",
	&"creature_water_04": &"creature_dreadmere",
	&"creature_water_05": &"creature_brinehound",
	&"creature_water_06": &"creature_mistwisp",
	&"creature_water_07": &"creature_deepcrag",
	&"creature_water_08": &"creature_mawleech",
	&"creature_water_09": &"creature_skimwing",
	&"creature_wind_01": &"creature_gustpip",
	&"creature_wind_02": &"creature_scorchbat",
	&"creature_wind_03": &"creature_quillimp",
	&"creature_wind_04": &"creature_pyrewing",
	&"creature_wind_05": &"creature_gloomgaze",
	&"creature_wind_06": &"creature_hexcaller",
	&"creature_wind_07": &"creature_galewing",
	&"creature_wind_08": &"creature_hexling",
	&"creature_wind_09": &"creature_stormeye",
}

var type_chart: TypeChart

var _species: Dictionary = {}
var _moves: Dictionary = {}
var _abilities: Dictionary = {}
var _quests: Dictionary = {}
var _items: Dictionary = {}


func _ready() -> void:
	reload()


## Rebuilds the whole index from disk.
func reload() -> void:
	_species.clear()
	_moves.clear()
	_abilities.clear()
	_quests.clear()
	_items.clear()
	_load_directory(SPECIES_DIR, _species, "species")
	_load_directory(MOVES_DIR, _moves, "move")
	_load_directory(ABILITIES_DIR, _abilities, "ability")
	# Quests are optional content (Specification 25.3): an empty or missing
	# directory only means nobody in the world has work to offer.
	if DirAccess.dir_exists_absolute(QUESTS_DIR):
		_load_directory(QUESTS_DIR, _quests, "quest")
	if DirAccess.dir_exists_absolute(ITEMS_DIR):
		_load_directory(ITEMS_DIR, _items, "item")
	_load_type_chart()
	DevLog.info(
		(
			"ContentRegistry loaded %d species, %d moves, %d abilities, %d quests and %d items."
			% [_species.size(), _moves.size(), _abilities.size(), _quests.size(), _items.size()]
		)
	)


func get_species(id: StringName) -> CreatureSpecies:
	return _species.get(canonical_species_id(id)) as CreatureSpecies


## [param id], or its current name when it is a legacy species id.
static func canonical_species_id(id: StringName) -> StringName:
	return LEGACY_SPECIES_IDS.get(id, id)


func get_move(id: StringName) -> MoveData:
	return _moves.get(id) as MoveData


func get_ability(id: StringName) -> AbilityData:
	return _abilities.get(id) as AbilityData


func get_quest(id: StringName) -> QuestData:
	return _quests.get(id) as QuestData


func get_item(id: StringName) -> ItemData:
	return _items.get(id) as ItemData


func has_item(id: StringName) -> bool:
	return _items.has(id)


## Every item, cheapest first, then by id.
func all_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item: ItemData in _items.values():
		out.append(item)
	out.sort_custom(
		func(a: ItemData, b: ItemData) -> bool:
			return a.price < b.price if a.price != b.price else String(a.id) < String(b.id)
	)
	return out


func has_species(id: StringName) -> bool:
	return _species.has(canonical_species_id(id))


func has_quest(id: StringName) -> bool:
	return _quests.has(id)


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


func all_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	var ids := _quests.keys()
	ids.sort()
	for id: StringName in ids:
		out.append(_quests[id])
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
	for quest: QuestData in all_quests():
		problems.append_array(quest.validate(self))
	for item: ItemData in all_items():
		problems.append_array(item.validate())
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
