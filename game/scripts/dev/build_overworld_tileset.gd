## Regenerates `res://assets/tilesets/overworld.tres` and `meadow.tres`.
##
## The sheets are plain PNGs, so the atlas sources have to be declared once
## somewhere. Doing it from a script keeps the tile list, the terrain peering
## bits and the collision shapes in one reviewable place instead of
## hand-editing the resources.
##
## What the tilesets give a map author (see `docs/map_authoring.md`):
##   overworld.tres (32 px tiles, one per map cell)
##   - Terrain set "Ground": Cainos grass (random variants) and stone paving.
##   - Terrain set "Walls": Cainos brick walls with the lit capstone row.
##   - Object sheets: every sprite is one tile; the manifests written by
##     `tools/build_overworld_sheets.py` say which ones block.
##   meadow.tres (16 px tiles, four per map cell)
##   - Terrain set "Meadow": Fan-tasy grass with dirt patches.
##   - Terrain set "Road": Fan-tasy dirt road, drawn over any grass.
##   - Terrain set "Water": animated Fan-tasy water with a sand shore.
##   Physics layer 0 in both: walls, water and the blocking props.
##
## Run with:
##   godot --headless --path game --script res://scripts/dev/build_overworld_tileset.gd
extends SceneTree

const TILE_SIZE: int = OverworldTiles.TILE_SIZE

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

## Cainos sprites at least this many tiles wide or tall block movement.
## Smaller dressing (tufts, pebbles, small pots) is walked over.
const BLOCKING_PROP_MIN_SIZE: int = 2
## Props collide over this fraction of their sprite so the shadow and soft
## edges stay walkable. Below 0.58 a two-cell prop's box stays inside its own
## cell, so a creature centered in the next cell does not touch it.
const PROP_COLLISION_FRACTION: float = 0.55
## A solid object (house wall, water) blocks almost its whole footprint; the
## sliver left over keeps the player from snagging on a neighbouring cell.
const SOLID_COLLISION_FRACTION: float = 0.96
## A tree trunk blocks this much of its base's width, centered.
const TRUNK_COLLISION_WIDTH: float = 0.4

const PHYSICS_LAYER: int = OverworldTiles.PHYSICS_LAYER

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
	var error: int = _build_overworld()
	if error == OK:
		error = _build_meadow()
	quit(0 if error == OK else 1)


func _build_overworld() -> int:
	var tile_set: TileSet = TileSet.new()
	tile_set.resource_name = "OverworldTileSet"
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_add_physics_layer(tile_set)
	_add_terrain_set(
		tile_set,
		OverworldTiles.GROUND_TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_CORNERS,
		[["Grass", Color("5cb85c")], ["Stone Path", Color("9a9a9a")]]
	)
	_add_terrain_set(
		tile_set,
		OverworldTiles.WALL_TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_SIDES,
		[["Brick Wall", Color("b5651d")]]
	)
	# Sources must be attached before their tiles are configured: a tile only
	# knows about physics layers and terrain sets through its TileSet.
	var sources: Dictionary = _add_sources(tile_set, OverworldTiles.SHEETS, TILE_SIZE)
	_configure_grass_source(sources[OverworldTiles.GRASS])
	_configure_wall_source(sources[OverworldTiles.WALL])
	for id: int in OverworldTiles.OBJECT_MANIFESTS:
		_configure_object_source(sources[id], OverworldTiles.OBJECT_MANIFESTS[id])
	return _save(tile_set, OverworldTiles.TILESET_PATH)


func _build_meadow() -> int:
	var tile_set: TileSet = TileSet.new()
	tile_set.resource_name = "MeadowTileSet"
	tile_set.tile_size = Vector2i(OverworldTiles.MEADOW_TILE_SIZE, OverworldTiles.MEADOW_TILE_SIZE)
	_add_physics_layer(tile_set)
	_add_terrain_set(
		tile_set,
		OverworldTiles.MEADOW_TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
		[["Meadow Grass", Color("7ed957")], ["Meadow Dirt", Color("b08968")]]
	)
	_add_terrain_set(
		tile_set,
		OverworldTiles.ROAD_TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
		[["Dirt Road", Color("d9a066")]]
	)
	_add_terrain_set(
		tile_set,
		OverworldTiles.WATER_TERRAIN_SET,
		TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES,
		[["Water", Color("5bc0eb")]]
	)
	var sources: Dictionary = _add_sources(tile_set, OverworldTiles.MEADOW_SHEETS, OverworldTiles.MEADOW_TILE_SIZE)
	_configure_terrain_source(
		sources[OverworldTiles.FT_GROUND],
		OverworldTiles.TERRAIN_MANIFESTS[OverworldTiles.FT_GROUND],
		OverworldTiles.MEADOW_TERRAIN_SET,
		false
	)
	_configure_terrain_source(
		sources[OverworldTiles.FT_ROAD],
		OverworldTiles.TERRAIN_MANIFESTS[OverworldTiles.FT_ROAD],
		OverworldTiles.ROAD_TERRAIN_SET,
		false
	)
	_configure_terrain_source(
		sources[OverworldTiles.FT_WATER],
		OverworldTiles.TERRAIN_MANIFESTS[OverworldTiles.FT_WATER],
		OverworldTiles.WATER_TERRAIN_SET,
		true
	)
	return _save(tile_set, OverworldTiles.MEADOW_TILESET_PATH)


