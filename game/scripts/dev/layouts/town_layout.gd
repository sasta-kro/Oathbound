extends RefCounted
## Layout of the starting town: a walled village packed around a paved
## square, with the north gate opening onto Area One.
##
## Baked by `bake_area.gd` into `res://areas/town.tscn`. Cells are map
## cells, x to the right and y down, (0, 0) top-left.
##
## ```text
##  rows 0-3   forest outside the wall, the exit under the gate arch
##  row 4      town wall, gate in the middle (columns 17-19)
##  rows 6-9   three houses along the road from the gate
##  rows 10-17 the square: paved plaza, well, lamp posts, statue
##  rows 11-16 market on the west side, pond on the east; the inn is the big
##             house north of the pond
##  rows 19-22 three houses and the camp along the south road
##  row 24     town wall
## ```

const SIZE := Vector2i(36, 27)
const SEED: int = 0x70A1

const AREA_ONE_SCENE := "res://areas/area_one.tscn"
const KNIGHT_SPRITE_FRAMES := "res://content/sprites/npc_knight.tres"
const ELDER_SPRITE_FRAMES := "res://content/sprites/npc_elder.tres"
const MERCHANT_SPRITE_FRAMES := "res://content/sprites/npc_merchant.tres"
const CHILD_SPRITE_FRAMES := "res://content/sprites/npc_child.tres"
const NPC_SPRITES_DIR := "res://content/sprites/npc_%s.tres"

const WALL_TOP_ROW: int = 4
const WALL_BOTTOM_ROW: int = 24
const WALL_LEFT_COLUMN: int = 2
const WALL_RIGHT_COLUMN: int = 33
## The arch stands on the wall line: its top a row above it, its pillars on
## the wall row and the one below.
const GATE_CELL := Vector2i(17, 3)
const GATE_WIDTH: int = 3
const ROAD_WIDTH: int = 3
const ROAD_COLUMN: int = 18

const PLAZA_CENTER := Vector2(18.5, 14.5)
const PLAZA_RADII := Vector2(5.5, 3.5)
const POND_CENTER := Vector2(30.5, 11.5)
const POND_RADII := Vector2(2.5, 1.5)
const MARKET_CENTER := Vector2(8.0, 13.5)
const MARKET_RADII := Vector2(4.0, 2.5)
const CAMP_CENTER := Vector2(12.5, 21.5)
const CAMP_RADII := Vector2(3.0, 1.5)

const FOREST_TREES: Array = ["tree_3", "tree_4", "tree_2"]
const FOREST_STEP := Vector2i(2, 2)
const BUSHES: Array = ["bush_1", "bush_3", "bush_4", "bush_5", "bush_6", "bush_7"]
const FLOWERS: Array = ["flowers_red_1", "flowers_red_2", "flowers_white_1", "flowers_white_2"]
const PEBBLES: Array = ["rock_6", "rock_9"]
const POTS: Array = ["prop_25", "prop_27", "prop_30"]


