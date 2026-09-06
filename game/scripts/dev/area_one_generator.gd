class_name AreaOneGenerator
extends Node2D

## Paints the starting layout of Area 1 into its TileMapLayer children.
##
## Development only. `bake_area_one.gd` runs this once to produce the
## hand-editable `res://areas/area_one.tscn`; from then on the map is painted
## in the editor and this script is just the record of how the first version
## was laid out.

const GRID_SIZE: int = 48
const ROOM_RECTANGLE: Rect2 = Rect2(-552, -312, 1056, 624)
const ROOM_SIZE_IN_CELLS := Vector2i(22, 13)

## Atlas source ids, matching `res://assets/tilesets/area_one.tres`.
const GRASS_SOURCE: int = 0
const WALL_SOURCE: int = 1
const PLANT_SOURCE: int = 2
const PROP_SOURCE: int = 3

## Cells covered by the room's StaticBody2D walls.
const WALL_RECTANGLES: Array[Rect2i] = [
	Rect2i(0, 0, 22, 1),
	Rect2i(0, 12, 22, 1),
	Rect2i(0, 0, 1, 13),
	Rect2i(21, 0, 1, 13),
	Rect2i(9, 6, 5, 1),
	Rect2i(15, 8, 1, 3),
]

## Stone paving. Overlapping rectangles are fine; they are merged into one
## region before the edge tiles are picked.
const PATH_RECTANGLES: Array[Rect2i] = [
	Rect2i(4, 2, 2, 10),
	Rect2i(4, 9, 11, 2),
	Rect2i(4, 2, 10, 2),
	Rect2i(14, 2, 1, 7),
	Rect2i(15, 6, 6, 2),
	Rect2i(17, 7, 2, 4),
	Rect2i(16, 9, 5, 2),
]

## Plain grass, safe to repeat anywhere.
const GRASS_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]

## Grass carrying flowers or pebbles. Sprinkled sparsely so it stays a detail.
const GRASS_ACCENT_TILES: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
	Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
]
const GRASS_ACCENT_CHANCE: float = 0.13

## Corner bits used to look up a stone-path tile. A tile's four corners either
## sit on stone or on grass, so the four bits pick the edge shape.
const CORNER_TOP_LEFT: int = 1
const CORNER_TOP_RIGHT: int = 2
const CORNER_BOTTOM_LEFT: int = 4
const CORNER_BOTTOM_RIGHT: int = 8
const ALL_CORNERS: int = 15

## Wall brick sheet: row 6 carries the lit capstone, row 7 is plain brick.
const WALL_CAP_ROW: int = 6
const WALL_BRICK_ROW: int = 7

## Corner mask -> interchangeable atlas tiles. The sheet has no tile for a
## grass-on-top-right corner, so that one is handled by `FLIPPED_PATH_TILE`.
const PATH_TILES: Dictionary = {
	15: [Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(0, 6)],
	10: [Vector2i(2, 4), Vector2i(2, 5)],
	5: [Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)],
	12: [Vector2i(4, 4), Vector2i(5, 4), Vector2i(7, 4)],
	3: [Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)],
	1: [Vector2i(4, 6), Vector2i(3, 7)],
	2: [Vector2i(5, 6), Vector2i(2, 6), Vector2i(2, 7)],
	4: [Vector2i(6, 6)],
	8: [Vector2i(7, 6)],
	7: [Vector2i(1, 6)],
	11: [Vector2i(1, 7)],
	14: [Vector2i(4, 7)],
}
const FLIPPED_PATH_MASK: int = 13
const FLIPPED_PATH_TILE := Vector2i(4, 7)