func _add_physics_layer(tile_set: TileSet) -> void:
	tile_set.add_physics_layer(PHYSICS_LAYER)
	tile_set.set_physics_layer_collision_layer(PHYSICS_LAYER, 1)
	tile_set.set_physics_layer_collision_mask(PHYSICS_LAYER, 1)


func _add_sources(tile_set: TileSet, sheets: Dictionary, tile_size: int) -> Dictionary:
	var sources: Dictionary = {}
	for id: int in sheets:
		var source: TileSetAtlasSource = _make_source(sheets[id], tile_size)
		tile_set.add_source(source, id)
		sources[id] = source
	return sources


func _save(tile_set: TileSet, path: String) -> int:
	var error: int = ResourceSaver.save(tile_set, path)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [path, error])
	else:
		print("Wrote ", path)
	return error


func _add_terrain_set(tile_set: TileSet, index: int, mode: TileSet.TerrainMode, terrains: Array) -> void:
	tile_set.add_terrain_set(index)
	tile_set.set_terrain_set_mode(index, mode)
	for terrain_index: int in terrains.size():
		tile_set.add_terrain(index, terrain_index)
		tile_set.set_terrain_name(index, terrain_index, terrains[terrain_index][0])
		tile_set.set_terrain_color(index, terrain_index, terrains[terrain_index][1])


func _configure_grass_source(source: TileSetAtlasSource) -> void:
	for y: int in GRASS_SHEET_SIZE.y:
		for x: int in GRASS_SHEET_SIZE.x:
			source.create_tile(Vector2i(x, y))

	# Rows 0-3: grass. Every tile is a full grass cell; the accents are rarer.
	for y: int in GRASS_ROWS:
		for x: int in GRASS_SHEET_SIZE.x:
			var data: TileData = source.get_tile_data(Vector2i(x, y), 0)
			data.terrain_set = OverworldTiles.GROUND_TERRAIN_SET
			data.terrain = OverworldTiles.GRASS_TERRAIN
			for bit: int in CORNER_BITS.values():
				data.set_terrain_peering_bit(bit, OverworldTiles.GRASS_TERRAIN)
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
	data.terrain_set = OverworldTiles.GROUND_TERRAIN_SET
	data.terrain = OverworldTiles.STONE_TERRAIN
	for corner: int in CORNER_BITS:
		var terrain: int = OverworldTiles.STONE_TERRAIN if mask & corner else -1
		data.set_terrain_peering_bit(CORNER_BITS[corner], terrain)


## The brick sheet is a four-tile loop with a lit capstone row on top. Only
## the top side distinguishes the two rows: a cap has nothing above it. The
## other sides are all marked brick so the four columns score alike and the
## brush picks among them at random.
func _configure_wall_source(source: TileSetAtlasSource) -> void:
	for coordinates: Vector2i in WALL_TILES:
		source.create_tile(coordinates)
		var data: TileData = source.get_tile_data(coordinates, 0)
		_add_box(data, Vector2.ZERO, Vector2.ONE * TILE_SIZE)
		if WALL_NARROW_TILES.has(coordinates):
			continue
		data.terrain_set = OverworldTiles.WALL_TERRAIN_SET
		data.terrain = OverworldTiles.BRICK_TERRAIN
		for bit: int in SIDE_BITS:
			data.set_terrain_peering_bit(bit, OverworldTiles.BRICK_TERRAIN)
		if coordinates.y == WALL_CAP_ROW:
			data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, -1)


## A sheet converted from a Tiled wang set. Each entry lists the eight
## neighbour colours clockwise from the top; colour 0 is "nothing", so it
## becomes an empty peering bit and colour N becomes terrain N - 1.
func _configure_terrain_source(
	source: TileSetAtlasSource, manifest_path: String, terrain_set: int, blocks: bool
) -> void:
	var manifest: Dictionary = OverworldTiles.load_json(manifest_path)
	var animation: Dictionary = manifest.get("animation", {})
	for entry: Dictionary in manifest["tiles"]:
		var coordinates := Vector2i(int(entry["cell"][0]), int(entry["cell"][1]))
		source.create_tile(coordinates)
		if not animation.is_empty():
			source.set_tile_animation_separation(coordinates, Vector2i(int(animation["separation"]), 0))
			source.set_tile_animation_frames_count(coordinates, int(animation["frames"]))
			for frame: int in int(animation["frames"]):
				source.set_tile_animation_frame_duration(coordinates, frame, float(animation["seconds"]))
		var data: TileData = source.get_tile_data(coordinates, 0)
		data.terrain_set = terrain_set
		var wang: Array = entry["wang"]
		data.terrain = _dominant_terrain(wang)
		for index: int in OverworldTiles.WANG_ORDER.size():
			var colour: int = int(wang[index])
			data.set_terrain_peering_bit(OverworldTiles.WANG_ORDER[index], colour - 1)
		if entry.has("probability"):
			data.probability = float(entry["probability"])
		if blocks:
			var cell: float = float(OverworldTiles.MEADOW_TILE_SIZE)
			_add_box(data, Vector2.ZERO, Vector2.ONE * cell * SOLID_COLLISION_FRACTION)


