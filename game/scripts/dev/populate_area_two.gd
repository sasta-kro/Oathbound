## Fills `areas/area_two.tscn` with its cast, its wild creatures, its boss,
## the supply camp before the stair down, the chests, and the walls that hold
## the whole map in.
##
## Area Two is the folded kingdom under the altar: the people sealed in with
## it are still alive down here, and the champions the Order has sent for
## centuries are mostly not. The five NPC markers the plan bake laid down
## become the cast, the Boss marker becomes the Kingsworn, and the spawn
## anchors below become the wild creatures of the deep.
##
## It also finishes the map the plan bake left half-done: every floor cell on
## the edge of the painted rooms gets the wall tile that faces it, the pits
## the plan drew inside the great hall are filled in as masonry, and the halls
## are dressed with tombs, urns and torchlight. All of that is written from
## the Ground layer, so it can be run again after the plan changes.
##
## This is a separate pass rather than part of `build_area_two_map.gd`,
## because that script still expects the Area One layer names and cannot run
## against this scene. It reads the markers the bake left, so re-running it is
## safe: the Actors and SpawnZones nodes are rebuilt from scratch each time.
##
## It runs as a scene rather than through `-s`, because `world_actor.gd` and
## `wild_creature.gd` read autoloads, and autoloads are only registered for a
## real main loop. Under `-s` those scripts fail to compile and every property
## set on their nodes is silently dropped.
##
##     Godot --headless --path game res://scenes/dev_tool.tscn
extends Node

const AREA_PATH := "res://areas/area_two.tscn"
const ACTOR_SCENE := preload("res://scenes/world_actor.tscn")
const CREATURE_SCENE := preload("res://scenes/wild_creature.tscn")
const SPAWN_SCENE := preload("res://scenes/spawn_zone.tscn")
const CHEST_SCENE := preload("res://scenes/treasure_chest.tscn")
const EXIT_SCENE := preload("res://scenes/area_exit.tscn")
const BEACON_SCENE := preload("res://scenes/altar_beacon.tscn")
const SPRITES := "res://content/sprites/npc_%s.tres"
const SPECIES := "res://content/creatures/creature_%s.tres"
const AREA_ONE_SCENE := "res://areas/area_one.tscn"
const AREA_THREE_SCENE := "res://areas/area_three.tscn"
## Everything on the map is laid out in these cells: x to the right, y down,
## one cell 24 world px, as `build_area_two_map.gd` drew the plan.
const DRESSING_SEED: int = 0x0A7B2

# --- The map itself ----------------------------------------------------------

## Catacombs floor, the same eight tiles the plan bake laid down.
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(46, 13), Vector2i(47, 13), Vector2i(49, 13), Vector2i(50, 13),
	Vector2i(46, 14), Vector2i(47, 14), Vector2i(49, 14), Vector2i(50, 14),
]
## The dark fill behind the rooms.
const BACKGROUND_TILE := Vector2i(10, 6)
## Wall tiles by which sides of the wall cell have floor against them: N is
## floor above the wall, S floor below it. Read off the map the bake left, so
## the sealed edges match the ones already painted by hand.
const WALL_TILES: Dictionary = {
	"N": [Vector2i(5, 3), Vector2i(11, 3), Vector2i(12, 3)],
	"S": [Vector2i(5, 11), Vector2i(11, 11), Vector2i(12, 11)],
	"W": [Vector2i(4, 5), Vector2i(4, 4)],
	"E": [Vector2i(15, 5), Vector2i(15, 4)],
	"NW": [Vector2i(3, 6)],
	"NE": [Vector2i(16, 6)],
	"SW": [Vector2i(3, 4)],
	"SE": [Vector2i(16, 4)],
	"NS": [Vector2i(9, 7)],
	"WE": [Vector2i(9, 7)],
	"NSW": [Vector2i(3, 6)],
	"NSE": [Vector2i(16, 6)],
	"NWE": [Vector2i(9, 2)],
	"SWE": [Vector2i(5, 11), Vector2i(11, 11)],
	"NSWE": [Vector2i(9, 7)],
}
## Solid rock, for the inside of a block of masonry no floor touches.
const ROCK_TILES: Array[Vector2i] = [
	Vector2i(9, 7), Vector2i(5, 7), Vector2i(11, 7), Vector2i(9, 12)
]
const DECORATIVE_SOURCE: int = 1
const ANIMATED_SOURCE: int = 2
const TORCH_TILE := Vector2i(0, 3)
const CANDLE_TILE := Vector2i(0, 0)

