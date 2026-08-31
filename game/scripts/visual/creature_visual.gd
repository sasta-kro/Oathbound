class_name CreatureVisual
extends Node2D
## Displays a creature, falling back to a labelled placeholder when the species
## has no sprite yet (Specification 23.1).
##
## Gameplay never depends on the sprite existing: this node is the only place
## that decides between real art and a placeholder, and callers drive both the
## same way, through [method play].

signal state_finished(state: StringName)

enum Context { BATTLE, OVERWORLD }

const STATE_IDLE := &"idle"
const STATE_WALK := &"walk"
const STATE_ATTACK := &"attack"
const STATE_HURT := &"hurt"
const STATE_DEATH := &"death"

## States that repeat until another state is requested. Every other state plays
## once and then returns to [constant STATE_IDLE].
const LOOPING_STATES: Array[StringName] = [STATE_IDLE, STATE_WALK]
## States that hold their final frame instead of returning to idle.
const TERMINAL_STATES: Array[StringName] = [STATE_DEATH]

## Placeholder frame counts per state, so a species without art still shows a
## visibly cycling frame counter (Specification 23.3).
const PLACEHOLDER_FRAMES: Dictionary[StringName, int] = {
	STATE_IDLE: 4,
	STATE_WALK: 4,
	STATE_ATTACK: 3,
	STATE_HURT: 2,
	STATE_DEATH: 4,
}
## Placeholder timing per state. Attack runs in roughly the 0.4 s a simple
## attack presentation is budgeted (Specification 11.12).
const PLACEHOLDER_FPS: Dictionary[StringName, float] = {
	STATE_IDLE: 4.0,
	STATE_WALK: 8.0,
	STATE_ATTACK: 7.5,
	STATE_HURT: 6.0,
	STATE_DEATH: 6.0,
}

@export var context: Context = Context.BATTLE
## Placeholder box size used when the species has no sprite.
@export var placeholder_size: Vector2 = Vector2(64, 64)

## Species shown. Assignable from a scene so a room can place a creature
## without code; runtime callers use [method set_species] or
## [method set_creature].
@export var species: CreatureSpecies:
	set(value):
		species = value
		_rebuild()

## The state currently playing. Read-only; change it with [method play].
var state: StringName = STATE_IDLE

var _visual: Node2D


## Shows a live creature.
func set_creature(instance: CreatureInstance) -> void:
	set_species(instance.species if instance != null else null)


## Shows a species directly, for menus such as the bestiary.
func set_species(new_species: CreatureSpecies) -> void:
	species = new_species


## Plays an animation state. One-shot states return to idle on their own and
## report completion through [signal state_finished]. Unknown states fall back
## to idle so a partially animated species still renders.
func play(new_state: StringName) -> void:
	state = new_state
	_apply_state()


## Convenience for the common battle beat: attack once, then idle again.
func play_attack() -> void:
	play(STATE_ATTACK)


func is_using_placeholder() -> bool:
	return _visual is PlaceholderVisual


## The animation actually running, which differs from [member state] when the
## species has no art for the requested state.
func current_animation() -> StringName:
	if _visual is AnimatedSprite2D:
		return (_visual as AnimatedSprite2D).animation
	if _visual is PlaceholderVisual:
		return StringName((_visual as PlaceholderVisual).animation_name)
	return &""


func is_animating() -> bool:
	if _visual is AnimatedSprite2D:
		return (_visual as AnimatedSprite2D).is_playing()
	if _visual is PlaceholderVisual:
		return (_visual as PlaceholderVisual).is_processing()
	return false


## Whether [param candidate] repeats until another state is requested.
static func is_looping_state(candidate: StringName) -> bool:
	return LOOPING_STATES.has(candidate)


func _ready() -> void:
	if _visual == null:
		_rebuild()


func _rebuild() -> void:
	if _visual != null:
		remove_child(_visual)
		_visual.queue_free()
		_visual = null
	if not is_inside_tree():
		return

	var frames := _sprite_frames()
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		sprite.animation_finished.connect(_on_animation_finished)
		_visual = sprite
	else:
		var content_id := String(species.id) if species != null else "creature_missing"
		if species != null:
			DevLog.missing_asset("sprite", species.id)
		var placeholder := PlaceholderVisual.create(content_id, PlaceholderVisual.Category.CREATURE)
		placeholder.size = placeholder_size
		placeholder.finished.connect(_on_animation_finished)
		_visual = placeholder
	add_child(_visual)
	_apply_state()


func _apply_state() -> void:
	if _visual == null:
		return
	var looping := is_looping_state(state)
	if _visual is AnimatedSprite2D:
		var sprite: AnimatedSprite2D = _visual
		var playable := _playable_animation(sprite, state)
		if playable == &"":
			return
		sprite.animation = playable
		sprite.set_frame_and_progress(0, 0.0)
		sprite.play(playable)
	elif _visual is PlaceholderVisual:
		var placeholder: PlaceholderVisual = _visual
		placeholder.animation_name = String(state)
		placeholder.frames_per_second = PLACEHOLDER_FPS.get(state, 4.0)
		placeholder.loops = looping
		placeholder.frame_count = PLACEHOLDER_FRAMES.get(state, 4)


## The animation a species actually has for [param wanted], falling back to
## idle, then to the first animation, then to nothing.
func _playable_animation(sprite: AnimatedSprite2D, wanted: StringName) -> StringName:
	var frames := sprite.sprite_frames
	if frames == null:
		return &""
	if frames.has_animation(wanted):
		return wanted
	if frames.has_animation(STATE_IDLE):
		return STATE_IDLE
	var names := frames.get_animation_names()
	return StringName(names[0]) if names.size() > 0 else &""


func _on_animation_finished() -> void:
	var finished_state := state
	state_finished.emit(finished_state)
	if is_looping_state(finished_state) or TERMINAL_STATES.has(finished_state):
		return
	play(STATE_IDLE)


func _sprite_frames() -> SpriteFrames:
	if species == null:
		return null
	return species.battle_sprite if context == Context.BATTLE else species.overworld_sprite
