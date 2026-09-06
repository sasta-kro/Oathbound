@tool
class_name SpawnZone
extends Node2D
## A circular region that keeps a species populated (Specification 7.2).
##
## Map authors drop `scenes/spawn_zone.tscn` into an area, pick a species and
## set the radius; the circle is drawn in the editor. At runtime the zone
## fills itself up to [member max_alive] creatures on free ground cells inside
## the circle, lets them roam within it, and respawns each one
## [member respawn_seconds] after it is defeated or bound.
##
## Density is the pair (radius, max_alive): "three Emberlings in this circle".

## Relayed from every creature this zone spawns, so the main scene can start
## hostile encounters without tracking individual creatures.
signal creature_reached_player(creature: WildCreature)

const GROUP := &"spawn_zones"
const CREATURE_SCENE: PackedScene = preload("res://scenes/wild_creature.tscn")
## Random cells tried per creature before the zone gives up for this fill.
const PLACEMENT_ATTEMPTS: int = 30
## Nothing spawns within this many cells of the player (Specification 7.2).
const PLAYER_CLEARANCE_IN_CELLS: float = 2.0
## Footprint checked for overlaps before a creature is placed.
const PROBE_SIZE: Vector2 = Vector2(40, 40)

const EDITOR_FILL_ALPHA: float = 0.18
const EDITOR_LABEL_SIZE: int = 14

@export var species: CreatureSpecies:
	set(value):
		species = value
		queue_redraw()
		update_configuration_warnings()
## Radius of the zone in map cells.
@export_range(1.0, 30.0, 0.5) var radius_in_cells: float = 4.0:
	set(value):
		radius_in_cells = value
		queue_redraw()
## How many creatures the zone keeps alive at once.
@export_range(1, 20) var max_alive: int = 3:
	set(value):
		max_alive = value
		queue_redraw()
@export_range(1, 40) var level_min: int = 3:
	set(value):
		level_min = value
		queue_redraw()
@export_range(1, 40) var level_max: int = 5:
	set(value):
		level_max = value
		queue_redraw()
@export var disposition: WildCreature.Disposition = WildCreature.Disposition.NEUTRAL:
	set(value):
		disposition = value
		queue_redraw()
## Hostile only: creatures notice the player within this many cells.
@export_range(1.0, 20.0, 0.5) var detection_radius_in_cells: float = 4.0
## Delay before a defeated creature is replaced. Provisional balance value.
@export_range(0.0, 600.0, 1.0) var respawn_seconds: float = 20.0
## Minimum cells between two creatures of this zone when they spawn.
@export_range(0.0, 10.0, 0.5) var min_spacing_in_cells: float = 1.0
## Draw the circle in the running game too, for debugging.
@export var debug_draw_in_game: bool = false

const FIRST_FILL_DELAY_IN_STEPS: int = 2

var _alive: Array[WildCreature] = []
var _pending_respawns: int = 0
var _steps_until_first_fill: int = FIRST_FILL_DELAY_IN_STEPS
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group(GROUP)
	_rng.randomize()


## Tile physics bodies are created deferred and only enter the broadphase on
## the following step, so the first fill waits a couple of physics steps. A
## counter rather than an await so a zone freed early never resumes.
func _physics_process(_delta: float) -> void:
	_steps_until_first_fill -= 1
	if _steps_until_first_fill > 0:
		return
	set_physics_process(false)
	fill()


func radius() -> float:
	return radius_in_cells * WorldArea.GRID_SIZE


func alive_count() -> int:
	return _alive.size()


func alive_creatures() -> Array[WildCreature]:
	return _alive.duplicate()


## Spawns creatures until the zone holds [member max_alive] or no free cell
## can be found. Safe to call again at any time.
func fill() -> void:
	if species == null:
		push_warning("SpawnZone %s has no species and spawns nothing." % name)
		return
	while _alive.size() + _pending_respawns < max_alive:
		if not _spawn_one():
			break


