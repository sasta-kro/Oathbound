class_name PlaceholderVisual
extends Node2D
## A labelled development placeholder for any missing visual asset
## (Specification 23.2, 23.3).
##
## Colour is only a debugging aid, so the placeholder always draws readable
## text as well. Animated placeholders visibly cycle a frame counter so timing
## and state transitions can be tested before real sprites exist.

## Emitted when a non-looping placeholder animation reaches its last frame, so
## callers can sequence one-shot states the same way they do with real sprites.
signal finished

enum Category { PLAYER, FRIENDLY_NPC, HOSTILE_OATHKEEPER, BOSS, CREATURE, INTERACTABLE, UI }

const CATEGORY_COLORS: Dictionary = {
	Category.PLAYER: Color("3f7fd4"),
	Category.FRIENDLY_NPC: Color("46a35a"),
	Category.HOSTILE_OATHKEEPER: Color("c0392b"),
	Category.BOSS: Color("e07b26"),
	Category.CREATURE: Color("8e44ad"),
	Category.INTERACTABLE: Color("d4b73f"),
	Category.UI: Color("7f8c8d"),
}

## Content id or other identifying text, for example CREATURE_FIRE_01.
@export var label_text: String = "PLACEHOLDER":
	set(value):
		label_text = value
		_refresh_text()
@export var category: Category = Category.CREATURE:
	set(value):
		category = value
		if _background != null:
			_background.color = CATEGORY_COLORS.get(category, CATEGORY_COLORS[Category.UI])
@export var size: Vector2 = Vector2(64, 64):
	set(value):
		size = value
		_refresh_layout()

@export_group("Animation")
## Intended animation or state name, for example WALK_UP. Optional.
@export var animation_name: String = "":
	set(value):
		animation_name = value
		_refresh_text()
## 0 keeps the placeholder static; anything higher cycles a visible counter.
@export_range(0, 32) var frame_count: int = 0:
	set(value):
		frame_count = value
		_restart()
@export_range(0.1, 30.0) var frames_per_second: float = 4.0
## When false, the placeholder holds its last frame and emits [signal finished]
## instead of cycling forever.
@export var loops: bool = true:
	set(value):
		loops = value
		_restart()

var _frame: int = 0
var _elapsed: float = 0.0
## True once a non-looping animation has run out, so it holds its last frame.
var _spent: bool = false
var _background: ColorRect
var _label: Label


static func create(text: String, of_category: Category = Category.CREATURE) -> PlaceholderVisual:
	var placeholder := PlaceholderVisual.new()
	placeholder.label_text = text
	placeholder.category = of_category
	return placeholder


func _ready() -> void:
	_background = ColorRect.new()
	_background.color = CATEGORY_COLORS.get(category, CATEGORY_COLORS[Category.UI])
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_refresh_layout()
	_refresh_text()


func _process(delta: float) -> void:
	if frame_count <= 1:
		return
	_elapsed += delta
	var frame_duration := 1.0 / maxf(0.1, frames_per_second)
	while _elapsed >= frame_duration:
		_elapsed -= frame_duration
		if not loops and _frame >= frame_count - 1:
			_elapsed = 0.0
			_spent = true
			set_process(false)
			finished.emit()
			return
		_frame = (_frame + 1) % frame_count
		_refresh_text()


## Text shown by the placeholder, following the labelling standard in
## Specification 23.3.
func placeholder_text() -> String:
	var text := label_text.to_upper()
	if not animation_name.is_empty():
		text += "\n" + animation_name.to_upper()
	if frame_count > 1:
		text += " [%d/%d]" % [_frame + 1, frame_count]
	return text


func _refresh_layout() -> void:
	if _background == null:
		return
	_background.position = -size * 0.5
	_background.size = size
	_label.position = -size * 0.5
	_label.size = size


## Rewinds to the first frame, used whenever the animation itself changes.
func _restart() -> void:
	_frame = 0
	_elapsed = 0.0
	_spent = false
	_refresh_text()


func _refresh_text() -> void:
	if _label != null:
		_label.text = placeholder_text()
	set_process(frame_count > 1 and not _spent)
