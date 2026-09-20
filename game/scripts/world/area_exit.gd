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
##
## In the game the exit signs itself: a name plate over the doorway and
## chevrons on the ground pointing the way out, dimmed and marked SEALED
## while a boss still holds the way. [member signpost] turns the sign off for
## an exit that is scenery in its own right, such as Area One's altar.

signal player_entered(exit: AreaExit)

const GROUP := &"area_exits"
const EDITOR_COLOR := Color(0.95, 0.75, 0.2, 0.35)
const EDITOR_LABEL_SIZE: int = 14
const LOCKED_EDITOR_COLOR := Color(0.75, 0.25, 0.3, 0.35)
const DEFAULT_LOCKED_LINE := "The way is sealed."

## The in-game sign: gold for a way that is open, dull red for a sealed one.
const SIGN_COLOR := Color(0.98, 0.85, 0.45)
const SIGN_LOCKED_COLOR := Color(0.85, 0.45, 0.45)
const SIGN_OUTLINE := Color(0.04, 0.05, 0.08, 0.85)
const SIGN_FONT_SIZE: int = 15
const SIGN_OUTLINE_SIZE: int = 5
const SEALED_SUFFIX := "  (SEALED)"
## How far over the middle of the trigger the plate floats, and how far it
## rises and falls.
const SIGN_HEIGHT: float = 46.0
const SIGN_BOB: float = 5.0
const SIGN_BOB_SECONDS: float = 1.9
## The chevrons on the ground: how many, how far apart and how big.
const CHEVRON_COUNT: int = 3
const CHEVRON_SPACING: float = 13.0
const CHEVRON_HALF_WIDTH: float = 11.0
const CHEVRON_DEPTH: float = 7.0
const CHEVRON_THICKNESS: float = 3.0
## One full crawl of the chevrons towards the doorway.
const CHEVRON_SECONDS: float = 1.4

## Scene of the area this exit leads to. A path rather than a PackedScene so
## two areas can point at each other without a circular resource load.
@export_file("*.tscn") var target_area_path: String = ""
## Name of the marker under the target area's `Entrances` node to appear at.
@export var target_entrance: StringName = &""
## Boss that must fall before this exit opens. Empty for a way that is open
## from the start (Specification 19).
@export var required_boss: StringName = &""
## Quest that must be finished before this exit opens, on top of [member
## required_boss]. A boss that falls out in the field is not the same as a
## boss reported back to the person who sent you, and the story only moves on
## the report, so the way stays shut until the quest is turned in.
@export var required_quest: StringName = &""
## What the player is told when they walk into the exit while it is still
## sealed. Empty falls back to [constant DEFAULT_LOCKED_LINE].
@export_multiline var locked_line: String = ""
## What the player is told once the boss is down but [member required_quest]
## has not been turned in yet, which is the moment they need pointing at the
## quest giver rather than at the boss. Empty falls back to [member
## locked_line].
@export_multiline var unreported_line: String = ""
## Whether the exit carries a name plate and chevrons in the game. Off for a
## way the map already announces on its own.
@export var signpost: bool = true
## What the plate reads. Empty falls back to the target scene's file name,
## so "res://areas/area_one.tscn" signs itself AREA ONE.
@export var signpost_text: String = ""
## Which way the chevrons crawl. ZERO points them away from the middle of the
## map, which is the way out of it.
@export var signpost_direction: Vector2i = Vector2i.ZERO
## Size of the trigger in map cells.
@export var size_in_cells: Vector2 = Vector2(3, 2):
	set(value):
		size_in_cells = value
		_apply_size()
		queue_redraw()


var _sign: Label
var _chevron_phase: float = 0.0
var _chevron_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	if signpost:
		_raise_signpost()
		# The plate stops saying SEALED the moment the way opens, without the
		# player having to leave and come back: when the boss holding it
		# falls, and again when the quest holding it is turned in.
		GameState.boss_defeated.connect(refresh_signpost.unbind(1))
		GameState.quest_changed.connect(refresh_signpost.unbind(2))
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_chevron_phase = fmod(_chevron_phase + delta / CHEVRON_SECONDS, 1.0)
	queue_redraw()


