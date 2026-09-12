class_name AreaPainter
extends RefCounted
## Paints an overworld area from a layout script and packs it as a scene.
##
## Development only. A layout (see `scripts/dev/layouts/`) describes a map in
## cells: terrain regions, named sprites at cells, dressing to scatter, and
## the markers, actors, zones and exits. `bake_area.gd` runs the layout
## through a painter and writes `res://areas/<name>.tscn`, which is then
## hand-edited in the editor like any other scene.
##
## Cells are map cells: one cell is 48 px in the world, and the layers draw
## the 32 px tiles at 1.5x to match. Cell (0, 0) is the top-left of the map.
## The Fan-tasy terrain (meadow grass, road, water) is 16 px art on its own
## layers, so those are painted on "fine" cells: two per map cell each way.

const GRID_SIZE: int = WorldArea.GRID_SIZE
const LAYER_SCALE := Vector2(1.5, 1.5)

## Draw order, bottom to top. Everything sits under the player except
## Overhead, which carries roofs and canopies.
const LAYER_NAMES: Array[String] = ["Ground", "Water", "Road", "Path", "Walls", "Decor", "Foliage", "Overhead"]
## Layers that always use the 16 px meadow tileset. Ground joins them when
## the map asks for a meadow ground.
const MEADOW_LAYERS: Array[String] = ["Water", "Road"]
## Fine cells per map cell, each way.
const FINE: int = 2
const OVERHEAD_LAYER := "Overhead"
const FOLIAGE_LAYER := "Foliage"
const DECOR_LAYER := "Decor"
const BELOW_PLAYER_Z: int = -1
const ABOVE_PLAYER_Z: int = 1

const WORLD_AREA_SCRIPT := "res://scripts/world/world_area.gd"
const FOLIAGE_SHADER := "res://shaders/foliage_sway.gdshader"
const ACTOR_SCENE := "res://scenes/world_actor.tscn"
const SPAWN_ZONE_SCENE := "res://scenes/spawn_zone.tscn"
const WILD_CREATURE_SCENE := "res://scenes/wild_creature.tscn"
const AREA_EXIT_SCENE := "res://scenes/area_exit.tscn"

## Cainos grass sheet: plain rows and the rarer accent columns.
const GRASS_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
]
const GRASS_ACCENT_TILES: Array[Vector2i] = [
	Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(7, 0),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
	Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
	Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3),
]
const GRASS_ACCENT_CHANCE: float = 0.13

## Cainos stone paving, looked up by which of a tile's corners sit on stone.
const CORNER_TOP_LEFT: int = 1
const CORNER_TOP_RIGHT: int = 2
const CORNER_BOTTOM_LEFT: int = 4
const CORNER_BOTTOM_RIGHT: int = 8
const ALL_CORNERS: int = 15
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
## The full paving tiles with the least grass in their cracks.
const PLAIN_STONE_TILES: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5)]
const FLIPPED_PATH_MASK: int = 13
const FLIPPED_PATH_TILE := Vector2i(4, 7)

## Cainos brick sheet: row 6 carries the lit capstone, row 7 plain brick.
const WALL_CAP_ROW: int = 6
const WALL_BRICK_ROW: int = 7

## Fan-tasy colour indices inside the wang manifests.
const WANG_NOTHING: int = 0
const MEADOW_GRASS: int = 1
const MEADOW_DIRT: int = 2
const SINGLE_COLOUR: int = 1

## Wang bit weights when no tile matches exactly: a wrong side shows more
## than a wrong corner.
const SIDE_WEIGHT: int = 3
const CORNER_WEIGHT: int = 1

const PLACEMENT_ATTEMPTS: int = 400
const NO_TILE := Vector2i(-1, -1)
## World units the invisible border body extends beyond the ground.
const BOUNDS_THICKNESS: float = 48.0

var area_name: String
var size_in_cells: Vector2i
## World position of the top-left corner of cell (0, 0).
var origin: Vector2
var random: RandomNumberGenerator = RandomNumberGenerator.new()