## Dressing for the halls, as the atlas cell of the sprite's top-left corner
## and its size in cells. The tombs and standing stones carry their own
## collision on that first cell, so painting the block is enough to make them
## solid; the urns and candles are small enough to walk around.
const TOMBS: Array = [
	[Vector2i(0, 4), Vector2i(3, 2)],
	[Vector2i(0, 6), Vector2i(3, 2)],
	[Vector2i(0, 8), Vector2i(3, 2)],
	[Vector2i(0, 10), Vector2i(3, 2)],
	[Vector2i(0, 12), Vector2i(3, 2)],
	[Vector2i(0, 14), Vector2i(3, 2)],
]
const STONES: Array = [
	[Vector2i(3, 4), Vector2i(2, 3)],
	[Vector2i(5, 4), Vector2i(2, 3)],
	[Vector2i(5, 7), Vector2i(2, 3)],
]
const URNS: Array = [
	[Vector2i(9, 8), Vector2i(1, 2)],
	[Vector2i(10, 8), Vector2i(1, 2)],
	[Vector2i(12, 8), Vector2i(1, 2)],
	[Vector2i(9, 11), Vector2i(1, 2)],
	[Vector2i(10, 11), Vector2i(1, 2)],
]
const CANDLES: Array = [
	[Vector2i(10, 1), Vector2i(1, 1)],
	[Vector2i(11, 1), Vector2i(1, 1)],
	[Vector2i(12, 1), Vector2i(1, 1)],
	[Vector2i(13, 1), Vector2i(1, 1)],
]
## How many of each go into the open halls.
const TOMB_COUNT: int = 70
const STONE_COUNT: int = 40
const URN_COUNT: int = 90
const CANDLE_COUNT: int = 80
## A torch on the wall every so many cells of wall the player can stand under.
const TORCH_SPACING: int = 8
## How far a marker may be walked to find floor to stand on.
const SETTLE_RADIUS: int = 14

# --- The supply camp and the stair down ---------------------------------------

## The expedition camp in the great hall, the one room down here big enough
## to pitch in. Whoever is still alive in the catacombs trades out of it and
## the Lamplighter keeps a bed by the fire, so a party routed below wakes
## here instead of back in the town (Specification 20.1).
##
## The furniture comes from the Fan-tasy prop sheet rather than the catacombs
## one, which has crypts and braziers but nothing anybody ever camped with.
## It is painted on its own layer at the overworld scale, two map cells to a
## prop cell, so a crate down here is the size of a crate upstairs.
const CAMP_RECT := Rect2i(108, 92, 22, 16)
const CAMP_LAYER := "CampProps"
## The camp, as (sprite name, cell on the camp layer). Cells are half the map
## cell, so (59, 49) here is map cell (118, 98).
const CAMP_PROPS: Array = [
	["campfire", Vector2i(59, 49)],
	["bench_short", Vector2i(58, 50)],
	["bench_short", Vector2i(60, 50)],
	["bench_long", Vector2i(59, 51)],
	["crate_large", Vector2i(56, 47)],
	["crate_medium", Vector2i(57, 47)],
	["barrel", Vector2i(56, 48)],
	["sack", Vector2i(57, 48)],
	["basket", Vector2i(57, 50)],
	["haystack", Vector2i(56, 51)],
	["water_trough", Vector2i(61, 50)],
	["table", Vector2i(61, 47)],
	["bulletin_board", Vector2i(55, 45)],
	["banner", Vector2i(58, 45)],
	["banner", Vector2i(62, 45)],
	["lamp_post", Vector2i(55, 52)],
	["lamp_post", Vector2i(62, 52)],
	["sign_1", Vector2i(59, 53)],
	["stump", Vector2i(62, 48)],
	["crate_medium", Vector2i(62, 49)],
	["sack", Vector2i(61, 51)],
]
## Catacombs light around the camp, on the map's own cells.
const CAMP_TORCH_CELLS: Array[Vector2i] = [
	Vector2i(110, 93), Vector2i(118, 93), Vector2i(128, 93),
	Vector2i(110, 106), Vector2i(128, 106),
]
const CAMP_CANDLE_CELLS: Array[Vector2i] = [
	Vector2i(114, 100), Vector2i(122, 100), Vector2i(118, 94),
]

const CAMP := [
	{
		"name": "Quartermaster",
		"display": "THE QUARTERMASTER",
		"sprite": "merchant",
		"cell": Vector2i(112, 96),
		"facing": &"down",
		"line": "The Quartermaster: Coin is coin, even down here. I buy off the ones who come back and sell to the ones going on, and I have stopped asking which of you is which. Take the salve. Take two.",
		"stock": [&"item_herb_salve", &"item_hearty_tonic", &"item_ember_draught", &"item_clearwater_vial"],
		"shop_title": "Deepmarket Stall",
	},
	{
		"name": "Sealwright",
		"display": "THE SEALWRIGHT",
		"sprite": "scribe",
		"cell": Vector2i(125, 97),
		"facing": &"down",
		"line": "The Sealwright: Scrolls, cut down here, from the seal-iron the Gravewright brings up. They hold as well as anything your Order prints upstairs, and they cost less, because there is nobody left to pay.",
		"stock": [&"item_binding_scroll", &"item_clearwater_vial"],
		"shop_title": "Sealwright's Bench",
	},
	{
		"name": "Lamplighter",
		"display": "THE LAMPLIGHTER",
		"sprite": "apothecary",
		"cell": Vector2i(118, 104),
		"facing": &"up",
		"line": "The Lamplighter: Sit down by the fire. There is a bed behind the crates and it is nobody's tonight. I keep the flames going on this stretch, and I put the champions back together before they go up that hall. Most of them come back down it on a board. You will not, if you sleep first.",
		"heals": true,
		"inn": true,
	},
]

