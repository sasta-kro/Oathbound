class_name QuestObjective
extends Resource
## One thing a quest asks for (Specification 17.2): defeat, bind, talk to,
## or reach something, [member count] times.
##
## Objectives are matched against events the overworld reports: a species
## id for DEFEAT and BIND, an actor id for TALK, an area scene path for
## REACH. The [member description] is what the log shows, worded naturally
## rather than as a raw counter ("Drive three Emberlings off the road").

enum Kind { DEFEAT, BIND, TALK, REACH }

@export var kind: Kind = Kind.DEFEAT
## Species id, actor id or area scene path, depending on [member kind].
@export var target: StringName = &""
## How many times the event has to happen. Ignored below 1.
@export_range(1, 99) var count: int = 1
## Player-facing wording. Shown with the tally when [member count] is above one.
@export var description: String = ""


## Whether an event of [param event_kind] about [param event_target] counts
## toward this objective.
func matches(event_kind: Kind, event_target: StringName) -> bool:
	return kind == event_kind and target == event_target


func required() -> int:
	return maxi(1, count)


func kind_name() -> String:
	return Kind.keys()[kind].to_lower()


func validate(quest_id: StringName, registry: Node) -> Array[String]:
	var problems: Array[String] = []
	var prefix := "Quest '%s' objective '%s'" % [quest_id, description]
	if target == &"":
		problems.append("%s has no target." % prefix)
		return problems
	match kind:
		Kind.DEFEAT, Kind.BIND:
			if registry != null and not registry.has_species(target):
				problems.append("%s names species '%s' which is not in the species registry." % [prefix, target])
		Kind.REACH:
			if not ResourceLoader.exists(String(target)):
				problems.append("%s names area '%s' which does not exist." % [prefix, target])
	if description.is_empty():
		problems.append("Quest '%s' has a %s objective with no description." % [quest_id, kind_name()])
	return problems