func build() -> AreaPainter:
	var p := AreaPainter.new("Town", SIZE, SEED, true)

	# Ground: meadow grass, trodden to dirt at the market, the camp and in a
	# ring around the square so the paving has an apron.
	var dirt: Dictionary = p.union(
		p.fine_ellipse(MARKET_CENTER, MARKET_RADII.x, MARKET_RADII.y),
		p.fine_ellipse(CAMP_CENTER, CAMP_RADII.x, CAMP_RADII.y)
	)
	dirt = p.union(dirt, p.fine_ellipse(PLAZA_CENTER, PLAZA_RADII.x + 1.0, PLAZA_RADII.y + 1.0))
	p.fill_meadow(dirt)

	var roads: Dictionary = p.path([Vector2i(ROAD_COLUMN, 3), Vector2i(ROAD_COLUMN, 11)], ROAD_WIDTH)
	roads = p.union(roads, p.path([Vector2i(24, 14), Vector2i(32, 14)], ROAD_WIDTH))
	roads = p.union(roads, p.path([Vector2i(13, 14), Vector2i(3, 14)], ROAD_WIDTH))
	roads = p.union(roads, p.path([Vector2i(ROAD_COLUMN, 18), Vector2i(ROAD_COLUMN, 23)], ROAD_WIDTH))
	p.paint_road(roads)
	p.paint_stone(p.ellipse(PLAZA_CENTER, PLAZA_RADII.x, PLAZA_RADII.y), false)
	p.paint_water(p.fine_ellipse(POND_CENTER, POND_RADII.x, POND_RADII.y))

	_town_wall(p)
	p.place_split("gate", GATE_CELL)

	# Buildings: three along the north road, three along the south.
	p.place_split("house_hay_3", Vector2i(4, 6))
	p.place_split("house_hay_1", Vector2i(11, 6))
	p.place_split("house_hay_2", Vector2i(25, 6))
	p.place_split("house_hay_4", Vector2i(5, 19))
	p.place_split("house_hay_4", Vector2i(22, 19))
	p.place_split("house_hay_1", Vector2i(27, 19))
	p.place_split("well", Vector2i(18, 12))

	# The square.
	for cell: Vector2i in [Vector2i(12, 10), Vector2i(23, 10), Vector2i(12, 17), Vector2i(23, 17)]:
		p.place("lamp_post", cell)
	p.place("prop_06", Vector2i(14, 11))
	p.place("bench_long", Vector2i(21, 12))
	p.place("bench_long", Vector2i(16, 16))
	p.place("bench_short", Vector2i(15, 15))
	p.place("banner", Vector2i(15, 5))
	p.place("banner", Vector2i(21, 5))
	p.place("sign_1", Vector2i(15, 8))
	p.place("bulletin_board", Vector2i(21, 8))
	p.place("potted_plant", Vector2i(24, 9))
	p.place("water_trough", Vector2i(14, 9))
	p.place("prop_14", Vector2i(24, 7))
	p.place("prop_30", Vector2i(10, 9))

	# Market stalls.
	p.place("table", Vector2i(5, 11))
	p.place("table", Vector2i(9, 11))
	p.place("crate_large", Vector2i(4, 16))
	p.place("crate_medium", Vector2i(5, 16))
	p.place("barrel", Vector2i(6, 16))
	p.place("sack", Vector2i(7, 16))
	p.place("basket", Vector2i(8, 16))
	p.place("haystack", Vector2i(10, 16))
	p.place("haystack", Vector2i(11, 16))
	p.place("prop_02", Vector2i(3, 10))

	# Camp by the south road.
	p.place("campfire", Vector2i(12, 21))
	p.place("stump", Vector2i(10, 20))
	p.place("stump", Vector2i(14, 22))
	p.place("bench_long", Vector2i(14, 20))
	p.place("bench_short", Vector2i(10, 22))

	# Yard behind the south-east houses.
	p.place("prop_02", Vector2i(30, 20))
	p.place("prop_07", Vector2i(30, 22))
	p.place("crate_medium", Vector2i(20, 22))
	p.place("barrel", Vector2i(21, 22))
	p.place("prop_16", Vector2i(26, 17))
	p.place("fireplace", Vector2i(3, 18))

	# Trees inside the wall.
	p.place_split("tree_1", Vector2i(3, 16))
	p.place_split("tree_2", Vector2i(30, 16))
	p.place_split("tree_4", Vector2i(31, 19))
	p.place_split("tree_1", Vector2i(3, 22))
	p.place_split("tree_2", Vector2i(9, 17))

	_people(p)
	_services(p)
	_townsfolk(p)
	_dressing(p)
	_forest_outside(p)

	p.set_player_start(Vector2i(18, 16))
	p.add_entrance("FromAreaOne", Vector2i(18, 7))
	# Where a new journey starts, facing the Elder by the well (Opening).
	p.add_entrance("OpeningSpot", Vector2i(18, 15))
	p.add_exit("ToAreaOne", Rect2i(17, 0, 3, 3), AREA_ONE_SCENE, "FromTown")
	p.add_bounds()
	return p


