## Rebuilds Area Two directly from the player's plan image. Each 8x8-pixel
## block becomes one map cell, preserving the drawn corridors and dead ends.
extends SceneTree


const AREA_PATH := "res://areas/area_two.tscn"
const PLAN_PATH := "res://temp/area_two_plan.png"
const CATACOMBS_TILESET := preload("res://assets/tilesets/catacombs.tres")
const MAP_SIZE := Vector2i(150, 125)
const PLAN_PIXELS_PER_CELL := 8
const MIN_PLAN_PIXELS := 8
const TILE_SIZE := 48
## The catacombs art is already upscaled to one 48 px tile per cell (see
## `build_catacombs_tileset.gd`), so the layers are drawn 1:1. Scaling them
## again would put the area on a 72 px grid while the rest of the game runs
## on `WorldArea.GRID_SIZE`.
const MAP_SCALE := Vector2(1, 1)
const MAP_POSITION := Vector2(-3600, -3000)

const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(46, 13), Vector2i(47, 13), Vector2i(49, 13), Vector2i(50, 13),
	Vector2i(46, 14), Vector2i(47, 14), Vector2i(49, 14), Vector2i(50, 14),
]
const FLOOR_ACCENTS: Array[Vector2i] = [
	Vector2i(46, 20), Vector2i(47, 20), Vector2i(49, 20), Vector2i(50, 20),
]
const MARKERS := {
	"NPC_1": Vector2i(32, 36),
	"NPC_2": Vector2i(26, 65),
	"NPC_3": Vector2i(87, 28),
	"NPC_4": Vector2i(71, 79),
	"NPC_5": Vector2i(128, 92),
	"Boss": Vector2i(124, 27),
	"Chest_Northwest": Vector2i(20, 9),
	"Chest_Southwest": Vector2i(7, 113),
}
## Where the stair from Area One comes out, and the way back beside it. The
## exit sits clear of the arrival marker, or the player would bounce back up.
const SPAWN_CELL := Vector2i(24, 51)
const EXIT_CELL := Vector2i(21, 51)
## Where the stair down from Area Three comes back out: the cell the area's
## boss holds, so returning lands where he fell.
const FROM_AREA_THREE_CELL := Vector2i(124, 27)
const EXIT_SIZE_IN_CELLS := Vector2(3, 4)


