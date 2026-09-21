extends Node
## Player-owned progression shared by the overworld and battles: the active
## party, Binding Scrolls, the item satchel, currency and the story level cap.
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
## A boss fell for the first time (Specification 19).
signal boss_defeated(boss_id: StringName)
## Emitted after a save reached disk, manual or automatic.
signal game_saved(slot: int)
## A quest was accepted, refused, abandoned or completed.
signal quest_changed(quest: QuestData, status: QuestLog.Status)
## An objective of an active quest moved; [param done] once it is met.
signal quest_objective_advanced(quest: QuestData, index: int, done: bool)
## Coins, Binding Scrolls or satchel items changed hands.
signal inventory_changed

## A chest was emptied. The field listens to keep the lid open.
signal chest_opened(chest_id: StringName)

const STARTER_SPECIES_ID := &"creature_emberling"
## Provisional starter level: with the additive damage formula a level-7
## Emberling beats the level-3 Loambuck outside with HP to spare.
const STARTER_LEVEL := 7
## The protagonist starts with 5 basic Binding Scrolls (Specification 4.5).
const STARTING_BINDING_SCROLLS := 5
## Active party maximum (Specification 9.2).
const PARTY_CAPACITY := 3
## How many Oathbound the paddock keeps for the player (Specification 9.3).
## Deep enough that nobody has to choose between binding and keeping.
const KEEPING_CAPACITY := 30
## Where a newly bound Oathbound went, from [method take_in].
const JOINED_PARTY := &"party"
const WENT_TO_KEEPING := &"keeping"
## Level cap before the Area 1 boss falls (Specification 9.4).
const INITIAL_LEVEL_CAP := 20
## The level cap each boss victory raises the party to (Specification 5.2,
## 9.4). Boss ids come from [member WildCreature.boss_id].
const BOSS_LEVEL_CAPS: Dictionary = {
	&"boss_area_01": 30,
	&"boss_area_02": 40,
}
const LEVEL_CAP_RAISED_TEXT := "Your Oathbound can now grow to level %d."
## The king on the barrow. His defeat raises no cap, because the cap is
## already at [constant CreatureRules.GLOBAL_MAX_LEVEL] by then, so the story
## says so itself rather than letting the last boss in the game pass without
## a word.
const FINAL_BOSS_ID := &"boss_area_03"
const FINAL_BOSS_TEXT := "The rite closes over him. The king sleeps."
## Quest EVENT ids the field reports on its own (Specification 17.2): an item
## bought or used, by item id, and a night at the inn.
const EVENT_BOUGHT_ITEM := "bought_%s"
const EVENT_USED_ITEM := "used_%s"
const EVENT_RESTED_AT_INN := &"rested_at_inn"
## Reported the first time an Oathbound is sent to the paddock or called back
## out of it, for the lesson that teaches the keeping (Specification 9.3).
const EVENT_KEPT_AN_OATHBOUND := &"kept_an_oathbound"
## Reported when the player changes which Oathbound walks in front.
const EVENT_CHANGED_LEAD := &"changed_lead"
## Provisional defeat penalty (Specification 20.1).
const DEFEAT_CURRENCY_PENALTY := 50
## Where a journey that has never rested anywhere wakes up after a rout: the
## town, on its own PlayerStart.
const DEFAULT_HAVEN_AREA := "res://areas/town.tscn"

var seen_species: Dictionary = {}
var party: Array[CreatureInstance] = []
## Everyone bound but not walking: healed, kept and saved with the journey.
var kept: Array[CreatureInstance] = []
var binding_scrolls: int = STARTING_BINDING_SCROLLS
var currency: int = 0
## The satchel: item id -> count, only items the player holds at least one
## of (Specification 16.1, unlimited). Binding Scrolls are counted in
## [member binding_scrolls] instead.
var items: Dictionary = {}
var level_cap: int = INITIAL_LEVEL_CAP
## Ids of every chest already emptied, as a set. A chest stays open for the
## rest of the journey (Specification 16.1).
var opened_chests: Dictionary = {}
## Ids of every boss beaten, as a set. Beaten bosses never return
## (Specification 19).
var defeated_bosses: Dictionary = {}
## Whether the ending has played. Saved, so loading a finished journey does
## not run the epilogue again on the first talk.
var story_complete: bool = false
## Standing with every quest (Specification 17). Built in [method _ready]
## because it reads content from the registry.
var quests: QuestLog

