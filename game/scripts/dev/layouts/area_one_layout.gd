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
	_forests(p)
	_meadow(p)
	_creatures(p)

	p.set_player_start(Vector2i(25, 32))
	p.add_entrance("FromTown", Vector2i(25, 32))
	p.add_exit("ToTown", Rect2i(24, 34, 3, 2), TOWN_SCENE, "FromAreaOne")
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
			"facing": &"left",
			"dialogue_line": "Scout: Follow the road and you will not get lost. It bends past the pond and climbs to the ruins. The altar is at the very end. Nobody goes further.",
			"quest_ids": Array[StringName]([&"quest_main_02_the_ruined_road"]),
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
	p.add_spawn_zone("EmberlingDen", Vector2i(20, 19), _zone("emberling", 2.5, 2, 3, 5, HOSTILE))
	p.add_spawn_zone("ShardHollow", Vector2i(28, 20), _zone("rimeshard", 2.5, 2, 3, 5, NEUTRAL))
	p.add_spawn_zone("TidePool", Vector2i(30, 26), _zone("rillfin", 3.0, 2, 4, 6, NEUTRAL))
	p.add_spawn_zone("GaleRise", Vector2i(21, 9), _zone("gustpip", 3.0, 2, 4, 6, HOSTILE))
	p.add_spawn_zone("CinderRuins", Vector2i(33, 15), _zone("cinderclaw", 2.0, 1, 6, 7, HOSTILE))
	# The altar's guardian: placed by hand, so it never respawns once beaten.
	p.add_creature(
		"Guardian",
		Vector2i(42, 10),
		{
			"species": load(SPECIES["cinderclaw"]),
			"level": 8,
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
