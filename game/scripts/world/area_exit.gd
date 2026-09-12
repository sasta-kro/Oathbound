@tool
class_name AreaExit
extends Area2D
## A doorway out of an area.
##
## Map authors drop `scenes/area_exit.tscn` where the player leaves the map,
## point it at the next area's scene and name the entrance marker to arrive
## at. The main scene listens for [signal player_entered] and swaps the area.
##
## The rectangle is drawn in the editor so the trigger is visible while
## painting. Arrive markers should sit outside every exit of their own area,
## or the player would bounce straight back.

signal player_entered(exit: AreaExit)

const GROUP := &"area_exits"
const EDITOR_COLOR := Color(0.95, 0.75, 0.2, 0.35)
const EDITOR_LABEL_SIZE: int = 14

## Scene of the area this exit leads to. A path rather than a PackedScene so
## two areas can point at each other without a circular resource load.
@export_file("*.tscn") var target_area_path: String = ""
## Name of the marker under the target area's `Entrances` node to appear at.
@export var target_entrance: StringName = &""
## Size of the trigger in map cells.
@export var size_in_cells: Vector2 = Vector2(3, 2):
	set(value):
		size_in_cells = value
		_apply_size()
		queue_redraw()


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_entered.emit(self)


func size_in_pixels() -> Vector2:
	return size_in_cells * WorldArea.GRID_SIZE


## Each instance gets its own shape, so resizing one exit in the editor does
## not resize every other exit sharing the scene's shape resource.
func _apply_size() -> void:
	var collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D")
	if collision == null:
		return
	var rectangle := RectangleShape2D.new()
	rectangle.size = size_in_pixels()
	collision.shape = rectangle


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var size: Vector2 = size_in_pixels()
	draw_rect(Rect2(-size / 2.0, size), EDITOR_COLOR, true)
	draw_rect(Rect2(-size / 2.0, size), EDITOR_COLOR.lightened(0.3), false, 2.0)
	var label: String = "-> %s" % target_area_path.get_file().get_basename()
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-size.x / 2.0 + 4.0, -size.y / 2.0 - 4.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		EDITOR_LABEL_SIZE,
	)