## The stair down to Area Three, in the north wall of the Kingsworn's hall,
## and the cells around it: he stands between the player and it, and a party
## coming back up arrives south of the trigger so it does not fire again.
const AREA_THREE_EXIT_CELL := Vector2i(124, 19)
const AREA_THREE_EXIT_SIZE := Vector2(2, 1)
const FROM_AREA_THREE_CELL := Vector2i(124, 24)
const BOSS_CELL := Vector2i(124, 22)
const STAIR_TORCH_CELLS: Array[Vector2i] = [Vector2i(121, 20), Vector2i(127, 20)]
## Both doorways carry the same light the altar in Area One does, so a way
## through reads as a way through from across the room. The catacombs run on
## a 24 px cell, half the overworld one the beacon measures itself in, so the
## sizes here are half what they would be upstairs.
const PORTAL_SIZE := Vector2(3, 4)
const PORTAL_GROUND_OFFSET: float = 0.5
const AREA_THREE_SIGN := "DOWN TO THE DEAD CITY"
const AREA_ONE_SIGN := "UP TO THE MEADOW"
const AREA_THREE_LOCKED_LINE := "The stair down is a black throat in the wall, and the Kingsworn is standing in it. Not while I hold this door, he says."

## The chests of Area Two, by the cell they stand on. Ids are what the save
## remembers, so they never change once a journey has opened one.
const CHESTS := [
	{
		"name": "ChestNorthwest",
		"id": &"chest_two_northwest",
		"cell": Vector2i(20, 9),
		"items": [&"item_hearty_tonic", &"item_herb_salve"],
		"counts": [2, 2],
		"line": "Somebody\'s kit, packed for a climb back up that never happened.",
	},
	{
		"name": "ChestSouthwest",
		"id": &"chest_two_southwest",
		"cell": Vector2i(7, 113),
		"coins": 120,
		"line": "Coin, in a purse with the Order\'s seal still on the string.",
	},
	{
		"name": "ChestCamp",
		"id": &"chest_two_camp",
		"cell": Vector2i(126, 101),
		"scrolls": 2,
		"line": "The Sealwright waves a hand at the crate by the fire. Take them. You will need them below more than I need the coin.",
	},
	{
		"name": "ChestKingsHall",
		"id": &"chest_two_kings_hall",
		"cell": Vector2i(132, 21),
		"coins": 90,
		"items": [&"item_ember_draught"],
		"counts": [1],
		"line": "A champion\'s pack, set down against the wall of the hall and never picked up again.",
	},
]


## The cast, by the marker each one stands on. Aldric is the through-line, the
## Bellkeeper is the safe point, and the Nurse is deliberately the furthest
## from the stair, because what she knows should be the last thing learned.
const CAST := [
	{
		"marker": "NPC_1",
		"name": "Aldric",
		"display": "ALDRIC",
		"sprite": "old_man",
		"facing": &"down",
		"line": "Aldric: Another one. Put the scroll away, lad, I'm no wild thing. Aldric of the Order, champion of the ninth watch. I came down that same stair thirty years ago and did what you're here to do. The stair shut before I climbed back up. Come on. I'll show you what nobody upstairs can tell you.",
	},
	{
		"marker": "NPC_2",
		"name": "Bellkeeper",
		"display": "THE BELLKEEPER",
		"sprite": "elder",
		"facing": &"right",
		"line": "The Bellkeeper: Rest, and let me see to your Oathbound. You heard the bells, didn't you. Everyone up there thinks the seal rings them. It doesn't. I ring them. I have rung them every time the seal thinned since before your town had a name, because someone has to call you people down.",
		"heals": true,
	},
	{
		"marker": "NPC_3",
		"name": "Archivist",
		"display": "THE ARCHIVIST",
		"sprite": "scribe",
		"facing": &"down",
		"line": "The Archivist: Nine, they tell you. Nine times the dead king has been put back under. I have the ledger here and the ledger says otherwise. It says forty-one. It also says each watch is shorter than the one before it, and that the one before yours was eleven years.",
	},
	{
		"marker": "NPC_4",
		"name": "Gravewright",
		"display": "THE GRAVEWRIGHT",
		"sprite": "merchant",
		"facing": &"down",
		"line": "The Gravewright: Mind where you tread. They are all champions, every one of these. I dig for the ones who make it this far and no further, and I take the seal-iron off them so it can go home even when they can't. Bring me any you find. They should not be left lying in his halls.",
	},
	{
		"marker": "NPC_5",
		"name": "Nurse",
		"display": "THE NURSE",
		"sprite": "innkeeper",
		"facing": &"up",
		"line": "The Nurse: You came a long way to be told this, so I will say it plainly. You cannot end him. Nobody can, while the boy endures. The king bound his own death to his son's un-death, and that is the knot your Order has been tying a bow around for four hundred years. Seal him if you like. Then come back and find me, and we will talk about the boy.",
	},
]