func _spawn_one() -> bool:
	var cell_position: Vector2 = _find_free_position()
	if cell_position == Vector2.INF:
		return false
	var creature: WildCreature = CREATURE_SCENE.instantiate()
	creature.configure(
		species,
		_rng.randi_range(mini(level_min, level_max), maxi(level_min, level_max)),
		global_position,
		radius(),
		disposition,
		detection_radius_in_cells * WorldArea.GRID_SIZE,
	)
	creature.name = "%s_%d" % [species.id, _alive.size()]
	creature.defeated.connect(_on_creature_defeated)
	creature.reached_player.connect(creature_reached_player.emit)
	add_child(creature)
	creature.global_position = cell_position
	_alive.append(creature)
	return true


## A random free cell center inside the circle, or Vector2.INF when every
## attempt hit a wall, a prop, another creature, the player or missing ground.
func _find_free_position() -> Vector2:
	var area: WorldArea = _area()
	for _attempt: int in PLACEMENT_ATTEMPTS:
		var distance: float = radius() * sqrt(_rng.randf())
		var candidate: Vector2 = (
			global_position + Vector2.RIGHT.rotated(_rng.randf() * TAU) * distance
		)
		if area != null:
			candidate = area.cell_to_world(area.world_to_cell(candidate))
			if not area.is_on_ground(candidate):
				continue
		if candidate.distance_to(global_position) > radius():
			continue
		if _is_near_player(candidate) or _is_near_own_creature(candidate):
			continue
		if _is_blocked(candidate):
			continue
		return candidate
	return Vector2.INF


func _is_near_player(candidate: Vector2) -> bool:
	var player: Node2D = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	if player == null:
		return false
	return (
		candidate.distance_to(player.global_position)
		< PLAYER_CLEARANCE_IN_CELLS * WorldArea.GRID_SIZE
	)


func _is_near_own_creature(candidate: Vector2) -> bool:
	var spacing: float = min_spacing_in_cells * WorldArea.GRID_SIZE
	for creature: WildCreature in _alive:
		if candidate.distance_to(creature.global_position) < spacing:
			return true
	return false


func _is_blocked(candidate: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = PROBE_SIZE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	# A little slack so a spawn never starts a hair inside something.
	query.margin = 1.0
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_shape(query, 1).is_empty()


func _on_creature_defeated(creature: WildCreature) -> void:
	_alive.erase(creature)
	creature.queue_free()
	_pending_respawns += 1
	get_tree().create_timer(respawn_seconds).timeout.connect(_on_respawn_due)


func _on_respawn_due() -> void:
	_pending_respawns = maxi(0, _pending_respawns - 1)
	if is_inside_tree():
		fill()


func _area() -> WorldArea:
	var node: Node = get_parent()
	while node != null and not node is WorldArea:
		node = node.get_parent()
	return node as WorldArea


func _get_configuration_warnings() -> PackedStringArray:
	if species == null:
		return ["Pick a species, or this zone spawns nothing."]
	return []


func _draw() -> void:
	if not Engine.is_editor_hint() and not debug_draw_in_game:
		return
	var color: Color = (
		Color("d9534f") if disposition == WildCreature.Disposition.HOSTILE else Color("5bc0de")
	)
	draw_circle(Vector2.ZERO, radius(), Color(color, EDITOR_FILL_ALPHA))
	draw_arc(Vector2.ZERO, radius(), 0.0, TAU, 64, color, 2.0)
	draw_line(Vector2(-6, 0), Vector2(6, 0), color, 2.0)
	draw_line(Vector2(0, -6), Vector2(0, 6), color, 2.0)
	var text: String = (
		"%s x%d  L%d-%d%s"
		% [
			species.display_name if species != null else "(no species)",
			max_alive,
			level_min,
			level_max,
			"  HOSTILE" if disposition == WildCreature.Disposition.HOSTILE else "",
		]
	)
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, EDITOR_LABEL_SIZE).x
	var origin := Vector2(-width / 2.0, -radius() - 6.0)
	draw_string(font, origin + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, EDITOR_LABEL_SIZE, Color.BLACK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, EDITOR_LABEL_SIZE, Color.WHITE)