## Brick wall around the town with a gap for the gate; its pillars stand in
## the gap and carry the wall's collision across it.
func _town_wall(p: AreaPainter) -> void:
	var gate_end: int = GATE_CELL.x + GATE_WIDTH
	var walls: Dictionary = p.rect(Rect2i(WALL_LEFT_COLUMN, WALL_TOP_ROW, GATE_CELL.x - WALL_LEFT_COLUMN, 1))
	walls = p.union(walls, p.rect(Rect2i(gate_end, WALL_TOP_ROW, WALL_RIGHT_COLUMN + 1 - gate_end, 1)))
	walls = p.union(walls, p.rect(Rect2i(WALL_LEFT_COLUMN, WALL_BOTTOM_ROW, WALL_RIGHT_COLUMN + 1 - WALL_LEFT_COLUMN, 1)))
	walls = p.union(walls, p.rect(Rect2i(WALL_LEFT_COLUMN, WALL_TOP_ROW, 1, WALL_BOTTOM_ROW + 1 - WALL_TOP_ROW)))
	walls = p.union(walls, p.rect(Rect2i(WALL_RIGHT_COLUMN, WALL_TOP_ROW, 1, WALL_BOTTOM_ROW + 1 - WALL_TOP_ROW)))
	p.paint_walls(walls)


func _people(p: AreaPainter) -> void:
	p.add_actor(
		"Knight",
		Vector2i(21, 15),
		{
			"display_name": "KNIGHT",
			"body_color": Color(0.247059, 0.72549, 0.34902, 1),
			"sprite_frames": load(KNIGHT_SPRITE_FRAMES),
			"dialogue_line": "Knight: Rest by the well, you look worn. The road through the north gate leads past the old ruins to the altar. Keep to it, and mind your manners when you reach the knight at the end of it.",
			"heals_party": true,
		}
	)
	p.add_actor(
		"Elder",
		Vector2i(17, 15),
		{
			"display_name": "ELDER",
			"body_color": Color(0.75, 0.62, 0.86, 1),
			"sprite_frames": load(ELDER_SPRITE_FRAMES),
			"facing": &"right",
			"dialogue_line": "Elder: The board has work for anyone willing to leave the walls. Wild Oathbound roam the meadow, and the seal is thinning again up by the ruins.",
			"quest_ids": _ids([&"quest_main_01_beyond_the_walls"]),
		}
	)
	p.add_actor(
		"Merchant",
		Vector2i(7, 12),
		{
			"display_name": "MERCHANT",
			"body_color": Color(0.9, 0.6, 0.3, 1),
			"sprite_frames": load(MERCHANT_SPRITE_FRAMES),
			"dialogue_line": "Merchant: Fresh bread, dried fish, and a crate I still have not opened. The caravans come slower every year the bells start up.",
			"quest_ids": _ids([&"quest_side_the_crossing"]),
		}
	)
	p.add_actor(
		"Child",
		Vector2i(13, 22),
		{
			"display_name": "CHILD",
			"body_color": Color(0.95, 0.85, 0.4, 1),
			"sprite_frames": load(CHILD_SPRITE_FRAMES),
			"facing": &"up",
			"dialogue_line": "Child: I saw a Loambuck from the wall! It had leaves on its back. Can I come with you? No? Fine.",
			"quest_ids": _ids([&"quest_side_leaf_hat"]),
		}
	)


