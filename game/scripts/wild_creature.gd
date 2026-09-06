@tool
class_name WildCreature
extends WorldActor
## A visible wild creature in the overworld (Specification 7).
##
## Neutral creatures roam inside a leash around their home; hostile ones also
## chase the player once it comes within detection range and report through
## [signal reached_player] when they get adjacent. Interacting with either
## starts a wild battle. Once defeated or bound the creature reports
## [signal defeated]; the [SpawnZone] that made it handles respawning.
##
## Tool script only so the Inspector can list the species' abilities by name;
## nothing moves in the editor.

## Emitted once when the creature leaves the map after a battle.
signal defeated(creature: WildCreature)
## Emitted by hostile creatures each time they close to interaction range.
signal reached_player(creature: WildCreature)

enum Disposition { NEUTRAL, HOSTILE }
enum State { IDLE, WANDER, CHASE }

## Inspector value of [member ability_index] meaning "roll one per encounter".
const RANDOM_ABILITY := -1
const CREATURE_GROUP := &"wild_creatures"
## Close enough to a wander target to count as arrived.
const ARRIVE_DISTANCE: float = 4.0
## Distance at which a chasing creature counts as adjacent, in cells.
const REACH_IN_CELLS: float = 1.5
## Hostile creatures give up a chase this far beyond their leash, in cells,
## so they cannot be kited across the whole map.
const CHASE_LEASH_SLACK_IN_CELLS: float = 2.0

@export var species: CreatureSpecies:
	set(value):
		species = value
		notify_property_list_changed()
		_refresh_presentation()
@export_range(1, 40) var level: int = 4
## Slot in the species ability pool, or [constant RANDOM_ABILITY] to roll one
## per encounter. Shown as a dropdown of the species' ability names.
@export var ability_index: int = RANDOM_ABILITY

@export_group("Behaviour")
@export var disposition: Disposition = Disposition.NEUTRAL
## Pixels per second while wandering. Provisional balance value.
@export var wander_speed: float = 70.0
## Pixels per second while chasing. Provisional balance value.
@export var chase_speed: float = 130.0
## How far from [member home_position] wander targets may be, in pixels.
@export var leash_radius: float = 144.0
## Hostile only: the player is noticed within this many pixels.
@export var detection_radius: float = 192.0
## Seconds spent standing still between wanders, picked at random.
@export var idle_time_range: Vector2 = Vector2(1.0, 3.0)
## A wander that has not arrived after this long gives up (it hit something).
@export var wander_timeout: float = 4.0

## Center of the roaming leash. Defaults to wherever the creature starts.
var home_position: Vector2
## Cleared by the main scene while a battle, dialogue or menu is open.
var roaming_enabled: bool = true
var was_defeated: bool = false
var state: State = State.IDLE

var _rng := RandomNumberGenerator.new()
var _state_time_left: float = 0.0
var _wander_target: Vector2

@onready var visual: CreatureVisual = get_node_or_null(^"CreatureVisual")
@onready var label: Label = get_node_or_null(^"Label")


func _ready() -> void:
	super()
	_refresh_presentation()
	if Engine.is_editor_hint():
		return
	add_to_group(CREATURE_GROUP)
	_rng.randomize()
	if home_position == Vector2.ZERO:
		home_position = global_position
	_enter_idle()


## Configures a freshly instantiated creature before it enters the tree.
func configure(
	new_species: CreatureSpecies,
	new_level: int,
	new_home: Vector2,
	new_leash_radius: float,
	new_disposition: Disposition,
	new_detection_radius: float,
) -> void:
	species = new_species
	level = new_level
	home_position = new_home
	leash_radius = new_leash_radius
	disposition = new_disposition
	detection_radius = new_detection_radius


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if was_defeated or not roaming_enabled:
		velocity = Vector2.ZERO
		_animate()
		return

	var player: Node2D = _player()
	if disposition == Disposition.HOSTILE and player != null:
		_update_hostility(player)

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_enter_wander()
		State.WANDER:
			_state_time_left -= delta
			var to_target: Vector2 = _wander_target - global_position
			if to_target.length() <= ARRIVE_DISTANCE or _state_time_left <= 0.0:
				_enter_idle()
			else:
				velocity = to_target.normalized() * wander_speed
		State.CHASE:
			if player == null:
				_enter_idle()
			else:
				velocity = (player.global_position - global_position).normalized() * chase_speed

	move_and_slide()
	_animate()


## Replaces the plain integer field with a dropdown of the current species'
## abilities. With no species or an empty pool only "Random" is offered.
func _validate_property(property: Dictionary) -> void:
	if property.name != &"ability_index":
		return
	var options: PackedStringArray = ["Random:%d" % RANDOM_ABILITY]
	if species != null:
		for index: int in species.ability_pool.size():
			var ability: AbilityData = species.ability_pool[index]
			var label_text: String = ability.display_name if ability != null else "(empty)"
			options.append("%s:%d" % [label_text.replace(",", " "), index])
	property.hint = PROPERTY_HINT_ENUM
	property.hint_string = ",".join(options)


## A fresh combat instance for this encounter. Wild creatures roll their
## ability unless the map pins one, so the same species does not always fight
## the same way.
func spawn_instance(rng: RandomNumberGenerator = null) -> CreatureInstance:
	var instance := CreatureInstance.create(species, level, maxi(0, ability_index))
	if ability_index < 0 and rng != null:
		instance.randomize_ability(rng)
	return instance


func is_interactable() -> bool:
	return not was_defeated


func set_roaming(enabled: bool) -> void:
	roaming_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO


func mark_defeated() -> void:
	if was_defeated:
		return
	was_defeated = true
	hide()
	# Leaving the body in place but off every layer frees the tile for the
	# player without moving the node other systems still reference.
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self)


func _update_hostility(player: Node2D) -> void:
	var to_player: float = global_position.distance_to(player.global_position)
	var from_home: float = global_position.distance_to(home_position)
	var chase_limit: float = leash_radius + CHASE_LEASH_SLACK_IN_CELLS * WorldArea.GRID_SIZE
	if state == State.CHASE:
		if to_player > detection_radius * 1.5 or from_home > chase_limit:
			_enter_idle()
		elif to_player <= REACH_IN_CELLS * WorldArea.GRID_SIZE:
			reached_player.emit(self)
	elif to_player <= detection_radius and from_home <= chase_limit:
		state = State.CHASE


func _enter_idle() -> void:
	state = State.IDLE
	_state_time_left = _rng.randf_range(idle_time_range.x, idle_time_range.y)


func _enter_wander() -> void:
	state = State.WANDER
	_state_time_left = wander_timeout
	# sqrt keeps the targets spread evenly over the disc instead of clumping
	# at the center.
	var distance: float = leash_radius * sqrt(_rng.randf())
	_wander_target = home_position + Vector2.RIGHT.rotated(_rng.randf() * TAU) * distance


func _animate() -> void:
	if visual == null:
		return
	var moving: bool = velocity.length_squared() > 1.0
	var wanted: StringName = CreatureVisual.STATE_WALK if moving else CreatureVisual.STATE_IDLE
	if visual.state != wanted:
		visual.play(wanted)
	if moving and absf(velocity.x) > 0.01:
		visual.flip_h = velocity.x < 0.0


func _refresh_presentation() -> void:
	if not is_inside_tree():
		return
	if visual != null:
		visual.species = species
	if label != null:
		label.text = species.display_name.to_upper() if species != null else "CREATURE"


func _player() -> Node2D:
	return get_tree().get_first_node_in_group(Player.GROUP) as Node2D
