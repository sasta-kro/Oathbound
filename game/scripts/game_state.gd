extends Node
## Player-owned progression shared by the overworld and battles: the active
## party, Binding Scrolls, currency and the story level cap.
##
## Autoloaded as [code]GameState[/code]. [method to_dict] and [method from_dict]
## are the whole save format; [SaveService] moves the result to and from disk.
## The overworld records where the player stands here before every save, so a
## loaded journey resumes on the same spot.
##
## Saving departs from Specification 21.1 on purpose: besides the autosave
## slot the field writes at state boundaries, the player has manual slots
## they save to and load from themselves.

signal experience_awarded(creature: CreatureInstance, before_xp: int, before_level: int, applied: int)
signal party_changed
## Emitted after a save reached disk, manual or automatic.
signal game_saved(slot: int)
## A quest was accepted, refused, abandoned or completed.
signal quest_changed(quest: QuestData, status: QuestLog.Status)
## An objective of an active quest moved; [param done] once it is met.
signal quest_objective_advanced(quest: QuestData, index: int, done: bool)

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
## Standing with every quest (Specification 17). Built in [method _ready]
## because it reads content from the registry.
var quests: QuestLog

## Scene path of the area the player was last recorded in, or empty when the
## journey has not left the shipped starting area yet.
var area_path: String = ""
var player_position: Vector2 = Vector2.ZERO
var player_facing: Vector2i = Vector2i.DOWN
## Seconds spent in the field, across sessions. Only counts while
## [member play_time_running] is set by the overworld.
var play_seconds: float = 0.0
var play_time_running: bool = false
## Unix time of the last successful save this session or the loaded one, 0
## when the journey has never been saved.
var last_saved_at: int = 0
## The manual slot this journey was last loaded from or saved to, so the save
## screen can offer it first. [constant SaveService.NO_SLOT] until the player
## picks one.
var active_slot: int = SaveService.NO_SLOT
## Set by [method load_game] and consumed by the overworld once, so a
## continued journey opens where it was saved while a recorded location never
## moves the player on its own.
var _resume_pending: bool = false


func _ready() -> void:
	quests = QuestLog.new(Content)
	ensure_starter()


func _process(delta: float) -> void:
	if play_time_running:
		play_seconds += delta


## Throws away the current journey and starts over with the starter. Does not
## touch the save on disk; the title screen erases that deliberately.
func new_game() -> void:
	seen_species.clear()
	party.clear()
	binding_scrolls = STARTING_BINDING_SCROLLS
	currency = 0
	level_cap = INITIAL_LEVEL_CAP
	quests.clear()
	clear_location()
	_resume_pending = false
	play_seconds = 0.0
	last_saved_at = 0
	active_slot = SaveService.NO_SLOT
	ensure_starter()


func has_location() -> bool:
	return area_path != ""


func record_location(at_area_path: String, at_position: Vector2, facing: Vector2i) -> void:
	area_path = at_area_path
	player_position = at_position
	player_facing = facing


func clear_location() -> void:
	area_path = ""
	player_position = Vector2.ZERO
	player_facing = Vector2i.DOWN


# --- Persistence -------------------------------------------------------------


## Writes the journey to [param slot]. Returns whether it reached disk. A
## manual slot becomes the active one; the autosave slot never does.
func save_game(slot: int) -> bool:
	var stamp: int = int(Time.get_unix_time_from_system())
	var previous_stamp: int = last_saved_at
	last_saved_at = stamp
	if not SaveService.write(slot, to_dict()):
		last_saved_at = previous_stamp
		return false
	if SaveService.is_manual_slot(slot):
		active_slot = slot
	game_saved.emit(slot)
	return true


## The field's boundary save.
func autosave() -> bool:
	return save_game(SaveService.AUTOSAVE_SLOT)


## Restores the journey from [param slot]. Returns false, leaving the current
## state alone, when the slot is empty.
func load_game(slot: int) -> bool:
	var data: Dictionary = SaveService.read(slot)
	if data.is_empty():
		return false
	from_dict(data)
	active_slot = slot if SaveService.is_manual_slot(slot) else SaveService.NO_SLOT
	_resume_pending = has_location()
	return true


## Whether the overworld should open at the saved location. True once per
## [method load_game]; the field consumes it when it places the player.
func take_resume_request() -> bool:
	var pending: bool = _resume_pending
	_resume_pending = false
	return pending


