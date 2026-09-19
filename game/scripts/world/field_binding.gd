class_name FieldBinding
extends RefCounted
## The words and numbers of the binding lesson (the "A Second Oath" main
## quest), kept apart from the overworld code that stages it, the way
## [FieldMending] is.
##
## Accepting the quest at the Scout's camp brings a wild Loambuck wandering
## up to the fire. The battle is guided by a [BindTutorialGuide]: the player
## wears it down with an attack, then offers it a Binding Scroll. Binding it
## reports the BIND event the quest's objective already waits for, so no
## story event is needed.

const QUEST_ID: StringName = &"quest_main_01a_a_second_oath"
const SPECIES_ID: StringName = &"creature_earth_01"
## A young Loambuck, like the ones in the meadow. Earth shrugs off fire, so
## even a well-trained Emberling needs a few blows to wear it down and cannot
## knock it out in one.
const LEVEL := 3
## It is curious rather than angry: its blows only sting, since Stone Toss at
## full strength would flatten the Emberling it is meant to teach.
const ATTACK_PERCENT := -40
## How far from the player the Loambuck appears, in cells, on the side away
## from the Scout.
const APPROACH_DISTANCE_CELLS := 1.5

## Spoken after the quest is accepted, before the Loambuck appears.
const APPROACH: PackedStringArray = [
	"Scout: Actually, you're in luck. Hold still. Smell of the fire draws them in...",
	"Scout: There. A Loambuck, come to see what's cooking. Go on, I'll talk you through it.",
]
const OPENING_TEXT := "The Loambuck lowers its head at %s."
## After it is bound.
const WON_LINE := "Scout: Ha! Knew you had it in you. Bring the pair of them over here."
## After the battle ends any other way. The quest stays active, and talking
## to the Scout again brings another Loambuck.
const LOST_LINE := "Scout: That one got away from you. No matter, they come back to the fire. Talk to me when you want another try."
## When the party has no room for it.
const PARTY_FULL_LINE := "Scout: Your party's full; there's nowhere for a new Oathbound to go. Bind one when you've room, or bring one you already have."


## Everything [code]main.gd[/code] needs to run the lesson battle: the guide,
## how it is won, and what the Scout says after.
static func stage() -> Dictionary:
	return {
		"guide": BindTutorialGuide.new(),
		"success": BattleEngine.Outcome.BOUND,
		"event": &"",
		"won_line": WON_LINE,
		"lost_line": LOST_LINE,
		"prepare": func(config: BattleConfig, enemy: CreatureInstance, party: Array[CreatureInstance]) -> void:
			prepare(config, enemy, party[0].display_name()),
	}


## Readies [param config] for the lesson: no running, its blows softened, it
## only attacks (it never mends itself back out of reach of the scroll), and
## the scroll always takes. Its moves are left alone: once bound it is the
## player's healer, and the next lesson needs its Mend.
static func prepare(config: BattleConfig, _enemy: CreatureInstance, lead_name: String) -> void:
	config.can_run = false
	config.enemy_attacks_only = true
	config.guaranteed_bind = true
	config.opening_text = OPENING_TEXT % lead_name
	var curious := StatModifier.new()
	curious.stat = Stats.Stat.ATTACK
	curious.percent = ATTACK_PERCENT
	config.enemy_modifiers = [curious]
