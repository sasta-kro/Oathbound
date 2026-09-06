## Regenerates `res://assets/tilesets/area_one.tres`.
##
## The Cainos sheets are plain PNGs, so the atlas sources have to be declared
## once somewhere. Doing it from a script keeps the tile list next to the
## coordinates `area_one_room.gd` reads, instead of hand-editing the resource.
##
## Run with:
##   godot --headless --path game --script res://scripts/dev/build_area_tileset.gd
extends SceneTree

const OUTPUT_PATH: String = "res://assets/tilesets/area_one.tres"

## Whole 8x8 sheet: rows 0-3 are grass variants, rows 4-7 the stone-path edges.
const GRASS_SHEET_SIZE := Vector2i(8, 8)

## Brick body used for the room walls, plus the two narrow pieces.
const WALL_TILES: Array[Vector2i] = [
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
	Vector2i(6, 6), Vector2i(6, 7),
]

## Atlas origin -> size in tiles. Sizes come from the sprites' alpha bounds in
## the "with shadow" sheets, so the shadow is never clipped.
const PLANT_TILES: Dictionary = {
	Vector2i(6, 5): Vector2i(3, 3),
	Vector2i(10, 5): Vector2i(3, 3),
	Vector2i(1, 6): Vector2i(1, 1),
	Vector2i(3, 6): Vector2i(1, 1),
	Vector2i(0, 12): Vector2i(1, 1),
	Vector2i(1, 12): Vector2i(1, 1),
	Vector2i(2, 12): Vector2i(1, 1),
	Vector2i(3, 12): Vector2i(1, 1),
	Vector2i(0, 13): Vector2i(1, 1),
	Vector2i(1, 13): Vector2i(1, 1),
	Vector2i(2, 13): Vector2i(1, 1),
	Vector2i(3, 13): Vector2i(1, 1),
	Vector2i(0, 14): Vector2i(1, 1),
	Vector2i(1, 14): Vector2i(1, 1),
	Vector2i(2, 14): Vector2i(1, 1),
	Vector2i(3, 14): Vector2i(1, 1),
	Vector2i(0, 15): Vector2i(1, 1),
	Vector2i(1, 15): Vector2i(1, 1),
	Vector2i(2, 15): Vector2i(1, 1),
}

const PROP_TILES: Dictionary = {
	Vector2i(3, 0): Vector2i(2, 2),
	Vector2i(5, 0): Vector2i(2, 2),
	Vector2i(3, 2): Vector2i(2, 2),
	Vector2i(5, 2): Vector2i(2, 2),
	Vector2i(5, 4): Vector2i(2, 2),
	Vector2i(3, 5): Vector2i(1, 1),
	Vector2i(5, 6): Vector2i(1, 2),
	Vector2i(3, 7): Vector2i(1, 1),
	Vector2i(5, 9): Vector2i(1, 1),
	Vector2i(5, 10): Vector2i(1, 2),
	Vector2i(13, 11): Vector2i(2, 2),
	Vector2i(0, 13): Vector2i(2, 2),
	Vector2i(0, 15): Vector2i(1, 1),
	Vector2i(1, 15): Vector2i(1, 1),
	Vector2i(2, 15): Vector2i(1, 1),
	Vector2i(3, 15): Vector2i(1, 1),
	Vector2i(4, 15): Vector2i(1, 1),
	Vector2i(5, 15): Vector2i(1, 1),
	Vector2i(7, 15): Vector2i(1, 1),
	Vector2i(8, 15): Vector2i(1, 1),
	Vector2i(9, 15): Vector2i(1, 1),
}


func _initialize() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.resource_name = "AreaOneTileSet"
	tile_set.tile_size = Vector2i(32, 32)

	var grass_tiles: Dictionary = {}
	for y: int in GRASS_SHEET_SIZE.y:
		for x: int in GRASS_SHEET_SIZE.x:
			grass_tiles[Vector2i(x, y)] = Vector2i.ONE

	var wall_tiles: Dictionary = {}
	for coordinates: Vector2i in WALL_TILES:
		wall_tiles[coordinates] = Vector2i.ONE

	tile_set.add_source(_make_source("grass", grass_tiles), 0)
	tile_set.add_source(_make_source("wall", wall_tiles), 1)
	tile_set.add_source(_make_source("plant", PLANT_TILES), 2)
	tile_set.add_source(_make_source("props", PROP_TILES), 3)

	var error: int = ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [OUTPUT_PATH, error])
	else:
		print("Wrote ", OUTPUT_PATH)
	quit(0 if error == OK else 1)


func _make_source(sheet_name: String, tiles: Dictionary) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = sheet_name
	source.texture = load("res://assets/tilesets/%s.png" % sheet_name)
	source.texture_region_size = Vector2i(32, 32)
	for coordinates: Vector2i in tiles:
		source.create_tile(coordinates, tiles[coordinates])
	return source
