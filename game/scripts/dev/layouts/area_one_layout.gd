extends RefCounted
## Layout of Area One: the meadow north of town, a dirt road winding up to
## the sealed ruins, and the altar on its stone dais at the road's end.
##
## Baked by `bake_area.gd` into `res://areas/area_one.tscn`. Cells are map
## cells, x to the right and y down, (0, 0) top-left. The player arrives at
## the bottom, from the town gate.
##
## ```text
##  rows 0-14   ruins in the north-east, woods in the north-west
##  rows 3-9    the dais and altar (columns 37-45)
##  rows 13-22  open meadow with the road bending through it
##  rows 23-28  pond in the east
##  rows 29-35  the entrance meadow, camp, exit to town at the bottom
## ```

const SIZE := Vector2i(50, 36)
const SEED: int = 0xA1EA

const TOWN_SCENE := "res://areas/town.tscn"
const AREA_TWO_SCENE := "res://areas/area_two.tscn"
## The way past the altar opens only once the Area 1 boss falls.
const ALTAR_BOSS := "boss_area_01"
const ALTAR_GATE_LINE := "The altar is cold, dark stone, and the seal in it is holding. The stair beneath it opens for the rite and nothing else, and nothing is set on it while the Oathbreaker keeps the door."
## The altar sprite is 4x3 cells from [constant ALTAR_CELL]. The way on is
## the altar itself, and the light rests on its base.
const ALTAR_SIZE := Vector2i(4, 3)
## Where the light rests: the middle of the altar's bowl, in map cells.
const ALTAR_LIGHT_CELL := Vector2(42.0, 6.3333)
const SCOUT_SPRITE_FRAMES := "res://content/sprites/npc_scout.tres"
const KNIGHT_SPRITE_FRAMES := "res://content/sprites/npc_knight.tres"
const MERCHANT_SPRITE_FRAMES := "res://content/sprites/npc_merchant.tres"
const ELDER_SPRITE_FRAMES := "res://content/sprites/npc_elder.tres"
const ROAD_WIDTH: int = 3
const ROAD: Array = [
	Vector2i(25, 35),
	Vector2i(25, 29),
	Vector2i(15, 25),
	Vector2i(13, 15),
	Vector2i(27, 13),
	Vector2i(33, 11),
	Vector2i(39, 10),
]
const DAIS_CENTER := Vector2(41.5, 6.5)
const DAIS_RADII := Vector2(4.5, 3.5)
const ALTAR_CELL := Vector2i(40, 5)
const POND_CENTER := Vector2(37.0, 25.5)
const POND_RADII := Vector2(5.0, 3.0)

const SPECIES := {
	"loambuck": "res://content/creatures/creature_earth_01.tres",
	"rimeshard": "res://content/creatures/creature_earth_02.tres",
	"emberling": "res://content/creatures/creature_fire_01.tres",
	"cinderclaw": "res://content/creatures/creature_fire_02.tres",
	"rillfin": "res://content/creatures/creature_water_01.tres",
	"gustpip": "res://content/creatures/creature_wind_01.tres",
	"slagling": "res://content/creatures/creature_fire_03.tres",
	"leechling": "res://content/creatures/creature_water_02.tres",
	"scorchbat": "res://content/creatures/creature_wind_02.tres",
	"hollow_squire": "res://content/creatures/creature_earth_03.tres",
	"oathbreaker": "res://content/creatures/creature_earth_05.tres",
}
const NEUTRAL: int = 0
const HOSTILE: int = 1