## Wild creatures of the deep, as (species id, anchor cell, radius, max alive,
## level band, hostile, species mixed in). Levels run 16 to 28, so the walk
## from the stair to the Kingsworn carries a party from the Black Knight up to
## him. The shipped scene has since gained hand-placed zones on top of these
## (Quarrybrute, Deepcrag, Grovehulk, Ashhound and the two nested west zones);
## re-running this script drops them.
const SPAWNS := [
	["hollow_squire", Vector2i(34, 44), 3.0, 2, 16, 18, true, ["sentinel_eye"]],
	["mistwisp", Vector2i(30, 70), 3.5, 3, 16, 19, false, ["brinehound"]],
	["gloomgaze", Vector2i(62, 34), 3.0, 2, 18, 21, true, ["galewing"]],
	["mirelash", Vector2i(78, 62), 3.5, 2, 19, 22, false, ["bramblewing"]],
	["bulwark", Vector2i(96, 40), 2.5, 2, 21, 24, true, ["ironhulk"]],
	["cinderhulk", Vector2i(104, 74), 3.0, 2, 22, 25, true, ["hammerhorn"]],
	["dreadmere", Vector2i(118, 84), 3.0, 2, 23, 26, false, ["rotcrawler"]],
	["hexcaller", Vector2i(116, 40), 2.5, 2, 24, 27, true, ["pyrewing", "razorfiend"]],
	["ironhorn", Vector2i(128, 34), 2.5, 1, 25, 28, true, ["gravereaper"]],
]

const BOSS_SPECIES := "kingsworn"
const BOSS_LEVEL := 28
const BOSS_ID: StringName = &"boss_area_02"
## The quest that should gate him once the Area Two chain exists. Left empty
## on the node for now: a required_quest naming a quest the registry does not
## have would seal him for good, and there would be no way to fight him.
const BOSS_QUEST: StringName = &""
const BOSS_CHALLENGE := "The Kingsworn: Far enough. I know what you are; one comes every few winters now, and each of you is younger than the last. My brother keeps the door above. I keep this one. He chose what he keeps. I did not have to choose, because my oath was never broken - it held, through all of it, and it holds now. That is the whole horror of me, and it will not move me aside. Draw."
const BOSS_SEALED := "A knight in gold-white fire stands between you and the stair down, unmoving. He does not draw. Not yet, he says. You have not seen what is below, and I will not spend you for nothing. Go and be told first. Then come back and mean it."
const BOSS_VICTORY := "The Kingsworn: Ah. Held, and still not enough. He lowers his sword and steps off the stair, and the blue fire on him gutters low. Go down, then. He is through there, on the seat, where he has been since the hour he unmade us. Tell him his knight kept faith. He will not care. He never did."


func _ready() -> void:
	var packed := load(AREA_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % AREA_PATH)
		get_tree().quit(1)
		return
	var area := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	var markers := area.get_node_or_null("MapMarkers")
	if markers == null:
		push_error("Area Two has no MapMarkers to build on.")
		get_tree().quit(1)
		return
	var ground := area.get_node("Ground") as TileMapLayer

	var actors := area.get_node("Actors") as Node2D
	var spawns := area.get_node("SpawnZones") as Node2D
	_clear(actors)
	_clear(spawns)
	spawns.visible = true

	# The map first: sealing the rooms decides which cells the dressing, the
	# camp and the chests are allowed to stand on.
	var floors: Dictionary = _floor_cells(ground)
	var sealed_count: int = _seal_walls(area, floors)
	var dressed: int = _dress_halls(area, floors)
	_raise_camp_props(area, ground)
	# Nothing may be left standing in the dark or inside a crypt, so every
	# marker the plan bake laid down is walked onto the nearest free floor.
	var blocked: Dictionary = _blocked_cells(area)

	for entry: Dictionary in CAST:
		var marker := markers.get_node_or_null(String(entry["marker"])) as Marker2D
		if marker == null:
			push_error("No marker %s in Area Two." % entry["marker"])
			continue
		marker.position = _cell_to_world(
			ground, _settled_cell(_cell_of(ground, marker.position), floors, blocked)
		)
		var actor := ACTOR_SCENE.instantiate()
		actor.name = String(entry["name"])
		actor.position = marker.position
		actor.set("display_name", entry["display"])
		actor.set("sprite_frames", load(SPRITES % entry["sprite"]))
		actor.set("facing", entry["facing"])
		actor.set("dialogue_line", entry["line"])
		if entry.get("heals", false):
			actor.set("heals_party", true)
		actors.add_child(actor)
		actor.owner = area

	for row: Array in SPAWNS:
		var zone := SPAWN_SCENE.instantiate()
		zone.name = "Spawn_%s" % row[0]
		zone.position = _cell_to_world(ground, _settled_cell(row[1], floors, blocked))
		zone.set("species", load(SPECIES % row[0]))
		var also_spawns: Array[CreatureSpecies] = []
		for id: String in row[7]:
			also_spawns.append(load(SPECIES % id))
		zone.set("also_spawns", also_spawns)
		zone.set("radius_in_cells", row[2])
		zone.set("max_alive", row[3])
		zone.set("level_min", row[4])
		zone.set("level_max", row[5])
		if row[6]:
			zone.set("disposition", 1)
		spawns.add_child(zone)
		zone.owner = area

	var boss_marker := markers.get_node_or_null("Boss") as Marker2D
	if boss_marker != null:
		# The marker is where the plan put him; he belongs in the mouth of the
		# stair he keeps, so the way down is behind him and nowhere else.
		boss_marker.position = _cell_to_world(ground, _settled_cell(BOSS_CELL, floors, blocked))
		var boss := CREATURE_SCENE.instantiate()
		boss.name = "Kingsworn"
		boss.position = boss_marker.position
		boss.set("species", load(SPECIES % BOSS_SPECIES))
		boss.set("level", BOSS_LEVEL)
		boss.set("ability_index", 0)
		boss.set("boss_id", BOSS_ID)
		boss.set("required_quest", BOSS_QUEST)
		boss.set("challenge_line", BOSS_CHALLENGE)
		boss.set("sealed_line", BOSS_SEALED)
		boss.set("victory_line", BOSS_VICTORY)
		boss.set("leash_radius", 0.0)
		actors.add_child(boss)
		boss.owner = area

	_raise_camp(area, actors, ground, floors, blocked)
	_place_chests(area, ground, floors, blocked)
	_open_the_stair(area, ground)

	var uid: String = _scene_uid()
	var rebuilt := PackedScene.new()
	var error := rebuilt.pack(area)
	if error == OK:
		error = ResourceSaver.save(rebuilt, AREA_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [AREA_PATH, error])
		get_tree().quit(1)
		return
	_restore_uid(uid)
	print(
		"Area Two populated: %d NPCs, %d at the camp, %d chests, %d spawn zones, boss %s at level %d."
		% [CAST.size(), CAMP.size(), CHESTS.size(), SPAWNS.size(), BOSS_SPECIES, BOSS_LEVEL]
	)
	print("  map: %d wall cells sealed, %d pieces of dressing." % [sealed_count, dressed])
	get_tree().quit(0)


