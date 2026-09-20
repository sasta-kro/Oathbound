@tool
class_name AltarBeacon
extends Node2D
## The light an altar takes on once its guardian falls.
##
## Map authors drop `scenes/altar_beacon.tscn` on the altar and name the boss
## that keeps it dark. The beacon is unlit while that boss stands, and lights
## itself the moment the boss falls, so the player sees the way open from
## wherever they are standing rather than on the next visit.
##
## The same light stands in the doorways between areas, so a way on and a way
## back read as a way through from across the room. A map can hold several,
## which is why the glow material is local to the scene: shared, the last
## beacon to wake would set every other one's intensity as well.

## Emitted when the altar takes the light, whether it was lit on arrival or
## woke up during the visit.
signal lit

const GROUP := &"altar_beacons"
## How long the light takes to come up after the boss falls. Slow enough to
## read as the altar waking rather than a lamp being switched on.
const WAKE_SECONDS: float = 2.5

## Boss whose defeat lights the altar. Empty for an altar that is always lit.
@export var required_boss: StringName = &""
## Size of the glow in map cells, centred on this node.
@export var size_in_cells := Vector2(5, 6):
	set(value):
		size_in_cells = value
		_apply_size()
## How far above the node's own position the glow's stone sits, in cells. The
## node goes on the altar's middle; the ring belongs on its base.
@export var ground_offset_in_cells: float = 1.0:
	set(value):
		ground_offset_in_cells = value
		_apply_size()

@onready var glow: ColorRect = $Glow

var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	_material = glow.material as ShaderMaterial
	_apply_size()
	if Engine.is_editor_hint():
		_set_intensity(1.0)
		return
	add_to_group(GROUP)
	if is_lit():
		_set_intensity(1.0)
		glow.visible = true
		return
	_set_intensity(0.0)
	glow.visible = false
	GameState.boss_defeated.connect(_on_boss_defeated)


## True once nothing keeps the altar dark any more.
func is_lit() -> bool:
	return required_boss == &"" or GameState.has_defeated_boss(required_boss)


## Brings the light up over [constant WAKE_SECONDS]. Safe to call twice; the
## second call simply finds the altar already lit.
func wake() -> void:
	if _tween != null and _tween.is_valid():
		return
	glow.visible = true
	_tween = create_tween()
	_tween.tween_method(_set_intensity, 0.0, 1.0, WAKE_SECONDS)
	_tween.finished.connect(func() -> void: lit.emit())


func _on_boss_defeated(boss_id: StringName) -> void:
	if boss_id != required_boss:
		return
	wake()


func _set_intensity(value: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("intensity", value)


func _apply_size() -> void:
	if glow == null:
		return
	var size: Vector2 = size_in_cells * WorldArea.GRID_SIZE
	glow.size = size
	# Centred across, and hung so the ring lands on the altar's base.
	glow.position = Vector2(
		-size.x * 0.5, -size.y + ground_offset_in_cells * WorldArea.GRID_SIZE
	)
	var material := glow.material as ShaderMaterial
	if material != null:
		var ground: float = 1.0 - (ground_offset_in_cells * WorldArea.GRID_SIZE) / maxf(size.y, 1.0)
		material.set_shader_parameter("ground_y", clampf(ground, 0.05, 0.95))