const FOREST_TREES: Array = ["tree_3", "tree_4", "tree_1", "tree_2"]
const FOREST_STEP := Vector2i(2, 2)
const CAINOS_TREES: Array = ["plant_00", "plant_01", "plant_02"]
const CAINOS_BUSHES: Array = ["plant_03", "plant_04", "plant_05", "plant_06"]
const CAINOS_TUFTS: Array = [
	"plant_07", "plant_08", "plant_09", "plant_10", "plant_11", "plant_12", "plant_13",
	"plant_14", "plant_15", "plant_16", "plant_17", "plant_18", "plant_19", "plant_20",
	"plant_21", "plant_22",
]
const CAINOS_PEBBLES: Array = [
	"prop_33", "prop_34", "prop_35", "prop_36", "prop_37", "prop_38", "prop_39", "prop_40", "prop_41",
]
const CAINOS_PILLARS: Array = ["prop_13", "prop_12", "prop_21", "prop_03", "prop_05"]
const CAINOS_RELICS: Array = ["prop_09", "prop_20", "prop_15", "prop_24", "prop_28"]
const BUSHES: Array = ["bush_1", "bush_3", "bush_4"]
const ROCKS: Array = ["rock_4", "rock_1", "rock_2"]
const PALE_ROCKS: Array = ["rocks_pale", "rock_pale"]
const STUMPS: Array = ["stump", "dead_stump"]
const FLOWERS: Array = ["flowers_red_1", "flowers_white_1"]


func build() -> AreaPainter:
	var p := AreaPainter.new("AreaOne", SIZE, SEED)
	p.fill_cainos_grass()

	p.paint_road(p.path(ROAD, ROAD_WIDTH))
	p.paint_water(p.fine_ellipse(POND_CENTER, POND_RADII.x, POND_RADII.y))
	p.paint_stone(p.ellipse(DAIS_CENTER, DAIS_RADII.x, DAIS_RADII.y))

	_ruins(p)
	_camp(p)
	_helpers(p)
	_forests(p)
	_meadow(p)
	_creatures(p)

	p.set_player_start(Vector2i(25, 32))
	p.add_entrance("FromTown", Vector2i(25, 32))
	p.add_entrance("FromAreaTwo", Vector2i(42, 9))
	p.add_exit("ToTown", Rect2i(24, 34, 3, 2), TOWN_SCENE, "FromAreaOne")
	# The altar itself is the way on, once its light is burning.
	p.add_exit(
		"ToAreaTwo",
		Rect2i(ALTAR_CELL, ALTAR_SIZE),
		AREA_TWO_SCENE,
		"FromAreaOne",
		ALTAR_BOSS,
		ALTAR_GATE_LINE,
	)
	p.add_altar_beacon(
		"AltarBeacon",
		ALTAR_LIGHT_CELL,
		{"required_boss": StringName(ALTAR_BOSS)},
	)
	p.add_bounds()
	return p


## The sealed ruins: broken brick runs, pillars and graves around the dais,
## and the altar itself in the middle of the paving.
func _ruins(p: AreaPainter) -> void:
	var walls: Dictionary = p.rect(Rect2i(32, 1, 6, 1))
	walls = p.union(walls, p.rect(Rect2i(43, 1, 6, 1)))
	walls = p.union(walls, p.rect(Rect2i(31, 1, 1, 4)))
	walls = p.union(walls, p.rect(Rect2i(48, 2, 1, 6)))
	walls = p.union(walls, p.rect(Rect2i(29, 8, 1, 3)))
	p.paint_walls(walls)

	p.place("prop_26", ALTAR_CELL)
	p.place("crystal_shard", Vector2i(35, 5))
	p.place("crystal_shard", Vector2i(45, 8))
	p.place("skull_small", Vector2i(38, 8))
	p.place("bone_long", Vector2i(39, 2))
	p.place("ruin_pillars", Vector2i(32, 2))
	p.place("ruin_rubble", Vector2i(35, 2))
	p.place("skull_pile", Vector2i(45, 2))
	p.place("ruin_arch", Vector2i(45, 10))
	p.place("dark_rubble", Vector2i(30, 5))
	p.place("skull_maw", Vector2i(33, 5))
	p.place("tombstone_1", Vector2i(30, 11))
	p.place("tombstone_2", Vector2i(47, 5))
	p.place("tombstone_3", Vector2i(34, 12))
	p.place("graves_row", Vector2i(41, 12))
	p.place("grave_pair", Vector2i(35, 13))
	p.place("graves_cluster", Vector2i(39, 13))
	p.place("dead_tree", Vector2i(27, 1))
	p.place("dead_tree", Vector2i(47, 12))
	p.place("gnarled_tree", Vector2i(44, 14))
	p.place("dead_shrub", Vector2i(37, 14))
	p.place("dead_tree_thin", Vector2i(30, 13))
	p.place("dead_tree_thin", Vector2i(48, 9))
	p.place("ghost_grass", Vector2i(46, 7), AreaPainter.FOLIAGE_LAYER)
	p.place("ghost_grass", Vector2i(28, 12), AreaPainter.FOLIAGE_LAYER)
	p.place("dry_bramble", Vector2i(42, 14), AreaPainter.FOLIAGE_LAYER)
	p.place("dry_bramble", Vector2i(32, 8), AreaPainter.FOLIAGE_LAYER)
	p.place("prop_10", Vector2i(36, 11))
	p.place("prop_20", Vector2i(33, 9))
	var ruins: Dictionary = p.rect(Rect2i(28, 2, 21, 13))
	p.scatter(CAINOS_PILLARS, 6, AreaPainter.DECOR_LAYER, 0, 2, ruins)
	p.scatter(CAINOS_RELICS, 4, AreaPainter.DECOR_LAYER, 0, 2, ruins)
	p.scatter(PALE_ROCKS, 3, AreaPainter.DECOR_LAYER, 0, 2, ruins)


