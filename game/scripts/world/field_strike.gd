class_name FieldStrike
extends RefCounted
## The words and numbers of the overworld-strike lesson (the "Strike First"
## main quest), kept apart from the overworld code that stages it, the way
## [FieldMending] is.
##
## Accepting the quest at the Scout's camp puts a young Loambuck in the grass
## within arm's reach, turns the player to face it and takes everything but
## the attack key away, so the lesson is one keypress and cannot be walked
## out of. The blow reports [constant EVENT_ID], which is the quest's only
## objective, and the battle it opens is one the player enters with the
## creature already wounded and a turn behind.

const QUEST_ID: StringName = &"quest_main_01e_strike_first"
## The story event the quest's objective waits for: the player's own swing,
## landed in the overworld rather than on the battle screen.
const EVENT_ID: StringName = &"first_strike_landed"

const SPECIES_ID: StringName = &"creature_earth_01"
## Earth shrugs off fire, so an Emberling's swing wounds this one instead of
## routing it where it stands, and the player gets to see the battle open
## with the advantage the blow bought them. Young, because earth answers fire
## hard and this is the player's first swing, not a test.
const LEVEL := 2
## What it has left when it wanders up. A Loambuck at full health takes more
## blows than a lesson is worth, and the point is over once the first one has
## landed.
const HP_FRACTION := 0.5
## Its blows only sting. The lesson is the swing and the head start, not the
## fight that follows, and the fight that follows must not be close.
const ATTACK_PERCENT := -60
## How far off the quarry is put, in cells, on the side away from the Scout.
## Inside the player's strike reach, because they are held in place for this:
## the lesson is the key and what it buys, not the walk up to it.
const DISTANCE_CELLS := 1.5

## Spoken after the quest is accepted, before the quarry is put in the grass.
const SIGHTING: PackedStringArray = [
	"Scout: Hold on. There, down the slope, in the tall grass...",
	"Scout: A Loambuck, head down and chewing, and it has not seen you. Stay exactly where you are and hit it before it does.",
]
## Held on screen until the swing lands. [code]%s[/code] is the quarry's name.
const PROMPT := "Press F to strike the %s before it knows you are there."
## Said as the battle opens, after the engine's own account of the blow.
## [code]%s[/code] is the player's lead.
const OPENING_TEXT := "Your blow landed before the fight began, so %s takes this turn whatever the Loambuck would have done with it."
## Held over the menus while the opening turn is chosen.
const LESSON_BANNER := "You swung first out in the grass, so this turn is yours: a strike buys the first move, not just the damage."
## After the battle the strike opened is won.
const WON_LINE := "Scout: That's the whole trick. You spent nothing and it came into that fight already bleeding. Come back to the fire."
## After it is lost or fled. The quest is already reported by then, since the
## swing is what the lesson asked for.
const LOST_LINE := "Scout: Never mind the rest of it. You landed the blow, and that was the lesson. Come back to the fire."


## Leaves [param creature] part-spent, as it wanders up: what the swing does
## not take off it, the first blow in the battle will.
static func wear_down(creature: CreatureInstance) -> void:
	creature.set_hp(maxi(1, int(round(float(creature.max_hp()) * HP_FRACTION))))


## Everything [code]main.gd[/code] needs for the battle the strike opens: a
## guide that explains the turn the swing bought, the player's own party and
## satchel, and a foe whose strength is spent. The event is reported by the
## swing itself, so the battle reports none of its own.
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


## Readies [param config] for the lesson: the quarry's strength spent for the
## whole fight, and a word on what the swing actually bought. Running is left
## open, because a player who would rather walk away has still learned what
## the lesson was for.
static func prepare(config: BattleConfig, lead_name: String) -> void:
	config.opening_text = OPENING_TEXT % lead_name
	var spent := StatModifier.new()
	spent.stat = Stats.Stat.ATTACK
	spent.percent = ATTACK_PERCENT
	spent.duration_turns = 0
	config.enemy_modifiers = [spent]