## The inn and the two market vendors (Specification 16.5). Service NPCs
## stand still; the vendors flank the Merchant's stall on the market road.
func _services(p: AreaPainter) -> void:
	p.add_actor(
		"Innkeeper",
		Vector2i(27, 10),
		{
			"display_name": "INNKEEPER",
			"sprite_frames": load(NPC_SPRITES_DIR % "innkeeper"),
			"dialogue_line": "Innkeeper: Welcome to the Hearthside. Beds are warm and the stew is hot. Stay the night? Oathkeepers sleep free. The Order has always paid for its own.",
			"chatter": PackedStringArray([
				"Innkeeper: Back again? Your Oathbound look like they could use a proper bed.",
				"Innkeeper: The Fisher swears he caught tonight's stew. He didn't. Rest a while?",
			]),
			"barks": PackedStringArray(["Stew's on!", "Rooms free tonight!", "Wipe your boots, please."]),
			"runs_inn": true,
			"quest_ids": _ids([&"quest_main_01g_a_stocked_satchel"]),
		}
	)
	p.add_actor(
		"Scribe",
		Vector2i(4, 12),
		{
			"display_name": "SCRIBE",
			"sprite_frames": load(NPC_SPRITES_DIR % "scribe"),
			"dialogue_line": "Scribe: Binding Scrolls, inked by my own hand. Oath-script holds better than any rope. It is the same hand that copies out the rite, for whatever that is worth to you.",
			"chatter": PackedStringArray([
				"Scribe: A worn-down creature listens closer. Weaken it before you offer the scroll.",
				"Scribe: Failed binding? The scroll crumbles, but the lesson stays. Buy another.",
			]),
			"barks": PackedStringArray(["Scrolls! Fresh-inked scrolls!", "Bind your next friend!"]),
			"shop_title": "Scribe's Stall",
			"quest_ids": _ids([&"quest_side_ink_and_oath"]),
			"shop_stock": _ids([&"item_binding_scroll"]),
		}
	)
	p.add_actor(
		"Apothecary",
		Vector2i(11, 12),
		{
			"display_name": "APOTHECARY",
			"sprite_frames": load(NPC_SPRITES_DIR % "apothecary"),
			"dialogue_line": "Apothecary: Salves for scrapes, tonics for worse, and a draught for when the worst has already happened. I have stocked every champion since I was young. Most of them came back.",
			"chatter": PackedStringArray([
				"Apothecary: Clearwater from the well, blessed twice. Burns and poisons don't stand a chance.",
				"Apothecary: Keep a salve in your satchel. The meadow bites harder than it looks.",
			]),
			"barks": PackedStringArray(["Salves and tonics!", "Mind your wounds, traveller."]),
			"shop_title": "Apothecary",
			"quest_ids": _ids([&"quest_main_01h_the_road_is_waiting"]),
			"shop_stock": _ids([&"item_herb_salve", &"item_hearty_tonic", &"item_ember_draught", &"item_clearwater_vial"]),
		}
	)