## Scattered dressing, largest first, by sprite name from the repacked sheet
## manifests (`assets/tilesets/props.json`, `plant.json`). `clearance` is how
## much free grass the sprite needs around its cell; `spacing` only keeps a
## batch from clumping against itself.
const DECOR_BATCHES: Array[Dictionary] = [
	{"source": PROP_SOURCE, "tiles": ["prop_31"], "count": 1, "clearance": 1, "spacing": 2},
	{
		"source": PROP_SOURCE,
		"tiles": ["prop_02", "prop_32", "prop_04"],
		"count": 3,
		"clearance": 1,
		"spacing": 3,
	},
	{
		"source": PROP_SOURCE,
		"tiles": ["prop_13", "prop_12", "prop_21"],
		"count": 3,
		"clearance": 1,
		"spacing": 3,
	},
	{"source": PROP_SOURCE, "tiles": ["prop_01"], "count": 2, "clearance": 1, "spacing": 3},
	{
		"source": PLANT_SOURCE,
		"tiles": ["plant_03", "plant_06"],
		"count": 9,
		"clearance": 1,
		"spacing": 2,
	},
	{
		"source": PROP_SOURCE,
		"tiles": ["prop_18", "prop_23"],
		"count": 2,
		"clearance": 0,
		"spacing": 2,
	},
	{"source": PROP_SOURCE, "tiles": ["prop_27"], "count": 2, "clearance": 0, "spacing": 3},
	{
		"source": PLANT_SOURCE,
		"tiles": ["plant_07", "plant_08"],
		"count": 14,
		"clearance": 0,
		"spacing": 1,
	},
	{
		"source": PROP_SOURCE,
		"tiles": [
			"prop_33", "prop_34", "prop_35", "prop_36", "prop_37",
			"prop_38", "prop_39", "prop_40", "prop_41",
		],
		"count": 18,
		"clearance": 0,
		"spacing": 1,
	},
	{
		"source": PLANT_SOURCE,
		"tiles": [
			"plant_09", "plant_10", "plant_11", "plant_12", "plant_13", "plant_14", "plant_15",
			"plant_16", "plant_17", "plant_18", "plant_19", "plant_20", "plant_21", "plant_22",
		],
		"count": 64,
		"clearance": 0,
		"spacing": 0,
	},
]

const MANIFESTS: Dictionary = {
	PLANT_SOURCE: "res://assets/tilesets/plant.json",
	PROP_SOURCE: "res://assets/tilesets/props.json",
}

## Fixed so the room looks the same every run.
const DECOR_SEED: int = 0x0A7B0
const PLACEMENT_ATTEMPTS: int = 600

@onready var ground_layer: TileMapLayer = $Ground
@onready var path_layer: TileMapLayer = $Path
@onready var wall_layer: TileMapLayer = $Walls
@onready var decor_layer: TileMapLayer = $Decor

var _wall_cells: Dictionary = {}
var _path_cells: Dictionary = {}
## Source id -> sprite name -> atlas cell.
var _sprite_cells: Dictionary = {}


static func cell_to_world(cell: Vector2i) -> Vector2:
	var half_cell: Vector2 = Vector2.ONE * GRID_SIZE / 2.0
	return ROOM_RECTANGLE.position + Vector2(cell * GRID_SIZE) + half_cell


func _ready() -> void:
	_wall_cells = _cells_in(WALL_RECTANGLES)
	_path_cells = _cells_in(PATH_RECTANGLES)
	for source: int in MANIFESTS:
		_sprite_cells[source] = _load_sprite_cells(MANIFESTS[source])
	_paint_ground()
	_paint_path()
	_paint_walls()
	_paint_decor()


func _paint_ground() -> void:
	var random: RandomNumberGenerator = _seeded_random(1)
	for y: int in ROOM_SIZE_IN_CELLS.y:
		for x: int in ROOM_SIZE_IN_CELLS.x:
			var tile: Vector2i = GRASS_TILES[random.randi() % GRASS_TILES.size()]
			if random.randf() < GRASS_ACCENT_CHANCE:
				tile = GRASS_ACCENT_TILES[random.randi() % GRASS_ACCENT_TILES.size()]
			ground_layer.set_cell(Vector2i(x, y), GRASS_SOURCE, tile)


