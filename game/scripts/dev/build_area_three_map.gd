## Bakes `res://areas/area_three.tscn`: the dead city under the altar, where
## the Skeleton Lord keeps his seat.
##
## Area Three is deliberately small and one-directional. The player comes up
## out of the Area Two catacombs at the bottom and walks north the whole way:
## an antechamber, a long causeway over nothing, two side chambers holding the
## elite guards of Specification 5.3, a bone gate, and then the throne hall.
## Everything narrows towards the throne so the hall opening out is the reveal.
##
## Run it from the repository root:
##     Godot --headless --path game -s res://scripts/dev/build_area_three_map.gd
extends SceneTree

const AREA_PATH := "res://areas/area_three.tscn"
const CATACOMBS_TILESET := preload("res://assets/tilesets/catacombs.tres")
const AREA_EXIT_SCENE := preload("res://scenes/area_exit.tscn")
const WORLD_AREA_SCRIPT := preload("res://scripts/world/world_area.gd")

const MAP_SIZE := Vector2i(92, 120)
const TILE_SIZE := 48
## The catacombs atlas is the 16 px source art upscaled 3x, so one atlas tile
## is 48 px. Drawn at 0.5 that is a 24 px cell, the same density the town gets
## from its own 16 px tileset.
const MAP_SCALE := Vector2(0.5, 0.5)
const MAP_POSITION := Vector2(-1104, -1440)
## A dead-red wash over the whole area, so it reads as somewhere else the
## moment the stair comes out.
const HELL_TINT := Color(0.74, 0.52, 0.54)

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(46, 13), Vector2i(47, 13), Vector2i(49, 13), Vector2i(50, 13),
	Vector2i(46, 14), Vector2i(47, 14), Vector2i(49, 14), Vector2i(50, 14),
]
const FLOOR_ACCENTS: Array[Vector2i] = [
	Vector2i(46, 20), Vector2i(47, 20), Vector2i(49, 20), Vector2i(50, 20),
]
## Wall tile for the side of a floor cell that faces nothing.
const WALLS := {
	Vector2i.UP: Vector2i(8, 1),
	Vector2i.DOWN: Vector2i(11, 1),
	Vector2i.LEFT: Vector2i(3, 4),
	Vector2i.RIGHT: Vector2i(16, 4),
}
## The animated source, whose four tiles are the only light down here.
const ANIMATED_SOURCE := 2
const CANDLE_A := Vector2i(0, 0)
const CANDLE_B := Vector2i(0, 1)
const SPIKES := Vector2i(0, 2)
const TORCH := Vector2i(0, 3)

## The rooms, south to north. Named so the log reads like a walkthrough.
const THRONE_HALL := Rect2i(20, 4, 54, 28)
const BONE_GATE := Rect2i(42, 32, 10, 8)
const UPPER_CAUSEWAY := Rect2i(40, 40, 14, 28)
const WEST_CHAMBER := Rect2i(14, 44, 20, 16)
const WEST_LINK := Rect2i(32, 50, 10, 6)
const EAST_CHAMBER := Rect2i(58, 44, 20, 16)
const EAST_LINK := Rect2i(52, 50, 8, 6)
const LOWER_CAUSEWAY := Rect2i(42, 68, 10, 24)
const ANTECHAMBER := Rect2i(32, 92, 30, 22)

const SPAWN_CELL := Vector2i(46, 106)
const EXIT_CELL := Vector2i(46, 110)
## An exit's shape is size_in_cells * WorldArea.GRID_SIZE (48), which is not
## this area's 24 px cell, so 2 here covers four cells of the map.
const EXIT_SIZE_IN_CELLS := Vector2(2, 2)

const MARKERS := {
	"Boss": Vector2i(46, 10),
	"Throne": Vector2i(46, 6),
	"Elite_West": Vector2i(22, 50),
	"Elite_East": Vector2i(68, 50),
	"Chest_West": Vector2i(16, 56),
	"Chest_East": Vector2i(74, 56),
}


