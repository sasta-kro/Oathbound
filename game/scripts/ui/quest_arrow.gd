class_name QuestArrow
extends Control
## The chevron that orbits the player and points at whoever is waiting for
## them (see [QuestCompass]).
##
## It draws itself rather than wearing a texture, so it costs nothing and
## turns cleanly at any angle. [method point_along] is given a direction in
## screen space and a name to caption; the field HUD places it, so this knows
## nothing about the world.

## How far from the player the chevron rides, in pixels.
const ORBIT_RADIUS: float = 64.0
## Half the width of the chevron, across the direction it points.
const HALF_WIDTH: float = 9.0
## How far the chevron reaches along the direction it points.
const REACH: float = 13.0
## How deep the notch in its tail is cut.
const NOTCH: float = 5.0
## The slow breath in and out, so it reads as a hint rather than an alarm.
const PULSE_SECONDS: float = 1.1
const PULSE_ALPHA: Vector2 = Vector2(0.55, 1.0)

var facing: Vector2 = Vector2.RIGHT
var _label: Label
var _pulse: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = OathTheme.label("", 9, OathTheme.GOLD)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	hide()


## Points the chevron along [param direction] from [param player_position],
## both in screen space, captioning it with [param caption].
func point_along(player_position: Vector2, direction: Vector2, caption: String) -> void:
	if direction.is_zero_approx():
		hide()
		return
	facing = direction.normalized()
	position = player_position + facing * ORBIT_RADIUS
	_label.text = caption
	_label.size = Vector2(160, 14)
	_label.position = Vector2(-80, REACH + 4)
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = fposmod(_pulse + delta, PULSE_SECONDS)
	var breath: float = 0.5 - 0.5 * cos(TAU * _pulse / PULSE_SECONDS)
	modulate.a = lerpf(PULSE_ALPHA.x, PULSE_ALPHA.y, breath)


func _draw() -> void:
	var across: Vector2 = facing.orthogonal()
	var points := PackedVector2Array([
		facing * REACH,
		across * HALF_WIDTH - facing * NOTCH,
		Vector2.ZERO,
		-across * HALF_WIDTH - facing * NOTCH,
	])
	draw_colored_polygon(points, OathTheme.GOLD)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0, 0, 0, 0.55), 1.5)
