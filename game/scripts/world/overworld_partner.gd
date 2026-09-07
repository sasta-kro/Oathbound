class_name OverworldPartner
extends Node2D
## The Oathbound at the front of the party, walking the overworld at the
## player's heel and throwing the overworld strike (Specification 7.3,
## extended).
##
## The knight never swings at anything: the lead creature does the fighting
## out here exactly as it does in a battle, which is why the damage comes from
## that creature's own best move. So it has to be somewhere before the strike
## rather than appearing for it, and this node is where it lives.
##
## It follows a breadcrumb trail of places the player has actually stood
## rather than steering straight at them. That costs nothing, keeps the
## partner out of the player's way in a corridor, and means it can never cut a
## corner through a wall despite having no collision of its own.

## Distance between recorded breadcrumbs. Shorter is a smoother path and a
## longer trail to keep.
const BREADCRUMB_SPACING: float = 12.0
## How far behind the player the partner walks, in cells.
const FOLLOW_DISTANCE_IN_CELLS: float = 1.1
## Close enough to the current breadcrumb to count as standing still.
const ARRIVE_DISTANCE: float = 2.0
## The partner runs a little faster than the player so it can close a gap it
## has fallen into, but never so fast that it overruns the trail.
const CATCH_UP_SPEED_SCALE: float = 1.35
## Beyond this the partner has been left behind by something other than
## walking, such as a battle or a new area, and simply reappears at the
## player's side.
const SNAP_DISTANCE: float = 320.0

## The strike: a dash in, a beat on the target, then back to following.
const STRIKE_DASH_SECONDS: float = 0.12
const STRIKE_HOLD_SECONDS: float = 0.16
## How far short of the struck point the partner pulls up, so it lands next to
## its target rather than inside it.
const STRIKE_STANDOFF: float = 24.0

@onready var visual: CreatureVisual = $CreatureVisual

## Cleared along with the player's movement while a menu, dialogue or battle
## is on screen.
var following_enabled: bool = true

var _creature: CreatureInstance
var _trail: PackedVector2Array = PackedVector2Array()
var _striking: bool = false
var _strike_tween: Tween
var _player: Player


func _ready() -> void:
	GameState.party_changed.connect(refresh_lead)
	refresh_lead()


func _physics_process(delta: float) -> void:
	var player: Player = _find_player()
	if player == null or _creature == null:
		return
	_record_breadcrumb(player.global_position)
	if _striking or not following_enabled:
		return
	_follow(player, delta)


## True while the partner is committed to a strike and not following.
func is_striking() -> bool:
	return _striking


## The creature currently walking with the player, or null when the party has
## nobody able to fight.
func creature() -> CreatureInstance:
	return _creature


## Sends the partner at [param point]: it dashes in, plays its attack, holds
## for a beat and then falls back into following. Awaitable, so a caller that
## wants the blow to look like it landed first can wait for it.
func strike_toward(point: Vector2) -> void:
	if _creature == null or not visible:
		return
	if _strike_tween != null and _strike_tween.is_valid():
		_strike_tween.kill()
	var approach: Vector2 = point - global_position
	if not approach.is_zero_approx():
		visual.flip_h = approach.x < 0.0
	visual.play_attack()
	_striking = true
	if not is_inside_tree():
		_striking = false
		return

	var landing: Vector2 = point
	if approach.length() > STRIKE_STANDOFF:
		landing = point - approach.normalized() * STRIKE_STANDOFF
	_strike_tween = create_tween()
	(
		_strike_tween
		. tween_property(self, "global_position", landing, STRIKE_DASH_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_strike_tween.tween_interval(STRIKE_HOLD_SECONDS)
	await _strike_tween.finished
	_striking = false


## Puts the partner back at the player's side without walking there, for a
## teleport, a new area or the far side of a battle.
func snap_to_player() -> void:
	var player: Player = _find_player()
	if player == null:
		return
	_trail.clear()
	global_position = player.global_position
	if _creature != null:
		visual.play(CreatureVisual.STATE_IDLE)


## Picks up whichever creature now leads the party. A wiped party has no lead,
## and the partner leaves the map until something can fight again.
##
## Battle damage changes who leads without going through the party itself, so
## the overworld calls this again on the way out of a battle.
func refresh_lead() -> void:
	var lead: CreatureInstance = GameState.lead_creature()
	var changed: bool = lead != _creature
	_creature = lead
	# Visibility is set every time rather than only on a change, so a party
	# that could never fight in the first place still leaves the map empty.
	visible = _creature != null
	if not visible or not changed:
		return
	visual.set_creature(_creature)
	visual.play(CreatureVisual.STATE_IDLE)
	if _trail.is_empty():
		snap_to_player()


func _record_breadcrumb(player_position: Vector2) -> void:
	if _trail.is_empty():
		_trail.append(player_position)
		return
	if player_position.distance_to(_trail[_trail.size() - 1]) < BREADCRUMB_SPACING:
		return
	_trail.append(player_position)
	# Only the tail of the path matters: everything older than the follow
	# distance has already been walked and can be dropped.
	while _trail.size() > _breadcrumbs_to_keep():
		_trail.remove_at(0)


## How many breadcrumbs make up the gap the partner keeps.
func _breadcrumbs_to_keep() -> int:
	return maxi(1, int(ceil(FOLLOW_DISTANCE_IN_CELLS * WorldArea.GRID_SIZE / BREADCRUMB_SPACING)))


func _follow(player: Player, delta: float) -> void:
	if global_position.distance_to(player.global_position) > SNAP_DISTANCE:
		snap_to_player()
		return
	# The oldest breadcrumb is the far end of the gap, so walking to it keeps
	# the partner exactly that far behind.
	var target: Vector2 = _trail[0]
	var distance: float = global_position.distance_to(target)
	if distance <= ARRIVE_DISTANCE:
		_animate(false, 0.0)
		return
	var speed: float = player.move_speed * CATCH_UP_SPEED_SCALE
	var before: Vector2 = global_position
	global_position = global_position.move_toward(target, speed * delta)
	_animate(true, global_position.x - before.x)


func _animate(moving: bool, horizontal_movement: float) -> void:
	var wanted: StringName = CreatureVisual.STATE_WALK if moving else CreatureVisual.STATE_IDLE
	if visual.state != wanted:
		visual.play(wanted)
	if moving and absf(horizontal_movement) > 0.01:
		visual.flip_h = horizontal_movement < 0.0


func _find_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	return _player
