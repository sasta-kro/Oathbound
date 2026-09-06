## Regenerates `res://assets/tilesets/area_one.tres`.
##
## The Cainos sheets are plain PNGs, so the atlas sources have to be declared
## once somewhere. Doing it from a script keeps the tile list, the terrain
## peering bits and the collision shapes in one reviewable place instead of
## hand-editing the resource.
##
## What the tileset gives a map author (see `docs/map_authoring.md`):
##   - Terrain set "Ground": paint Grass (random variants) or Stone (paths with
##     matched edges) with the terrain brush.
##   - Terrain set "Walls": paint brick walls; the capstone row appears on top
##     of each run by itself.
##   - Physics layer 0: wall tiles and the larger props block movement.
##
## Run with:
##   godot --headless --path game --script res://scripts/dev/build_area_tileset.gd
extends SceneTree

const OUTPUT_PATH: String = "res://assets/tilesets/area_one.tres"
const TILE_SIZE: int = 32

## Whole 8x8 sheet: rows 0-3 are grass variants, rows 4-7 the stone-path edges.
const GRASS_SHEET_SIZE := Vector2i(8, 8)
const GRASS_ROWS: int = 4
## Columns 4-7 of the grass rows carry flowers or pebbles. Kept rare so they
## read as detail when the terrain brush picks variants.
const GRASS_ACCENT_FIRST_COLUMN: int = 4
const GRASS_ACCENT_PROBABILITY: float = 0.13

## Corner bits used to look up a stone-path tile. A tile's four corners either
## sit on stone or on grass, so the four bits pick the edge shape.
const CORNER_TOP_LEFT: int = 1
const CORNER_TOP_RIGHT: int = 2
const CORNER_BOTTOM_LEFT: int = 4
const CORNER_BOTTOM_RIGHT: int = 8

## Corner mask -> interchangeable atlas tiles. The sheet has no tile for a
## grass-on-top-right corner, so that one is a flipped alternative of (4, 7).
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

## Brick body used for the room walls, plus the two narrow pieces.
## Row 6 carries the lit capstone, row 7 is plain brick.
const WALL_CAP_ROW: int = 6
const WALL_BRICK_ROW: int = 7
const WALL_TILES: Array[Vector2i] = [
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6),
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
	Vector2i(6, 6), Vector2i(6, 7),
]
const WALL_NARROW_TILES: Array[Vector2i] = [Vector2i(6, 6), Vector2i(6, 7)]

## The prop and plant sheets are repacked onto the grid by
## `tools/pack_sprite_sheet.py`, which also writes these manifests: one entry
## per sprite with its atlas cell and size in cells.
const PLANT_MANIFEST: String = "res://assets/tilesets/plant.json"
const PROPS_MANIFEST: String = "res://assets/tilesets/props.json"

## Sprites at least this many tiles wide or tall block movement. Smaller
## dressing (tufts, pebbles, small pots) is walked over.
const BLOCKING_PROP_MIN_SIZE: int = 2
## Blocking props collide over this fraction of their sprite so the shadow and
## soft edges stay walkable. Below 0.58 a two-cell prop's box stays inside its
## own cell, so a creature centered in the next cell does not touch it.
const PROP_COLLISION_FRACTION: float = 0.55

const PHYSICS_LAYER: int = 0
const GROUND_TERRAIN_SET: int = 0
const GRASS_TERRAIN: int = 0
const STONE_TERRAIN: int = 1
const WALL_TERRAIN_SET: int = 1
const BRICK_TERRAIN: int = 0

const CORNER_BITS: Dictionary = {
	CORNER_TOP_LEFT: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	CORNER_TOP_RIGHT: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	CORNER_BOTTOM_LEFT: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	CORNER_BOTTOM_RIGHT: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
}
const SIDE_BITS: Array[int] = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
]