## Where the road from town comes in: a scout's camp and a signpost.
func _camp(p: AreaPainter) -> void:
	p.place("campfire", Vector2i(28, 32))
	p.place("stump", Vector2i(27, 33))
	p.place("crate_large", Vector2i(29, 33))
	p.place("sack", Vector2i(30, 32))
	p.place("sign_2", Vector2i(22, 28))
	p.place("sign_1", Vector2i(26, 12))
	p.add_actor(
		"Scout",
		Vector2i(27, 31),
		{
			"display_name": "SCOUT",
			"body_color": Color(0.35, 0.6, 0.85, 1),
			"sprite_frames": load(SCOUT_SPRITE_FRAMES),
			"facing": &"left",
			"dialogue_line": "Scout: Follow the road and you will not get lost. It bends past the pond and climbs to the ruins. The altar is at the very end, and the knight is in front of it, same as he always is.",
			"quest_ids": Array[StringName]([
				&"quest_main_01a_a_second_oath",
				&"quest_main_01b_field_mending",
				&"quest_main_01c_strike_first",
				&"quest_main_01d_caught_in_the_open",
				&"quest_main_01e_no_battle_at_all",
				&"quest_main_01f_a_bed_at_the_hearthside",
				&"quest_main_02_the_ruined_road",
				&"quest_main_02_to_the_ranger",
			]),
		}
	)


