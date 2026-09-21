class_name GameOpening
extends RefCounted
## The words of the game's opening (Specification 4.5), kept apart from the
## code that stages them.
##
## The opening has two halves. [constant PROLOGUE] is the Elder speaking over
## a dark screen before the world is shown, in the prologue scene the title
## screen opens for a new journey. The rest is the first scene in the field:
## the player standing with the Elder by the well in the town square, where
## the starter is handed over and the first main quest given. The overworld
## plays that half; see [code]main.gd[/code].
##
## Both halves tell the same story the rest of the main chain assumes: the
## town is what is left of the Guardian Order, a dead king and his kingdom
## are sealed inside the altar at the end of the ruined road, the seal thins,
## and the town sends one of its own up to make it hold again. It has been
## done many times and will be done many more.

## The prologue, one entry per beat. A blank line inside an entry starts a new
## box, as in field dialogue. [constant PROLOGUE_CREATURE_PAGE] is the entry
## the starter's art first appears on.
const PROLOGUE: PackedStringArray = [
	"Ah, there you are. Sit a moment, and let an old man tell it the way it was told to him. Every child of this town hears it once. You are hearing it the day it becomes yours.",
	"This is the Verdant Reach. Green hills, old roads, and more wild creatures than there are stars over the lake.",
	"Some of those creatures choose to walk beside a person. The two swear an oath to one another, and from that day the creature is Oathbound, and the one who walks with it an Oathkeeper.",
	"Most oaths are quiet ones. Farmers plough with their Oathbound, healers mend with them, children grow up beside them. Ours has never been quiet.",
	"We are not the village we look like. We are what is left of the Guardian Order, and we have kept one watch and no other since before the road had a name.",
	"North of the gate, at the end of that road, there is an altar. A whole kingdom is sealed inside it. Its king, its knights, its walls, folded down into stone.",
	"That king had a son, and the son died, and the king would not have it.\n\nHe reached for a magic no crown was ever meant to touch. It brought the boy back wrong, and it took the kingdom with him, and every knight who had sworn to him besides.",
	"Our Order sealed all of it away rather than let it walk.\n\nWe have kept that seal ever since. It thins. It always thins, and the dead king stirs under it, and the town sends one of its own up the road to put him back down.\n\nIt has been done more times than we have names for. It will be done again after you.",
	"The bells beneath the altar rang last night. Come. I will be waiting for you by the well in the square.",
]
const PROLOGUE_CREATURE_PAGE: int = 2
const PROLOGUE_SPEAKER := "THE ELDER"

## Actor id of the Elder in the town, whom the field scene is played with.
const ELDER_ID: StringName = &"elder"
## Marker under the town's `Entrances` the player stands on for the scene.
const PLAYER_SPOT: StringName = &"OpeningSpot"
## The main quest the Elder sends the player out on.
const FIRST_QUEST_ID: StringName = &"quest_main_01_beyond_the_walls"

## Before the starter is handed over.
const WELCOME: PackedStringArray = [
	"Elder: There you are. Look at you, standing by the old well. I remember when you could barely see over its rim.",
	"Elder: You have come of age, and of everything you could have been, you chose the watch your parents kept, and theirs before them. The Order has a new Oathkeeper today.",
	"Elder: But an Oathkeeper needs a partner. This one hatched in my hearth three winters ago, and it has been waiting for someone worth following.",
]
## Shown as a notice when the starter joins, with its name.
const STARTER_JOINED_TEXT := "%s joined you!"
## After the starter is handed over: what it is and how it fights.
const STARTER_EXPLAINED: PackedStringArray = [
	"Elder: An Emberling. There is a coal in its belly that never goes out. Fire bites hard against green growing things and against rot, but earth and water will smother it, so choose your fights.",
	"Elder: Out past the walls it walks beside you and fights for you. Press F and it strikes whatever stands in front of you. Catch a wild creature off guard and you may win before it can fight back.",
	"Elder: And take these five Binding Scrolls. Weaken a wild creature in battle, then offer it a scroll. If it accepts, it swears to you as your Emberling has.",
]
## The threat, and the ask.
const THREAT: PackedStringArray = [
	"Elder: Now the part you have known since you were small. The bells beneath the altar rang on their own last night. The seal is thinning, and the dead king is turning over in it.",
	"Elder: So we do what this town has always done. The rite is gathered, the road is cleared, and one of ours walks up to the altar and puts him back to sleep. This turn it falls to you.",
	"Elder: You will not go straight up, mind. Nobody does. Our scout keeps the camp past the north gate, and he keeps the rite with it. Everything the altar needs, he will start you on.",
]
const ASK := "Elder: Find him, hear what he has seen, and do as he tells you, in the order he tells you. The altar will still be there at the end of it. Will you go?"
const REPLIES: PackedStringArray = ["I'll find him.", "Do I have a choice?"]
## The Elder's answer to each of [constant REPLIES], by index.
const SEND_OFF: PackedStringArray = [
	"Elder: Good. Follow the road north through the gate, and come back to tell me what he says.",
	"Elder: Ha! You always have a choice. You simply never pick the other one. North through the gate, then, and come back to tell me what he says.",
]


## The way to face from [param from] to look at [param to], on the four
## directions the player's sprite has.
static func facing_toward(from: Vector2, to: Vector2) -> Vector2i:
	var offset: Vector2 = to - from
	if absf(offset.x) >= absf(offset.y):
		return Vector2i.RIGHT if offset.x >= 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if offset.y >= 0.0 else Vector2i.UP