## The colour a tile shows most, so painting "this terrain" in the editor
## lands on a sensible tile.
func _dominant_terrain(wang: Array) -> int:
	var counts: Dictionary = {}
	for colour: Variant in wang:
		if int(colour) == 0:
			continue
		counts[int(colour)] = int(counts.get(int(colour), 0)) + 1
	var best: int = 0
	var best_count: int = -1
	for colour: int in counts:
		if counts[colour] > best_count:
			best = colour
			best_count = counts[colour]
	return best - 1


## Sprites packed onto the grid by `tools/pack_sprite_sheet.py` or
## `tools/build_overworld_sheets.py`. Each entry is one tile covering
## `size` cells; `kind` decides what, if anything, it blocks.
func _configure_object_source(source: TileSetAtlasSource, manifest_path: String) -> void:
	var sprites: Array = OverworldTiles.load_json(manifest_path)
	for sprite: Dictionary in sprites:
		var coordinates := Vector2i(int(sprite["cell"][0]), int(sprite["cell"][1]))
		var size := Vector2i(int(sprite["size"][0]), int(sprite["size"][1]))
		source.create_tile(coordinates, size)
		if sprite.has("animation"):
			var animation: Dictionary = sprite["animation"]
			source.set_tile_animation_frames_count(coordinates, int(animation["frames"]))
			for frame: int in int(animation["frames"]):
				source.set_tile_animation_frame_duration(coordinates, frame, float(animation["seconds"]))
		var data: TileData = source.get_tile_data(coordinates, 0)
		# Godot centers an oversized tile's texture on its cell, which leaves a
		# 2x2 prop straddling four cells. Anchoring the texture to the cell's
		# top-left makes a WxH prop cover exactly WxH cells when painted.
		var anchor: Vector2 = Vector2(size - Vector2i.ONE) * TILE_SIZE / 2.0
		data.texture_origin = -anchor
		var footprint: Vector2 = Vector2(size * TILE_SIZE)
		# The Cainos manifests predate `kind`; their rule was purely by size.
		var kind: String = sprite.get("kind", "prop")
		match kind:
			"overhead", "walkable":
				pass
			"solid":
				var collision: Variant = sprite.get("collision", null)
				if collision is Array:
					for rect: Array in collision:
						var origin := Vector2(float(rect[0]), float(rect[1])) * TILE_SIZE
						var box := Vector2(float(rect[2]), float(rect[3])) * TILE_SIZE
						_add_box(data, anchor + origin + box / 2.0 - footprint / 2.0, box * SOLID_COLLISION_FRACTION)
				elif collision == "trunk":
					var box := Vector2(footprint.x * TRUNK_COLLISION_WIDTH, footprint.y * SOLID_COLLISION_FRACTION)
					_add_box(data, anchor, box)
				else:
					_add_box(data, anchor, footprint * SOLID_COLLISION_FRACTION)
			_:
				if maxi(size.x, size.y) >= BLOCKING_PROP_MIN_SIZE:
					_add_box(data, anchor, footprint * PROP_COLLISION_FRACTION)


## A collision rectangle of [param size] centered on [param center], in the
## tile's local pixels (0,0 being the middle of its top-left cell).
func _add_box(data: TileData, center: Vector2, size: Vector2) -> void:
	var half: Vector2 = size / 2.0
	var index: int = data.get_collision_polygons_count(PHYSICS_LAYER)
	data.add_collision_polygon(PHYSICS_LAYER)
	data.set_collision_polygon_points(
		PHYSICS_LAYER,
		index,
		PackedVector2Array(
			[
				center + Vector2(-half.x, -half.y),
				center + Vector2(half.x, -half.y),
				center + Vector2(half.x, half.y),
				center + Vector2(-half.x, half.y),
			]
		),
	)


func _make_source(sheet_name: String, tile_size: int) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.resource_name = sheet_name
	source.texture = load("res://assets/tilesets/%s.png" % sheet_name)
	source.texture_region_size = Vector2i(tile_size, tile_size)
	return source
