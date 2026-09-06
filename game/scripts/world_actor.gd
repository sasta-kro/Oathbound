class_name WorldActor
extends CharacterBody2D
## Anything the player can walk up to and press interact on: NPCs and wild
## creatures. Every actor joins the `world_actors` group so the main scene
## can find the nearest one without knowing the map layout.

const GROUP := &"world_actors"

## Name shown above the placeholder body.
@export var display_name: String = "NPC"
## Placeholder body colour until the actor has art.
@export var body_color: Color = Color(0.8, 0.8, 0.8)
@export_multiline var dialogue_line: String = ""
## Talking to this actor restores the party, standing in for the Hub healing
## service until one exists.
@export var heals_party: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	var body: Polygon2D = get_node_or_null(^"Body")
	if body != null:
		body.color = body_color
	var label: Label = get_node_or_null(^"Label")
	if label != null:
		label.text = display_name


## Whether the player can still interact with this actor.
func is_interactable() -> bool:
	return true
