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
## Quests this actor gives and takes back in, by id, in the order they are
## offered. Talk-to objectives name actors by [method actor_id].
@export var quest_ids: Array[StringName] = []


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


## Stable id quests refer to this actor by: the node name, lower-cased, so
## the "Elder" in the town is [code]&"elder"[/code].
func actor_id() -> StringName:
	return StringName(name.to_lower())


## The quest this actor wants to talk about right now: one that is ready to
## turn in first, then one in progress, then the first that can be offered.
## Null when there is nothing but small talk.
func current_quest(log: QuestLog, registry: Node) -> QuestData:
	var offerable: QuestData = null
	var in_progress: QuestData = null
	for id: StringName in quest_ids:
		var quest: QuestData = registry.get_quest(id)
		if quest == null:
			continue
		if log.is_ready(quest):
			return quest
		if in_progress == null and log.is_active(quest.id):
			in_progress = quest
		elif offerable == null and log.can_offer(quest):
			offerable = quest
	return in_progress if in_progress != null else offerable
