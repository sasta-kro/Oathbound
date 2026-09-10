@tool
class_name WildCreature
extends WorldActor
## A visible wild creature in the overworld (Specification 7).
##
## Neutral creatures roam inside a leash around their home; hostile ones also
## chase the player once it comes within detection range. A hostile creature
## that catches up winds up visibly and then strikes, reporting through
## [signal reached_player] only once the blow actually lands, so the player
## always has a moment to swing first or back out of range.
##
## The creature carries one [CreatureInstance] for as long as it lives, so a
## hit taken in the overworld is still there when the battle screen opens and
## survives the player running away. Once defeated or bound the creature
## reports [signal defeated]; the [SpawnZone] that made it handles respawning.
##
## Tool script only so the Inspector can list the species' abilities by name;
## nothing moves in the editor.

## Emitted once when the creature leaves the map after a battle.
signal defeated(creature: WildCreature)
## Emitted by hostile creatures each time an overworld strike of theirs lands.
signal reached_player(creature: WildCreature)

enum Disposition { NEUTRAL, HOSTILE }
enum State { IDLE, WANDER, CHASE, WINDUP, RECOVER }

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
## The telegraph before a hostile creature's strike lands. This is the window
## the player has to swing first or step out of reach, so it is the single
## most important number in the overworld fight.
const STRIKE_WINDUP_SECONDS: float = 0.45
## How long a creature is left open after striking.
const STRIKE_RECOVER_SECONDS: float = 0.8
## How long a creature reels after being hit, during which it cannot strike.
const FLINCH_SECONDS: float = 0.4
## Grace given to a creature the player has just finished a battle with, so
## walking out of a battle does not walk straight into the next one.
const POST_BATTLE_GRACE_SECONDS: float = 1.5
## How far a hit knocks a creature back.
const KNOCKBACK_SPEED: float = 220.0
## Pixels per second the knockback bleeds off.
const KNOCKBACK_DECAY: float = 900.0
## Seconds a routed creature spends dying before it leaves the map.
const ROUT_SECONDS: float = 0.45
const ROUT_FADE_SECONDS: float = 0.25
## How long a defeated creature takes to break apart into light.
const ROUT_DISSOLVE_SECONDS: float = 0.8

## Effects played in the world. Both are shared presets: see [VfxPreset].
const HIT_VFX: VfxPreset = preload("res://content/vfx/vfx_hit_impact.tres")
const DEFEAT_VFX: VfxPreset = preload("res://content/vfx/vfx_defeat_sparks.tres")
## The presets are authored for the battle stage, where a creature is drawn
## several times larger than it is on the map. Played at full size out here
## they swallow the creature they are meant to be happening to.
const WORLD_VFX_SCALE: float = 0.42

## Overworld health bar, shown only once a creature has actually been hurt.
const HEALTH_BAR_SIZE := Vector2(44.0, 5.0)
const HEALTH_BAR_OFFSET_Y: float = -20.0
const HEALTH_BAR_BORDER_COLOR := Color(0.05, 0.06, 0.08, 0.9)
const HEALTH_BAR_BACK_COLOR := Color(0.16, 0.17, 0.2, 0.9)
## Read at a glance from across the map, so the thresholds are the same ones
## the battle screen uses on its own bars.
const HEALTH_HEALTHY_COLOR := Color("4cc260")
const HEALTH_WARY_COLOR := Color("e0b23a")
const HEALTH_CRITICAL_COLOR := Color("d1453b")
const HEALTH_WARY_FRACTION: float = 0.5
const HEALTH_CRITICAL_FRACTION: float = 0.2

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
var _knockback: Vector2 = Vector2.ZERO
## Built on first use and kept for the creature's whole life, so overworld
## damage persists. See [method encounter_instance].
var _encounter: CreatureInstance
## World-sized copies of the shared presets, made once rather than per hit.
@onready var _world_hit_vfx: VfxPreset = HIT_VFX.scaled(WORLD_VFX_SCALE)
@onready var _world_defeat_vfx: VfxPreset = DEFEAT_VFX.scaled(WORLD_VFX_SCALE)
## Set while the creature is playing its death beat, during which it is no
## longer a valid encounter but has not left the map yet.
var _routed: bool = false

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
	if was_defeated or _routed or not roaming_enabled:
		velocity = Vector2.ZERO
		_animate()
		return

	var player: Node2D = _player()
	# A creature that is winding up, striking or reeling has committed to that
	# beat, so nothing re-targets it until the beat is over.
	if disposition == Disposition.HOSTILE and player != null and _is_free_to_act():
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
		State.WINDUP:
			velocity = Vector2.ZERO
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_land_strike(player)
		State.RECOVER:
			velocity = _knockback
			_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
			_state_time_left -= delta
			if _state_time_left <= 0.0:
				_enter_idle()

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