## Builds the name plate and works out which way the chevrons crawl. The
## direction comes from the area's painted ground: an exit sits at its edge,
## so pointing away from the middle points out of the map.
func _raise_signpost() -> void:
	_chevron_direction = Vector2(signpost_direction)
	if _chevron_direction == Vector2.ZERO:
		var area: WorldArea = _area()
		if area != null:
			var middle: Vector2 = area.bounds().get_center()
			var offset: Vector2 = global_position - middle
			if absf(offset.x) >= absf(offset.y):
				_chevron_direction = Vector2.RIGHT if offset.x >= 0.0 else Vector2.LEFT
			else:
				_chevron_direction = Vector2.DOWN if offset.y >= 0.0 else Vector2.UP
	if _chevron_direction == Vector2.ZERO:
		_chevron_direction = Vector2.DOWN
	_chevron_direction = _chevron_direction.normalized()

	_sign = Label.new()
	_sign.text = signpost_label()
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.add_theme_font_size_override("font_size", SIGN_FONT_SIZE)
	_sign.add_theme_color_override("font_color", SIGN_LOCKED_COLOR if is_locked() else SIGN_COLOR)
	_sign.add_theme_color_override("font_outline_color", SIGN_OUTLINE)
	_sign.add_theme_constant_override("outline_size", SIGN_OUTLINE_SIZE)
	_sign.size = Vector2(260.0, 20.0)
	_sign.position = Vector2(-130.0, -size_in_pixels().y / 2.0 - SIGN_HEIGHT)
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sign)
	var bob: Tween = create_tween().set_loops()
	var rest: float = _sign.position.y
	bob.tween_property(_sign, "position:y", rest - SIGN_BOB, SIGN_BOB_SECONDS).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_sign, "position:y", rest, SIGN_BOB_SECONDS).set_trans(Tween.TRANS_SINE)


## The area this exit belongs to, however deep under it the exit is placed.
func _area() -> WorldArea:
	var node: Node = get_parent()
	while node != null:
		if node is WorldArea:
			return node as WorldArea
		node = node.get_parent()
	return null


## What the plate reads: the author's own words, or the target scene's name.
func signpost_label() -> String:
	var text: String = signpost_text
	if text == "":
		text = target_area_path.get_file().get_basename().replace("_", " ").to_upper()
	if is_locked():
		text += SEALED_SUFFIX
	return text


## Keeps the plate honest after the boss holding the way falls.
func refresh_signpost() -> void:
	if _sign == null:
		return
	_sign.text = signpost_label()
	_sign.add_theme_color_override("font_color", SIGN_LOCKED_COLOR if is_locked() else SIGN_COLOR)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_entered.emit(self)


## True while the exit names a boss the player has not beaten yet, or a quest
## they have not turned in. The overworld turns the player back instead of
## travelling.
func is_locked() -> bool:
	return _boss_stands() or _report_owed()


func locked_text() -> String:
	if _report_owed() and unreported_line != "":
		return unreported_line
	return locked_line if locked_line != "" else DEFAULT_LOCKED_LINE


## Whether the boss holding this way is still standing.
func _boss_stands() -> bool:
	return required_boss != &"" and not GameState.has_defeated_boss(required_boss)


## Whether the way is held by a quest that is finished in the field but not
## yet reported back. False while the boss still stands, so the boss line is
## the one the player hears first.
func _report_owed() -> bool:
	if required_quest == &"" or _boss_stands():
		return false
	if Engine.is_editor_hint() or GameState.quests == null:
		return false
	return not GameState.quests.is_completed(required_quest)


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
		_draw_chevrons()
		return
	var size: Vector2 = size_in_pixels()
	var color: Color = LOCKED_EDITOR_COLOR if required_boss != &"" else EDITOR_COLOR
	draw_rect(Rect2(-size / 2.0, size), color, true)
	draw_rect(Rect2(-size / 2.0, size), color.lightened(0.3), false, 2.0)
	var label: String = "-> %s" % target_area_path.get_file().get_basename()
	if required_boss != &"":
		label += " (needs %s)" % required_boss
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-size.x / 2.0 + 4.0, -size.y / 2.0 - 4.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		EDITOR_LABEL_SIZE,
	)


## The way out, crawling towards the doorway on the ground. Drawn rather than
## instanced so an exit needs nothing but its own node on the map.
func _draw_chevrons() -> void:
	if not signpost:
		return
	var color: Color = SIGN_LOCKED_COLOR if is_locked() else SIGN_COLOR
	var across: Vector2 = _chevron_direction.orthogonal()
	for index: int in CHEVRON_COUNT:
		# The chevrons fade in at the back of the run and out at the front, so
		# the line reads as moving rather than blinking.
		var along: float = (float(index) + _chevron_phase) / float(CHEVRON_COUNT)
		var center: Vector2 = _chevron_direction * (along - 0.5) * CHEVRON_SPACING * float(CHEVRON_COUNT)
		var fade: float = sin(along * PI)
		var tip: Vector2 = center + _chevron_direction * CHEVRON_DEPTH
		draw_line(center - across * CHEVRON_HALF_WIDTH, tip, Color(color, 0.75 * fade), CHEVRON_THICKNESS)
		draw_line(center + across * CHEVRON_HALF_WIDTH, tip, Color(color, 0.75 * fade), CHEVRON_THICKNESS)