## The whole save. Content is referenced by id, JSON-friendly throughout.
func to_dict() -> Dictionary:
	var party_data: Array = []
	for creature: CreatureInstance in party:
		party_data.append(creature.to_dict())
	var seen: Array = []
	for id: StringName in seen_species:
		seen.append(String(id))
	seen.sort()
	return {
		"saved_at": last_saved_at,
		"play_seconds": int(play_seconds),
		"party": party_data,
		"seen_species": seen,
		"binding_scrolls": binding_scrolls,
		"currency": currency,
		"level_cap": level_cap,
		"quests": quests.to_dict(),
		"location":
		{
			"area": area_path,
			"x": player_position.x,
			"y": player_position.y,
			"facing_x": player_facing.x,
			"facing_y": player_facing.y,
		},
	}


## Replaces the journey with [param data] from [method to_dict]. Creatures
## whose species no longer exists are dropped; a party left empty by that
## gets the starter back, so a save can never be unplayable.
func from_dict(data: Dictionary) -> void:
	party.clear()
	for entry: Variant in data.get("party", []):
		if not entry is Dictionary:
			continue
		var creature: CreatureInstance = CreatureInstance.from_dict(entry, Content)
		if creature != null and not party_is_full():
			party.append(creature)
	seen_species.clear()
	for id: Variant in data.get("seen_species", []):
		seen_species[StringName(String(id))] = true
	for creature: CreatureInstance in party:
		seen_species[creature.species_id()] = true
	binding_scrolls = maxi(0, int(data.get("binding_scrolls", STARTING_BINDING_SCROLLS)))
	currency = maxi(0, int(data.get("currency", 0)))
	level_cap = clampi(int(data.get("level_cap", INITIAL_LEVEL_CAP)), 1, CreatureRules.GLOBAL_MAX_LEVEL)
	quests.from_dict(data.get("quests", {}) if data.get("quests") is Dictionary else {})
	play_seconds = float(data.get("play_seconds", 0))
	last_saved_at = int(data.get("saved_at", 0))
	var location: Dictionary = data.get("location", {}) if data.get("location") is Dictionary else {}
	var saved_area: String = String(location.get("area", ""))
	if saved_area != "" and ResourceLoader.exists(saved_area):
		record_location(
			saved_area,
			Vector2(float(location.get("x", 0.0)), float(location.get("y", 0.0))),
			Vector2i(int(location.get("facing_x", 0)), int(location.get("facing_y", 1))),
		)
	else:
		clear_location()
	ensure_starter()
	party_changed.emit()


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


# --- Quests ------------------------------------------------------------------


func accept_quest(quest: QuestData) -> bool:
	if not quests.accept(quest):
		return false
	quest_changed.emit(quest, QuestLog.Status.ACTIVE)
	return true


func refuse_quest(quest: QuestData) -> bool:
	if not quests.refuse(quest):
		return false
	quest_changed.emit(quest, QuestLog.Status.REFUSED)
	return true


func abandon_quest(quest: QuestData) -> bool:
	if not quests.abandon(quest):
		return false
	quest_changed.emit(quest, QuestLog.Status.ABANDONED)
	return true


## Turns in a quest whose objectives are all met and pays its rewards
## (Specification 17.3). Returns the player-facing reward lines, empty when
## the quest was not ready.
func complete_quest(quest: QuestData) -> PackedStringArray:
	var lines: PackedStringArray = []
	if not quests.complete(quest):
		return lines
	if quest.reward_currency > 0:
		currency += quest.reward_currency
		lines.append("+%d coins" % quest.reward_currency)
	if quest.reward_binding_scrolls > 0:
		binding_scrolls += quest.reward_binding_scrolls
		lines.append(
			"+%d Binding Scroll%s" % [quest.reward_binding_scrolls, "" if quest.reward_binding_scrolls == 1 else "s"]
		)
	if quest.reward_xp > 0:
		for creature: CreatureInstance in party:
			if not creature.is_fainted():
				lines.append_array(_award_xp(creature, quest.reward_xp))
		party_changed.emit()
	quest_changed.emit(quest, QuestLog.Status.COMPLETED)
	return lines


## The overworld telling the log that [param kind] happened to
## [param target]: a species defeated or bound, an actor spoken to, an area
## entered. Every active quest that cares moves along.
func report_quest_event(kind: QuestObjective.Kind, target: StringName) -> void:
	for step: Dictionary in quests.report(kind, target):
		quest_objective_advanced.emit(step.quest, step.index, step.done)