## The people along the way to the altar. Each hands the player on to the
## next, and each one's quest sends them somewhere a little more dangerous,
## so the party is around level 15 when the Warden sends them to the Oathbreaker.
func _helpers(p: AreaPainter) -> void:
	p.add_actor(
		"Ranger",
		Vector2i(37, 21),
		{
			"display_name": "RANGER",
			"body_color": Color(0.3, 0.55, 0.35, 1),
			"sprite_frames": load(SCOUT_SPRITE_FRAMES),
			"facing": &"right",
			"dialogue_line": "Ranger: The pond feeds half the meadow, and the altar's stillwater comes out of it. When something troubles this water, everything out here feels it.",
			"quest_ids": Array[StringName]([&"quest_main_02a_scalded_shallows", &"quest_main_02a_to_the_woodcutter", &"quest_side_leech_shallows"]),
		}
	)
	p.add_actor(
		"Woodcutter",
		Vector2i(10, 21),
		{
			"display_name": "WOODCUTTER",
			"body_color": Color(0.6, 0.45, 0.3, 1),
			"sprite_frames": load(MERCHANT_SPRITE_FRAMES),
			"facing": &"up",
			"dialogue_line": "Woodcutter: The deeper you go into these woods, the meaner the things that live there. Always worse when the seal thins, and it is thinning. Same goes for the road north.",
			"quest_ids": Array[StringName]([&"quest_main_02b_wings_in_the_wood", &"quest_main_02b_to_the_warden"]),
		}
	)
	p.add_actor(
		"Hermit",
		Vector2i(16, 11),
		{
			"display_name": "HERMIT",
			"body_color": Color(0.55, 0.55, 0.5, 1),
			"sprite_frames": load(ELDER_SPRITE_FRAMES),
			"facing": &"right",
			"dialogue_line": "Hermit: The ruins? Hah. I went up there once, young and proud, and the knight sent me back down a good deal less of both. Kindly, mind. He is always kind about it.",
			"quest_ids": Array[StringName]([&"quest_side_feathers_on_the_rise"]),
		}
	)
	p.add_actor(
		"Warden",
		Vector2i(38, 15),
		{
			"display_name": "WARDEN",
			"body_color": Color(0.25, 0.7, 0.35, 1),
			"sprite_frames": load(KNIGHT_SPRITE_FRAMES),
			"facing": &"up",
			"dialogue_line": "Warden: Rest a moment. I'll see your Oathbound mended. Whatever you do next, don't face the altar tired. Nobody has ever beaten him tired.",
			"heals_party": true,
			"quest_ids": Array[StringName]([&"quest_main_02c_the_hollow_watch", &"quest_main_03_the_black_knight"]),
		}
	)


func _forests(p: AreaPainter) -> void:
	# The border: two staggered rows on every side, the way out to town left
	# open at the bottom.
	p.plant_forest(Rect2i(0, 0, SIZE.x, 1), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(1, 1, SIZE.x, 1), FOREST_TREES, FOREST_STEP, 0)
	for column: int in [0, 1]:
		p.plant_forest(Rect2i(column, SIZE.y - 2 + column, 21 - column, 1), FOREST_TREES, FOREST_STEP, 0)
		p.plant_forest(Rect2i(30 + column, SIZE.y - 2 + column, SIZE.x - 30, 1), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(-1, 2, 1, SIZE.y - 4), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(0, 3, 1, SIZE.y - 5), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(SIZE.x - 2, 2, 1, SIZE.y - 4), FOREST_TREES, FOREST_STEP, 0)
	p.plant_forest(Rect2i(SIZE.x - 1, 3, 1, SIZE.y - 5), FOREST_TREES, FOREST_STEP, 0)
	# Woods and copses that shape the meadow around the road.
	p.plant_forest(Rect2i(2, 3, 9, 9), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(2, 18, 7, 7), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(18, 3, 8, 4), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(42, 17, 7, 4), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(40, 30, 8, 4), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(17, 30, 5, 4), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(33, 17, 5, 3), FOREST_TREES, FOREST_STEP)
	p.plant_forest(Rect2i(5, 28, 6, 3), FOREST_TREES, FOREST_STEP)
	# The olive Cainos trees suit the Cainos grass; a few break up the meadow.
	p.scatter(CAINOS_TREES, 8, AreaPainter.DECOR_LAYER, 0, 3)


func _meadow(p: AreaPainter) -> void:
	p.place("boulder_pale", Vector2i(19, 9))
	p.place("boulder_pale", Vector2i(43, 28))
	p.place("boulder_pale", Vector2i(10, 26))
	p.scatter(STUMPS, 5, AreaPainter.DECOR_LAYER, 1, 4)
	p.scatter(ROCKS, 18, AreaPainter.DECOR_LAYER, 1, 3)
	p.scatter(PALE_ROCKS, 4, AreaPainter.DECOR_LAYER, 0, 4)
	p.scatter(CAINOS_BUSHES, 18, AreaPainter.DECOR_LAYER, 0, 3)
	p.scatter(BUSHES, 14, AreaPainter.FOLIAGE_LAYER, 0, 3)
	p.scatter(FLOWERS, 14, AreaPainter.FOLIAGE_LAYER, 0, 3)
	p.scatter(CAINOS_PEBBLES, 30, AreaPainter.DECOR_LAYER, 0, 1)
	p.scatter(CAINOS_TUFTS, 120, AreaPainter.FOLIAGE_LAYER, 0, 0)


