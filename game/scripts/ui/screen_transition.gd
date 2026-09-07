class_name ScreenTransition
extends CanvasLayer
## Full-screen wipe played whenever the game moves between the overworld and
## the battle screen.
##
## The transition is deliberately two halves rather than one animation: the
## caller [method cover]s the screen, swaps whatever is underneath while
## nothing is visible, then [method reveal]s it again. Both halves are
## awaitable, so the swap reads as a single move even though two different
## nodes own the two screens.
##
## Nothing here knows about battles. [enum Style] only picks the colour and
## whether the cover opens with the encounter flashes.

## Emitted once the screen is fully covered.
signal covered
## Emitted once the screen is clear again.
signal revealed

## What the transition is moving into. Battles announce themselves with a few
## quick flashes first; returning to the overworld does not.
enum Style { WORLD, BATTLE }

const COVER_SECONDS := 0.45
const REVEAL_SECONDS := 0.35
## One flash is this long on and this long off again.
const FLASH_SECONDS := 0.07
const FLASH_COUNT := 3

const WORLD_COLOR := Color("0f131a")
const BATTLE_COLOR := Color("120d16")
const FLASH_COLOR := Color(1.0, 0.97, 0.9, 0.9)

const PROGRESS_PARAMETER := &"progress"
const FILL_COLOR_PARAMETER := &"fill_color"

## Skips every wait and tween so a test can drive a transition synchronously.
var instant: bool = false

var _playing: bool = false
var _progress: float = 0.0

@onready var root: Control = $Root
@onready var wipe: ColorRect = $Root/Wipe
@onready var flash: ColorRect = $Root/Flash


func _ready() -> void:
	root.hide()
	flash.hide()
	_set_progress(0.0)


## True while the transition owns the screen, either because it is animating or
## because it is holding a covered screen between the two halves. Callers use
## this to keep the world frozen for the whole swap.
func is_busy() -> bool:
	return _playing or root.visible


## Fills the screen. Returns once nothing underneath is visible.
func cover(style: Style = Style.WORLD) -> void:
	_playing = true
	_set_fill_color(style)
	_set_progress(0.0)
	root.show()
	if style == Style.BATTLE:
		await _play_flashes()
	await _tween_progress(1.0, COVER_SECONDS)
	_playing = false
	covered.emit()


## Clears the screen again. Returns once the wipe is gone.
func reveal(style: Style = Style.WORLD) -> void:
	_playing = true
	_set_fill_color(style)
	_set_progress(1.0)
	root.show()
	await _tween_progress(0.0, REVEAL_SECONDS)
	root.hide()
	_playing = false
	revealed.emit()


func _set_fill_color(style: Style) -> void:
	var color: Color = BATTLE_COLOR if style == Style.BATTLE else WORLD_COLOR
	_shader().set_shader_parameter(FILL_COLOR_PARAMETER, color)


func _set_progress(value: float) -> void:
	_progress = value
	_shader().set_shader_parameter(PROGRESS_PARAMETER, value)


func _tween_progress(target: float, seconds: float) -> void:
	if instant or not is_inside_tree():
		_set_progress(target)
		return
	var tween := create_tween()
	tween.tween_method(_set_progress, _progress, target, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished


## The short burst that announces an encounter. Purely presentation: skipping
## it changes nothing but the look.
func _play_flashes() -> void:
	if instant or not is_inside_tree():
		return
	flash.color = FLASH_COLOR
	for _index: int in FLASH_COUNT:
		flash.show()
		await get_tree().create_timer(FLASH_SECONDS).timeout
		flash.hide()
		await get_tree().create_timer(FLASH_SECONDS).timeout


func _shader() -> ShaderMaterial:
	return wipe.material as ShaderMaterial
