extends RefCounted
## Layout of Area Three: the dead wood the swallowed kingdom became, and the
## barrow at the top of it where the Skeleton Lord keeps his seat.
##
## Area Three is the last fight, not a country to wander: it is one walk, from
## the stair up out of the catacombs to the barrow, with the wood closed in on
## both sides of it. Everything on the road — the graves, the household in
## their glades, the wild dead — is there to make the king at the end of it
## feel earned. That is why the map is small and the trees are planted solid
## outside the hollow the road runs through.
##
## Baked by `bake_area.gd` into `res://areas/area_three.tscn`. Cells are map
## cells, x to the right and y down, (0, 0) top-left.
##
## ```text
##  rows 1-10   the barrow: standing stones, the seat, the king
##  rows 11-14  the bone gate, a gap in the pillars the road goes through
##  rows 15-26  the graves, with a glade either side for his household
##  rows 27-35  the last of the wood and the black pool
##  rows 36-43  the arrival clearing and the stair back down to Area Two
## ```
##
## There is no daylight here. The ground is the Undead pack's cracked dead
## earth, the wood standing on it is the same pack's dead trees and graves,
## and the whole map is washed with [constant TINT] so it reads as one cold
## place rather than as a meadow at night.

const SIZE := Vector2i(30, 44)
const SEED: int = 0xDEAD3

const AREA_TWO_SCENE := "res://areas/area_two.tscn"
## A dead, moonless wash: enough blue to kill the warmth in the dirt, dark
## enough that the torch-lit catacombs behind still feel like shelter.
const TINT := Color(0.68, 0.70, 0.78)

# --- The shape of the map ----------------------------------------------------

const BARROW_CENTER := Vector2(15.0, 6.0)
const BARROW_RADII := Vector2(8.5, 4.5)
const BONE_GATE := Rect2i(12, 11, 7, 4)
const WEST_GLADE_CENTER := Vector2(8.0, 22.0)
const EAST_GLADE_CENTER := Vector2(22.0, 26.0)
const GLADE_RADII := Vector2(4.5, 3.5)
const GRAVEFIELD := Rect2i(6, 16, 18, 10)
const POOL_CENTER := Vector2(22.0, 33.0)
const POOL_RADII := Vector2(2.5, 1.5)
const ARRIVAL_CENTER := Vector2(15.0, 38.0)
const ARRIVAL_RADII := Vector2(6.5, 4.0)

## The road is the map: outside it and the clearings it links, the wood is
## planted solid, so there is nowhere to wander off to.
const ROAD_WIDTH: int = 3
const ROAD: Array = [
	Vector2i(15, 41),
	Vector2i(15, 33),
	Vector2i(10, 27),
	Vector2i(15, 21),
	Vector2i(15, 13),
	Vector2i(15, 7),
]
## How far either side of the road and the clearings the player can still
## walk before the trees start.
const HOLLOW_MARGIN: int = 1

const SPAWN_CELL := Vector2i(15, 38)
const EXIT_CELLS := Rect2i(14, 41, 3, 2)
const STAIR_SIGN := "DOWN TO THE CATACOMBS"
const PORTAL_SIZE := Vector2(4, 5)
const PORTAL_GROUND_OFFSET: float = 1.0
const BOSS_CELL := Vector2i(15, 5)
const THRONE_CELL := Vector2i(15, 3)
const GHOST_CELL := Vector2i(11, 37)

# --- What grows and stands here ----------------------------------------------

const TREES: Array = [
	"dead_tree", "gnarled_tree", "dead_tree_thin", "dead_shrub", "bramble_tree"
]
const THIN_TREES: Array = ["dead_tree_thin", "dead_stump"]
const BRUSH: Array = ["dry_bramble", "ghost_grass"]
const BONES: Array = ["bone_long", "skull_small"]
const SKULLS: Array = ["skull_pile", "skull_maw", "ribcage", "corpse_hang"]
## Cracks in the dead earth, walked over rather than around.
const CRACKS: Array = ["ground_crack", "ground_crack_large"]
const LOGS: Array = ["fallen_log"]
## The dead that never went anywhere, standing about in the wood.
const SPIRITS: Array = ["pale_spirit"]
const GRAVES: Array = ["graves_row", "grave_pair", "graves_cluster"]
const STONES: Array = ["tombstone_1", "tombstone_2", "tombstone_3"]
const ROCKS: Array = ["rock_pale", "rocks_pale", "boulder_pale"]
const RUBBLE: Array = ["ruin_rubble", "dark_rubble"]
const CRYSTALS: Array = ["crystal_shard"]

