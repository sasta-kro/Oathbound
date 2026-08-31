extends Node2D

var creature_has_spoken: bool = false

@onready var player: GridPlayer = $Area1/Player
@onready var knight: WorldActor = $Area1/Knight
@onready var creature: WorldActor = $Area1/Creature
@onready var creature_visual: CreatureVisual = $Area1/Creature/CreatureVisual
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu


func _ready() -> void:
	player.moved.connect(_on_player_moved)
	settings_menu.opened.connect(_on_settings_opened)
	settings_menu.closed.connect(_on_settings_closed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		if settings_menu.is_open():
			settings_menu.close()
		else:
			settings_menu.open()
		return

	if settings_menu.is_open():
		return

	if not event.is_action_pressed(&"interact"):
		return

	get_viewport().set_input_as_handled()
	if dialogue_panel.is_open():
		_close_dialogue()
		return

	if _is_adjacent_to(knight):
		_open_dialogue(knight.dialogue_line)
	elif _is_adjacent_to(creature):
		# Milestone demo: shows the creature's one-shot attack returning to idle.
		creature_visual.play_attack()


func _on_settings_opened() -> void:
	player.movement_enabled = false


## Dialogue also owns movement, so closing the menu must not hand control back
## while a line is still on screen.
func _on_settings_closed() -> void:
	player.movement_enabled = not dialogue_panel.is_open()


func _on_player_moved() -> void:
	if creature_has_spoken or dialogue_panel.is_open():
		return
	if _is_adjacent_to(creature):
		creature_has_spoken = true
		_open_dialogue(creature.dialogue_line)


func _is_adjacent_to(actor: WorldActor) -> bool:
	var position_difference: Vector2 = actor.global_position - player.global_position
	var tile_distance: float = abs(position_difference.x) + abs(position_difference.y)
	return is_equal_approx(tile_distance, float(player.grid_size))


func _open_dialogue(line: String) -> void:
	player.movement_enabled = false
	dialogue_panel.show_line(line)


func _close_dialogue() -> void:
	dialogue_panel.close()
	player.movement_enabled = true
