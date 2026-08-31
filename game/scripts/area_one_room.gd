class_name AreaOneRoom
extends Node2D

const GRID_SIZE: int = 48
const ROOM_RECTANGLE: Rect2 = Rect2(-552, -312, 1056, 624)


static func cell_to_world(cell: Vector2i) -> Vector2:
	var half_cell: Vector2 = Vector2.ONE * GRID_SIZE / 2.0
	return ROOM_RECTANGLE.position + Vector2(cell * GRID_SIZE) + half_cell


func _draw() -> void:
	draw_rect(ROOM_RECTANGLE, Color("355c3a"))
	_draw_grid()
	_draw_wall_tiles()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-521, -263),
		"AREA 1 PLACEHOLDER ROOM",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color("f4f1dc"),
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-521, -236),
		"WASD: MOVE    E: INTERACT",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("d5e3c5"),
	)


func _draw_grid() -> void:
	var vertical_position: float = ROOM_RECTANGLE.position.x
	while vertical_position <= ROOM_RECTANGLE.end.x:
		draw_line(
			Vector2(vertical_position, ROOM_RECTANGLE.position.y),
			Vector2(vertical_position, ROOM_RECTANGLE.end.y),
			Color("4f794a"),
			1.0,
		)
		vertical_position += GRID_SIZE

	var horizontal_position: float = ROOM_RECTANGLE.position.y
	while horizontal_position <= ROOM_RECTANGLE.end.y:
		draw_line(
			Vector2(ROOM_RECTANGLE.position.x, horizontal_position),
			Vector2(ROOM_RECTANGLE.end.x, horizontal_position),
			Color("4f794a"),
			1.0,
		)
		horizontal_position += GRID_SIZE


func _draw_wall_tiles() -> void:
	draw_rect(Rect2(-552, -312, 1056, 48), Color("786655"))
	draw_rect(Rect2(-552, 264, 1056, 48), Color("786655"))
	draw_rect(Rect2(-552, -312, 48, 624), Color("786655"))
	draw_rect(Rect2(456, -312, 48, 624), Color("786655"))
	draw_rect(Rect2(-120, -24, 240, 48), Color("786655"))
	draw_rect(Rect2(168, 72, 48, 144), Color("786655"))