## How much of each goes in. The wood is planted last, so the graves, the
## bones and the ruins get the room they need first and the trees fill in
## whatever is left.
## The wood outside the hollow: one tree per block of this many cells, and
## the stumps and brush that fill in whatever gaps the trees leave.
const THICKET_STEP := Vector2i(2, 2)
const THICKET_STUMPS: int = 90
const THICKET_BRUSH: int = 110
const GRAVE_COUNT: int = 18
const TOMBSTONE_COUNT: int = 22
const BONE_COUNT: int = 26
const SKULL_COUNT: int = 8
const ROCK_COUNT: int = 14
const RUBBLE_COUNT: int = 8
const CRYSTAL_COUNT: int = 6
const CRACK_COUNT: int = 10
const LOG_COUNT: int = 6
const SPIRIT_COUNT: int = 7
## The king's fire, burning along the edge of the wood: it is what the player
## reads as "not that way", and the invisible wall is right behind it.
const BRAZIER_SPACING_CELLS: float = 5.0
## The pocket of open ground kept clear around every spawn anchor.
const SPAWN_CLEARING_RADII := Vector2(4.0, 3.0)

# --- Who is in it ------------------------------------------------------------

const SPECIES := "res://content/creatures/creature_%s.tres"
const KNIGHT_SPRITE_FRAMES := "res://content/sprites/npc_knight.tres"
const NEUTRAL: int = 0
const HOSTILE: int = 1

## The wild dead, as (species id, cell, radius, max alive, level band, species
## mixed in). The band runs 30 to 38, so the walk from the stair to the seat
## carries a party on from the Kingsworn.
const SPAWNS: Array = [
	["barrow_knight", Vector2i(15, 34), 3.0, 2, 30, 32, ["elderbough"]],
	["gloomgaze", Vector2i(12, 28), 3.0, 2, 32, 34, ["stormeye"]],
	["bulwark", Vector2i(15, 20), 3.0, 2, 34, 36, ["bastion"]],
	["cinderhulk", Vector2i(15, 14), 2.5, 2, 36, 38, ["hellmaw", "forgehorn"]],
]

## The two elites of Specification 5.3, each in a glade off the road.
const ELITES: Array = [
	{"name": "HouseholdKnightWest", "cell": Vector2i(8, 22), "species": "kingsworn", "level": 34},
	{"name": "HouseholdKnightEast", "cell": Vector2i(22, 26), "species": "oathbreaker", "level": 34},
]

const BOSS_SPECIES := "skeleton_lord"
const BOSS_LEVEL: int = 38
const BOSS_ID := "boss_area_03"
const BOSS_CHALLENGE := "The Skeleton Lord: Another of the little wardens. Do you know what you are interrupting? I am waiting. I have been waiting on this seat since the hour I reached past the door of the world and took my son back through it. He is still coming. He has been coming for four hundred years. Put your oath down and wait with me, or put it to use. It makes very little difference which."
const BOSS_SEALED := "A crowned thing sits on the barrow at the end of the wood, wrapped in green fire, and does not look up. Whatever is left of the Kingsworn's faith is the only reason it has not already noticed you."
const BOSS_VICTORY := "The Skeleton Lord: Ah. There. The green fire goes out of him one thread at a time, and the crown slides off a skull that is only a skull. Not gone, he says, as the seat empties. Only set down again. Come back in a hundred years and I will still be waiting on him, and so will whoever they send. The bells begin to ring somewhere far above, and for once nobody is pulling the rope."

const GHOST := {
	"name": "LastChampion",
	"display": "A DEAD CHAMPION",
	"line": "A dead champion of the Order sits with her back to a dead tree, seal-iron still on her chest, and does not get up. You made it further than I did, she says, without much interest. He is up the road, past the pillars, on the barrow. Mind the two in the glades; they are his household, and they were knights once, same as us. Go on. I will keep the stair.",
}

## The chests of Area Three, one in each glade and one behind the seat.
const CHESTS: Array = [
	{
		"name": "ChestWestGlade",
		"id": &"chest_three_west_glade",
		"cell": Vector2i(5, 21),
		"items": [&"item_ember_draught"],
		"counts": [1],
		"line": "The household knight was standing over a champion's pack. Whoever carried it got this far and no further.",
	},
	{
		"name": "ChestEastGlade",
		"id": &"chest_three_east_glade",
		"cell": Vector2i(25, 27),
		"scrolls": 3,
		"line": "Scrolls, still dry after all this time, in a case cut from seal-iron.",
	},
	{
		"name": "ChestBarrow",
		"id": &"chest_three_barrow",
		"cell": Vector2i(21, 4),
		"coins": 240,
		"items": [&"item_hearty_tonic"],
		"counts": [2],
		"line": "The king's own, heaped behind the seat and never once spent.",
	},
]