var area: Node2D
var layers: Dictionary = {}
var meadow_ground: bool
var _tile_set: TileSet
var _meadow_set: TileSet
## Sprite name -> {"source": id, "cell": Vector2i, "size": Vector2i, "kind": String}.
var _sprites: Dictionary = {}
## Source id -> wang key -> Array of {"cell": Vector2i, "weight": float}.
var _wang_tiles: Dictionary = {}
## Cells something already occupies; scatter and placement keep off them.
var _claimed: Dictionary = {}
var _entrances: Node2D
var _spawn_zones: Node2D
var _exits: Node2D
var _actors: Node2D
var _fallback_warnings: Dictionary = {}


## With [param use_meadow_ground] the Ground layer is Fan-tasy grass on fine
## cells; otherwise it is Cainos grass on map cells.
func _init(name: String, size: Vector2i, seed: int, use_meadow_ground: bool = false) -> void:
	area_name = name
	size_in_cells = size
	meadow_ground = use_meadow_ground
	origin = -Vector2(size * GRID_SIZE) / 2.0
	random.seed = seed
	_tile_set = load(OverworldTiles.TILESET_PATH)
	_meadow_set = load(OverworldTiles.MEADOW_TILESET_PATH)
	_load_manifests()
	_build_area_node()


# ---------------------------------------------------------------------------
# Cells and shapes
# ---------------------------------------------------------------------------


## Center of [param cell] in the area's local space.
func cell_to_world(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell * GRID_SIZE) + Vector2.ONE * GRID_SIZE / 2.0


func cell_to_world_f(cell: Vector2) -> Vector2:
	return origin + cell * GRID_SIZE


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size_in_cells.x and cell.y < size_in_cells.y


func all_cells() -> Dictionary:
	return rect(Rect2i(Vector2i.ZERO, size_in_cells))