## A fresh combat instance for this creature. Wild creatures roll their
## ability unless the map pins one, so the same species does not always fight
## the same way.
func spawn_instance(rng: RandomNumberGenerator = null) -> CreatureInstance:
	var instance := CreatureInstance.create(species, level, maxi(0, ability_index))
	if ability_index < 0 and rng != null:
		instance.randomize_ability(rng)
	return instance


## The instance this creature fights with, built once and then kept. Damage
## landed on it in the overworld is the same damage the battle screen opens
## with, and it is still there if the player runs away and comes back.
func encounter_instance() -> CreatureInstance:
	if _encounter == null:
		_encounter = spawn_instance(_rng)
	return _encounter


## Applies a blow landed in the overworld and leaves the creature reeling.
## Returns true when the hit put it down, in which case no battle happens and
## the caller pays out the rewards itself.
func take_overworld_hit(amount: int, from_position: Vector2) -> bool:
	var instance: CreatureInstance = encounter_instance()
	instance.set_hp(instance.current_hp - amount)
	var away: Vector2 = global_position - from_position
	_knockback = (
		away.normalized() * KNOCKBACK_SPEED if not away.is_zero_approx() else Vector2.ZERO
	)
	_enter_recover(FLINCH_SECONDS)
	if visual != null:
		visual.play(CreatureVisual.STATE_HURT)
	_play_world_vfx(_world_hit_vfx, global_position)
	queue_redraw()
	return instance.is_fainted()


## Plays the beat where a creature leaves the map: it comes apart into flecks
## of light and is then taken off. Awaited by the caller when a reward line
## follows, so the text does not land on top of a creature still standing.
##
## [param as_defeat] plays the death animation on the way out. A creature that
## was bound rather than beaten is released the same way but should not be
## shown dying, so binding passes false.
func play_rout(as_defeat: bool = true) -> void:
	if was_defeated or _routed:
		return
	_routed = true
	velocity = Vector2.ZERO
	if visual != null and as_defeat:
		visual.play(CreatureVisual.STATE_DEATH)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_interval(ROUT_SECONDS)
		tween.tween_callback(_release_into_light)
		# A creature with real art comes apart into flecks; a placeholder has
		# no canvas item of its own to dissolve, so it fades instead.
		if visual != null and visual.prepare_dissolve():
			tween.tween_property(visual, "dissolve", 1.0, ROUT_DISSOLVE_SECONDS)
		else:
			tween.tween_property(self, "modulate:a", 0.0, ROUT_FADE_SECONDS)
		await tween.finished
	mark_defeated()


## The motes a defeated creature leaves behind. They are parented to the world
## rather than to the body, because the body is hidden the moment it is marked
## defeated and would take them with it.
func _release_into_light() -> void:
	_play_world_vfx(_world_defeat_vfx, global_position)


func _play_world_vfx(preset: VfxPreset, at: Vector2) -> void:
	var host := get_parent() as Node2D
	if host == null or not is_inside_tree():
		return
	VfxPlayer.play_global(host, preset, at)


## Backs a creature off for a moment, so leaving a battle does not immediately
## walk into the next one (Specification 7.4).
func back_off(seconds: float = POST_BATTLE_GRACE_SECONDS) -> void:
	if was_defeated or _routed:
		return
	_knockback = Vector2.ZERO
	_enter_recover(seconds)


