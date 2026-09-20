@tool
class_name TreasureChest
extends StaticBody2D
## A chest standing on the map with something in it (Specification 16.1).
##
## Map authors drop `scenes/treasure_chest.tscn` where the reward should be,
## give it an id that is unique across the game and list what it holds. The
## overworld opens it when the player presses interact next to it; the lid
## stays open for the rest of the journey, because [GameState] remembers the
## id and never pays the same chest out twice.
##
## The chest blocks movement, so it is never hidden behind an NPC and the
## player always walks up to it rather than over it.

const GROUP := &"treasure_chests"
## Regions of the catacombs decor sheet holding the shut and the sprung chest.
const CLOSED_REGION := Rect2(390, 225, 36, 63)
const OPEN_REGION := Rect2(390, 291, 36, 45)
const SHEET_PATH := "res://assets/tilesets/catacombs_decorative.png"
## Quest EVENT id reported when a chest is emptied, by chest id.
const EVENT_OPENED := "opened_%s"
const DEFAULT_EMPTY_LINE := "The chest is open and empty."
const DEFAULT_LOCKED_LINE := "The lid does not give."
## How far the lid jumps when it springs, and for how long.
const OPEN_BUMP: float = 5.0
const OPEN_SECONDS: float = 0.18
## The shut chest breathes a little light so it reads as worth crossing to.
const GLINT_SECONDS: float = 1.6
const GLINT_BRIGHTNESS: float = 1.22

## Id this chest is remembered by. Must be unique across every area; the
## convention is `chest_<area>_<place>`.
@export var chest_id: StringName = &""
## Coins inside.
@export_range(0, 9999) var coins: int = 0
## Binding Scrolls inside.
@export_range(0, 99) var binding_scrolls: int = 0
## Item ids inside, from `content/items/`.
@export var item_ids: Array[StringName] = []
## How many of each entry in [member item_ids]. A missing entry means one.
@export var item_counts: Array[int] = []
## What the player is told as the lid comes up. The rewards themselves are
## shown as field notices, so this is flavour.
@export_multiline var opened_line: String = ""
## What the player is told when they come back to an emptied chest.
@export_multiline var empty_line: String = ""
## Boss that must fall before the lid gives. Empty for an ordinary chest.
@export var required_boss: StringName = &""
## What the player is told while the chest is still sealed.
@export_multiline var locked_line: String = ""

@onready var _sprite: Sprite2D = $Sprite

var _glint: Tween


func _ready() -> void:
	_refresh_lid()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	if chest_id == &"":
		push_warning("%s has no chest_id; it can be emptied again after a reload." % name)
	_start_glint()


## Whether this chest has already been emptied on this journey.
func is_open() -> bool:
	return chest_id != &"" and GameState.has_opened_chest(chest_id)


## True while the chest names a boss the player has not beaten yet.
func is_locked() -> bool:
	return required_boss != &"" and not GameState.has_defeated_boss(required_boss)


func locked_text() -> String:
	return locked_line if locked_line != "" else DEFAULT_LOCKED_LINE


func empty_text() -> String:
	return empty_line if empty_line != "" else DEFAULT_EMPTY_LINE


## What is inside, in the shape [method GameState.open_chest] takes.
func contents() -> Dictionary:
	var items: Dictionary = {}
	for index: int in item_ids.size():
		var id: StringName = item_ids[index]
		if id == &"":
			continue
		var count: int = item_counts[index] if index < item_counts.size() else 1
		items[id] = int(items.get(id, 0)) + maxi(1, count)
	return {"coins": coins, "binding_scrolls": binding_scrolls, "items": items}


## Empties the chest into the party's satchel and springs the lid. Returns the
## reward lines, empty when there was nothing left to take.
func take() -> PackedStringArray:
	if is_open():
		return PackedStringArray()
	var lines: PackedStringArray = GameState.open_chest(chest_id, contents())
	GameState.report_quest_event(QuestObjective.Kind.EVENT, StringName(EVENT_OPENED % chest_id))
	_spring()
	return lines


## The lid coming up: the sprite swaps and the chest gives a small jolt.
func _spring() -> void:
	SfxService.play(&"bind_success")
	if _glint != null:
		_glint.kill()
	_sprite.modulate = Color.WHITE
	_refresh_lid()
	var rest: float = _sprite.position.y
	var jolt: Tween = create_tween()
	jolt.tween_property(_sprite, "position:y", rest - OPEN_BUMP, OPEN_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	jolt.tween_property(_sprite, "position:y", rest, OPEN_SECONDS)


func _refresh_lid() -> void:
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = load(SHEET_PATH)
	atlas.region = OPEN_REGION if (not Engine.is_editor_hint() and is_open()) else CLOSED_REGION
	sprite.texture = atlas
	# Whatever the lid is doing, the chest stands on its own foot.
	sprite.offset = Vector2(-atlas.region.size.x / 2.0, -atlas.region.size.y)


func _start_glint() -> void:
	if is_open():
		return
	_glint = create_tween().set_loops()
	_glint.tween_property(_sprite, "modulate", Color(1, 1, 1, 1) * GLINT_BRIGHTNESS, GLINT_SECONDS).set_trans(Tween.TRANS_SINE)
	_glint.tween_property(_sprite, "modulate", Color.WHITE, GLINT_SECONDS).set_trans(Tween.TRANS_SINE)