func _initialize() -> void:
	var floors := {}
	for room: Rect2i in [
		THRONE_HALL, BONE_GATE, UPPER_CAUSEWAY, WEST_CHAMBER, WEST_LINK,
		EAST_CHAMBER, EAST_LINK, LOWER_CAUSEWAY, ANTECHAMBER,
	]:
		for cell_y: int in range(room.position.y, room.end.y):
			for cell_x: int in range(room.position.x, room.end.x):
				floors[Vector2i(cell_x, cell_y)] = true

	var area := Node2D.new()
	area.name = "AreaThree"
	area.set_script(WORLD_AREA_SCRIPT)

	var tint := CanvasModulate.new()
	tint.name = "HellTint"
	tint.color = HELL_TINT
	_adopt(area, tint)

	var ground := _layer(area, "Ground")
	_paint_floor(ground, floors)
	var walls := _layer(area, "Walls")
	_paint_walls(walls, floors)
	var decor := _layer(area, "Decor")
	_paint_decor(decor, floors)
	_layer(area, "Overhead")

	area.set("ground", ground)
	area.set("music_id", &"field")

	var entrances := Node2D.new()
	entrances.name = "Entrances"
	_adopt(area, entrances)
	var from_two := Marker2D.new()
	from_two.name = "FromAreaTwo"
	from_two.position = _cell_to_world(SPAWN_CELL)
	_adopt(entrances, from_two, area)

	_adopt(area, _named(Node2D.new(), "Actors"))
	_adopt(area, _named(Node2D.new(), "SpawnZones"))

	var exits := Node2D.new()
	exits.name = "Exits"
	_adopt(area, exits)
	var back := AREA_EXIT_SCENE.instantiate()
	back.name = "ToAreaTwo"
	back.position = _cell_to_world(EXIT_CELL)
	_adopt(exits, back, area)

	var start := Marker2D.new()
	start.name = "PlayerStart"
	start.position = _cell_to_world(SPAWN_CELL)
	_adopt(area, start)
	area.set("player_start", start)

	_add_bounds(area)
	_add_markers(area)

	var uid: String = _scene_uid()
	var packed := PackedScene.new()
	if packed.pack(area) != OK:
		push_error("Could not pack Area Three.")
		quit(1)
		return
	var error := ResourceSaver.save(packed, AREA_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [AREA_PATH, error])
		quit(1)
		return
	_restore_uid(uid)
	_write_exit_properties()
	print("Area Three baked: %d floor cells, %d rooms." % [floors.size(), 9])
	quit(0)


