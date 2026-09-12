class_name OverworldTiles
extends RefCounted
## Shared ids for the two overworld tilesets.
##
## `overworld.tres` holds the 32 px art: the Cainos sheets the first map was
## built on, and the Fan-tasy and Undead objects packed onto the same grid.
## `meadow.tres` holds the Fan-tasy 16 px terrain (grass, road, water), which
## is drawn on its own layers at half the cell size so its edges stay fine.
##
## The tileset builder, the map painter and the layout scripts all refer to
## sources and terrains by these names, so a renumbering happens in one place.

const TILESET_PATH: String = "res://assets/tilesets/overworld.tres"
const MEADOW_TILESET_PATH: String = "res://assets/tilesets/meadow.tres"
const TILE_SIZE: int = 32
const MEADOW_TILE_SIZE: int = 16

## Atlas source ids in `overworld.tres`. 0-3 are the Cainos sheets; the rest
## come from `tools/build_overworld_sheets.py`.
const GRASS: int = 0
const WALL: int = 1
const PLANT: int = 2
const PROPS: int = 3
const FT_BUILDINGS: int = 4
const FT_NATURE: int = 5
const FT_PROPS: int = 6
const RUINS: int = 7

## Atlas source ids in `meadow.tres`.
const FT_GROUND: int = 0
const FT_ROAD: int = 1
const FT_WATER: int = 2

const SHEETS: Dictionary = {
	GRASS: "grass",
	WALL: "wall",
	PLANT: "plant",
	PROPS: "props",
	FT_BUILDINGS: "ft_buildings",
	FT_NATURE: "ft_nature",
	FT_PROPS: "ft_props",
	RUINS: "ruins",
}
const MEADOW_SHEETS: Dictionary = {
	FT_GROUND: "ft_ground",
	FT_ROAD: "ft_road",
	FT_WATER: "ft_water",
}

## Sheets whose tiles are individual sprites, described by a manifest.
const OBJECT_MANIFESTS: Dictionary = {
	PLANT: "res://assets/tilesets/plant.json",
	PROPS: "res://assets/tilesets/props.json",
	FT_BUILDINGS: "res://assets/tilesets/ft_buildings.json",
	FT_NATURE: "res://assets/tilesets/ft_nature.json",
	FT_PROPS: "res://assets/tilesets/ft_props.json",
	RUINS: "res://assets/tilesets/ruins.json",
}

## Sheets converted from Tiled terrain (wang) sets, in `meadow.tres`.
const TERRAIN_MANIFESTS: Dictionary = {
	FT_GROUND: "res://assets/tilesets/ft_ground.json",
	FT_ROAD: "res://assets/tilesets/ft_road.json",
	FT_WATER: "res://assets/tilesets/ft_water.json",
}

## Terrain sets in `overworld.tres`, for the editor's terrain brush.
const GROUND_TERRAIN_SET: int = 0
const GRASS_TERRAIN: int = 0
const STONE_TERRAIN: int = 1
const WALL_TERRAIN_SET: int = 1
const BRICK_TERRAIN: int = 0
## Terrain sets in `meadow.tres`.
const MEADOW_TERRAIN_SET: int = 0
const MEADOW_GRASS_TERRAIN: int = 0
const MEADOW_DIRT_TERRAIN: int = 1
const ROAD_TERRAIN_SET: int = 1
const ROAD_TERRAIN: int = 0
const WATER_TERRAIN_SET: int = 2
const WATER_TERRAIN: int = 0

## Only physics layer in either tileset; everything that blocks uses it.
const PHYSICS_LAYER: int = 0

## Tiled lists a wang id clockwise from the top. Godot names the same eight
## neighbours differently, so this is the translation.
const WANG_ORDER: Array[int] = [
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
]
## Cell offsets in the same order as [constant WANG_ORDER].
const WANG_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]


static func load_json(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("Could not parse %s" % path)
	return parsed