## Moves a companion has grown into but has no free slot for, each entry a
## {"creature": CreatureInstance, "move": MoveData}. The replace-or-refuse
## choice (Specification 9.8) is a screen of its own, and a battle cannot stop
## to show it, so the moves wait here until the field is calm again. Not
## saved: an unanswered offer is a moment, not part of the journey, and the
## move stays relearnable in Hub 1 either way.
var pending_move_learns: Array[Dictionary] = []

## Scene path of the area the player was last recorded in, or empty when the
## journey has not left the shipped starting area yet.
var area_path: String = ""
var player_position: Vector2 = Vector2.ZERO
var player_facing: Vector2i = Vector2i.DOWN
## Scene path of the last roof the party slept or healed under, and the spot
## in it to wake on. A rout carries the player back here instead of reviving
## them where they fell (Specification 20.1). Empty until the first inn or
## healer, which falls back to [constant DEFAULT_HAVEN_AREA].
var haven_area_path: String = ""
var haven_position: Vector2 = Vector2.ZERO
## Name of the inn or healer the haven belongs to, for the waking line.
var haven_name: String = ""
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
## Set by [method new_game] when the journey begins with the opening at the
## well, and consumed by the overworld once (Specification 4.5).
var _opening_pending: bool = false
## Set by [method jump_to_area]: the field opens in this area at its own
## PlayerStart instead of the town. Consumed once, like the other two.
var _jump_area: String = ""
## Set for the whole of a dev jump. Autosaving is off while it is true, so
## poking around an unfinished area cannot overwrite a real journey.
var dev_jump: bool = false


func _ready() -> void:
	quests = QuestLog.new(Content)
	ensure_starter()


func _process(delta: float) -> void:
	if play_time_running:
		play_seconds += delta


## Throws away the current journey and starts over. Does not touch the save
## on disk; the title screen erases that deliberately.
##
## With [param with_opening] the party starts empty and the overworld plays
## the opening, where the Elder hands over the starter (Specification 4.5).
## Without it the starter is granted straight away, which is what tests and
## a field launched directly from the editor want.
func new_game(with_opening: bool = false) -> void:
	seen_species.clear()
	party.clear()
	kept.clear()
	binding_scrolls = STARTING_BINDING_SCROLLS
	currency = 0
	items.clear()
	level_cap = INITIAL_LEVEL_CAP
	opened_chests.clear()
	defeated_bosses.clear()
	story_complete = false
	quests.clear()
	clear_location()
	clear_haven()
	_resume_pending = false
	play_seconds = 0.0
	last_saved_at = 0
	active_slot = SaveService.NO_SLOT
	_jump_area = ""
	dev_jump = false
	_opening_pending = with_opening
	if not with_opening:
		ensure_starter()


## Opens the field in [param area_scene_path] rather than the town, at that
## area's own PlayerStart. For the title screen's dev shortcuts, so an area
## can be walked before the quests that lead to it exist. Nothing is autosaved
## for the rest of the session; a manual save from the pause menu still works.
func jump_to_area(area_scene_path: String) -> void:
	_jump_area = area_scene_path
	dev_jump = true


## The area a dev jump asked for, once. Empty when there is none.
func take_jump_area() -> String:
	var path: String = _jump_area
	_jump_area = ""
	return path


## Whether the overworld should play the opening. True once per
## [code]new_game(true)[/code]; the field consumes it as it starts.
func take_opening_request() -> bool:
	var pending: bool = _opening_pending
	_opening_pending = false
	return pending


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