func _creatures(p: AreaPainter) -> void:
	p.add_spawn_zone("LoambuckMeadow", Vector2i(9, 31), _zone("loambuck", 3.0, 3, 2, 4, NEUTRAL))
	# Levels climb along the quest path: den, pit, wood, graves, then the knight.
	p.add_spawn_zone("EmberlingDen", Vector2i(20, 19), _zone("emberling", 2.5, 2, 4, 6, HOSTILE))
	p.add_spawn_zone("ShardHollow", Vector2i(28, 20), _zone("rimeshard", 2.5, 2, 3, 5, NEUTRAL))
	p.add_spawn_zone("TidePool", Vector2i(30, 26), _zone("rillfin", 3.0, 2, 4, 6, NEUTRAL))
	p.add_spawn_zone("GaleRise", Vector2i(21, 9), _zone("gustpip", 3.0, 2, 6, 8, HOSTILE))
	p.add_spawn_zone("CinderRuins", Vector2i(33, 15), _zone("cinderclaw", 2.0, 1, 6, 7, HOSTILE))
	p.add_spawn_zone("SlagPit", Vector2i(42, 19), _zone("slagling", 3.0, 2, 6, 8, NEUTRAL))
	p.add_spawn_zone("LeechShallows", Vector2i(44, 26), _zone("leechling", 2.5, 2, 6, 8, NEUTRAL))
	p.add_spawn_zone("BatWood", Vector2i(9, 17), _zone("scorchbat", 3.0, 2, 8, 9, HOSTILE))
	p.add_spawn_zone("SquireGraves", Vector2i(31, 6), _zone("hollow_squire", 2.0, 2, 9, 11, HOSTILE))
	# The Area 1 boss in front of the altar. It only accepts a challenge while
	# the Warden's last quest is under way, and stays beaten once it falls.
	p.add_creature(
		"BlackKnight",
		Vector2i(42, 9),
		{
			"species": load(SPECIES["oathbreaker"]),
			"level": 14,
			"ability_index": 0,
			"boss_id": &"boss_area_01",
			"required_quest": &"quest_main_03_the_black_knight",
			"challenge_line": "The Oathbreaker: So. She has the water, the wood and the iron, and she sends me another one. Good. Hear it the way every one of you hears it. They named me Oathbreaker. I did not break it. It was broken for me, in the hour my king reached past what a king may touch, and it went through his knights before it ever reached his son. What I keep now, I chose. I keep this door, and I do not open it for anyone who cannot take it from me. Come and show me you can carry him.",
			"sealed_line": "The knight in black armour stands where he has always stood, between you and the altar. His helm tilts as you come up, almost a greeting. The Oathbreaker: Not yet. The rite is not whole, and I do not spend anyone who is not ready for me. Go back to the warden camped at the edge of the ruins. When she sends you, I will be here. I am always here.",
			"victory_line": "The Oathbreaker: Good. That is the one I was waiting for. He grounds his sword and steps out of the way of the altar. Set them down. Water, wood and iron, the three things he has none of and the only three that will hold him. The stone drinks the offerings and wakes, and a stair opens beneath the altar. Go down and put him back to sleep. I will be standing here when you come up. And when your children come up. It does not end. It only holds.",
			"leash_radius": 0.0,
		}
	)
	# The altar's guardian: placed by hand, so it never respawns once beaten.
	p.add_creature(
		"Guardian",
		Vector2i(35, 11),
		{
			"species": load(SPECIES["cinderclaw"]),
			"level": 10,
			"disposition": HOSTILE,
			"leash_radius": 96.0,
		}
	)


func _zone(species: String, radius: float, max_alive: int, level_min: int, level_max: int, disposition: int) -> Dictionary:
	return {
		"species": load(SPECIES[species]),
		"radius_in_cells": radius,
		"max_alive": max_alive,
		"level_min": level_min,
		"level_max": level_max,
		"disposition": disposition,
	}