## People who make the town feel lived in: a guard at the gate, a fisher at
## the pond, a bard by the fire, and a few who stroll about.
func _townsfolk(p: AreaPainter) -> void:
	p.add_actor(
		"Guard",
		Vector2i(16, 5),
		{
			"display_name": "GUARD",
			"sprite_frames": load(NPC_SPRITES_DIR % "guard"),
			"dialogue_line": "Guard: The gate stays open while the sun is up. After dark, knock twice and say your oath. We have kept that rule since before the altar was raised.",
			"chatter": PackedStringArray(["Guard: Wild ones don't come past the wall. Mostly. Nothing has ever come past the altar."]),
			"barks": PackedStringArray(["Quiet day.", "Mind the ruins out there."]),
		}
	)
	p.add_actor(
		"OldMan",
		Vector2i(22, 12),
		{
			"display_name": "OLD MAN",
			"sprite_frames": load(NPC_SPRITES_DIR % "old_man"),
			"facing": &"left",
			"dialogue_line": "Old Man: The dead king has been put back under nine times since this town started keeping count, and the count was already old when we started it.",
			"chatter": PackedStringArray(["Old Man: Sit a while. Well water tastes better when you're not rushing, and that altar has waited longer than you have."]),
			"barks": PackedStringArray(["Hmph. Pigeons.", "Back in my day..."]),
		}
	)
	p.add_actor(
		"Fisher",
		Vector2i(30, 13),
		{
			"display_name": "FISHER",
			"sprite_frames": load(NPC_SPRITES_DIR % "fisher"),
			"facing": &"up",
			"dialogue_line": "Fisher: Nothing biting but leeches. Don't tell the Innkeeper, she thinks I catch the stew.",
			"barks": PackedStringArray(["Come on, bite...", "Was that a ripple?"]),
		}
	)
	p.add_actor(
		"Bard",
		Vector2i(11, 21),
		{
			"display_name": "BARD",
			"sprite_frames": load(NPC_SPRITES_DIR % "bard"),
			"facing": &"right",
			"dialogue_line": "Bard: I'm writing a ballad about the Oathbreaker. Hardest song in the Reach. Nobody can agree on whether it is meant to end sad.",
			"chatter": PackedStringArray(["Bard: Every oath has a verse. Yours hasn't been written yet, and his has been sung wrong for a hundred years."]),
			"barks": PackedStringArray(["♪ Oh, the meadow grass was green... ♪", "♪ ...and the scroll held true ♪"]),
		}
	)
	p.add_actor(
		"Kid",
		Vector2i(15, 21),
		{
			"display_name": "KID",
			"sprite_frames": load(NPC_SPRITES_DIR % "kid"),
			"dialogue_line": "Kid: I'm faster than an Emberling! Watch! ...Okay, not yet. Soon.",
			"barks": PackedStringArray(["Can't catch me!", "Race you to the well!"]),
			"wander_radius_cells": 2.0,
		}
	)
	p.add_actor(
		"Villager",
		Vector2i(20, 17),
		{
			"display_name": "VILLAGER",
			"sprite_frames": load(NPC_SPRITES_DIR % "villager"),
			"dialogue_line": "Villager: The market's busier since the caravan came. Even the Scribe is selling scrolls again.",
			"chatter": PackedStringArray(["Villager: If you're heading out, the Apothecary's salves are worth every coin."]),
			"barks": PackedStringArray(["Fresh bread smells lovely today.", "Has anyone seen my cat?"]),
			"wander_radius_cells": 3.0,
		}
	)
	p.add_actor(
		"Farmer",
		Vector2i(8, 18),
		{
			"display_name": "FARMER",
			"sprite_frames": load(NPC_SPRITES_DIR % "farmer"),
			"dialogue_line": "Farmer: Loambucks keep nibbling the hay. Can't blame them, it's good hay.",
			"barks": PackedStringArray(["Hay won't stack itself.", "Rain's coming, I can feel it."]),
			"quest_ids": _ids([&"quest_side_field_medicine"]),
			"wander_radius_cells": 2.0,
		}
	)


func _dressing(p: AreaPainter) -> void:
	var inside: Dictionary = p.rect(
		Rect2i(
			WALL_LEFT_COLUMN + 1,
			WALL_TOP_ROW + 1,
			WALL_RIGHT_COLUMN - WALL_LEFT_COLUMN - 1,
			WALL_BOTTOM_ROW - WALL_TOP_ROW - 1
		)
	)
	p.scatter(BUSHES, 18, AreaPainter.FOLIAGE_LAYER, 0, 2, inside)
	p.scatter(FLOWERS, 14, AreaPainter.FOLIAGE_LAYER, 0, 2, inside)
	p.scatter(PEBBLES, 8, AreaPainter.DECOR_LAYER, 0, 1, inside)
	p.scatter(POTS, 5, AreaPainter.DECOR_LAYER, 0, 2, inside)


## Trees on every side outside the wall, leaving the way out of the gate
## open. Two staggered rows per side so the canopy closes.
func _forest_outside(p: AreaPainter) -> void:
	var gate_clearance: int = 2
	var left_end: int = GATE_CELL.x - gate_clearance
	var right_start: int = GATE_CELL.x + GATE_WIDTH + gate_clearance
	for row: int in [2, 3]:
		p.plant_forest(Rect2i(row % 2, row, left_end - row % 2, 1), FOREST_TREES, FOREST_STEP, 0)
		p.plant_forest(Rect2i(right_start + row % 2, row, SIZE.x - right_start, 1), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(0, SIZE.y - 2, SIZE.x, 1), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(1, SIZE.y - 1, SIZE.x, 1), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(-1, 4, 1, SIZE.y - 6), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(0, 5, 1, SIZE.y - 7), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(SIZE.x - 2, 4, 1, SIZE.y - 6), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(SIZE.x - 1, 5, 1, SIZE.y - 7), FOREST_TREES, FOREST_STEP, 0)


## A typed id list for an actor's exported [code]Array[StringName][/code].
static func _ids(ids: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: Variant in ids:
		out.append(StringName(id))
	return out
