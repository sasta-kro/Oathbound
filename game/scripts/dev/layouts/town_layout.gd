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
##  rows 11-16 market on the west side, pond on the east
##  rows 19-22 three houses and the camp along the south road
##  row 24     town wall
## ```

const SIZE := Vector2i(36, 27)
const SEED: int = 0x70A1

const AREA_ONE_SCENE := "res://areas/area_one.tscn"
const KNIGHT_SPRITE_FRAMES := "res://content/sprites/npc_knight.tres"

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
	_dressing(p)
	_forest_outside(p)

	p.set_player_start(Vector2i(18, 16))
	p.add_entrance("FromAreaOne", Vector2i(18, 7))
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
			"dialogue_line": "Knight: Rest by the well, you look worn. The road through the north gate leads past the old ruins to the altar. Keep to it.",
			"heals_party": true,
		}
	)
	p.add_actor(
		"Elder",
		Vector2i(24, 11),
		{
			"display_name": "ELDER",
			"body_color": Color(0.75, 0.62, 0.86, 1),
			"facing": &"left",
			"dialogue_line": "Elder: The board has work for anyone willing to leave the walls. Wild Oathbound roam the meadow, and worse things by the ruins.",
		}
	)
	p.add_actor(
		"Merchant",
		Vector2i(7, 12),
		{
			"display_name": "MERCHANT",
			"body_color": Color(0.9, 0.6, 0.3, 1),
			"dialogue_line": "Merchant: Fresh bread, dried fish, and a crate I have not opened since the caravan came. Take a look.",
		}
	)
	p.add_actor(
		"Child",
		Vector2i(13, 22),
		{
			"display_name": "CHILD",
			"body_color": Color(0.95, 0.85, 0.4, 1),
			"facing": &"up",
			"dialogue_line": "Child: I saw a Loambuck from the wall! It had leaves on its back. Can I come with you? No? Fine.",
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