## Remembers the inn bed or healer's table the party was last put back
## together at. A rout wakes the player here (Specification 20.1).
func record_haven(at_area_path: String, at_position: Vector2, keeper_name: String) -> void:
	if at_area_path == "":
		return
	haven_area_path = at_area_path
	haven_position = at_position
	haven_name = keeper_name


func clear_haven() -> void:
	haven_area_path = ""
	haven_position = Vector2.ZERO
	haven_name = ""


func has_haven() -> bool:
	return haven_area_path != "" and ResourceLoader.exists(haven_area_path)


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


## The field's boundary save. A dev jump never reaches the autosave slot, so
## exploring an unfinished area leaves the player's own journey alone.
func autosave() -> bool:
	if dev_jump:
		return false
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
	_opening_pending = false
	return true


## Whether the overworld should open at the saved location. True once per
## [method load_game]; the field consumes it when it places the player.
func take_resume_request() -> bool:
	var pending: bool = _resume_pending
	_resume_pending = false
	return pending


## The whole save. Content is referenced by id, JSON-friendly throughout.
func to_dict() -> Dictionary:
	var party_data: Array = _creature_save_data(party)
	var seen: Array = []
	for id: StringName in seen_species:
		seen.append(String(id))
	seen.sort()
	var bosses: Array = []
	for id: StringName in defeated_bosses:
		bosses.append(String(id))
	bosses.sort()
	var chests: Array = []
	for id: StringName in opened_chests:
		chests.append(String(id))
	chests.sort()
	return {
		"saved_at": last_saved_at,
		"play_seconds": int(play_seconds),
		"party": party_data,
		"kept": _creature_save_data(kept),
		"seen_species": seen,
		"binding_scrolls": binding_scrolls,
		"currency": currency,
		"items": _item_save_data(),
		"level_cap": level_cap,
		"opened_chests": chests,
		"defeated_bosses": bosses,
		"story_complete": story_complete,
		"quests": quests.to_dict(),
		"location":
		{
			"area": area_path,
			"x": player_position.x,
			"y": player_position.y,
			"facing_x": player_facing.x,
			"facing_y": player_facing.y,
		},
		"haven":
		{
			"area": haven_area_path,
			"x": haven_position.x,
			"y": haven_position.y,
			"name": haven_name,
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
	kept.clear()
	for entry: Variant in data.get("kept", []):
		if not entry is Dictionary:
			continue
		var kept_creature: CreatureInstance = CreatureInstance.from_dict(entry, Content)
		if kept_creature != null and has_keeping_room():
			kept.append(kept_creature)
			seen_species[kept_creature.species_id()] = true
	seen_species.clear()
	for id: Variant in data.get("seen_species", []):
		seen_species[ContentRegistry.canonical_species_id(StringName(String(id)))] = true
	for creature: CreatureInstance in party:
		seen_species[creature.species_id()] = true
	binding_scrolls = maxi(0, int(data.get("binding_scrolls", STARTING_BINDING_SCROLLS)))
	currency = maxi(0, int(data.get("currency", 0)))
	items.clear()
	var saved_items: Dictionary = data.get("items", {}) if data.get("items") is Dictionary else {}
	for id: Variant in saved_items:
		var item: ItemData = Content.get_item(StringName(String(id)))
		if item != null and not item.is_binding_scroll():
			add_item(item, int(saved_items[id]))
	level_cap = clampi(int(data.get("level_cap", INITIAL_LEVEL_CAP)), 1, CreatureRules.GLOBAL_MAX_LEVEL)
	opened_chests.clear()
	for id: Variant in data.get("opened_chests", []):
		opened_chests[StringName(String(id))] = true
	defeated_bosses.clear()
	for id: Variant in data.get("defeated_bosses", []):
		defeated_bosses[StringName(String(id))] = true
	story_complete = bool(data.get("story_complete", false))
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
	var haven: Dictionary = data.get("haven", {}) if data.get("haven") is Dictionary else {}
	var saved_haven: String = String(haven.get("area", ""))
	if saved_haven != "" and ResourceLoader.exists(saved_haven):
		record_haven(
			saved_haven,
			Vector2(float(haven.get("x", 0.0)), float(haven.get("y", 0.0))),
			String(haven.get("name", "")),
		)
	else:
		clear_haven()
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


## Adds a creature to the party. Returns false when it is full; use
## [method take_in] to let the paddock catch the overflow.
func add_to_party(creature: CreatureInstance) -> bool:
	if creature == null or party_is_full():
		return false
	seen_species[creature.species_id()] = true
	party.append(creature)
	party_changed.emit()
	return true


# --- The paddock (Specification 9.3) -----------------------------------------
##
## Three walk with the player; everyone else is kept, and nothing bound is
## ever turned away for want of room. Kept Oathbound are healed, out of the
## weather and saved with the journey, and they can be swapped for a
## companion at any time, because the alternative is a player who stops
## binding anything once the third slot fills.


func has_keeping_room() -> bool:
	return kept.size() < KEEPING_CAPACITY


## Takes [param creature] into the journey: into the party when there is room
## for it, and into the paddock when there is not. Returns where it went, as
## [constant JOINED_PARTY] or [constant WENT_TO_KEEPING], or an empty name
## when it could not be taken at all.
func take_in(creature: CreatureInstance) -> StringName:
	if creature == null:
		return &""
	if add_to_party(creature):
		return JOINED_PARTY
	if not has_keeping_room():
		return &""
	seen_species[creature.species_id()] = true
	kept.append(creature)
	party_changed.emit()
	return WENT_TO_KEEPING


## Sends the party member at [param index] to the paddock. Refused when it
## would leave nobody to walk with, or when the paddock is full.
func send_to_keeping(index: int) -> bool:
	if index < 0 or index >= party.size() or party.size() <= 1 or not has_keeping_room():
		return false
	var creature: CreatureInstance = party[index]
	party.remove_at(index)
	creature.heal_full()
	kept.append(creature)
	party_changed.emit()
	report_quest_event(QuestObjective.Kind.EVENT, EVENT_KEPT_AN_OATHBOUND)
	return true


## Calls the kept Oathbound at [param index] back into the party. Refused
## when the party is full, so the swap is always deliberate.
func call_out_of_keeping(index: int) -> bool:
	if index < 0 or index >= kept.size() or party_is_full():
		return false
	var creature: CreatureInstance = kept[index]
	kept.remove_at(index)
	party.append(creature)
	party_changed.emit()
	report_quest_event(QuestObjective.Kind.EVENT, EVENT_KEPT_AN_OATHBOUND)
	return true


## Puts the party member at [param index] in front, which is who fights first
## and who lands and takes blows in the field (Specification 9.2).
func set_lead(index: int) -> bool:
	if index <= 0 or index >= party.size() or party[index].is_fainted():
		return false
	var creature: CreatureInstance = party[index]
	party.remove_at(index)
	party.push_front(creature)
	party_changed.emit()
	report_quest_event(QuestObjective.Kind.EVENT, EVENT_CHANGED_LEAD)
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


## Remembers that [param creature] reached [param move] with no room for it,
## so the field can offer the choice once it is somewhere it can be shown.
## Only party members are queued: a lesson's borrowed creature is not the
## player's to reshape, and an offer already waiting is not doubled up.
func queue_move_learn(creature: CreatureInstance, move: MoveData) -> void:
	if creature == null or move == null or creature.knows_move(move):
		return
	if not party.has(creature):
		return
	for entry: Dictionary in pending_move_learns:
		if entry["creature"] == creature and entry["move"] == move:
			return
	pending_move_learns.append({"creature": creature, "move": move})


## The next offer to put to the player, or an empty dictionary when there is
## none left. Offers for a creature that has since left the party, or that
## found room for the move another way, are dropped rather than shown.
func take_pending_move_learn() -> Dictionary:
	while not pending_move_learns.is_empty():
		var entry: Dictionary = pending_move_learns.pop_front()
		var creature: CreatureInstance = entry["creature"]
		var move: MoveData = entry["move"]
		if creature == null or not party.has(creature) or creature.knows_move(move):
			continue
		if creature.has_free_move_slot():
			creature.learn_move(move)
			party_changed.emit()
			continue
		return entry
	return {}


## Full heal, as a healing service would do (Specification 16.6, 20.1).
## Returns true when anyone was actually hurt, so a healer can tell the player
## what its table just did rather than leaving the mend invisible.
func heal_party() -> bool:
	var mended: bool = false
	for creature: CreatureInstance in party:
		if creature.current_hp < creature.max_hp():
			mended = true
		creature.heal_full()
	party_changed.emit()
	return mended


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
	# A move with nowhere to go is announced here and offered for real once
	# the field is calm again (Specification 9.8).
	for move: MoveData in needs_choice:
		queue_move_learn(creature, move)
		lines.append(
			BattleRules.MOVE_LEARN_PENDING_TEXT % [creature.display_name(), move.display_name]
		)
	if result.evolution_ready:
		lines.append(BattleRules.EVOLUTION_READY_TEXT % creature.display_name())
	return lines


func has_defeated_boss(boss_id: StringName) -> bool:
	return defeated_bosses.has(boss_id)


## Records a boss victory and raises the level cap it unlocks. Returns the
## player-facing lines describing what changed, empty when the boss had
## already been beaten.
func record_boss_defeat(boss_id: StringName) -> PackedStringArray:
	var lines: PackedStringArray = []
	if boss_id == &"" or has_defeated_boss(boss_id):
		return lines
	defeated_bosses[boss_id] = true
	var new_cap: int = int(BOSS_LEVEL_CAPS.get(boss_id, 0))
	if new_cap > level_cap:
		level_cap = mini(new_cap, CreatureRules.GLOBAL_MAX_LEVEL)
		lines.append(LEVEL_CAP_RAISED_TEXT % level_cap)
	if boss_id == FINAL_BOSS_ID:
		lines.append(FINAL_BOSS_TEXT)
	boss_defeated.emit(boss_id)
	return lines


## Whether the chest called [param chest_id] has already been emptied.
func has_opened_chest(chest_id: StringName) -> bool:
	return opened_chests.has(chest_id)


## Empties a chest into the satchel and returns the player-facing lines for
## what was in it. A chest already emptied gives nothing back, so a reloaded
## save can never pay out twice.
func open_chest(chest_id: StringName, contents: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	if chest_id == &"" or has_opened_chest(chest_id):
		return lines
	opened_chests[chest_id] = true
	var coins: int = maxi(0, int(contents.get("coins", 0)))
	if coins > 0:
		currency += coins
		lines.append("+%d coins" % coins)
	var scrolls: int = maxi(0, int(contents.get("binding_scrolls", 0)))
	if scrolls > 0:
		binding_scrolls += scrolls
		lines.append("+%d Binding Scroll%s" % [scrolls, "" if scrolls == 1 else "s"])
	var item_counts: Dictionary = contents.get("items", {}) if contents.get("items") is Dictionary else {}
	for id: Variant in item_counts:
		var item: ItemData = Content.get_item(StringName(String(id)))
		var count: int = maxi(0, int(item_counts[id]))
		if item == null or count <= 0:
			continue
		add_item(item, count)
		lines.append("+%d %s" % [count, item.display_name])
	if not lines.is_empty():
		inventory_changed.emit()
	chest_opened.emit(chest_id)
	return lines


func apply_defeat_penalty() -> void:
	currency = maxi(0, currency - DEFEAT_CURRENCY_PENALTY)


# --- Items and shops ---------------------------------------------------------


func item_count(id: StringName) -> int:
	var item: ItemData = Content.get_item(id)
	if item != null and item.is_binding_scroll():
		return binding_scrolls
	return int(items.get(id, 0))


## Puts [param count] of [param item] in the satchel, or on the scroll pile
## for a Binding Scroll.
func add_item(item: ItemData, count: int = 1) -> void:
	if item == null or count <= 0:
		return
	if item.is_binding_scroll():
		binding_scrolls += count
	else:
		items[item.id] = int(items.get(item.id, 0)) + count
	inventory_changed.emit()


## Takes one [param item] out of the satchel. False when there was none.
func remove_item(item: ItemData) -> bool:
	if item == null or item_count(item.id) <= 0:
		return false
	if item.is_binding_scroll():
		binding_scrolls -= 1
	else:
		items[item.id] = int(items[item.id]) - 1
		if int(items[item.id]) <= 0:
			items.erase(item.id)
	inventory_changed.emit()
	return true


## Satchel items in shop order, as [code]{item, count}[/code] pairs.
func held_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: ItemData in Content.all_items():
		if not item.is_binding_scroll() and item_count(item.id) > 0:
			out.append({"item": item, "count": item_count(item.id)})
	return out


## Replaces the satchel with counts a battle settled on.
func set_item_counts(counts: Dictionary) -> void:
	items.clear()
	for id: StringName in counts:
		if int(counts[id]) > 0:
			items[id] = int(counts[id])
	inventory_changed.emit()


## Buys one [param item] (Specification 16.5, unlimited stock). False when
## the player cannot afford it.
func buy_item(item: ItemData) -> bool:
	if item == null or currency < item.price:
		return false
	currency -= item.price
	add_item(item)
	report_quest_event(QuestObjective.Kind.EVENT, StringName(EVENT_BOUGHT_ITEM % item.id))
	return true


## Uses [param item] on [param creature] outside battle. Returns the line
## describing what happened, or the reason it could not be used, and whether
## the item was spent.
func use_item_in_field(item: ItemData, creature: CreatureInstance) -> Dictionary:
	if item == null or item_count(item.id) <= 0:
		return {"used": false, "text": "You have none left."}
	if not item.usable_in_field:
		return {"used": false, "text": "%s can only be used in battle." % item.display_name}
	var refusal: String = item.refusal(creature)
	if not refusal.is_empty():
		return {"used": false, "text": refusal}
	var restored: int = item.heal_amount(creature)
	creature.set_hp(creature.current_hp + restored)
	remove_item(item)
	party_changed.emit()
	report_quest_event(QuestObjective.Kind.EVENT, StringName(EVENT_USED_ITEM % item.id))
	var text: String = (
		"%s was revived with %d HP." % [creature.display_name(), restored]
		if item.effect == ItemData.Effect.REVIVE
		else "%s recovered %d HP." % [creature.display_name(), restored]
	)
	return {"used": true, "text": text}


## Every creature in [param creatures] as save data, in order.
func _creature_save_data(creatures: Array[CreatureInstance]) -> Array:
	var out: Array = []
	for creature: CreatureInstance in creatures:
		out.append(creature.to_dict())
	return out


func _item_save_data() -> Dictionary:
	var out: Dictionary = {}
	var ids: Array = items.keys()
	ids.sort()
	for id: StringName in ids:
		out[String(id)] = int(items[id])
	return out


# --- Quests ------------------------------------------------------------------


## Accepts [param quest]. A BIND objective counts Oathbound already in the
## party, so a player who bound the creature early is never asked to bind a
## second one into a party that may have no room for it.
func accept_quest(quest: QuestData) -> bool:
	if not quests.accept(quest):
		return false
	quest_changed.emit(quest, QuestLog.Status.ACTIVE)
	for objective: QuestObjective in quest.objectives:
		if objective == null or objective.kind != QuestObjective.Kind.BIND:
			continue
		for creature: CreatureInstance in party:
			if creature.species_id() == objective.target:
				report_quest_event(QuestObjective.Kind.BIND, objective.target)
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
	var reward_item: ItemData = Content.get_item(quest.reward_item) if quest.reward_item != &"" else null
	if reward_item != null and quest.reward_item_count > 0:
		add_item(reward_item, quest.reward_item_count)
		lines.append("+%d %s" % [quest.reward_item_count, reward_item.display_name])
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
