class_name FieldAmbush
extends RefCounted
## The words and numbers of the ambush lesson (the "Caught in the Open" main
## quest), kept apart from the overworld code that stages it, the way
## [FieldStrike] is.
##
## It is [FieldStrike] turned around. Accepting the quest at the Scout's camp
## sends a hostile Emberling at the player, and the lesson asks them to stand
## still and let it arrive: it winds up, lands a blow that is already on the
## party's lead when the screen opens, and takes the first turn. The blow
## reports [constant EVENT_ID], which is the quest's only objective.

const QUEST_ID: StringName = &"quest_main_01f_caught_in_the_open"
## The story event the quest's objective waits for: a hostile creature's
## overworld strike landing on the player.
const EVENT_ID: StringName = &"ambush_taken"

const SPECIES_ID: StringName = &"creature_fire_01"
const LEVEL := 3
## Its blow stings rather than bites, in the overworld and in the fight after
## it. The player is being asked to stand still for this one, so it must not
## be the thing that ends their journey.
const ATTACK_PERCENT := -35
## How far off it starts, in cells, on the side away from the Scout: far
## enough to be seen coming, close enough that standing still is a choice
## rather than a wait.
const DISTANCE_CELLS := 3.0
## Its home is the spot it starts from, and it gives up a chase that carries
## it past this. Wide enough to cross [constant DISTANCE_CELLS] and still be
## hunting when it arrives.
const LEASH_RADIUS := 240.0
## It notices the player from anywhere in the camp, so the charge starts the
## moment the Scout stops talking.
const DETECTION_RADIUS := 400.0

## Spoken after the quest is accepted, before it comes out of the grass.
const CHARGE: PackedStringArray = [
	"Scout: Right. Stay exactly where you are, and whatever you feel like doing, don't.",
	"Scout: There it is. Emberling, and it has already seen you. Watch it gather itself before it hits: that pause is your whole warning. This once, wear it.",
]
## Held on screen while it closes. The player could not move or swing now
## even if they wanted to, which is the point: this one is watched, not done.
const PROMPT := "Hold still. Let it reach you and land the first blow."
## Said as the battle opens, after the engine's own account of the blow.
## [code]%s[/code] is the player's lead.
const OPENING_TEXT := "It reached you before the fight began, so it takes this turn and %s answers after it."
## Held over the menus while the opening turn is chosen.
const LESSON_BANNER := "It swung first out in the grass, so the first move here is its own. That is what standing still costs: the same thing your own strike buys."
## After the battle its ambush opened is won.
const WON_LINE := "Scout: And you still took it. Good. Now you know both ends of it: land that blow, or be standing somewhere else when it comes. Back to the fire."
## After it is lost or fled. The quest is already reported by then, since
## taking the blow is what the lesson asked for.
const LOST_LINE := "Scout: Easy. That is what a free blow and the first turn are worth, and now you have felt it from underneath. Come back to the fire."


## Everything [code]main.gd[/code] needs for the battle the ambush opens: no
## guide, the player's own party and satchel, and a foe whose strength is
## spent. The event is reported by the blow itself, so the battle reports
## none of its own.
static func stage() -> Dictionary:
	return {
		"guide": OpeningLessonGuide.new(LESSON_BANNER),
		"success": BattleEngine.Outcome.VICTORY,
		"event": &"",
		"satchel": true,
		"won_line": WON_LINE,
		"lost_line": LOST_LINE,
		"prepare": func(config: BattleConfig, _enemy: CreatureInstance, party: Array[CreatureInstance]) -> void:
			prepare(config, party[0].display_name()),
	}


## Readies [param config] for the lesson: the ambusher's strength spent for
## the whole fight, so the free blow and the first turn are the lesson rather
## than the end of the journey.
static func prepare(config: BattleConfig, lead_name: String) -> void:
	config.opening_text = OPENING_TEXT % lead_name
	var spent := StatModifier.new()
	spent.stat = Stats.Stat.ATTACK
	spent.percent = ATTACK_PERCENT
	spent.duration_turns = 0
	config.enemy_modifiers = [spent]