## Cells nothing should be standing on: the walls that hold the rooms in and
## the dressing that blocks. Read after the map is sealed and dressed, so a
## marker the plan bake left in the dark can be walked back onto the floor.
func _blocked_cells(area: Node2D) -> Dictionary:
	var blocked: Dictionary = {}
	for layer_name: String in ["Walls", "Decor", "Floor Decor"]:
		var layer := area.get_node_or_null(NodePath(layer_name)) as TileMapLayer
		if layer == null:
			continue
		for cell: Vector2i in layer.get_used_cells():
			blocked[cell] = true
	var camp := area.get_node_or_null(NodePath(CAMP_LAYER)) as TileMapLayer
	if camp != null:
		# The camp layer draws at twice the map's cell, so each of its cells
		# covers a 2x2 block of them.
		for cell: Vector2i in camp.get_used_cells():
			for offset_y: int in 2:
				for offset_x: int in 2:
					blocked[cell * 2 + Vector2i(offset_x, offset_y)] = true
	return blocked


## The nearest cell to [param cell] that is painted floor and has nothing
## standing on it. The plan bake dropped its markers on cells it had not
## drawn, which is how an NPC ends up in the dark outside a room.
func _settled_cell(cell: Vector2i, floors: Dictionary, blocked: Dictionary) -> Vector2i:
	# Room to stand in first: a spot with free floor all around it reads as
	# somebody standing in a room rather than pressed against its wall. Any
	# free floor will do if the room is too tight for that.
	for clearance: int in [1, 0]:
		if _stands_clear(cell, floors, blocked, clearance):
			return cell
		for radius: int in range(1, SETTLE_RADIUS):
			var best: Vector2i = cell
			var best_distance: float = INF
			for offset_y: int in range(-radius, radius + 1):
				for offset_x: int in range(-radius, radius + 1):
					var candidate: Vector2i = cell + Vector2i(offset_x, offset_y)
					if not _stands_clear(candidate, floors, blocked, clearance):
						continue
					var distance: float = Vector2(candidate - cell).length()
					if distance < best_distance:
						best = candidate
						best_distance = distance
			if best_distance < INF:
				return best
	push_warning("No free floor within %d cells of %s." % [SETTLE_RADIUS, cell])
	return cell


## Whether [param cell] is free floor with [param clearance] cells of free
## floor around it.
func _stands_clear(
	cell: Vector2i, floors: Dictionary, blocked: Dictionary, clearance: int
) -> bool:
	for offset_y: int in range(-clearance, clearance + 1):
		for offset_x: int in range(-clearance, clearance + 1):
			var at: Vector2i = cell + Vector2i(offset_x, offset_y)
			if not floors.has(at) or blocked.has(at):
				return false
	return true


