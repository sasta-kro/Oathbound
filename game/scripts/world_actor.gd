class_name WorldActor
extends CharacterBody2D
## Anything the player can walk up to and press interact on: NPCs and wild
## creatures. Every actor joins the `world_actors` group so the main scene
## can find the nearest one without knowing the map layout.

const GROUP := &"world_actors"

## Name shown above the placeholder body.
@export var display_name: String = "NPC"
## Placeholder body colour, used only while `sprite_frames` is unset.
@export var body_color: Color = Color(0.8, 0.8, 0.8)
## Character art for this actor. Actors without art fall back to the coloured
## placeholder body.
@export var sprite_frames: SpriteFrames = null
## Which row of `sprite_frames` the actor stands in, as an `idle_*` animation.
@export var facing: StringName = &"down"
@export_multiline var dialogue_line: String = ""
## Talking to this actor restores the party, standing in for the Hub healing
## service until one exists.
@export var heals_party: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	var sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")
	var body: Polygon2D = get_node_or_null(^"Body")
	if sprite != null:
		sprite.sprite_frames = sprite_frames
		sprite.visible = sprite_frames != null
		if sprite_frames != null:
			var idle: StringName = StringName("idle_%s" % facing)
			if sprite_frames.has_animation(idle):
				sprite.play(idle)
	if body != null:
		body.color = body_color
		body.visible = sprite_frames == null
	var label: Label = get_node_or_null(^"Label")
	if label != null:
		label.text = display_name


## Whether the player can still interact with this actor.
func is_interactable() -> bool:
	return true
