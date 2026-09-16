## Builds the 48 px Catacombs atlas used when authoring Area Two.
##
## The source art is upscaled with nearest-neighbour sampling before this
## script runs, so every atlas coordinate is one 48 x 48 world tile.
extends SceneTree


const TILE_SIZE := Vector2i(48, 48)
const OUTPUT_PATH := "res://assets/tilesets/catacombs.tres"


func _initialize() -> void:
	var tile_set := TileSet.new()
	tile_set.resource_name = "CatacombsTileSet"
	tile_set.tile_size = TILE_SIZE

	_add_static_source(
		tile_set,
		0,
		"catacombs_mainlevbuild",
		"res://assets/tilesets/catacombs_mainlevbuild.png",
		Vector2i(64, 40)
	)
	_add_static_source(
		tile_set,
		1,
		"catacombs_decorative",
		"res://assets/tilesets/catacombs_decorative.png",
		Vector2i(16, 16)
	)
	var animated_source := _make_source(
		"catacombs_animated_tiles", "res://assets/tilesets/catacombs_animated_tiles.png"
	)
	tile_set.add_source(animated_source, 2)
	_add_animation(animated_source, Vector2i(0, 0), 4) # Candle A
	_add_animation(animated_source, Vector2i(0, 1), 4) # Candle B
	_add_animation(animated_source, Vector2i(0, 2), 5) # Spikes
	_add_animation(animated_source, Vector2i(0, 3), 4) # Torch

	var error := ResourceSaver.save(tile_set, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [OUTPUT_PATH, error])
	quit(0 if error == OK else 1)


func _add_static_source(
	tile_set: TileSet, source_id: int, source_name: String, texture_path: String, grid_size: Vector2i
) -> void:
	var source := _make_source(source_name, texture_path)
	tile_set.add_source(source, source_id)
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			source.create_tile(Vector2i(x, y))


func _add_animation(source: TileSetAtlasSource, coordinates: Vector2i, frames: int) -> void:
	source.create_tile(coordinates)
	source.set_tile_animation_frames_count(coordinates, frames)
	for frame: int in frames:
		source.set_tile_animation_frame_duration(coordinates, frame, 0.15)


func _make_source(source_name: String, texture_path: String) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.resource_name = source_name
	source.texture = load(texture_path)
	source.texture_region_size = TILE_SIZE
	return source
