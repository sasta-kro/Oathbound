extends Node2D
## Overworld driver: loads the current area, places the player, routes
## interaction to the nearest actor and hands hostile contact and player
## interaction to the battle scene.
##
## The scene knows nothing about a specific map. Areas are `WorldArea` scenes
## under `res://areas/`; actors and spawn zones announce themselves through
## groups and signals.

const INTERACTION_REACH_IN_CELLS: float = 1.5

@onready var area: WorldArea = $Area
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var battle_scene: BattleScene = $BattleScene

var _battling_creature: WildCreature


func _ready() -> void:
	player.global_position = area.player_start_position()
	_fit_camera_to_area()
	settings_menu.opened.connect(_on_settings_opened)
	settings_menu.closed.connect(_on_settings_closed)
	battle_scene.battle_finished.connect(_on_battle_finished)
	for zone: SpawnZone in get_tree().get_nodes_in_group(SpawnZone.GROUP):
		zone.creature_reached_player.connect(_on_creature_reached_player)
	# Creatures placed by hand in the area rather than by a zone.
	for creature: WildCreature in get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP):
		if not creature.reached_player.is_connected(_on_creature_reached_player):
			creature.reached_player.connect(_on_creature_reached_player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		if settings_menu.is_open():
			settings_menu.close()
		else:
			settings_menu.open()
		return

	if settings_menu.is_open() or battle_scene.is_active():
		return

	if not event.is_action_pressed(&"interact"):
		return

	get_viewport().set_input_as_handled()
	if dialogue_panel.is_open():
		_close_dialogue()
		return

	var actor: WorldActor = nearest_actor_in_reach()
	if actor == null:
		return
	if actor is WildCreature:
		_start_wild_battle(actor as WildCreature)
		return
	if actor.heals_party:
		GameState.heal_party()
	_open_dialogue(actor.dialogue_line)


## The closest interactable actor the player can touch, or null.
func nearest_actor_in_reach() -> WorldActor:
	var best: WorldActor = null
	var best_distance: float = INF
	for actor: WorldActor in get_tree().get_nodes_in_group(WorldActor.GROUP):
		if not actor.is_interactable() or not _is_adjacent_to(actor):
			continue
		var distance: float = player.global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


## Movement is analog, so "adjacent" means within reach rather than on a
## neighbouring cell: close enough to touch the actor from any side or corner,
## but not from two tiles away.
func _is_adjacent_to(actor: Node2D) -> bool:
	var reach: float = player.grid_size * INTERACTION_REACH_IN_CELLS
	return player.global_position.distance_to(actor.global_position) <= reach


func _fit_camera_to_area() -> void:
	var limits: Rect2 = area.bounds()
	if limits.size == Vector2.ZERO:
		return
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.end.x)
	camera.limit_bottom = int(limits.end.y)


func _on_settings_opened() -> void:
	_refresh_world_activity()


## Dialogue and battle also own movement, so closing the menu must not hand
## control back while either is still on screen.
func _on_settings_closed() -> void:
	_refresh_world_activity()


func _on_creature_reached_player(creature: WildCreature) -> void:
	if _world_is_paused() or creature.was_defeated:
		return
	_start_wild_battle(creature)


func _start_wild_battle(creature: WildCreature) -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close()
	_battling_creature = creature
	if not GameState.has_usable_party_member():
		GameState.heal_party()

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var config := BattleConfig.wild(
		GameState.party, creature.spawn_instance(rng), Content.type_chart
	)
	config.binding_scrolls = GameState.binding_scrolls
	config.has_bind_destination = not GameState.party_is_full()
	config.level_cap = GameState.level_cap
	battle_scene.start_battle(config)
	_refresh_world_activity()


func _on_battle_finished(engine: BattleEngine) -> void:
	GameState.binding_scrolls = engine.binding_scrolls
	GameState.currency += engine.currency_earned
	var creature: WildCreature = _battling_creature
	_battling_creature = null
	match engine.outcome:
		BattleEngine.Outcome.VICTORY:
			if creature != null:
				creature.mark_defeated()
		BattleEngine.Outcome.BOUND:
			GameState.add_to_party(engine.bound_creature)
			if creature != null:
				creature.mark_defeated()
		BattleEngine.Outcome.DEFEAT:
			# No revival location exists yet, so recovery happens in place
			# (Specification 20.1 steps 2, 4 and 5).
			GameState.apply_defeat_penalty()
			GameState.heal_party()
			_open_dialogue(
				"You wake by the road. Your Oathbound have been revived, but %d coins are gone."
				% GameState.DEFEAT_CURRENCY_PENALTY
			)
			return
	_refresh_world_activity()


func _open_dialogue(line: String) -> void:
	dialogue_panel.show_line(line)
	_refresh_world_activity()


func _close_dialogue() -> void:
	dialogue_panel.close()
	_refresh_world_activity()


func _world_is_paused() -> bool:
	return settings_menu.is_open() or battle_scene.is_active() or dialogue_panel.is_open()


## The player and every roaming creature stop together while a menu, dialogue
## or battle is on screen, and resume together when the last one closes.
func _refresh_world_activity() -> void:
	var active: bool = not _world_is_paused()
	player.movement_enabled = active
	get_tree().call_group(WildCreature.CREATURE_GROUP, &"set_roaming", active)
