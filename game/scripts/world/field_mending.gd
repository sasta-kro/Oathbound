class_name FieldMending
extends RefCounted
## The words and numbers of the support-move tutorial (the "Field Mending"
## main quest), kept apart from the overworld code that stages it, the way
## [GameOpening] is.
##
## Accepting the quest at the Scout's camp springs a wild Emberling on the
## player. The battle is guided by a [SupportTutorialGuide]: the player's
## striker opens hurt, and the player switches to their healer, mends the
## striker on the bench, switches back and finishes the fight. Winning reports
## [constant EVENT_ID], which is the quest's only objective.

const QUEST_ID: StringName = &"quest_main_01c_field_mending"
## The story event the quest's objective waits for.
const EVENT_ID: StringName = &"field_mending_won"

const ENEMY_SPECIES_ID: StringName = &"creature_emberling"
const ENEMY_LEVEL := 3
## The ambusher has been scrapping in the grass and opens part-spent, so the
## striker's first blow after the mend can finish it.
const ENEMY_HP_FRACTION := 0.5
## The ambusher is spent from its scrap, so its blows only sting: the lesson
## is about the swap and the mend, not about surviving.
const ENEMY_ATTACK_PERCENT := -35
## How hurt the striker is when the battle opens: the ambush's blow.
const STRIKER_HP_FRACTION := 0.3
## How far from the player the ambusher bursts out, in cells, on the side
## away from the Scout.
const AMBUSH_DISTANCE_CELLS := 1.5
## Actor id of the Scout, who gives the lesson.
const SCOUT_ID: StringName = &"scout"

## Spoken after the quest is accepted, before the Emberling appears.
const AMBUSH: PackedStringArray = [
	"Scout: Right. First thing a mender teaches you is that—",
	"Scout: Down! Emberling, out of the grass!",
]
## Spoken once it has appeared, as the battle opens.
const AMBUSH_HIT_TEXT := "The wild Emberling scorches %s before you can react!"
## After the tutorial battle is won.
const WON_LINE := "Scout: Ha! That's the way of it. Come here and let me look at the pair of you."
## After it is lost. The quest stays active, and talking to the Scout again
## replays it.
const LOST_LINE := "Scout: Easy, easy. I dragged the three of you back to the fire. Talk to me when you're ready to try that again."
## When nobody in the party can heal, the lesson is only told.
const NO_HEALER_LINE := "Scout: Hm. None of yours can mend. Then listen instead: a healer can patch up a partner on the bench, so swap your hurt one out, mend it, and swap it back. Remember that."


## Who plays which part, from [param party]: the healer is the first conscious
## member with a healing support move, the striker the first other conscious
## member with a damaging move. Returns {striker, healer, mend}, or an empty
## dictionary when the party cannot stage the lesson.
static func roles(party: Array[CreatureInstance]) -> Dictionary:
	var healer: CreatureInstance = null
	var mend: MoveData = null
	for creature: CreatureInstance in party:
		if creature == null or creature.is_fainted():
			continue
		for move: MoveData in creature.moves:
			if move != null and move.targets_ally() and move.heals():
				healer = creature
				mend = move
				break
		if healer != null:
			break
	if healer == null:
		return {}
	for creature: CreatureInstance in party:
		if creature == null or creature == healer or creature.is_fainted():
			continue
		for move: MoveData in creature.moves:
			if move != null and move.is_damaging():
				return {"striker": creature, "healer": healer, "mend": mend}
	return {}


## Everything [code]main.gd[/code] needs to run the lesson battle: the battle
## party, striker first so it opens the fight, the guide that walks the player
## through it, how it is won and what the Scout says after. Heals both first,
## then leaves the striker wounded by the ambush.
static func stage(cast: Dictionary) -> Dictionary:
	var striker: CreatureInstance = cast.striker
	var healer: CreatureInstance = cast.healer
	striker.heal_full()
	healer.heal_full()
	striker.set_hp(maxi(1, int(round(float(striker.max_hp()) * STRIKER_HP_FRACTION))))
	var party: Array[CreatureInstance] = [striker, healer]
	return {
		"party": party,
		"guide": SupportTutorialGuide.new(0, 1, cast.mend),
		"success": BattleEngine.Outcome.VICTORY,
		"event": EVENT_ID,
		"won_line": WON_LINE,
		"lost_line": LOST_LINE,
		"prepare": func(config: BattleConfig, _enemy: CreatureInstance, _party: Array[CreatureInstance]) -> void:
			prepare(config, striker.display_name()),
	}


## Leaves [param enemy] part-spent, as it opens the fight.
static func wear_down(enemy: CreatureInstance) -> void:
	enemy.set_hp(maxi(1, int(round(float(enemy.max_hp()) * ENEMY_HP_FRACTION))))


## Readies [param config] for the lesson: no running, the ambush named, and
## the ambusher's strength spent for the whole fight.
static func prepare(config: BattleConfig, striker_name: String) -> void:
	config.can_run = false
	config.opening_text = AMBUSH_HIT_TEXT % striker_name
	var spent := StatModifier.new()
	spent.stat = Stats.Stat.ATTACK
	spent.percent = ENEMY_ATTACK_PERCENT
	spent.duration_turns = 0
	config.enemy_modifiers = [spent]
