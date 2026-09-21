class_name QuestCompass
extends RefCounted
## Which way the player has to walk next, for the arrow on the field HUD.
##
## Two questions, both answered without instancing anything: who is the
## player supposed to reach for the quest they are on, and which way out of
## this area is the way to them. Areas are read straight out of their packed
## scenes ([SceneState]), so an actor two areas away still gets an arrow, and
## the map is walked with nothing loaded but its node table.
##
## Pure lookup: no nodes, no global state. [code]main.gd[/code] turns the
## answer into a position on screen.

## Where the actors of an area live in its scene. [SceneState] spells a node
## path from the scene root, so the parent reads "./Actors".
const ACTORS_PATH := "./Actors/"
## The property that makes a node a doorway out of an area.
const EXIT_PROPERTY := "target_area_path"
## Area scene path -> {"actors": PackedStringArray, "exits": PackedStringArray}.
## Areas never change while the game runs, so each one is read once.
static var _areas: Dictionary = {}


## Where [param log]'s most pressing quest wants the player to walk, as
## {"actor": id} or {"area": scene path}: whoever takes the quest in once it
## is ready, whoever it says to go and talk to, or the area it says to reach.
## An errand handed in to somebody other than its giver (a night's sleep, a
## purchase) happens at that somebody, so it points at them from the start.
## Only the story is pointed at: side errands are the player's to find their
## own way through. Empty when the next step is not a walk at all (a fight).
static func destination(log: QuestLog) -> Dictionary:
	for quest: QuestData in log.active_quests():
		if not quest.is_main():
			continue
		if log.is_ready(quest):
			return {"actor": quest.turn_in_actor()}
		for index: int in quest.objectives.size():
			var objective: QuestObjective = quest.objectives[index]
			if objective == null or log.is_objective_done(quest, index):
				continue
			match objective.kind:
				QuestObjective.Kind.TALK:
					return {"actor": objective.target}
				QuestObjective.Kind.REACH:
					return {"area": String(objective.target)}
				QuestObjective.Kind.EVENT:
					if quest.turn_in != &"":
						return {"actor": quest.turn_in}
			break
	return {}


## Who the player owes a visit, or empty when the next step is not a person.
static func target_actor(log: QuestLog) -> StringName:
	return destination(log).get("actor", &"")


## The area scene [param actor_id] stands in, searching outwards from
## [param from_area] along the doorways. Empty when nothing found.
static func area_of(actor_id: StringName, from_area: String) -> String:
	for path: String in _reachable(from_area):
		if String(actor_id) in area(path)["actors"]:
			return path
	return ""


## The next area to walk into to reach [param actor_id], starting from
## [param from_area]: [param from_area] itself when the actor is already
## here, and empty when there is no way through. The arrow points at the
## doorway that leads there.
static func step_toward(actor_id: StringName, from_area: String) -> String:
	return step_toward_area(area_of(actor_id, from_area), from_area)


## The next area to walk into on the way to [param goal] from
## [param from_area]: [param from_area] itself when that is already the goal,
## and empty when there is no way through.
static func step_toward_area(goal: String, from_area: String) -> String:
	if goal == "" or goal == from_area:
		return goal
	# Breadth first from here, remembering the doorway each route started
	# with, so the answer is the first door rather than the last.
	var seen: Dictionary = {from_area: true}
	var queue: Array = []
	for door: String in area(from_area)["exits"]:
		if seen.has(door):
			continue
		seen[door] = true
		queue.append([door, door])
	while not queue.is_empty():
		var step: Array = queue.pop_front()
		var here: String = step[0]
		if here == goal:
			return step[1]
		for door: String in area(here)["exits"]:
			if seen.has(door):
				continue
			seen[door] = true
			queue.append([door, step[1]])
	return ""


## The actor ids and doorways of the area at [param path], read from its
## packed scene and kept. An unreadable path answers with nothing, so a
## half-built map cannot break the HUD.
static func area(path: String) -> Dictionary:
	if _areas.has(path):
		return _areas[path]
	var empty: Dictionary = {"actors": PackedStringArray(), "exits": PackedStringArray()}
	if path == "" or not ResourceLoader.exists(path):
		return empty
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return empty
	var state: SceneState = packed.get_state()
	var actors := PackedStringArray()
	var exits := PackedStringArray()
	for index: int in state.get_node_count():
		if String(state.get_node_path(index)).begins_with(ACTORS_PATH):
			actors.append(String(state.get_node_name(index)).to_lower())
		for property: int in state.get_node_property_count(index):
			if String(state.get_node_property_name(index, property)) != EXIT_PROPERTY:
				continue
			var target: String = String(state.get_node_property_value(index, property))
			if target != "" and not target in exits:
				exits.append(target)
	_areas[path] = {"actors": actors, "exits": exits}
	return _areas[path]


## Every area reachable from [param from_area], itself first.
static func _reachable(from_area: String) -> PackedStringArray:
	var out := PackedStringArray()
	if from_area == "":
		return out
	out.append(from_area)
	var index: int = 0
	while index < out.size():
		for door: String in area(out[index])["exits"]:
			if not door in out:
				out.append(door)
		index += 1
	return out