func _initialize() -> void:
	var plan := Image.load_from_file(ProjectSettings.globalize_path(PLAN_PATH))
	if plan == null or plan.is_empty():
		push_error("Could not load Area Two plan: %s" % PLAN_PATH)
		quit(1)
		return
	if plan.get_size() != MAP_SIZE * PLAN_PIXELS_PER_CELL:
		push_error("Area Two plan must be 1200x1000 pixels; got %s" % plan.get_size())
		quit(1)
		return

	var floors := _read_walkable_cells(plan)
	var component_count := _count_components(floors)
	if component_count != 1:
		push_error("Plan produced %d disconnected walkable regions; refusing to save" % component_count)
		quit(1)
		return

	var packed_scene := load(AREA_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load %s" % AREA_PATH)
		quit(1)
		return
	var area := packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	area.name = "AreaTwo"

	var maps := _prepare_tile_layers(area)
	_paint_floor(maps["Ground"], floors)
	_paint_floor_accents(maps["Path"], floors)
	_paint_walls(maps["Walls"], floors)
	_paint_decor(maps["Decor"], floors)

	_clear_children(area.get_node("Actors"))
	_clear_children(area.get_node("SpawnZones"))
	_place_markers(area, maps["Ground"], floors)
	_set_entry_and_bounds(area, maps["Ground"], floors)

	var rebuilt := PackedScene.new()
	var error := rebuilt.pack(area)
	if error == OK:
		error = ResourceSaver.save(rebuilt, AREA_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [AREA_PATH, error])
	else:
		print("Area Two rebuilt: %d walkable cells, %d connected region, 150x125 plan grid" % [floors.size(), component_count])
	area.queue_free()
	quit(0 if error == OK else 1)


func _prepare_tile_layers(area: Node2D) -> Dictionary:
	var result := {}
	for layer_name: String in ["Ground", "Path", "Water", "Road", "Walls", "Foliage", "Decor", "Overhead"]:
		var layer := area.get_node(layer_name) as TileMapLayer
		layer.clear()
		layer.tile_set = CATACOMBS_TILESET
		layer.position = MAP_POSITION
		layer.scale = MAP_SCALE
		layer.z_index = -1 if layer_name == "Ground" else 0
		result[layer_name] = layer
	return result


func _read_walkable_cells(plan: Image) -> Dictionary:
	var cells := {}
	for cell_y: int in range(MAP_SIZE.y):
		for cell_x: int in range(MAP_SIZE.x):
			var plan_pixel_count := 0
			for pixel_y: int in range(PLAN_PIXELS_PER_CELL):
				for pixel_x: int in range(PLAN_PIXELS_PER_CELL):
					var image_x := cell_x * PLAN_PIXELS_PER_CELL + pixel_x
					var image_y := cell_y * PLAN_PIXELS_PER_CELL + pixel_y
					if _is_plan_pixel(plan.get_pixel(image_x, image_y)):
						plan_pixel_count += 1
			if plan_pixel_count >= MIN_PLAN_PIXELS:
				cells[Vector2i(cell_x, cell_y)] = true
	return cells


func _is_plan_pixel(color: Color) -> bool:
	# The source drawing uses a black background and solid gray/marker colors.
	# Treating every non-black pixel as walkable preserves gray hidden by labels.
	return color.r > 0.15 or color.g > 0.15 or color.b > 0.15


func _paint_floor(layer: TileMapLayer, floors: Dictionary) -> void:
	for cell: Vector2i in floors:
		var tile_index: int = posmod(cell.x * 13 + cell.y * 7, FLOOR_TILES.size())
		layer.set_cell(cell, 0, FLOOR_TILES[tile_index])


func _paint_floor_accents(layer: TileMapLayer, floors: Dictionary) -> void:
	for cell: Vector2i in floors:
		if posmod(cell.x * 5 + cell.y * 11, 29) == 0:
			var tile_index: int = posmod(cell.x + cell.y, FLOOR_ACCENTS.size())
			layer.set_cell(cell, 0, FLOOR_ACCENTS[tile_index])


func _paint_walls(layer: TileMapLayer, floors: Dictionary) -> void:
	var wall_cells := {}
	var directions := {
		Vector2i.UP: Vector2i(8, 1),
		Vector2i.DOWN: Vector2i(11, 1),
		Vector2i.LEFT: Vector2i(3, 4),
		Vector2i.RIGHT: Vector2i(16, 4),
	}
	for cell: Vector2i in floors:
		for direction: Vector2i in directions:
			var wall_cell := cell + direction
			if not floors.has(wall_cell) and not wall_cells.has(wall_cell):
				wall_cells[wall_cell] = true
				layer.set_cell(wall_cell, 0, directions[direction])


func _paint_decor(layer: TileMapLayer, floors: Dictionary) -> void:
	# Sparse lights only; these add no collision and cannot create routes.
	for requested_cell: Vector2i in [
		Vector2i(30, 19), Vector2i(55, 13), Vector2i(87, 29),
		Vector2i(71, 78), Vector2i(111, 67), Vector2i(128, 91),
	]:
		var cell := _nearest_floor_cell(requested_cell, floors)
		layer.set_cell(cell, 2, Vector2i(0, 0))


func _place_markers(area: Node2D, layer: TileMapLayer, floors: Dictionary) -> void:
	var markers := area.get_node_or_null("MapMarkers") as Node2D
	if markers == null:
		markers = Node2D.new()
		markers.name = "MapMarkers"
		area.add_child(markers)
		markers.owner = area
	_clear_children(markers)
	for marker_name: String in MARKERS:
		var marker := Marker2D.new()
		marker.name = marker_name
		var cell := _nearest_floor_cell(MARKERS[marker_name], floors)
		marker.position = _cell_to_world(layer, cell)
		markers.add_child(marker)
		marker.owner = area


func _set_entry_and_bounds(area: Node2D, layer: TileMapLayer, floors: Dictionary) -> void:
	var entry_cell := _nearest_floor_cell(SPAWN_CELL, floors)
	var entry_position := _cell_to_world(layer, entry_cell)
	(area.get_node("PlayerStart") as Marker2D).position = entry_position
	(area.get_node("Entrances/FromAreaOne") as Marker2D).position = entry_position
	var from_three := area.get_node_or_null("Entrances/FromAreaThree") as Marker2D
	if from_three == null:
		from_three = Marker2D.new()
		from_three.name = "FromAreaThree"
		var entrances: Node = area.get_node("Entrances")
		entrances.add_child(from_three)
		from_three.owner = area
	from_three.position = _cell_to_world(layer, _nearest_floor_cell(FROM_AREA_THREE_CELL, floors))
	var exit := area.get_node("Exits/ToAreaOne") as Node2D
	exit.position = _cell_to_world(layer, _nearest_floor_cell(EXIT_CELL, floors))
	exit.set("size_in_cells", EXIT_SIZE_IN_CELLS)

	var left := MAP_POSITION.x - 24.0
	var right := MAP_POSITION.x + MAP_SIZE.x * TILE_SIZE * MAP_SCALE.x + 24.0
	var top := MAP_POSITION.y - 24.0
	var bottom := MAP_POSITION.y + MAP_SIZE.y * TILE_SIZE * MAP_SCALE.y + 24.0
	_set_bound(area.get_node("Bounds/Top") as CollisionShape2D, Vector2((left + right) / 2.0, top), Vector2(right - left, 48))
	_set_bound(area.get_node("Bounds/Bottom") as CollisionShape2D, Vector2((left + right) / 2.0, bottom), Vector2(right - left, 48))
	_set_bound(area.get_node("Bounds/Left") as CollisionShape2D, Vector2(left, (top + bottom) / 2.0), Vector2(48, bottom - top))
	_set_bound(area.get_node("Bounds/Right") as CollisionShape2D, Vector2(right, (top + bottom) / 2.0), Vector2(48, bottom - top))


func _nearest_floor_cell(requested: Vector2i, floors: Dictionary) -> Vector2i:
	if floors.has(requested):
		return requested
	for radius: int in range(1, 16):
		for y: int in range(requested.y - radius, requested.y + radius + 1):
			for x: int in range(requested.x - radius, requested.x + radius + 1):
				var candidate := Vector2i(x, y)
				if floors.has(candidate):
					return candidate
	push_error("No walkable cell near %s" % requested)
	return requested


func _count_components(floors: Dictionary) -> int:
	var unseen := floors.duplicate()
	var component_count := 0
	while not unseen.is_empty():
		component_count += 1
		var start: Vector2i = unseen.keys()[0]
		var frontier: Array[Vector2i] = [start]
		unseen.erase(start)
		while not frontier.is_empty():
			var cell: Vector2i = frontier.pop_back()
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = cell + direction
				if unseen.erase(neighbor):
					frontier.push_back(neighbor)
	return component_count


func _set_bound(collision: CollisionShape2D, position_value: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_value


func _cell_to_world(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	return layer.position + layer.scale * layer.map_to_local(cell)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()