## The fine cells covering [param cells].
func fine(cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		for y: int in FINE:
			for x: int in FINE:
				result[cell * FINE + Vector2i(x, y)] = true
	return result


## Map cells touched by any of [param fine_cells].
func coarse(fine_cells: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in fine_cells:
		result[Vector2i(floori(float(cell.x) / FINE), floori(float(cell.y) / FINE))] = true
	return result


## An ellipse in fine cells, given in map cells, so its edge is smoother than
## one built from whole cells.
func fine_ellipse(center: Vector2, radius_x: float, radius_y: float) -> Dictionary:
	return ellipse(center * FINE, radius_x * FINE, radius_y * FINE)


func rect(rectangle: Rect2i) -> Dictionary:
	var cells: Dictionary = {}
	for y: int in rectangle.size.y:
		for x: int in rectangle.size.x:
			cells[rectangle.position + Vector2i(x, y)] = true
	return cells


## Cells whose centers fall inside an ellipse of the given radii (in cells)
## around [param center].
func ellipse(center: Vector2, radius_x: float, radius_y: float) -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(floori(center.y - radius_y) - 1, ceili(center.y + radius_y) + 2):
		for x: int in range(floori(center.x - radius_x) - 1, ceili(center.x + radius_x) + 2):
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var normalized: Vector2 = Vector2(offset.x / radius_x, offset.y / radius_y)
			if normalized.length_squared() <= 1.0:
				cells[Vector2i(x, y)] = true
	return cells


## A road of [param width] cells through [param points] in order.
func path(points: Array, width: int) -> Dictionary:
	var cells: Dictionary = {}
	var half_low: int = (width - 1) / 2
	var half_high: int = width / 2
	for index: int in range(points.size() - 1):
		var from: Vector2i = points[index]
		var to: Vector2i = points[index + 1]
		for step: Vector2i in _line(from, to):
			for offset_y: int in range(-half_low, half_high + 1):
				for offset_x: int in range(-half_low, half_high + 1):
					cells[step + Vector2i(offset_x, offset_y)] = true
	return cells


func union(a: Dictionary, b: Dictionary) -> Dictionary:
	var cells: Dictionary = a.duplicate()
	cells.merge(b)
	return cells


func subtract(a: Dictionary, b: Dictionary) -> Dictionary:
	var cells: Dictionary = {}
	for cell: Vector2i in a:
		if not b.has(cell):
			cells[cell] = true
	return cells


func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta: Vector2i = (to - from).abs()
	var step := Vector2i(1 if to.x > from.x else -1, 1 if to.y > from.y else -1)
	var error: int = delta.x - delta.y
	var cell: Vector2i = from
	while true:
		cells.append(cell)
		if cell == to:
			break
		var doubled: int = error * 2
		if doubled > -delta.y:
			error -= delta.y
			cell.x += step.x
		if doubled < delta.x:
			error += delta.x
			cell.y += step.y
	return cells


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------


## Cainos grass on every cell, with the occasional flower or pebble.
func fill_cainos_grass() -> void:
	if meadow_ground:
		push_error("%s: fill_cainos_grass needs a painter without a meadow ground." % area_name)
		return
	var layer: TileMapLayer = layers["Ground"]
	for cell: Vector2i in all_cells():
		var tile: Vector2i = GRASS_TILES[random.randi() % GRASS_TILES.size()]
		if random.randf() < GRASS_ACCENT_CHANCE:
			tile = GRASS_ACCENT_TILES[random.randi() % GRASS_ACCENT_TILES.size()]
		layer.set_cell(cell, OverworldTiles.GRASS, tile)


## Fan-tasy grass on every fine cell, with dirt where [param dirt_fine_cells]
## says. Only for a painter made with a meadow ground.
func fill_meadow(dirt_fine_cells: Dictionary = {}) -> void:
	if not meadow_ground:
		push_error("%s: fill_meadow needs a painter made with a meadow ground." % area_name)
		return
	var layer: TileMapLayer = layers["Ground"]
	var full_grass: Array = _wang_tiles[OverworldTiles.FT_GROUND][_wang_key(_full_wang(MEADOW_GRASS))]
	for cell: Vector2i in fine(all_cells()):
		layer.set_cell(cell, OverworldTiles.FT_GROUND, _pick_weighted(full_grass))
	_paint_wang("Ground", OverworldTiles.FT_GROUND, dirt_fine_cells, MEADOW_DIRT, MEADOW_GRASS)


## Fan-tasy dirt road over whatever ground is painted, through [param cells]
## (map cells).
func paint_road(cells: Dictionary) -> void:
	_paint_wang("Road", OverworldTiles.FT_ROAD, fine(cells), SINGLE_COLOUR, WANG_NOTHING)
	claim(cells, 0)


## Fan-tasy water with its sand shore over [param fine_cells]. Water blocks,
## so the map cells it touches count as occupied from here on.
func paint_water(fine_cells: Dictionary) -> void:
	_paint_wang("Water", OverworldTiles.FT_WATER, fine_cells, SINGLE_COLOUR, WANG_NOTHING)
	claim(coarse(fine_cells), 1)


## Cainos stone paving. The edge tiles are corner-matched: a grid corner
## counts as stone when any of the four cells touching it is paved, so the
## edge sits inside the painted cells and a strip needs to be two wide.
## Without [param edges] every cell gets a full paving tile, for a square
## that sits on a meadow: the edge tiles carry Cainos grass, which clashes
## with the Fan-tasy green.
func paint_stone(cells: Dictionary, edges: bool = true) -> void:
	var layer: TileMapLayer = layers["Path"]
	if not edges:
		for cell: Vector2i in cells:
			layer.set_cell(cell, OverworldTiles.GRASS, PLAIN_STONE_TILES[random.randi() % PLAIN_STONE_TILES.size()])
		claim(cells, 0)
		return
	var stone_corners: Dictionary = {}
	for cell: Vector2i in cells:
		for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			stone_corners[cell + offset] = true
	var touched: Dictionary = {}
	for cell: Vector2i in cells:
		for offset_y: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				touched[cell + Vector2i(offset_x, offset_y)] = true
	for cell: Vector2i in touched:
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
			layer.set_cell(cell, OverworldTiles.GRASS, FLIPPED_PATH_TILE, TileSetAtlasSource.TRANSFORM_FLIP_H)
			continue
		# The sheet has no diagonal-only pieces; filling the tile reads better
		# than leaving a hole in the paving.
		var tiles: Array = PATH_TILES.get(mask, PATH_TILES[ALL_CORNERS])
		layer.set_cell(cell, OverworldTiles.GRASS, tiles[random.randi() % tiles.size()])
	claim(cells, 0)


## Cainos brick walls. A wall gets the lit capstone where nothing sits above
## it and plain brick below; stepping the column along the run keeps the
## courses lined up between neighbours.
func paint_walls(cells: Dictionary) -> void:
	var layer: TileMapLayer = layers["Walls"]
	for cell: Vector2i in cells:
		var runs_horizontally: bool = cells.has(cell + Vector2i.LEFT) or cells.has(cell + Vector2i.RIGHT)
		var step: int = cell.x if runs_horizontally else cell.y
		var row: int = WALL_BRICK_ROW if cells.has(cell + Vector2i.UP) else WALL_CAP_ROW
		layer.set_cell(cell, OverworldTiles.WALL, Vector2i(1 + posmod(step, 4), row))
	claim(cells, 0)


## Paints [param cells] in [param colour] on a wang sheet, and the transition
## tiles around them, the way Tiled's terrain brush does: a painted cell has
## the colour on all eight bits, its neighbours get the colour on the bits
## that face it, and everything else stays [param background]. Cells left
## entirely [param background] are not painted, so a road or pond only
## touches the cells it needs.
func _paint_wang(layer_name: String, source: int, cells: Dictionary, colour: int, background: int) -> void:
	var layer: TileMapLayer = layers[layer_name]
	var touched: Dictionary = {}
	for cell: Vector2i in cells:
		touched[cell] = true
		for offset: Vector2i in OverworldTiles.WANG_OFFSETS:
			touched[cell + offset] = true
	var fine_size: Vector2i = size_in_cells * FINE
	for cell: Vector2i in touched:
		if cell.x < 0 or cell.y < 0 or cell.x >= fine_size.x or cell.y >= fine_size.y:
			continue
		var wang: Array[int] = []
		if cells.has(cell):
			wang = _full_wang(colour)
		else:
			wang.resize(OverworldTiles.WANG_OFFSETS.size())
			var any: bool = false
			for index: int in OverworldTiles.WANG_OFFSETS.size():
				var painted: bool
				if index % 2 == 0:
					painted = cells.has(cell + OverworldTiles.WANG_OFFSETS[index])
				else:
					# A corner is shared with three other cells; any of them
					# being painted pulls the corner over.
					painted = (
						cells.has(cell + OverworldTiles.WANG_OFFSETS[index])
						or cells.has(cell + OverworldTiles.WANG_OFFSETS[(index + 1) % 8])
						or cells.has(cell + OverworldTiles.WANG_OFFSETS[(index + 7) % 8])
					)
				wang[index] = colour if painted else background
				any = any or painted
			if not any:
				continue
		var tile: Vector2i = _wang_tile(source, wang, background)
		if tile != NO_TILE:
			layer.set_cell(cell, source, tile)


func _full_wang(colour: int) -> Array[int]:
	var wang: Array[int] = []
	wang.resize(OverworldTiles.WANG_OFFSETS.size())
	wang.fill(colour)
	return wang


func _wang_key(wang: Array) -> String:
	return ",".join(PackedStringArray(wang.map(func(value: int) -> String: return str(value))))


func _wang_tile(source: int, wang: Array[int], background: int) -> Vector2i:
	var tiles: Dictionary = _wang_tiles[source]
	var key: String = _wang_key(wang)
	if tiles.has(key):
		return _pick_weighted(tiles[key])
	if not _touches_a_side(wang, background):
		# Only a corner is painted: the sheet has no piece for a diagonal
		# touch, and nothing reads better than a stray nub.
		return NO_TILE
	# No exact piece on the sheet: take the closest, sides counting more.
	var best_key: String = ""
	var best_score: int = 1 << 30
	for candidate_key: String in tiles:
		var candidate: PackedStringArray = candidate_key.split(",")
		var score: int = 0
		for index: int in wang.size():
			if int(candidate[index]) != wang[index]:
				score += SIDE_WEIGHT if index % 2 == 0 else CORNER_WEIGHT
		if score < best_score:
			best_score = score
			best_key = candidate_key
	if not _fallback_warnings.has(key):
		_fallback_warnings[key] = true
		print("  no exact tile in source %d for %s, using %s" % [source, key, best_key])
	return _pick_weighted(tiles[best_key])


func _touches_a_side(wang: Array[int], background: int) -> bool:
	for index: int in range(0, wang.size(), 2):
		if wang[index] != background:
			return true
	return false


func _pick_weighted(tiles: Array) -> Vector2i:
	var total: float = 0.0
	for tile: Dictionary in tiles:
		total += float(tile["weight"])
	var roll: float = random.randf() * total
	for tile: Dictionary in tiles:
		roll -= float(tile["weight"])
		if roll <= 0.0:
			return tile["cell"]
	return tiles[tiles.size() - 1]["cell"]


# ---------------------------------------------------------------------------
# Sprites
# ---------------------------------------------------------------------------


## Paints the sprite called [param name] with its top-left on [param cell].
## Overhead sprites go on the Overhead layer; anything else on
## [param layer_name]. Everything but an overhead sprite claims its footprint.
func place(name: String, cell: Vector2i, layer_name: String = DECOR_LAYER) -> void:
	var sprite: Dictionary = _sprite(name)
	var kind: String = sprite["kind"]
	if kind == "overhead":
		layer_name = OVERHEAD_LAYER
	var layer: TileMapLayer = layers[layer_name]
	layer.set_cell(cell, sprite["source"], sprite["cell"])
	if kind != "overhead":
		claim(rect(Rect2i(cell, sprite["size"])), 0)


## A sprite split into a `_top` drawn over the player and a `_base` that
## blocks, painted one above the other from [param cell]. Returns the cells
## the whole sprite covers.
func place_split(name: String, cell: Vector2i, layer_name: String = DECOR_LAYER) -> Rect2i:
	var top: Dictionary = _sprite(name + "_top")
	var base: Dictionary = _sprite(name + "_base")
	place(name + "_top", cell)
	place(name + "_base", cell + Vector2i(0, top["size"].y), layer_name)
	return Rect2i(cell, Vector2i(base["size"].x, top["size"].y + base["size"].y))


## Dense trees over [param region]: one every [param step] cells on a jittered
## grid, standing on the row they are planted on. Trees may overlap each
## other, never anything that was there before the forest.
func plant_forest(region: Rect2i, names: Array, step: Vector2i, jitter: int = 1) -> void:
	var before: Dictionary = _claimed.duplicate()
	for row: int in range(region.position.y, region.end.y, step.y):
		for column: int in range(region.position.x, region.end.x, step.x):
			var name: String = names[random.randi() % names.size()]
			var top: Dictionary = _sprite(name + "_top")
			var base: Dictionary = _sprite(name + "_base")
			var foot := Vector2i(
				column + random.randi_range(-jitter, jitter), row + random.randi_range(-jitter, jitter)
			)
			var top_left: Vector2i = foot - Vector2i(0, top["size"].y + base["size"].y - 1)
			var blocked: bool = false
			for cell: Vector2i in rect(Rect2i(top_left + Vector2i(0, top["size"].y), base["size"])):
				if before.has(cell):
					blocked = true
					break
			if not blocked:
				place_split(name, top_left)


## Sprinkles [param count] sprites from [param names] over free cells of
## [param region] (the whole map by default). [param clearance] is how many
## free cells a sprite needs around its footprint; [param spacing] only
## keeps this batch from clumping against itself.
func scatter(
	names: Array,
	count: int,
	layer_name: String = DECOR_LAYER,
	clearance: int = 0,
	spacing: int = 1,
	region: Dictionary = {}
) -> int:
	if region.is_empty():
		region = rect(Rect2i(Vector2i.ONE, size_in_cells - Vector2i.ONE * 2))
	var region_cells: Array = region.keys()
	var spread: Dictionary = {}
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < PLACEMENT_ATTEMPTS * count:
		attempts += 1
		var cell: Vector2i = region_cells[random.randi() % region_cells.size()]
		var name: String = names[random.randi() % names.size()]
		var sprite: Dictionary = _sprite(name)
		var footprint := Rect2i(cell, sprite["size"])
		if spread.has(cell) or not _is_free(footprint, clearance, region):
			continue
		place(name, cell, layer_name)
		for claimed_cell: Vector2i in _grown(footprint, spacing):
			spread[claimed_cell] = true
		placed += 1
	if placed < count:
		print("  %s: placed %d of %d %s (%d cells claimed)" % [area_name, placed, count, names, _claimed.size()])
	return placed


func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and not _claimed.has(cell)


## Marks [param cells] and [param clearance] cells around them as occupied.
func claim(cells: Dictionary, clearance: int) -> void:
	for cell: Vector2i in cells:
		for offset_y: int in range(-clearance, clearance + 1):
			for offset_x: int in range(-clearance, clearance + 1):
				_claimed[cell + Vector2i(offset_x, offset_y)] = true


func _is_free(footprint: Rect2i, clearance: int, region: Dictionary) -> bool:
	for cell: Vector2i in _grown(footprint, clearance):
		if not in_bounds(cell) or _claimed.has(cell):
			return false
	for cell: Vector2i in rect(footprint):
		if not region.has(cell):
			return false
	return true


func _grown(footprint: Rect2i, amount: int) -> Dictionary:
	return rect(footprint.grow(amount))


func _sprite(name: String) -> Dictionary:
	if not _sprites.has(name):
		push_error("No sprite called %s in any manifest." % name)
		return {"source": 0, "cell": Vector2i.ZERO, "size": Vector2i.ONE, "kind": "walkable"}
	return _sprites[name]


func sprite_size(name: String) -> Vector2i:
	return _sprite(name)["size"]


# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------


func set_player_start(cell: Vector2i) -> void:
	var marker := Marker2D.new()
	marker.name = "PlayerStart"
	marker.position = cell_to_world(cell)
	_adopt(marker, area)
	area.set("player_start", marker)


func add_entrance(name: String, cell: Vector2i) -> void:
	var marker := Marker2D.new()
	marker.name = name
	marker.position = cell_to_world(cell)
	_adopt(marker, _entrances)


## An exit covering [param cells], leading to the area at [param target_path]
## and its entrance marker [param entrance].
func add_exit(name: String, cells: Rect2i, target_path: String, entrance: String) -> void:
	var exit: Node2D = (load(AREA_EXIT_SCENE) as PackedScene).instantiate()
	exit.name = name
	exit.position = cell_to_world_f(Vector2(cells.position) + Vector2(cells.size) / 2.0)
	exit.set("target_area_path", target_path)
	exit.set("target_entrance", StringName(entrance))
	exit.set("size_in_cells", Vector2(cells.size))
	_adopt(exit, _exits)


func add_actor(name: String, cell: Vector2i, properties: Dictionary) -> void:
	var actor: Node2D = (load(ACTOR_SCENE) as PackedScene).instantiate()
	actor.name = name
	actor.position = cell_to_world(cell)
	for property: String in properties:
		actor.set(property, properties[property])
	_adopt(actor, _actors)
	claim(rect(Rect2i(cell, Vector2i.ONE)), 0)


func add_spawn_zone(name: String, cell: Vector2i, properties: Dictionary) -> void:
	var zone: Node2D = (load(SPAWN_ZONE_SCENE) as PackedScene).instantiate()
	zone.name = name
	zone.position = cell_to_world(cell)
	for property: String in properties:
		zone.set(property, properties[property])
	_adopt(zone, _spawn_zones)


func add_creature(name: String, cell: Vector2i, properties: Dictionary) -> void:
	var creature: Node2D = (load(WILD_CREATURE_SCENE) as PackedScene).instantiate()
	creature.name = name
	creature.position = cell_to_world(cell)
	for property: String in properties:
		creature.set(property, properties[property])
	_adopt(creature, _actors)
	claim(rect(Rect2i(cell - Vector2i.ONE, Vector2i.ONE * 3)), 0)


## An invisible wall just outside the painted ground, so the map edge holds
## even where the dressing leaves a gap.
func add_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Bounds"
	_adopt(body, area)
	var size: Vector2 = Vector2(size_in_cells * GRID_SIZE)
	var edges: Array = [
		[Vector2(size.x / 2.0, -BOUNDS_THICKNESS / 2.0), Vector2(size.x + BOUNDS_THICKNESS * 2.0, BOUNDS_THICKNESS)],
		[Vector2(size.x / 2.0, size.y + BOUNDS_THICKNESS / 2.0), Vector2(size.x + BOUNDS_THICKNESS * 2.0, BOUNDS_THICKNESS)],
		[Vector2(-BOUNDS_THICKNESS / 2.0, size.y / 2.0), Vector2(BOUNDS_THICKNESS, size.y)],
		[Vector2(size.x + BOUNDS_THICKNESS / 2.0, size.y / 2.0), Vector2(BOUNDS_THICKNESS, size.y)],
	]
	var names: Array[String] = ["Top", "Bottom", "Left", "Right"]
	for index: int in edges.size():
		var shape := CollisionShape2D.new()
		shape.name = names[index]
		var rectangle := RectangleShape2D.new()
		rectangle.size = edges[index][1]
		shape.shape = rectangle
		shape.position = origin + edges[index][0]
		_adopt(shape, body)


func save(path: String) -> int:
	# Empty containers are dropped so the scene tree stays tidy.
	for container: Node2D in [_entrances, _spawn_zones, _exits, _actors]:
		if container.get_child_count() == 0:
			area.remove_child(container)
			container.free()
	var packed := PackedScene.new()
	var error: int = packed.pack(area)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		error = ResourceSaver.save(packed, path)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [path, error])
	else:
		print("Wrote ", path)
	return error


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------


func _build_area_node() -> void:
	area = Node2D.new()
	area.name = area_name
	area.set_script(load(WORLD_AREA_SCRIPT))
	for layer_name: String in LAYER_NAMES:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		var fine_layer: bool = MEADOW_LAYERS.has(layer_name) or (meadow_ground and layer_name == "Ground")
		layer.tile_set = _meadow_set if fine_layer else _tile_set
		layer.position = origin
		layer.scale = LAYER_SCALE
		layer.z_index = ABOVE_PLAYER_Z if layer_name == OVERHEAD_LAYER else BELOW_PLAYER_Z
		if layer_name == FOLIAGE_LAYER:
			var material := ShaderMaterial.new()
			material.shader = load(FOLIAGE_SHADER)
			layer.material = material
		_adopt(layer, area)
		layers[layer_name] = layer
	area.set("ground", layers["Ground"])
	_entrances = _container("Entrances")
	_actors = _container("Actors")
	_spawn_zones = _container("SpawnZones")
	_exits = _container("Exits")


func _container(name: String) -> Node2D:
	var node := Node2D.new()
	node.name = name
	_adopt(node, area)
	return node


## Only the node itself is owned by the area: an instanced scene's inner
## nodes must stay the instance's, or they are written out twice.
func _adopt(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = area


func _load_manifests() -> void:
	for source: int in OverworldTiles.OBJECT_MANIFESTS:
		var entries: Array = OverworldTiles.load_json(OverworldTiles.OBJECT_MANIFESTS[source])
		for entry: Dictionary in entries:
			var name: String = entry["name"]
			if _sprites.has(name):
				push_error("Sprite name %s appears in two manifests." % name)
			_sprites[name] = {
				"source": source,
				"cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])),
				"size": Vector2i(int(entry["size"][0]), int(entry["size"][1])),
				"kind": entry.get("kind", "prop"),
			}
	for source: int in OverworldTiles.TERRAIN_MANIFESTS:
		var manifest: Dictionary = OverworldTiles.load_json(OverworldTiles.TERRAIN_MANIFESTS[source])
		var by_key: Dictionary = {}
		for entry: Dictionary in manifest["tiles"]:
			var key: String = _wang_key(entry["wang"])
			if not by_key.has(key):
				by_key[key] = []
			by_key[key].append(
				{
					"cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])),
					"weight": float(entry.get("probability", 1.0)),
				}
			)
		_wang_tiles[source] = by_key