func build() -> AreaPainter:
	var p := AreaPainter.new("AreaThree", SIZE, SEED)
	p.add_tint(TINT)

	# Dead earth everywhere, with the kingdom's old paving still showing
	# through where the barrow and the stair landing were built.
	p.fill_dead_ground()
	p.paint_stone(p.ellipse(BARROW_CENTER, BARROW_RADII.x - 2.0, BARROW_RADII.y - 1.5), false)
	p.paint_stone(p.ellipse(ARRIVAL_CENTER, ARRIVAL_RADII.x - 2.0, ARRIVAL_RADII.y - 1.5), false)

	var road: Dictionary = p.path(ROAD, ROAD_WIDTH)
	p.paint_road(road)
	p.paint_water(p.fine_ellipse(POOL_CENTER, POOL_RADII.x, POOL_RADII.y))

	var hollow: Dictionary = _hollow(p, road)
	_barrow(p)
	_gate(p)
	_graves(p, hollow)
	# The fires go in before the wood, or there is no room left on the edge
	# for them to stand.
	var fires: int = _blue_fires(p, hollow)
	var walled: int = _thicket(p, hollow)
	_dressing(p, hollow)
	_cast(p)
	print(
		"  AreaThree: %d pieces of wood, %d blue fires, %d runs of thicket wall"
		% [walled, fires, _wall_off(p, hollow)]
	)

	p.set_player_start(SPAWN_CELL)
	p.add_entrance("FromAreaTwo", SPAWN_CELL)
	p.add_exit("ToAreaTwo", EXIT_CELLS, AREA_TWO_SCENE, "FromAreaThree")
	(p.area.get_node("Exits/ToAreaTwo") as Node2D).set("signpost_text", STAIR_SIGN)
	# The way back down carries the same light the altar in Area One does, so
	# the stair is a thing you can see rather than a line of text.
	p.add_altar_beacon(
		"PortalToAreaTwo",
		Vector2(EXIT_CELLS.position) + Vector2(EXIT_CELLS.size) / 2.0,
		{"size_in_cells": PORTAL_SIZE, "ground_offset_in_cells": PORTAL_GROUND_OFFSET},
	)
	p.add_marker("Boss", BOSS_CELL)
	p.add_marker("Throne", THRONE_CELL)
	p.add_marker("Elite_West", ELITES[0]["cell"])
	p.add_marker("Elite_East", ELITES[1]["cell"])
	p.add_marker("Chest_West", CHESTS[0]["cell"])
	p.add_marker("Chest_East", CHESTS[1]["cell"])
	p.add_bounds()
	return p


## Everywhere the player is meant to be able to stand: the road, the barrow,
## the gate, the glades and the landing, plus a cell of slack around them.
## The wood is planted on everything else, so this is the map.
func _hollow(p: AreaPainter, road: Dictionary) -> Dictionary:
	var cells: Dictionary = road.duplicate()
	cells = p.union(cells, p.ellipse(BARROW_CENTER, BARROW_RADII.x, BARROW_RADII.y))
	cells = p.union(cells, p.rect(BONE_GATE))
	cells = p.union(cells, p.ellipse(WEST_GLADE_CENTER, GLADE_RADII.x, GLADE_RADII.y))
	cells = p.union(cells, p.ellipse(EAST_GLADE_CENTER, GLADE_RADII.x, GLADE_RADII.y))
	cells = p.union(cells, p.ellipse(ARRIVAL_CENTER, ARRIVAL_RADII.x, ARRIVAL_RADII.y))
	# The pool is water, which blocks on its own, but the bank of it should be
	# walkable or it is a picture of a pool rather than one.
	cells = p.union(cells, p.ellipse(POOL_CENTER, POOL_RADII.x + 2.0, POOL_RADII.y + 2.0))
	for row: Array in SPAWNS:
		cells = p.union(cells, p.ellipse(Vector2(row[1]), SPAWN_CLEARING_RADII.x, SPAWN_CLEARING_RADII.y))
	for entry: Dictionary in CHESTS:
		cells = p.union(cells, p.ellipse(Vector2(entry["cell"]), 2.0, 2.0))
	var grown: Dictionary = {}
	for cell: Vector2i in cells:
		for offset_y: int in range(-HOLLOW_MARGIN, HOLLOW_MARGIN + 1):
			for offset_x: int in range(-HOLLOW_MARGIN, HOLLOW_MARGIN + 1):
				grown[cell + Vector2i(offset_x, offset_y)] = true
	return grown