func _initialize() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.resource_name = "AreaOneTileSet"
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	tile_set.add_physics_layer(PHYSICS_LAYER)
	tile_set.set_physics_layer_collision_layer(PHYSICS_LAYER, 1)
	tile_set.set_physics_layer_collision_mask(PHYSICS_LAYER, 1)

	tile_set.add_terrain_set(GROUND_TERRAIN_SET)
	tile_set.set_terrain_set_mode(GROUND_TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	tile_set.add_terrain(GROUND_TERRAIN_SET, GRASS_TERRAIN)
	tile_set.set_terrain_name(GROUND_TERRAIN_SET, GRASS_TERRAIN, "Grass")
	tile_set.set_terrain_color(GROUND_TERRAIN_SET, GRASS_TERRAIN, Color("5cb85c"))
	tile_set.add_terrain(GROUND_TERRAIN_SET, STONE_TERRAIN)
	tile_set.set_terrain_name(GROUND_TERRAIN_SET, STONE_TERRAIN, "Stone Path")
	tile_set.set_terrain_color(GROUND_TERRAIN_SET, STONE_TERRAIN, Color("9a9a9a"))

	tile_set.add_terrain_set(WALL_TERRAIN_SET)
	tile_set.set_terrain_set_mode(WALL_TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tile_set.add_terrain(WALL_TERRAIN_SET, BRICK_TERRAIN)
	tile_set.set_terrain_name(WALL_TERRAIN_SET, BRICK_TERRAIN, "Brick Wall")
	tile_set.set_terrain_color(WALL_TERRAIN_SET, BRICK_TERRAIN, Color("b5651d"))

	# Sources must be attached before their tiles are configured: a tile only
	# knows about physics layers and terrain sets through its TileSet.
	var grass: TileSetAtlasSource = _make_source("grass")
	var wall: TileSetAtlasSource = _make_source("wall")
	var plant: TileSetAtlasSource = _make_source("plant")
	var props: TileSetAtlasSource = _make_source("props")
	tile_set.add_source(grass, 0)
	tile_set.add_source(wall, 1)
	tile_set.add_source(plant, 2)
	tile_set.add_source(props, 3)
	_configure_grass_source(grass)
	_configure_wall_source(wall)
	_configure_prop_source(plant, _load_manifest(PLANT_MANIFEST))
	_configure_prop_source(props, _load_manifest(PROPS_MANIFEST))

	var error: int = ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [OUTPUT_PATH, error])
	else:
		print("Wrote ", OUTPUT_PATH)
	quit(0 if error == OK else 1)


func _configure_grass_source(source: TileSetAtlasSource) -> void:
	for y: int in GRASS_SHEET_SIZE.y:
		for x: int in GRASS_SHEET_SIZE.x:
			source.create_tile(Vector2i(x, y))

	# Rows 0-3: grass. Every tile is a full grass cell; the accents are rarer.
	for y: int in GRASS_ROWS:
		for x: int in GRASS_SHEET_SIZE.x:
			var data: TileData = source.get_tile_data(Vector2i(x, y), 0)
			data.terrain_set = GROUND_TERRAIN_SET
			data.terrain = GRASS_TERRAIN
			for bit: int in CORNER_BITS.values():
				data.set_terrain_peering_bit(bit, GRASS_TERRAIN)
			if x >= GRASS_ACCENT_FIRST_COLUMN:
				data.probability = GRASS_ACCENT_PROBABILITY

	# Rows 4-7: stone edges. Corners on stone connect, corners on grass are
	# left empty so the edge sits inside the painted stone cells.
	for mask: int in PATH_TILES:
		for coordinates: Vector2i in PATH_TILES[mask]:
			_set_path_terrain(source.get_tile_data(coordinates, 0), mask)
	var flipped: int = source.create_alternative_tile(FLIPPED_PATH_TILE)
	var flipped_data: TileData = source.get_tile_data(FLIPPED_PATH_TILE, flipped)
	flipped_data.flip_h = true
	_set_path_terrain(flipped_data, FLIPPED_PATH_MASK)


func _set_path_terrain(data: TileData, mask: int) -> void:
	data.terrain_set = GROUND_TERRAIN_SET
	data.terrain = STONE_TERRAIN
	for corner: int in CORNER_BITS:
		var terrain: int = STONE_TERRAIN if mask & corner else -1
		data.set_terrain_peering_bit(CORNER_BITS[corner], terrain)


## The brick sheet is a four-tile loop with a lit capstone row on top. Only
## the top side distinguishes the two rows: a cap has nothing above it. The
## other sides are all marked brick so the four columns score alike and the
## brush picks among them at random.
func _configure_wall_source(source: TileSetAtlasSource) -> void:
	var half: float = TILE_SIZE / 2.0
	var full_cell := PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	for coordinates: Vector2i in WALL_TILES:
		source.create_tile(coordinates)
		var data: TileData = source.get_tile_data(coordinates, 0)
		data.add_collision_polygon(PHYSICS_LAYER)
		data.set_collision_polygon_points(PHYSICS_LAYER, 0, full_cell)
		if WALL_NARROW_TILES.has(coordinates):
			continue
		data.terrain_set = WALL_TERRAIN_SET
		data.terrain = BRICK_TERRAIN
		for bit: int in SIDE_BITS:
			data.set_terrain_peering_bit(bit, BRICK_TERRAIN)
		if coordinates.y == WALL_CAP_ROW:
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, -1)


func _configure_prop_source(source: TileSetAtlasSource, sprites: Array) -> void:
	for sprite: Dictionary in sprites:
		var coordinates := Vector2i(int(sprite["cell"][0]), int(sprite["cell"][1]))
		var size := Vector2i(int(sprite["size"][0]), int(sprite["size"][1]))
		source.create_tile(coordinates, size)
		var data: TileData = source.get_tile_data(coordinates, 0)
		# Godot centers an oversized tile's texture on its cell, which leaves a
		# 2x2 prop straddling four cells. Anchoring the texture to the cell's
		# top-left makes a WxH prop cover exactly WxH cells when painted.
		var anchor: Vector2 = Vector2(size - Vector2i.ONE) * TILE_SIZE / 2.0
		data.texture_origin = -anchor
		if maxi(size.x, size.y) < BLOCKING_PROP_MIN_SIZE:
			continue
		var half: Vector2 = Vector2(size * TILE_SIZE) * PROP_COLLISION_FRACTION / 2.0
		data.add_collision_polygon(PHYSICS_LAYER)
		data.set_collision_polygon_points(
			PHYSICS_LAYER,
			0,
			PackedVector2Array(
				[
					anchor + Vector2(-half.x, -half.y),
					anchor + Vector2(half.x, -half.y),
					anchor + Vector2(half.x, half.y),
					anchor + Vector2(-half.x, half.y),
				]
			),
		)


func _load_manifest(path: String) -> Array:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Array:
		push_error("Manifest %s is not a JSON array." % path)
		return []
	return parsed


func _make_source(sheet_name: String) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = sheet_name
	source.texture = load("res://assets/tilesets/%s.png" % sheet_name)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	return source
