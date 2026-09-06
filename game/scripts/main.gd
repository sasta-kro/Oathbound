extends Node2D

const INTERACTION_REACH_IN_CELLS: float = 1.5

var creature_has_spoken: bool = false

@onready var player: Player = $Area1/Player
@onready var knight: WorldActor = $Area1/Knight
@onready var creature: WildCreature = $Area1/Creature
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var battle_scene: BattleScene = $BattleScene


func _ready() -> void:
	player.moved.connect(_on_player_moved)
	settings_menu.opened.connect(_on_settings_opened)
	settings_menu.closed.connect(_on_settings_closed)
	battle_scene.battle_finished.connect(_on_battle_finished)


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

	if _is_adjacent_to(knight):
		# The knight stands in for the Hub healing service until one exists.
		GameState.heal_party()
		_open_dialogue(knight.dialogue_line)
	elif _is_adjacent_to(creature) and not creature.defeated:
		_start_wild_battle()


func _on_settings_opened() -> void:
	player.movement_enabled = false


## Dialogue and battle also own movement, so closing the menu must not hand
## control back while either is still on screen.
func _on_settings_closed() -> void:
	player.movement_enabled = not dialogue_panel.is_open() and not battle_scene.is_active()


func _on_player_moved() -> void:
	if creature_has_spoken or creature.defeated or dialogue_panel.is_open():
		return
	if _is_adjacent_to(creature):
		creature_has_spoken = true
		_open_dialogue(creature.dialogue_line)


## Movement is analog, so "adjacent" means within reach rather than on a
## neighbouring cell: close enough to touch the actor from any side or corner,
## but not from two tiles away.
func _is_adjacent_to(actor: WorldActor) -> bool:
	var reach: float = player.grid_size * INTERACTION_REACH_IN_CELLS
	return player.global_position.distance_to(actor.global_position) <= reach


func _start_wild_battle() -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close()
	player.movement_enabled = false
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


func _on_battle_finished(engine: BattleEngine) -> void:
	GameState.binding_scrolls = engine.binding_scrolls
	GameState.currency += engine.currency_earned
	match engine.outcome:
		BattleEngine.Outcome.VICTORY:
			creature.mark_defeated()
		BattleEngine.Outcome.BOUND:
			GameState.add_to_party(engine.bound_creature)
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
	player.movement_enabled = true


func _open_dialogue(line: String) -> void:
	player.movement_enabled = false
	dialogue_panel.show_line(line)


func _close_dialogue() -> void:
	dialogue_panel.close()
	player.movement_enabled = true
