class_name CreatureVisual
extends Node2D
## Displays a creature, falling back to a labelled placeholder when the species
## has no sprite yet (Specification 23.1).
##
## Gameplay never depends on the sprite existing: this node is the only place
## that decides between real art and a placeholder.

enum Context { BATTLE, OVERWORLD }

@export var context: Context = Context.BATTLE
## Placeholder box size used when the species has no sprite.
@export var placeholder_size: Vector2 = Vector2(64, 64)
## Frames the placeholder cycles through, so animation timing stays testable.
@export_range(0, 32) var placeholder_frame_count: int = 4

var species: CreatureSpecies

var _visual: Node2D


## Shows a live creature.
func set_creature(instance: CreatureInstance) -> void:
	set_species(instance.species if instance != null else null)


## Shows a species directly, for menus such as the bestiary.
func set_species(new_species: CreatureSpecies) -> void:
	species = new_species
	_rebuild()


func is_using_placeholder() -> bool:
	return _visual is PlaceholderVisual


func _ready() -> void:
	if _visual == null:
		_rebuild()


func _rebuild() -> void:
	if _visual != null:
		_visual.queue_free()
		_visual = null
	if not is_inside_tree():
		return

	var frames := _sprite_frames()
	if frames != null:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		if frames.get_animation_names().size() > 0:
			sprite.animation = frames.get_animation_names()[0]
		sprite.play()
		_visual = sprite
	else:
		var content_id := String(species.id) if species != null else "creature_missing"
		if species != null:
			DevLog.missing_asset("sprite", species.id)
		var placeholder := PlaceholderVisual.create(content_id, PlaceholderVisual.Category.CREATURE)
		placeholder.size = placeholder_size
		placeholder.animation_name = "IDLE"
		placeholder.frame_count = placeholder_frame_count
		_visual = placeholder
	add_child(_visual)


func _sprite_frames() -> SpriteFrames:
	if species == null:
		return null
	return species.battle_sprite if context == Context.BATTLE else species.overworld_sprite
