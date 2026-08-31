class_name GridPlayer
extends CharacterBody2D

signal moved

@export var grid_size: int = 48

var facing_direction: Vector2i = Vector2i.DOWN
var movement_enabled: bool = true


func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled:
		return

	var requested_direction: Vector2i = _get_requested_direction(event)
	if requested_direction == Vector2i.ZERO:
		return

	facing_direction = requested_direction
	move_and_collide(Vector2(requested_direction * grid_size))
	moved.emit()


func _get_requested_direction(event: InputEvent) -> Vector2i:
	if event.is_action_pressed(&"move_up"):
		return Vector2i.UP
	if event.is_action_pressed(&"move_down"):
		return Vector2i.DOWN
	if event.is_action_pressed(&"move_left"):
		return Vector2i.LEFT
	if event.is_action_pressed(&"move_right"):
		return Vector2i.RIGHT
	return Vector2i.ZERO