## The barrow at the top of the road: the kingdom's gate arch, the standing
## stones, and the crowned thing the whole place is built around.
func _barrow(p: AreaPainter) -> void:
	p.place("king_relic", Vector2i(13, 1))
	p.place("ruin_arch", Vector2i(13, 8))
	p.place("ruin_pillars", Vector2i(8, 2))
	p.place("ruin_pillars", Vector2i(20, 2))
	p.place("ribcage", Vector2i(7, 6))
	p.place("ribcage", Vector2i(21, 6))
	for cell: Vector2i in [Vector2i(10, 8), Vector2i(19, 8), Vector2i(11, 3), Vector2i(18, 3)]:
		p.place("tombstone_2", cell)
	p.place("crystal_shard", Vector2i(12, 5))
	p.place("crystal_shard", Vector2i(18, 5))


## The bone gate: the last of the kingdom's wall, with a gap the road goes
## through and nothing else does.
func _gate(p: AreaPainter) -> void:
	p.place("ruin_pillars", Vector2i(9, 11))
	p.place("ruin_pillars", Vector2i(19, 11))
	p.place("ruin_rubble", Vector2i(8, 14))
	p.place("ruin_rubble", Vector2i(21, 13))
	p.place("skull_maw", Vector2i(12, 13))
	p.place("skull_maw", Vector2i(18, 13))


## The wood, planted solid everywhere the player is not meant to go. Trees
## block, so this is what keeps the walk to the barrow a walk rather than a
## country to cross.
func _thicket(p: AreaPainter, hollow: Dictionary) -> int:
	var planted: int = 0
	for row: int in range(0, SIZE.y, THICKET_STEP.y):
		for column: int in range(0, SIZE.x, THICKET_STEP.x):
			var cell := Vector2i(
				column + p.random.randi_range(0, THICKET_STEP.x - 1),
				row + p.random.randi_range(0, THICKET_STEP.y - 1),
			)
			if hollow.has(cell) or not p.is_free(cell):
				continue
			var name: String = TREES[p.random.randi() % TREES.size()]
			var size: Vector2i = p.sprite_size(name)
			if not _room_for(p, cell, size, hollow):
				continue
			p.place(name, cell)
			planted += 1
	# Stumps and dead brush in whatever gaps the trees left, so the wall of
	# wood has a floor rather than ending in mid-air.
	var undergrowth: Dictionary = {}
	for cell_y: int in SIZE.y:
		for cell_x: int in SIZE.x:
			var cell := Vector2i(cell_x, cell_y)
			if not hollow.has(cell) and p.is_free(cell):
				undergrowth[cell] = true
	planted += p.scatter(THIN_TREES, THICKET_STUMPS, "Decor", 0, 1, undergrowth)
	planted += p.scatter(BRUSH, THICKET_BRUSH, "Foliage", 0, 1, undergrowth)
	return planted


## Braziers of the king's blue fire, standing along the inside edge of the
## wood at [constant BRAZIER_SPACING_CELLS] apart. They are the visible half
## of the wall: everywhere the player cannot go is lit like this.
func _blue_fires(p: AreaPainter, hollow: Dictionary) -> int:
	var edge: Array[Vector2i] = []
	for cell: Vector2i in hollow:
		if not p.in_bounds(cell):
			continue
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not hollow.has(cell + direction):
				edge.append(cell)
				break
	edge.sort()
	var size: Vector2i = p.sprite_size("blue_brazier")
	var placed: Array[Vector2i] = []
	var lit: int = 0
	for cell: Vector2i in edge:
		var too_close: bool = false
		for other: Vector2i in placed:
			if Vector2(cell - other).length() < BRAZIER_SPACING_CELLS:
				too_close = true
				break
		if too_close or not _room_for(p, cell, size, {}):
			continue
		p.place("blue_brazier", cell)
		placed.append(cell)
		lit += 1
	return lit


## The wood is scenery; this is what stops the player walking into it. Every
## cell outside the hollow is made solid, so Area Three is the walk to the
## barrow and nothing else (the map is a boss approach, not a country).
func _wall_off(p: AreaPainter, hollow: Dictionary) -> int:
	var blocked: Dictionary = {}
	for cell_y: int in SIZE.y:
		for cell_x: int in SIZE.x:
			var cell := Vector2i(cell_x, cell_y)
			if not hollow.has(cell):
				blocked[cell] = true
	return p.add_solid_cells("Thicket", blocked)


