class_name Player
extends CharacterBody2D

## Emitted after every physics step in which the player actually moved.
signal moved

const GROUP := &"player"
const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"

## Pixels per second at full stick deflection.
@export var move_speed: float = 240.0
## Grid cell size, kept for callers that reason about tiles.
@export var grid_size: int = 48

var facing_direction: Vector2i = Vector2i.DOWN
var movement_enabled: bool = true

## Optional: the hero art. Movement works without it.
@onready var sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(GROUP)
	_animate(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Vector2.ZERO
	if movement_enabled:
		input_direction = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
	move_with(input_direction)


## Moves the player for one physics step in `direction` (any length up to 1)
## and returns whether it actually changed position.
func move_with(direction: Vector2) -> bool:
	direction = direction.limit_length(1.0)
	if direction != Vector2.ZERO:
		facing_direction = _facing_from(direction)

	var position_before: Vector2 = global_position
	velocity = direction * move_speed
	move_and_slide()
	_animate(direction)

	if global_position.is_equal_approx(position_before):
		return false
	moved.emit()
	return true


## Snaps an analog direction to one of the eight compass directions.
func _facing_from(direction: Vector2) -> Vector2i:
	var x: int = 0
	var y: int = 0
	if abs(direction.x) > abs(direction.y) * 0.5:
		x = 1 if direction.x > 0.0 else -1
	if abs(direction.y) > abs(direction.x) * 0.5:
		y = 1 if direction.y > 0.0 else -1
	return Vector2i(x, y)


## The hero sheet is side-view art, so it only mirrors on horizontal input and
## keeps its last facing while walking straight up or down.
func _animate(direction: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var wanted: StringName = ANIMATION_WALK if direction != Vector2.ZERO else ANIMATION_IDLE
	if sprite.sprite_frames.has_animation(wanted) and sprite.animation != wanted:
		sprite.play(wanted)
	elif not sprite.is_playing():
		sprite.play()
	if absf(direction.x) > 0.01:
		sprite.flip_h = direction.x < 0.0