## Writes the way back to Area Two onto the saved scene by hand.
##
## `area_exit.gd` reads the GameState autoload, and autoloads are not
## registered for a `-s` script, so the instanced exit's script never compiles
## here and setting its properties in memory does nothing. The scene is text,
## so the three lines are appended to its node block instead.
func _write_exit_properties() -> void:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot reopen %s to write the exit." % AREA_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var marker := "[node name=\"ToAreaTwo\""
	var start: int = text.find(marker)
	if start < 0:
		push_error("No ToAreaTwo node in the baked scene.")
		return
	var line_end: int = text.find("\n", start)
	var properties := (
		"\ntarget_area_path = \"res://areas/area_two.tscn\""
		+ "\ntarget_entrance = &\"FromAreaThree\""
		+ "\nsize_in_cells = Vector2(%d, %d)" % [EXIT_SIZE_IN_CELLS.x, EXIT_SIZE_IN_CELLS.y]
	)
	text = text.insert(line_end, properties)
	file = FileAccess.open(AREA_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s." % AREA_PATH)
		return
	file.store_string(text)
	file.close()


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


## Adds [param child] to [param parent] and gives it an owner, without which
## it is not written into the packed scene.
func _adopt(parent: Node, child: Node, scene_owner: Node = null) -> void:
	parent.add_child(child)
	child.owner = scene_owner if scene_owner != null else parent


func _layer(area: Node2D, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = CATACOMBS_TILESET
	layer.position = MAP_POSITION
	layer.scale = MAP_SCALE
	_adopt(area, layer)
	return layer


func _paint_floor(layer: TileMapLayer, floors: Dictionary) -> void:
	for cell: Vector2i in floors:
		var index: int = posmod(cell.x * 13 + cell.y * 7, FLOOR_TILES.size())
		layer.set_cell(cell, 0, FLOOR_TILES[index])
		if posmod(cell.x * 5 + cell.y * 11, 23) == 0:
			var accent: int = posmod(cell.x + cell.y, FLOOR_ACCENTS.size())
			layer.set_cell(cell, 0, FLOOR_ACCENTS[accent])


func _paint_walls(layer: TileMapLayer, floors: Dictionary) -> void:
	var placed := {}
	for cell: Vector2i in floors:
		for direction: Vector2i in WALLS:
			var wall: Vector2i = cell + direction
			if not floors.has(wall) and not placed.has(wall):
				placed[wall] = true
				layer.set_cell(wall, 0, WALLS[direction])


## The only light in Area Three: torches down the causeway, spikes in the
## gate, and candles ringing the throne.
func _paint_decor(layer: TileMapLayer, floors: Dictionary) -> void:
	for cell_y: int in range(UPPER_CAUSEWAY.position.y, LOWER_CAUSEWAY.end.y, 6):
		for cell_x: int in [40, 52]:
			var cell := Vector2i(cell_x, cell_y)
			if floors.has(cell):
				layer.set_cell(cell, ANIMATED_SOURCE, TORCH)
	for cell_x: int in range(BONE_GATE.position.x, BONE_GATE.end.x):
		if posmod(cell_x, 2) == 1:
			layer.set_cell(Vector2i(cell_x, BONE_GATE.position.y), ANIMATED_SOURCE, SPIKES)
			layer.set_cell(Vector2i(cell_x, BONE_GATE.end.y - 1), ANIMATED_SOURCE, SPIKES)
	# Two rows of candles leading up to the seat, and a ring behind it.
	for cell_y: int in range(THRONE_HALL.position.y + 4, THRONE_HALL.end.y - 2, 4):
		for cell_x: int in [36, 56]:
			layer.set_cell(Vector2i(cell_x, cell_y), ANIMATED_SOURCE, CANDLE_A)
	for cell_x: int in range(38, 56, 4):
		layer.set_cell(Vector2i(cell_x, THRONE_HALL.position.y), ANIMATED_SOURCE, CANDLE_B)
	for corner: Vector2i in [
		THRONE_HALL.position + Vector2i(1, 1),
		Vector2i(THRONE_HALL.end.x - 2, THRONE_HALL.position.y + 1),
		THRONE_HALL.position + Vector2i(1, THRONE_HALL.size.y - 2),
		THRONE_HALL.end - Vector2i(2, 2),
	]:
		layer.set_cell(corner, ANIMATED_SOURCE, TORCH)
	# A guttering light in each guard's chamber, so they are not black holes.
	for chamber: Rect2i in [WEST_CHAMBER, EAST_CHAMBER]:
		layer.set_cell(chamber.position + Vector2i(1, 1), ANIMATED_SOURCE, TORCH)
		layer.set_cell(chamber.end - Vector2i(2, 2), ANIMATED_SOURCE, TORCH)


func _add_markers(area: Node2D) -> void:
	var markers := Node2D.new()
	markers.name = "MapMarkers"
	_adopt(area, markers)
	for marker_name: String in MARKERS:
		var marker := Marker2D.new()
		marker.name = marker_name
		marker.position = _cell_to_world(MARKERS[marker_name])
		_adopt(markers, marker, area)


func _add_bounds(area: Node2D) -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "Bounds"
	_adopt(area, bounds)
	var left: float = MAP_POSITION.x - 24.0
	var right: float = MAP_POSITION.x + MAP_SIZE.x * TILE_SIZE * MAP_SCALE.x + 24.0
	var top: float = MAP_POSITION.y - 24.0
	var bottom: float = MAP_POSITION.y + MAP_SIZE.y * TILE_SIZE * MAP_SCALE.y + 24.0
	var edges := {
		"Top": [Vector2((left + right) / 2.0, top), Vector2(right - left, 48)],
		"Bottom": [Vector2((left + right) / 2.0, bottom), Vector2(right - left, 48)],
		"Left": [Vector2(left, (top + bottom) / 2.0), Vector2(48, bottom - top)],
		"Right": [Vector2(right, (top + bottom) / 2.0), Vector2(48, bottom - top)],
	}
	for edge_name: String in edges:
		var shape := CollisionShape2D.new()
		shape.name = edge_name
		shape.position = edges[edge_name][0]
		var rectangle := RectangleShape2D.new()
		rectangle.size = edges[edge_name][1]
		shape.shape = rectangle
		_adopt(bounds, shape, area)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return MAP_POSITION + (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE * MAP_SCALE


## The `uid="..."` the scene already carries, or a fresh one on a first bake.
## Saving a repacked scene drops it, and anything referring to the area by
## uid:// then resolves to whichever scene the cache saw last.
func _scene_uid() -> String:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file != null:
		var header: String = file.get_line()
		file.close()
		if ' uid="' in header:
			return header.split(' uid="')[1].split('"')[0]
	return ResourceUID.id_to_text(ResourceUID.create_id())


## Writes [param uid] back into the freshly saved scene's header.
func _restore_uid(uid: String) -> void:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if uid.is_empty() or ' uid="' in text.split("\n")[0]:
		return
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="%s"]' % uid)
	file = FileAccess.open(AREA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