## Whether a sprite of [param size] standing on [param cell] stays out of the
## hollow and on the map.
func _room_for(p: AreaPainter, cell: Vector2i, size: Vector2i, hollow: Dictionary) -> bool:
	for offset_y: int in size.y:
		for offset_x: int in size.x:
			var at: Vector2i = cell + Vector2i(offset_x, offset_y)
			if not p.in_bounds(at) or hollow.has(at) or not p.is_free(at):
				return false
	return true


## What lies about on the road itself: bones, cracked ground, the odd rock,
## and the dead who never went anywhere.
func _dressing(p: AreaPainter, hollow: Dictionary) -> void:
	var open: Dictionary = {}
	for cell: Vector2i in hollow:
		if p.is_free(cell):
			open[cell] = true
	p.scatter(CRACKS, CRACK_COUNT, "Foliage", 0, 3, open)
	p.scatter(SKULLS, SKULL_COUNT, "Decor", 0, 3, open)
	p.scatter(LOGS, LOG_COUNT, "Decor", 0, 3, open)
	p.scatter(ROCKS, ROCK_COUNT, "Decor", 0, 2, open)
	p.scatter(RUBBLE, RUBBLE_COUNT, "Decor", 0, 3, open)
	p.scatter(CRYSTALS, CRYSTAL_COUNT, "Decor", 0, 3, open)
	p.scatter(SPIRITS, SPIRIT_COUNT, "Foliage", 0, 4, open)
	p.scatter(BONES, BONE_COUNT, "Foliage", 0, 1, open)


## The graves the road runs through halfway up: the champions who came
## before, in what is left of the kingdom's own burying ground.
func _graves(p: AreaPainter, hollow: Dictionary) -> void:
	var field: Dictionary = {}
	for cell: Vector2i in p.rect(GRAVEFIELD):
		if hollow.has(cell):
			field[cell] = true
	p.scatter(GRAVES, GRAVE_COUNT, "Decor", 0, 2, field)
	p.scatter(STONES, TOMBSTONE_COUNT, "Decor", 0, 1, field)


## The dead champion at the stair, the household in the glades, and the king
## on the barrow.
func _cast(p: AreaPainter) -> void:
	p.add_actor(
		GHOST["name"],
		GHOST_CELL,
		{
			"display_name": GHOST["display"],
			"sprite_frames": load(KNIGHT_SPRITE_FRAMES),
			"facing": &"right",
			"dialogue_line": GHOST["line"],
			"heals_party": true,
		},
	)
	for entry: Dictionary in CHESTS:
		var properties: Dictionary = {
			"chest_id": entry["id"],
			"coins": int(entry.get("coins", 0)),
			"binding_scrolls": int(entry.get("scrolls", 0)),
			"opened_line": entry.get("line", ""),
		}
		var ids: Array[StringName] = []
		for id: StringName in entry.get("items", []):
			ids.append(id)
		var counts: Array[int] = []
		for count: int in entry.get("counts", []):
			counts.append(count)
		properties["item_ids"] = ids
		properties["item_counts"] = counts
		p.add_chest(entry["name"], entry["cell"], properties)
	# One zone per species; the row's extra ids get their own zones on the
	# same spot, so a quest that counts one species is never starved.
	for row: Array in SPAWNS:
		for id: String in [row[0]] + row[6]:
			p.add_spawn_zone(
				"Spawn_%s" % id,
				row[1],
				{
					"species": load(SPECIES % id),
					"radius_in_cells": row[2],
					"max_alive": row[3],
					"level_min": row[4],
					"level_max": row[5],
					"disposition": HOSTILE,
				},
			)
	for elite: Dictionary in ELITES:
		p.add_creature(
			elite["name"],
			elite["cell"],
			{
				"species": load(SPECIES % elite["species"]),
				"level": elite["level"],
				"disposition": HOSTILE,
				"leash_radius": 240.0,
			},
		)
	p.add_creature(
		"SkeletonLord",
		BOSS_CELL,
		{
			"species": load(SPECIES % BOSS_SPECIES),
			"level": BOSS_LEVEL,
			"ability_index": 0,
			"boss_id": StringName(BOSS_ID),
			"challenge_line": BOSS_CHALLENGE,
			"sealed_line": BOSS_SEALED,
			"victory_line": BOSS_VICTORY,
			"leash_radius": 0.0,
		},
	)
