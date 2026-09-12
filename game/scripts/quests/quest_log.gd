class_name QuestLog
extends RefCounted
## The player's standing with every quest they have touched (Specification
## 17): which are active, how far along each objective is, which are done.
##
## Pure state and rules. Rewards, saving and dialogue happen in [GameState]
## and the overworld; this only answers what a quest's status is and moves
## it along when the world reports an event. Quests it has never heard of
## are [constant Status.NEW], so content added later needs nothing here.
##
## A quest can never fail (Specification 17.1). Refusing or abandoning it
## leaves it offerable again; abandoning also resets its progress, since
## objectives only count while the quest is accepted (Specification 17.2).

enum Status { NEW, REFUSED, ACTIVE, ABANDONED, COMPLETED }

const STATUS_KEY := "status"
const PROGRESS_KEY := "progress"
const QUEST_KEY := "quest"

## Quest id -> {status: int, progress: Array[int], quest: QuestData} for
## every quest touched.
var _entries: Dictionary = {}
## Where saved quest ids are resolved; the [ContentRegistry] in the game.
var _registry: Node


func _init(registry: Node) -> void:
	_registry = registry


func clear() -> void:
	_entries.clear()


func status(id: StringName) -> Status:
	if not _entries.has(id):
		return Status.NEW
	return _entries[id][STATUS_KEY] as Status


func is_active(id: StringName) -> bool:
	return status(id) == Status.ACTIVE


func is_completed(id: StringName) -> bool:
	return status(id) == Status.COMPLETED


## Whether the giver may put [param quest] to the player right now: never
## accepted or done, and whatever it builds on is complete.
func can_offer(quest: QuestData) -> bool:
	if quest == null:
		return false
	match status(quest.id):
		Status.NEW, Status.REFUSED, Status.ABANDONED:
			return quest.requires == &"" or is_completed(quest.requires)
	return false


## Whether the quest has been offered before and turned down or dropped, so
## the giver can ask whether the player changed their mind.
func was_declined(id: StringName) -> bool:
	return status(id) in [Status.REFUSED, Status.ABANDONED]


func accept(quest: QuestData) -> bool:
	if not can_offer(quest):
		return false
	_entries[quest.id] = _entry(quest, Status.ACTIVE)
	return true


func refuse(quest: QuestData) -> bool:
	if not can_offer(quest):
		return false
	_entries[quest.id] = _entry(quest, Status.REFUSED)
	return true


## Drops an active quest. Its progress is thrown away with it.
func abandon(quest: QuestData) -> bool:
	if quest == null or not is_active(quest.id):
		return false
	_entries[quest.id] = _entry(quest, Status.ABANDONED)
	return true


## Marks an active quest whose objectives are all met as done. Returns
## false when it is not active or not yet ready, so a turn-in can never
## skip the work.
func complete(quest: QuestData) -> bool:
	if not is_ready(quest):
		return false
	_entries[quest.id][STATUS_KEY] = Status.COMPLETED
	return true


## Active with every objective met, waiting to be turned in.
func is_ready(quest: QuestData) -> bool:
	if quest == null or not is_active(quest.id):
		return false
	for index: int in quest.objectives.size():
		if not is_objective_done(quest, index):
			return false
	return true


func progress(quest: QuestData, index: int) -> int:
	if quest == null or not _entries.has(quest.id):
		return 0
	var tallies: Array = _entries[quest.id][PROGRESS_KEY]
	if index < 0 or index >= tallies.size():
		return 0
	return int(tallies[index])


func is_objective_done(quest: QuestData, index: int) -> bool:
	if quest == null or index < 0 or index >= quest.objectives.size():
		return false
	var objective: QuestObjective = quest.objectives[index]
	return objective == null or progress(quest, index) >= objective.required()


## Tells every active quest that [param kind] happened to [param target].
## One event advances every objective it fits (Specification 17.2), across
## quests. Returns the objectives that moved as
## [code]{quest: QuestData, index: int, done: bool}[/code], in quest order.
func report(kind: QuestObjective.Kind, target: StringName) -> Array[Dictionary]:
	var advanced: Array[Dictionary] = []
	for quest: QuestData in active_quests():
		var tallies: Array = _entries[quest.id][PROGRESS_KEY]
		for index: int in quest.objectives.size():
			var objective: QuestObjective = quest.objectives[index]
			if objective == null or not objective.matches(kind, target):
				continue
			if int(tallies[index]) >= objective.required():
				continue
			tallies[index] = int(tallies[index]) + 1
			advanced.append({"quest": quest, "index": index, "done": is_objective_done(quest, index)})
	return advanced


## Every active quest, main story first, then by id so the order is stable.
func active_quests() -> Array[QuestData]:
	return _quests_with(Status.ACTIVE)


func completed_quests() -> Array[QuestData]:
	return _quests_with(Status.COMPLETED)


func _quests_with(wanted: Status) -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id: StringName in _entries:
		if _entries[id][STATUS_KEY] == wanted:
			out.append(_entries[id][QUEST_KEY])
	# StringNames compare by identity, so the ids are ordered as text.
	out.sort_custom(func(a: QuestData, b: QuestData) -> bool:
		if a.is_main() != b.is_main():
			return a.is_main()
		return String(a.id) < String(b.id))
	return out


func _entry(quest: QuestData, with_status: Status) -> Dictionary:
	return {STATUS_KEY: with_status, PROGRESS_KEY: _fresh_progress(quest), QUEST_KEY: quest}


func _fresh_progress(quest: QuestData) -> Array:
	var tallies: Array = []
	tallies.resize(quest.objectives.size())
	tallies.fill(0)
	return tallies


# --- Persistence -------------------------------------------------------------


## JSON-friendly: quest id -> {status, progress}.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	var ids: Array = []
	for id: StringName in _entries:
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var entry: Dictionary = _entries[StringName(id)]
		var tallies: Array = []
		for tally: Variant in entry[PROGRESS_KEY]:
			tallies.append(int(tally))
		out[String(id)] = {STATUS_KEY: int(entry[STATUS_KEY]), PROGRESS_KEY: tallies}
	return out


## Replaces the log with [param data] from [method to_dict]. Quests that no
## longer exist are dropped, and progress is resized to the quest's current
## objectives so a content change cannot leave a quest impossible to read.
## A completed quest reads as fully done whatever its saved tallies say.
func from_dict(data: Dictionary) -> void:
	_entries.clear()
	for raw_id: Variant in data:
		var id := StringName(String(raw_id))
		var quest: QuestData = _registry.get_quest(id)
		var entry: Variant = data[raw_id]
		if quest == null or not entry is Dictionary:
			continue
		var raw_status: int = int(entry.get(STATUS_KEY, Status.NEW))
		if raw_status < 0 or raw_status >= Status.size() or raw_status == Status.NEW:
			continue
		var tallies: Array = _fresh_progress(quest)
		var saved: Variant = entry.get(PROGRESS_KEY, [])
		if saved is Array:
			for index: int in mini(tallies.size(), saved.size()):
				tallies[index] = maxi(0, int(saved[index]))
		if raw_status == Status.COMPLETED:
			for index: int in quest.objectives.size():
				var objective: QuestObjective = quest.objectives[index]
				tallies[index] = objective.required() if objective != null else 1
		_entries[id] = {STATUS_KEY: raw_status, PROGRESS_KEY: tallies, QUEST_KEY: quest}