func _cell_of(ground: TileMapLayer, position: Vector2) -> Vector2i:
	return Vector2i(((position - ground.position) / ground.scale / Vector2(ground.tile_set.tile_size)).floor())


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _cell_to_world(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	return ground.position + (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(ground.tile_set.tile_size) * ground.scale


## Saving a repacked scene drops the uid, and anything referring to the area
## by uid:// then resolves to whichever scene the cache saw last.
func _scene_uid() -> String:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return ""
	var header: String = file.get_line()
	file.close()
	if not (' uid="' in header):
		return ""
	return header.split(' uid="')[1].split('"')[0]


func _restore_uid(uid: String) -> void:
	if uid.is_empty():
		return
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if ' uid="' in text.split("\n")[0]:
		return
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="%s"]' % uid)
	file = FileAccess.open(AREA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


# --- The map ------------------------------------------------------------------


func _floor_cells(ground: TileMapLayer) -> Dictionary:
	var floors := {}
	for cell: Vector2i in ground.get_used_cells():
		floors[cell] = true
	return floors


## Puts a wall on every cell that touches the painted floor and has nothing on
## it, and fills the blocks of masonry the plan left hollow. Without this a
## player can walk off the edge of a room into the dark, which is what the
## plan bake left behind everywhere its rooms were not drawn back to back.
## Returns how many cells were painted.
func _seal_walls(area: Node2D, floors: Dictionary) -> int:
	var walls := area.get_node("Walls") as TileMapLayer
	var background := area.get_node("Background") as TileMapLayer
	var painted: int = 0
	var edges := {}
	for cell: Vector2i in floors:
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var side: Vector2i = cell + direction
			if not floors.has(side):
				edges[side] = true
	for cell: Vector2i in edges:
		if walls.get_cell_source_id(cell) != -1:
			continue
		var key: String = _wall_key(cell, floors)
		var choices: Array = WALL_TILES.get(key, ROCK_TILES)
		walls.set_cell(cell, 0, choices[posmod(cell.x * 7 + cell.y * 13, choices.size())])
		painted += 1
	# Everything the rooms do not cover is the dark behind them, the pits the
	# plan drew inside the great hall included: with the walls now facing the
	# floor on every side, the dark reads as the inside of a block of masonry
	# rather than as a hole in the map.
	var bounds: Rect2i = _floor_bounds(floors)
	for cell_y: int in range(bounds.position.y, bounds.end.y):
		for cell_x: int in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(cell_x, cell_y)
			if floors.has(cell) or background.get_cell_source_id(cell) != -1:
				continue
			background.set_cell(cell, 0, BACKGROUND_TILE)
			painted += 1
	return painted


## Which sides of a wall cell have floor against them, as the key
## [constant WALL_TILES] is written in.
func _wall_key(cell: Vector2i, floors: Dictionary) -> String:
	var key: String = ""
	if floors.has(cell + Vector2i.UP):
		key += "N"
	if floors.has(cell + Vector2i.DOWN):
		key += "S"
	if floors.has(cell + Vector2i.LEFT):
		key += "W"
	if floors.has(cell + Vector2i.RIGHT):
		key += "E"
	return key


func _floor_bounds(floors: Dictionary) -> Rect2i:
	var bounds := Rect2i()
	var first: bool = true
	for cell: Vector2i in floors:
		if first:
			bounds = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
	return bounds


## Tombs, standing stones, urns, candles and wall torches over the open floor.
## Everything is placed on cells with floor all around them, so nothing can
## close a doorway, and the same seed gives the same halls every run.
func _dress_halls(area: Node2D, floors: Dictionary) -> int:
	var decor := area.get_node("Decor") as TileMapLayer
	decor.clear()
	var taken := {}
	for cell: Vector2i in _reserved_cells():
		taken[cell] = true
	var random := RandomNumberGenerator.new()
	random.seed = DRESSING_SEED
	var open: Array[Vector2i] = []
	for cell: Vector2i in floors:
		open.append(cell)
	open.sort()
	var placed: int = 0
	placed += _scatter(decor, TOMBS, TOMB_COUNT, open, floors, taken, random, 1)
	placed += _scatter(decor, STONES, STONE_COUNT, open, floors, taken, random, 1)
	placed += _scatter(decor, URNS, URN_COUNT, open, floors, taken, random, 0)
	placed += _scatter(decor, CANDLES, CANDLE_COUNT, open, floors, taken, random, 0)
	placed += _light_the_walls(decor, floors, taken)
	return placed


## Cells the dressing must keep off: the cast, the camp, the chests, the way
## in and out, and the spawn anchors, each with room to stand.
func _reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var anchors: Array[Vector2i] = [
		AREA_THREE_EXIT_CELL, FROM_AREA_THREE_CELL, BOSS_CELL, Vector2i(24, 51), Vector2i(21, 51)
	]
	for entry: Dictionary in CAMP:
		anchors.append(entry["cell"])
	for entry: Dictionary in CHESTS:
		anchors.append(entry["cell"])
	for row: Array in SPAWNS:
		anchors.append(row[1])
	for cell: Vector2i in CAMP_TORCH_CELLS + CAMP_CANDLE_CELLS + STAIR_TORCH_CELLS:
		anchors.append(cell)
	for cell_y: int in range(CAMP_RECT.position.y, CAMP_RECT.end.y):
		for cell_x: int in range(CAMP_RECT.position.x, CAMP_RECT.end.x):
			cells.append(Vector2i(cell_x, cell_y))
	for anchor: Vector2i in anchors:
		for offset_y: int in range(-4, 5):
			for offset_x: int in range(-4, 5):
				cells.append(anchor + Vector2i(offset_x, offset_y))
	return cells


func _scatter(
	decor: TileMapLayer,
	kinds: Array,
	count: int,
	open: Array[Vector2i],
	floors: Dictionary,
	taken: Dictionary,
	random: RandomNumberGenerator,
	clearance: int
) -> int:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 400:
		attempts += 1
		var kind: Array = kinds[random.randi() % kinds.size()]
		var cell: Vector2i = open[random.randi() % open.size()]
		if not _fits(cell, kind[1], floors, taken, clearance):
			continue
		for offset_y: int in kind[1].y:
			for offset_x: int in kind[1].x:
				var at: Vector2i = cell + Vector2i(offset_x, offset_y)
				decor.set_cell(at, DECORATIVE_SOURCE, kind[0] + Vector2i(offset_x, offset_y))
				taken[at] = true
		for offset_y: int in range(-clearance - 1, kind[1].y + clearance + 1):
			for offset_x: int in range(-clearance - 1, kind[1].x + clearance + 1):
				taken[cell + Vector2i(offset_x, offset_y)] = true
		placed += 1
	return placed


## Whether a sprite of [param size] standing on [param cell] is on open floor
## with [param clearance] free cells around it.
func _fits(
	cell: Vector2i, size: Vector2i, floors: Dictionary, taken: Dictionary, clearance: int
) -> bool:
	for offset_y: int in range(-clearance - 1, size.y + clearance + 1):
		for offset_x: int in range(-clearance - 1, size.x + clearance + 1):
			var at: Vector2i = cell + Vector2i(offset_x, offset_y)
			if not floors.has(at) or taken.has(at):
				return false
	return true


## A torch on the floor under the north wall of a room, every so often, so a
## long hall is read as a hall rather than as a black corridor.
func _light_the_walls(decor: TileMapLayer, floors: Dictionary, taken: Dictionary) -> int:
	var under_wall: Array[Vector2i] = []
	for cell: Vector2i in floors:
		if not floors.has(cell + Vector2i.UP):
			under_wall.append(cell)
	under_wall.sort()
	var placed: int = 0
	for index: int in under_wall.size():
		if index % TORCH_SPACING != 0:
			continue
		var cell: Vector2i = under_wall[index]
		if taken.has(cell):
			continue
		decor.set_cell(cell, ANIMATED_SOURCE, TORCH_TILE)
		taken[cell] = true
		placed += 1
	return placed


# --- The camp, the chests and the stair ---------------------------------------


## The camp: its furniture on its own layer, its lamps on the map's, and the
## three keepers standing in it.
func _raise_camp(
	area: Node2D, actors: Node2D, ground: TileMapLayer, floors: Dictionary, blocked: Dictionary
) -> void:
	var decor := area.get_node("Decor") as TileMapLayer
	# The dressing pass keeps out of the camp, but a run from before the camp
	# existed may have left a crypt standing in the middle of it.
	for cell_y: int in range(CAMP_RECT.position.y, CAMP_RECT.end.y):
		for cell_x: int in range(CAMP_RECT.position.x, CAMP_RECT.end.x):
			decor.erase_cell(Vector2i(cell_x, cell_y))
	for cell: Vector2i in CAMP_TORCH_CELLS:
		decor.set_cell(cell, ANIMATED_SOURCE, TORCH_TILE)
	for cell: Vector2i in CAMP_CANDLE_CELLS:
		decor.set_cell(cell, ANIMATED_SOURCE, CANDLE_TILE)
	for entry: Dictionary in CAMP:
		var keeper := ACTOR_SCENE.instantiate()
		keeper.name = String(entry["name"])
		keeper.position = _cell_to_world(ground, _settled_cell(entry["cell"], floors, blocked))
		keeper.set("display_name", entry["display"])
		keeper.set("sprite_frames", load(SPRITES % entry["sprite"]))
		keeper.set("facing", entry["facing"])
		keeper.set("dialogue_line", entry["line"])
		if entry.has("stock"):
			var stock: Array[StringName] = []
			for id: StringName in entry["stock"]:
				stock.append(id)
			keeper.set("shop_stock", stock)
			keeper.set("shop_title", entry.get("shop_title", ""))
		if entry.get("heals", false):
			keeper.set("heals_party", true)
		if entry.get("inn", false):
			keeper.set("runs_inn", true)
		actors.add_child(keeper)
		keeper.owner = area


## Paints the camp furniture on its own TileMapLayer, made on the first run
## and cleared on every one after it. Runs before anything is placed, so the
## keepers and the chest know to stand clear of it. The layer carries the overworld tileset
## at 1.5x, the scale the rest of the game draws that art at, which is two
## map cells to a prop cell down here.
func _raise_camp_props(area: Node2D, ground: TileMapLayer) -> void:
	var layer := area.get_node_or_null(NodePath(CAMP_LAYER)) as TileMapLayer
	if layer == null:
		layer = TileMapLayer.new()
		layer.name = CAMP_LAYER
		area.add_child(layer)
		layer.owner = area
		# Above the floor and the crypts, below the Overhead layer.
		area.move_child(layer, (area.get_node("Decor") as Node).get_index() + 1)
	layer.tile_set = load(OverworldTiles.TILESET_PATH)
	layer.position = ground.position
	layer.scale = Vector2(1.5, 1.5)
	layer.clear()
	var sprites: Dictionary = _prop_sprites()
	for entry: Array in CAMP_PROPS:
		var sprite: Dictionary = sprites.get(entry[0], {})
		if sprite.is_empty():
			push_error("No camp prop called %s in the prop manifests." % entry[0])
			continue
		var size: Vector2i = sprite["size"]
		for offset_y: int in size.y:
			for offset_x: int in size.x:
				var offset := Vector2i(offset_x, offset_y)
				layer.set_cell(entry[1] + offset, sprite["source"], sprite["cell"] + offset)


## Name -> source, atlas cell and size, read from the manifests the overworld
## tileset is built from.
func _prop_sprites() -> Dictionary:
	var sprites: Dictionary = {}
	for source: int in OverworldTiles.OBJECT_MANIFESTS:
		var entries: Variant = OverworldTiles.load_json(OverworldTiles.OBJECT_MANIFESTS[source])
		if not entries is Array:
			continue
		for entry: Dictionary in entries:
			sprites[String(entry["name"])] = {
				"source": source,
				"cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])),
				"size": Vector2i(int(entry["size"][0]), int(entry["size"][1])),
			}
	return sprites


## The chests, rebuilt from scratch so re-running cannot leave two on a cell.
func _place_chests(
	area: Node2D, ground: TileMapLayer, floors: Dictionary, blocked: Dictionary
) -> void:
	var chests := area.get_node_or_null("Chests") as Node2D
	if chests == null:
		chests = Node2D.new()
		chests.name = "Chests"
		area.add_child(chests)
		chests.owner = area
	_clear(chests)
	for entry: Dictionary in CHESTS:
		var chest := CHEST_SCENE.instantiate()
		chest.name = String(entry["name"])
		chest.position = _cell_to_world(ground, _settled_cell(entry["cell"], floors, blocked))
		chest.set("chest_id", entry["id"])
		chest.set("coins", int(entry.get("coins", 0)))
		chest.set("binding_scrolls", int(entry.get("scrolls", 0)))
		var ids: Array[StringName] = []
		for id: StringName in entry.get("items", []):
			ids.append(id)
		var counts: Array[int] = []
		for count: int in entry.get("counts", []):
			counts.append(count)
		chest.set("item_ids", ids)
		chest.set("item_counts", counts)
		chest.set("opened_line", entry.get("line", ""))
		chests.add_child(chest)
		chest.owner = area


## The way down to Area Three, sealed behind the Kingsworn, and the way back
## up to Area One signed so it can be found again.
func _open_the_stair(area: Node2D, ground: TileMapLayer) -> void:
	var exits := area.get_node("Exits") as Node2D
	var decor := area.get_node("Decor") as TileMapLayer
	for cell: Vector2i in STAIR_TORCH_CELLS:
		decor.set_cell(cell, ANIMATED_SOURCE, TORCH_TILE)

	var back := exits.get_node_or_null("ToAreaOne") as Node2D
	if back != null:
		back.set("signpost_text", AREA_ONE_SIGN)

	var down := exits.get_node_or_null("ToAreaThree") as Node2D
	if down == null:
		down = EXIT_SCENE.instantiate()
		down.name = "ToAreaThree"
		exits.add_child(down)
		down.owner = area
	down.position = _cell_to_world(ground, AREA_THREE_EXIT_CELL)
	down.set("target_area_path", AREA_THREE_SCENE)
	down.set("target_entrance", &"FromAreaTwo")
	down.set("required_boss", BOSS_ID)
	down.set("locked_line", AREA_THREE_LOCKED_LINE)
	down.set("signpost_text", AREA_THREE_SIGN)
	down.set("size_in_cells", AREA_THREE_EXIT_SIZE)

	var arrival := area.get_node_or_null("Entrances/FromAreaThree") as Marker2D
	if arrival != null:
		arrival.position = _cell_to_world(ground, FROM_AREA_THREE_CELL)

	if back != null:
		_raise_portal(area, "PortalToAreaOne", back.position, &"")
	_raise_portal(area, "PortalToAreaThree", down.position, BOSS_ID)


## The light standing in a doorway. Naming [param required_boss] keeps it dark
## until that boss falls, which is how the stair down stays a wall until the
## Kingsworn steps off it.
func _raise_portal(area: Node2D, name: String, at: Vector2, required_boss: StringName) -> void:
	var beacon := area.get_node_or_null(NodePath(name)) as Node2D
	if beacon == null:
		beacon = BEACON_SCENE.instantiate()
		beacon.name = name
		area.add_child(beacon)
		beacon.owner = area
	beacon.position = at
	beacon.set("required_boss", required_boss)
	beacon.set("size_in_cells", PORTAL_SIZE)
	beacon.set("ground_offset_in_cells", PORTAL_GROUND_OFFSET)
