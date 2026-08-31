class_name GridPlayer
extends CharacterBody2D

signal moved

@export var grid_size: int = 48

var facing_direction: Vector2i = Vector2i.DOWN
var movement_enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled or not _is_movement_action_pressed(event):
		return

	var requested_direction: Vector2i = _get_pressed_direction()
	if requested_direction == Vector2i.ZERO:
		return

	get_viewport().set_input_as_handled()
	attempt_grid_move(requested_direction)


func attempt_grid_move(requested_direction: Vector2i) -> bool:
	var direction: Vector2i = Vector2i(
		clampi(requested_direction.x, -1, 1), clampi(requested_direction.y, -1, 1)
	)
	if direction == Vector2i.ZERO:
		return false

	facing_direction = direction
	if _is_diagonal_corner_blocked(direction):
		return false

	var motion: Vector2 = Vector2(direction * grid_size)
	if _is_destination_cell_occupied(motion):
		return false

	global_position += motion
	moved.emit()
	return true


func _is_movement_action_pressed(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"move_up")
		or event.is_action_pressed(&"move_down")
		or event.is_action_pressed(&"move_left")
		or event.is_action_pressed(&"move_right")
	)


func _get_pressed_direction() -> Vector2i:
	var horizontal_direction: int = (
		int(Input.is_action_pressed(&"move_right")) - int(Input.is_action_pressed(&"move_left"))
	)
	var vertical_direction: int = (
		int(Input.is_action_pressed(&"move_down")) - int(Input.is_action_pressed(&"move_up"))
	)
	return Vector2i(horizontal_direction, vertical_direction)


func _is_diagonal_corner_blocked(direction: Vector2i) -> bool:
	if direction.x == 0 or direction.y == 0:
		return false

	var horizontal_motion: Vector2 = Vector2(direction.x * grid_size, 0)
	var vertical_motion: Vector2 = Vector2(0, direction.y * grid_size)
	return (
		_is_destination_cell_occupied(horizontal_motion)
		or _is_destination_cell_occupied(vertical_motion)
	)


func _is_destination_cell_occupied(motion: Vector2) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = global_position + motion
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()
