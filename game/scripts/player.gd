class_name Player
extends CharacterBody2D

## Emitted after every physics step in which the player actually moved.
signal moved

const GROUP := &"player"
const ANIMATION_IDLE := &"idle"
const ANIMATION_WALK := &"walk"

## The hero sheet has one row per compass direction, so every animation is
## named `<idle|walk>_<facing>`. Diagonals borrow the row of their dominant
## axis, which keeps eight-way movement on four rows of art.
const FACING_SUFFIXES := {
	Vector2i.DOWN: &"down",
	Vector2i.UP: &"up",
	Vector2i.LEFT: &"left",
	Vector2i.RIGHT: &"right",
}

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


## Plays the walk or idle row that matches the way the player is facing.
func _animate(direction: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var prefix: StringName = ANIMATION_WALK if direction != Vector2.ZERO else ANIMATION_IDLE
	var wanted: StringName = StringName("%s_%s" % [prefix, _facing_suffix()])
	if not sprite.sprite_frames.has_animation(wanted):
		return
	if sprite.animation != wanted:
		sprite.play(wanted)
	elif not sprite.is_playing():
		sprite.play()


## The animation row for the current facing. Diagonals resolve to their
## horizontal row, because the side views read more clearly than the front and
## back ones.
func _facing_suffix() -> StringName:
	var row: Vector2i = facing_direction
	if row.x != 0:
		row = Vector2i(row.x, 0)
	elif row.y == 0:
		row = Vector2i.DOWN
	else:
		row = Vector2i(0, row.y)
	return FACING_SUFFIXES[row]