## The stone edge tiles are corner-matched: a grid corner counts as stone when
## any of the four cells touching it is paved.
func _paint_path() -> void:
	var stone_corners: Dictionary = {}
	for cell: Vector2i in _path_cells:
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			stone_corners[cell + offset] = true

	var random: RandomNumberGenerator = _seeded_random(2)
	for y: int in ROOM_SIZE_IN_CELLS.y:
		for x: int in ROOM_SIZE_IN_CELLS.x:
			var cell := Vector2i(x, y)
			var mask: int = 0
			if stone_corners.has(cell):
				mask |= CORNER_TOP_LEFT
			if stone_corners.has(cell + Vector2i(1, 0)):
				mask |= CORNER_TOP_RIGHT
			if stone_corners.has(cell + Vector2i(0, 1)):
				mask |= CORNER_BOTTOM_LEFT
			if stone_corners.has(cell + Vector2i(1, 1)):
				mask |= CORNER_BOTTOM_RIGHT
			if mask == 0:
				continue
			if mask == FLIPPED_PATH_MASK:
				path_layer.set_cell(
					cell, GRASS_SOURCE, FLIPPED_PATH_TILE, TileSetAtlasSource.TRANSFORM_FLIP_H
				)
				continue
			# The sheet has no diagonal-only pieces; filling the tile reads
			# better than leaving a hole in the paving.
			var tiles: Array = PATH_TILES.get(mask, PATH_TILES[ALL_CORNERS])
			path_layer.set_cell(cell, GRASS_SOURCE, tiles[random.randi() % tiles.size()])


## The brick sheet is a four-tile loop with a lit capstone row on top, so a
## wall gets the capstone where nothing sits above it and plain brick below.
func _paint_walls() -> void:
	for cell: Vector2i in _wall_cells:
		var runs_horizontally: bool = (
			_wall_cells.has(cell + Vector2i.LEFT) or _wall_cells.has(cell + Vector2i.RIGHT)
		)
		# Stepping along the run keeps the courses lined up between neighbours.
		var step: int = cell.x if runs_horizontally else cell.y
		var row: int = WALL_BRICK_ROW if _wall_cells.has(cell + Vector2i.UP) else WALL_CAP_ROW
		wall_layer.set_cell(cell, WALL_SOURCE, Vector2i(1 + posmod(step, 4), row))


## Batches run big-to-small. `occupied` is what every later batch has to avoid,
## while `spread` only keeps a batch from clumping against itself, so the grass
## tufts can still fill in around the crates and bushes.
func _paint_decor() -> void:
	var random: RandomNumberGenerator = _seeded_random(3)
	var occupied: Dictionary = {}
	for batch: Dictionary in DECOR_BATCHES:
		var tiles: Array = batch["tiles"]
		var clearance: int = int(batch["clearance"])
		var spread: Dictionary = {}
		var placed: int = 0
		var attempts: int = 0
		while placed < int(batch["count"]) and attempts < PLACEMENT_ATTEMPTS:
			attempts += 1
			var cell := Vector2i(
				random.randi_range(1, ROOM_SIZE_IN_CELLS.x - 2),
				random.randi_range(1, ROOM_SIZE_IN_CELLS.y - 2),
			)
			if spread.has(cell) or not _is_free(cell, clearance, occupied):
				continue
			_claim(cell, clearance, occupied)
			_claim(cell, int(batch["spacing"]), spread)
			var source: int = int(batch["source"])
			var sprite_name: String = tiles[random.randi() % tiles.size()]
			decor_layer.set_cell(cell, source, _sprite_cells[source][sprite_name])
			placed += 1


## Grass only: nothing is allowed to sit on a wall, on the paving, or on top of
## a sprite that was placed earlier.
func _is_free(cell: Vector2i, clearance: int, occupied: Dictionary) -> bool:
	for offset_y: int in range(-clearance, clearance + 1):
		for offset_x: int in range(-clearance, clearance + 1):
			var probe: Vector2i = cell + Vector2i(offset_x, offset_y)
			if _wall_cells.has(probe) or _path_cells.has(probe) or occupied.has(probe):
				return false
	return true


func _claim(cell: Vector2i, radius: int, cells: Dictionary) -> void:
	for offset_y: int in range(-radius, radius + 1):
		for offset_x: int in range(-radius, radius + 1):
			cells[cell + Vector2i(offset_x, offset_y)] = true


func _load_sprite_cells(path: String) -> Dictionary:
	var cells: Dictionary = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	for sprite: Dictionary in parsed:
		cells[sprite["name"]] = Vector2i(int(sprite["cell"][0]), int(sprite["cell"][1]))
	return cells


func _cells_in(rectangles: Array[Rect2i]) -> Dictionary:
	var cells: Dictionary = {}
	for rectangle: Rect2i in rectangles:
		for y: int in rectangle.size.y:
			for x: int in rectangle.size.x:
				cells[rectangle.position + Vector2i(x, y)] = true
	return cells


func _seeded_random(stream: int) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = DECOR_SEED + stream
	return random
