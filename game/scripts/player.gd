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

## How far a strike reaches, in cells, measured centre to centre. Creatures
## are drawn larger than the 40 px box they actually occupy, so this is set
## well past the distance at which the two sprites look like they touch:
## a strike that visibly connects has to land.
const STRIKE_REACH_IN_CELLS: float = 2.4
## Half-width of the strike wedge, 75 degrees, so a strike sweeps the 150
## degrees the player faces. Facing snaps to eight directions while creatures
## stand anywhere, so the wedge has to be wider than the gap between two
## facings for aiming to feel fair.
const STRIKE_HALF_ANGLE: float = PI * 5.0 / 12.0
## Anything this close, in cells, is hit whichever way the player is facing.
## A creature standing on top of the player must never be missable, and facing
## only updates while walking, so it is easy to be turned the wrong way.
const POINT_BLANK_IN_CELLS: float = 1.25
## Seconds before the player can swing again. Provisional balance value.
const STRIKE_COOLDOWN_SECONDS: float = 0.45

## Pixels per second at full stick deflection.
@export var move_speed: float = 240.0
## Grid cell size, kept for callers that reason about tiles.
@export var grid_size: int = 48

var facing_direction: Vector2i = Vector2i.DOWN
var movement_enabled: bool = true
## Cleared alongside movement while a menu, dialogue or battle is on screen.
var strike_enabled: bool = true

var _strike_cooldown_left: float = 0.0

## Optional: the hero art. Movement works without it.
@onready var sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(GROUP)
	_animate(Vector2.ZERO)


func _physics_process(delta: float) -> void:
	_strike_cooldown_left = maxf(0.0, _strike_cooldown_left - delta)
	var input_direction: Vector2 = Vector2.ZERO
	if movement_enabled:
		input_direction = Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
	move_with(input_direction)


## Turns the player without moving it, as when a saved journey resumes.
func face(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	facing_direction = direction
	_animate(Vector2.ZERO)


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


# --- Striking (Specification 7.3, extended) ----------------------------------
#
# The player owns only where and how often a strike reaches. Who throws it and
# what it does to the target belong to the party, so they live in the
# overworld scene and in [OverworldStrike].


func can_strike() -> bool:
	return strike_enabled and _strike_cooldown_left <= 0.0


## Starts a strike, putting it on cooldown. Returns false when the previous
## one has not finished cooling down, so a caller can tell a real strike from
## a dropped key press.
func strike() -> bool:
	if not can_strike():
		return false
	_strike_cooldown_left = STRIKE_COOLDOWN_SECONDS
	return true


## Unit vector the player would strike along.
func strike_direction() -> Vector2:
	return Vector2(facing_direction).normalized()


func strike_reach() -> float:
	return STRIKE_REACH_IN_CELLS * float(grid_size)


## Radius inside which facing stops mattering.
func point_blank_reach() -> float:
	return POINT_BLANK_IN_CELLS * float(grid_size)


## Whether a point in world space lies inside the wedge a strike covers.
func strike_covers(point: Vector2) -> bool:
	var offset: Vector2 = point - global_position
	var distance: float = offset.length()
	if distance > strike_reach():
		return false
	if distance <= point_blank_reach():
		return true
	return absf(strike_direction().angle_to(offset)) <= STRIKE_HALF_ANGLE


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
