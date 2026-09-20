## Puts the baked `areas/area_two.tscn` back on the game's tile scale.
##
## The catacombs atlas is the 16 px source art upscaled 3x, so one atlas tile
## is 48 px. Drawing those layers at 1.5x put Area Two on a 72 px grid while
## the town draws its own 16 px art at 24 px. This rescales the layers to 0.5
## (24 px cells, the same density as the town) and moves every marker, exit
## and bound to match.
##
## This edits the baked scene rather than re-running the plan bake, because
## `build_area_two_map.gd` currently expects the Area One layer names and
## cannot run against this scene. Delete this script once that is fixed and
## the plan bake is authoritative again.
##
##     Godot --headless --path game -s res://scripts/dev/rescale_area_two.gd
extends SceneTree

const AREA_PATH := "res://areas/area_two.tscn"
const MAP_SIZE := Vector2i(150, 125)
const ATLAS_TILE := 48.0
## What one cell should measure on screen, matching the town.
const NEW_CELL := 24.0
const OLD_CELL := 72.0
const OLD_ORIGIN := Vector2(-5400, -4500)


func _initialize() -> void:
	var packed := load(AREA_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % AREA_PATH)
		quit(1)
		return
	var area := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	var ground := area.get_node_or_null("Ground") as TileMapLayer
	if ground != null and is_equal_approx(ground.scale.x * ATLAS_TILE, NEW_CELL):
		print("Area Two is already on %d px cells; nothing to do." % int(NEW_CELL))
		quit(0)
		return
	var new_origin := -Vector2(MAP_SIZE) * NEW_CELL / 2.0
	var factor: float = NEW_CELL / OLD_CELL

	var layers: int = 0
	var moved: int = 0
	for child: Node in area.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			layer.position = new_origin
			layer.scale = Vector2.ONE * (NEW_CELL / ATLAS_TILE)
			layers += 1
		elif child is Node2D and child.name != "Bounds":
			moved += _move(child as Node2D, new_origin, factor)

	_rebuild_bounds(area, new_origin)

	# Saving a repacked scene drops the uid the editor gave the file, and
	# anything referring to the area by uid:// then resolves elsewhere. Keep it.
	var uid: String = _scene_uid()
	var rebuilt := PackedScene.new()
	var error := rebuilt.pack(area)
	if error == OK:
		error = ResourceSaver.save(rebuilt, AREA_PATH)
	if error == OK:
		_restore_uid(uid)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [AREA_PATH, error])
		quit(1)
		return
	print(
		"Area Two rescaled: %d layers at %d px cells, %d nodes moved, %d x %d cells."
		% [layers, int(NEW_CELL), moved, MAP_SIZE.x, MAP_SIZE.y]
	)
	quit(0)


## Maps [param node] and its Node2D descendants from the old grid onto the
## new one. Returns how many were moved.
func _move(node: Node2D, new_origin: Vector2, factor: float) -> int:
	var moved: int = 1
	node.position = new_origin + (node.position - OLD_ORIGIN) * factor
	for child: Node in node.get_children():
		if child is Node2D:
			moved += _move(child as Node2D, new_origin, factor)
	return moved


## The four walls of the map, rebuilt for the new extent rather than scaled,
## so they keep their thickness.
func _rebuild_bounds(area: Node2D, new_origin: Vector2) -> void:
	var bounds := area.get_node_or_null("Bounds") as StaticBody2D
	if bounds == null:
		push_error("Area Two has no Bounds node.")
		return
	var left: float = new_origin.x - 24.0
	var right: float = new_origin.x + MAP_SIZE.x * NEW_CELL + 24.0
	var top: float = new_origin.y - 24.0
	var bottom: float = new_origin.y + MAP_SIZE.y * NEW_CELL + 24.0
	var edges := {
		"Top": [Vector2((left + right) / 2.0, top), Vector2(right - left, 48)],
		"Bottom": [Vector2((left + right) / 2.0, bottom), Vector2(right - left, 48)],
		"Left": [Vector2(left, (top + bottom) / 2.0), Vector2(48, bottom - top)],
		"Right": [Vector2(right, (top + bottom) / 2.0), Vector2(48, bottom - top)],
	}
	for edge_name: String in edges:
		var shape := bounds.get_node_or_null(edge_name) as CollisionShape2D
		if shape == null:
			continue
		shape.position = edges[edge_name][0]
		var rectangle := RectangleShape2D.new()
		rectangle.size = edges[edge_name][1]
		shape.shape = rectangle


## The `uid="..."` of the scene as it stands on disk, or "" when it has none.
func _scene_uid() -> String:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return ""
	var header: String = file.get_line()
	file.close()
	if not (' uid="' in header):
		return ""
	return header.split(' uid="')[1].split('"')[0]


## Writes [param uid] back into the freshly saved scene's header.
func _restore_uid(uid: String) -> void:
	if uid.is_empty():
		return
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if ' uid="' in text.split("\n")[0]:
		return
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="%s"]' % uid)
	file = FileAccess.open(AREA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
