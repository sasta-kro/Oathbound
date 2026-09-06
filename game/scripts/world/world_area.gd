class_name WorldArea
extends Node2D
## Root of a hand-painted overworld area (Specification 7).
##
## An area scene holds TileMapLayers, NPCs, [SpawnZone]s and a `PlayerStart`
## marker. Map authors paint tiles in the Godot editor and drop spawn zones in;
## nothing here needs to change for a new area. See `docs/map_authoring.md`.
##
## The walkable footprint is whatever the ground layer has painted, so the
## camera limits and spawn validity follow the art without extra setup.

## World-space size of one map cell. The 32 px sheets are drawn at 1.5x.
const GRID_SIZE: int = 48

## Layer whose painted cells define where the area exists. Spawns are only
## valid on painted ground.
@export var ground: TileMapLayer
## Where the player appears when the area loads.
@export var player_start: Marker2D


func _ready() -> void:
	if ground == null:
		ground = get_node_or_null(^"Ground") as TileMapLayer
	if player_start == null:
		player_start = get_node_or_null(^"PlayerStart") as Marker2D
	if ground == null:
		push_warning("%s has no Ground TileMapLayer; spawns and camera limits are off." % name)


## World-space rectangle covering every painted ground cell.
func bounds() -> Rect2:
	if ground == null:
		return Rect2()
	var used: Rect2i = ground.get_used_rect()
	var top_left: Vector2 = ground.to_global(ground.map_to_local(used.position)) - Vector2.ONE * GRID_SIZE / 2.0
	return Rect2(top_left, Vector2(used.size) * GRID_SIZE)


func is_on_ground(world_position: Vector2) -> bool:
	if ground == null:
		return false
	return ground.get_cell_source_id(world_to_cell(world_position)) != -1


func world_to_cell(world_position: Vector2) -> Vector2i:
	if ground == null:
		return Vector2i(world_position / GRID_SIZE)
	return ground.local_to_map(ground.to_local(world_position))


## Center of [param cell] in world space.
func cell_to_world(cell: Vector2i) -> Vector2:
	if ground == null:
		return (Vector2(cell) + Vector2(0.5, 0.5)) * GRID_SIZE
	return ground.to_global(ground.map_to_local(cell))


func player_start_position() -> Vector2:
	if player_start == null:
		return global_position
	return player_start.global_position