## Whether the creature can be talked to or swung at right now.
func is_interactable() -> bool:
	return not was_defeated and not _routed


## True while the creature is about to strike, which is the window the player
## can react in.
func is_winding_up() -> bool:
	return state == State.WINDUP


## Redraws the health bar after something other than an overworld hit changed
## the creature's HP, which in practice means a battle the player ran from.
func refresh_health() -> void:
	queue_redraw()


func set_roaming(enabled: bool) -> void:
	roaming_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		# A half-finished windup must not resume and land after the screen the
		# player was looking at has closed.
		if state == State.WINDUP:
			_enter_idle()


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
		elif to_player <= strike_reach():
			_enter_windup()
	elif to_player <= detection_radius and from_home <= chase_limit:
		state = State.CHASE


func strike_reach() -> float:
	return REACH_IN_CELLS * WorldArea.GRID_SIZE


## Whether the creature is in a state that can be interrupted or re-targeted.
func _is_free_to_act() -> bool:
	return state == State.IDLE or state == State.WANDER or state == State.CHASE


## The telegraph: the creature stops, rears up and commits. It is only after
## [constant STRIKE_WINDUP_SECONDS] that the blow actually lands, so a player
## who reacts can swing first or simply walk out of reach.
func _enter_windup() -> void:
	state = State.WINDUP
	_state_time_left = STRIKE_WINDUP_SECONDS
	velocity = Vector2.ZERO
	if visual != null:
		visual.play(CreatureVisual.STATE_ATTACK)


## Resolves a windup. The blow only counts if the player is still in reach,
## which is what makes stepping back a real answer to the telegraph.
func _land_strike(player: Node2D) -> void:
	_enter_recover(STRIKE_RECOVER_SECONDS)
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= strike_reach():
		_play_world_vfx(_world_hit_vfx, player.global_position)
		reached_player.emit(self)


func _enter_recover(seconds: float) -> void:
	state = State.RECOVER
	_state_time_left = seconds


func _enter_idle() -> void:
	state = State.IDLE
	_knockback = Vector2.ZERO
	_state_time_left = _rng.randf_range(idle_time_range.x, idle_time_range.y)


func _enter_wander() -> void:
	state = State.WANDER
	_state_time_left = wander_timeout
	# sqrt keeps the targets spread evenly over the disc instead of clumping
	# at the center.
	var distance: float = leash_radius * sqrt(_rng.randf())
	_wander_target = home_position + Vector2.RIGHT.rotated(_rng.randf() * TAU) * distance


## A thin bar over a creature that has been hurt, so the overworld shows the
## damage a swing did without opening a battle screen. A creature at full
## health draws nothing, which keeps an untouched map clean.
func _draw() -> void:
	if Engine.is_editor_hint() or _encounter == null or was_defeated:
		return
	var fraction: float = clampf(_encounter.hp_fraction(), 0.0, 1.0)
	if fraction >= 1.0:
		return
	var origin := Vector2(-HEALTH_BAR_SIZE.x * 0.5, HEALTH_BAR_OFFSET_Y)
	draw_rect(Rect2(origin - Vector2.ONE, HEALTH_BAR_SIZE + Vector2(2.0, 2.0)), HEALTH_BAR_BORDER_COLOR)
	draw_rect(Rect2(origin, HEALTH_BAR_SIZE), HEALTH_BAR_BACK_COLOR)
	if fraction <= 0.0:
		return
	draw_rect(
		Rect2(origin, Vector2(HEALTH_BAR_SIZE.x * fraction, HEALTH_BAR_SIZE.y)),
		_health_color(fraction),
	)


func _health_color(fraction: float) -> Color:
	if fraction <= HEALTH_CRITICAL_FRACTION:
		return HEALTH_CRITICAL_COLOR
	if fraction <= HEALTH_WARY_FRACTION:
		return HEALTH_WARY_COLOR
	return HEALTH_HEALTHY_COLOR


func _animate() -> void:
	if visual == null:
		return
	# A windup or a flinch owns the sprite until it finishes; overwriting it
	# with a walk cycle would erase the telegraph the player reacts to.
	if state == State.WINDUP or state == State.RECOVER:
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
