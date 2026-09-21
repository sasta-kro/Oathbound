class_name PartyLesson
extends RefCounted
## The words and steps of the two party-page lessons the Scout gives ("Room
## for More" and "Who Walks in Front"), kept apart from the overworld and the
## page that stage them, the way [FieldStrike] is.
##
## Accepting either quest holds the player in place with the party key as
## the only one that answers, and a standing instruction says to press it.
## On the page, a banner names the one button to press next, that button
## pulses, and every other action on the page is shut until the lesson is
## done. Which step is up is read off the quest and the party as they stand,
## so a lesson picked up again after a reload starts wherever the player
## left off.

enum Step { NONE, OPEN_PAGE, SEND_TO_KEEPING, CALL_OUT, TAKE_LEAD, DONE }

const KEEPING_QUEST_ID: StringName = &"quest_main_01b_room_for_more"
const LEAD_QUEST_ID: StringName = &"quest_main_01d_who_walks_in_front"
const QUEST_IDS: Array[StringName] = [KEEPING_QUEST_ID, LEAD_QUEST_ID]
## The keeping quest's objectives, in the order the lesson walks them.
const KEPT_OBJECTIVE := 0
const CALLED_BACK_OBJECTIVE := 1

## Held on the field while the page is shut.
const OPEN_PROMPT := "Press Tab to open your party page."
## The banner over the page, one per step.
const INSTRUCTIONS: Dictionary = {
	Step.SEND_TO_KEEPING: "Press \"Send to keeping\" under any companion. It walks down to the Hearthside paddock.",
	Step.CALL_OUT: "Now press \"Call out\" on it, down in the paddock row, to bring it straight back.",
	Step.TAKE_LEAD: "Press \"Walk in front\" under a companion who is not leading. It will follow at your shoulder.",
	Step.DONE: "That's the lesson. Press Q to go back to the field, then talk to the Scout.",
}
## What a button the lesson is not pointing at says when hovered.
const NOT_YET_TOOLTIP := "The Scout is showing you something else first."


static func is_lesson(quest_id: StringName) -> bool:
	return quest_id in QUEST_IDS


## The step of [param quest_id]'s lesson that is up, with the party page open
## or shut ([param page_open]). [constant Step.NONE] for any other quest.
static func step(quest_id: StringName, page_open: bool) -> Step:
	if not is_lesson(quest_id):
		return Step.NONE
	var quest: QuestData = Content.get_quest(quest_id)
	if quest == null or not GameState.quests.is_active(quest_id) or GameState.quests.is_ready(quest):
		return Step.DONE
	if not page_open:
		return Step.OPEN_PAGE
	var can_call_out: bool = not GameState.kept.is_empty() and not GameState.party_is_full()
	if quest_id == LEAD_QUEST_ID:
		# With nobody else walking there is nobody to put in front, so one is
		# called out of the paddock first.
		return Step.CALL_OUT if GameState.party.size() <= 1 and can_call_out else Step.TAKE_LEAD
	var can_send: bool = GameState.party.size() > 1 and GameState.has_keeping_room()
	var wants_send: bool = not GameState.quests.is_objective_done(quest, KEPT_OBJECTIVE)
	var wants_call: bool = not GameState.quests.is_objective_done(quest, CALLED_BACK_OBJECTIVE)
	if wants_send and can_send:
		return Step.SEND_TO_KEEPING
	if wants_call and can_call_out:
		return Step.CALL_OUT
	# Whichever half is left cannot be done as the party stands (a full party
	# with somebody kept, say), so the other half makes room for it.
	return Step.SEND_TO_KEEPING if can_send else Step.CALL_OUT


static func instruction(at: Step) -> String:
	return INSTRUCTIONS.get(at, "")
