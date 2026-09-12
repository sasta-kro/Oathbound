class_name QuestData
extends Resource
## A quest as content (Specification 17): who gives it, what it asks, what
## it pays, and the lines its giver says at every step.
##
## Quests live as [code].tres[/code] files under [code]res://content/quests[/code]
## and are indexed by [ContentRegistry] on their [member id]. The main story
## is a chain of MAIN quests linked by [member requires]; SIDE quests are
## optional and can be refused, abandoned and picked up again without loss
## (Specification 17.5).
##
## Every line below is the giver's; the player's replies are the two
## options shown with it. Empty lines fall back to sensible defaults so a
## quest only needs an offer to be playable.

enum Kind { MAIN, SIDE }

const DEFAULT_ACCEPT_OPTION := "I'll do it."
const DEFAULT_REFUSE_OPTION := "Not right now."
const DEFAULT_CONTINUE_OPTION := "I'm still working on it."
const DEFAULT_ABANDON_OPTION := "I don't think I can help anymore."
const DEFAULT_REOFFER_LINE := "Have you changed your mind?"
const DEFAULT_PROGRESS_LINE := "How is it going?"
const DEFAULT_ABANDONED_LINE := "I see. Come back if you change your mind."
const DEFAULT_DONE_LINE := "Thank you again for your help."

@export var id: StringName = &""
@export var title: String = ""
@export var kind: Kind = Kind.SIDE
## One or two sentences for the log.
@export_multiline var summary: String = ""
## Actor id of the NPC who offers the quest and takes it back in.
@export var giver: StringName = &""
## Quest that must be completed before this one is offered. Empty for none.
@export var requires: StringName = &""
@export var objectives: Array[QuestObjective] = []

@export_group("Rewards")
@export var reward_currency: int = 0
@export var reward_binding_scrolls: int = 0
## XP given to every conscious party member on completion.
@export var reward_xp: int = 0

@export_group("Dialogue")
## The ask. Shown with the accept and refuse options.
@export_multiline var offer_line: String = ""
@export var accept_option: String = DEFAULT_ACCEPT_OPTION
@export var refuse_option: String = DEFAULT_REFUSE_OPTION
@export_multiline var accepted_line: String = ""
@export_multiline var refused_line: String = ""
## The ask again, after a refusal or abandonment.
@export_multiline var reoffer_line: String = ""
## While the quest is active and not yet done. Shown with the continue and
## abandon options.
@export_multiline var progress_line: String = ""
@export var continue_option: String = DEFAULT_CONTINUE_OPTION
@export var abandon_option: String = DEFAULT_ABANDON_OPTION
@export_multiline var abandoned_line: String = ""
## Turning it in.
@export_multiline var complete_line: String = ""
## Every talk after completion.
@export_multiline var done_line: String = ""


func is_main() -> bool:
	return kind == Kind.MAIN


func kind_display_name() -> String:
	return "Main quest" if is_main() else "Side quest"


func has_reward() -> bool:
	return reward_currency > 0 or reward_binding_scrolls > 0 or reward_xp > 0


func reoffer_text() -> String:
	return reoffer_line if not reoffer_line.is_empty() else DEFAULT_REOFFER_LINE


func progress_text() -> String:
	return progress_line if not progress_line.is_empty() else DEFAULT_PROGRESS_LINE


func abandoned_text() -> String:
	return abandoned_line if not abandoned_line.is_empty() else DEFAULT_ABANDONED_LINE


func done_text() -> String:
	return done_line if not done_line.is_empty() else DEFAULT_DONE_LINE


## Falls back to the offer so a quest with only that line still reads.
func accepted_text() -> String:
	return accepted_line if not accepted_line.is_empty() else offer_line


func refused_text() -> String:
	return refused_line if not refused_line.is_empty() else abandoned_text()


func complete_text() -> String:
	return complete_line if not complete_line.is_empty() else done_text()


func validate(registry: Node = null) -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("A quest has no id.")
		return problems
	if title.is_empty():
		problems.append("Quest '%s' has no title." % id)
	if giver == &"":
		problems.append("Quest '%s' has no giver." % id)
	if offer_line.is_empty():
		problems.append("Quest '%s' has no offer line." % id)
	if objectives.is_empty():
		problems.append("Quest '%s' has no objectives." % id)
	for objective: QuestObjective in objectives:
		if objective == null:
			problems.append("Quest '%s' has an empty objective slot." % id)
			continue
		problems.append_array(objective.validate(id, registry))
	if requires == id:
		problems.append("Quest '%s' requires itself." % id)
	elif requires != &"" and registry != null and not registry.has_quest(requires):
		problems.append("Quest '%s' requires '%s' which is not in the quest registry." % [id, requires])
	return problems
