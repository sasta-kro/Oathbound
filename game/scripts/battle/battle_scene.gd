class_name BattleScene
extends CanvasLayer
## The battle screen: side-view stage, status windows, command menu and
## message log (Specification 11.12, 22.5).
##
## The flow is the familiar creature-battle one, but the stage is a side view
## rather than front-and-back: the player's creature stands on the left facing
## right and the enemy stands on the right, mirrored, because every sprite in
## the project is drawn in profile. All rules live in [BattleEngine]; this node
## only asks for the player's choice, then plays back the events it returns.

## Emitted when the battle is over and the screen has closed. The engine
## carries the outcome, rewards and any bound creature.
signal battle_finished(engine: BattleEngine)

enum Menu { NONE, COMMAND, MOVES, PARTY }


## One row of the command window.
class MenuEntry:
	extends RefCounted
	var button: Button
	var label: String = ""
	var callback: Callable
	var hint: String = ""
	var enabled: bool = true
	var disabled_reason: String = ""


## Flat ellipse under each creature so it reads as standing on the ground.
class StageShadow:
	extends Node2D
	const RADIUS := 34.0
	const COLOR := Color(0.0, 0.0, 0.0, 0.35)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, RADIUS, COLOR)


## Battles are meant to be fast (Specification 11.12): messages advance on
## their own after this long, or sooner on a key press.
const MESSAGE_HOLD_SECONDS := 0.55
## A simple attack presents in about 0.4 s (Specification 11.12).
const ATTACK_SECONDS := 0.4
const LUNGE_DISTANCE := 36.0
const HP_TWEEN_SECONDS := 0.35
const SEND_OUT_SECONDS := 0.25
const DODGE_SECONDS := 0.2
const FAINT_SECONDS := 0.7
const BIND_SECONDS := 0.5

const HP_HEALTHY_COLOR := Color("4cc260")
const HP_WARY_COLOR := Color("e0b23a")
const HP_CRITICAL_COLOR := Color("d1453b")
const HP_WARY_FRACTION := 0.5
const HP_CRITICAL_FRACTION := 0.2

## Effects shared with the rest of the game: see [VfxPreset].
const HIT_VFX: VfxPreset = preload("res://content/vfx/vfx_hit_impact.tres")
const DEFEAT_VFX: VfxPreset = preload("res://content/vfx/vfx_defeat_sparks.tres")
const BIND_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_seal.tres")
const DISSOLVE_SECONDS := 0.8

const HIT_FLASH_COLOR := Color(1.0, 0.45, 0.45)
const BIND_FLASH_COLOR := Color(1.0, 0.85, 0.35)
const DISABLED_TEXT_COLOR := Color(0.55, 0.55, 0.55)
const MENU_TEXT_COLOR := Color(0.87, 0.87, 0.83)
const MENU_SELECTED_TEXT_COLOR := Color(1.0, 0.97, 0.85)
const MENU_HIGHLIGHT_COLOR := Color(0.72549, 0.682353, 0.321569, 0.22)
const MENU_HIGHLIGHT_BORDER_COLOR := Color(0.72549, 0.682353, 0.321569, 0.9)
const CURSOR_PREFIX := "▶ "
const IDLE_PREFIX := "  "
const DISMISS_HINT := "  ▼"
const MENU_FONT_SIZE := 17
const MENU_ROW_PADDING := 2
const MENU_ROW_MARGIN := 6
## Every button state a row restyles, so hover and focus cannot fight the
## cursor for which row looks selected.
const ROW_STYLE_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]

## Three-letter badges shown in the status panels (Specification 12).
const STATUS_BADGE_TEXT: Dictionary = {
	StatusIds.POISON: "PSN",
	StatusIds.BURN: "BRN",
	StatusIds.STUN: "STN",
}
const STATUS_BADGE_COLORS: Dictionary = {
	StatusIds.POISON: Color("8e5bc0"),
	StatusIds.BURN: Color("d4703a"),
	StatusIds.STUN: Color("d8c23c"),
}
const STATUS_BADGE_FONT_SIZE := 11
const STATUS_BADGE_TEXT_COLOR := Color(0.07, 0.07, 0.09)

const DAMAGE_NUMBER_FONT_SIZE := 30
const DAMAGE_NUMBER_WIDTH := 120.0
const DAMAGE_NUMBER_RISE := 34.0
const DAMAGE_NUMBER_SECONDS := 0.7
## Just above the sprite's head. Any higher and the number rises into the
## status windows, which sit in front of the stage.
const DAMAGE_NUMBER_OFFSET := Vector2(0.0, -78.0)
const DAMAGE_NEUTRAL_COLOR := Color(1.0, 0.95, 0.9)
const DAMAGE_STRONG_COLOR := Color(1.0, 0.65, 0.3)
const DAMAGE_WEAK_COLOR := Color(0.7, 0.75, 0.8)

const SHAKE_SECONDS := 0.24
const SHAKE_STEPS := 4
const SHAKE_STRENGTH := 7.0
## Super-effective hits knock the stage this much harder.
const SHAKE_STRONG_SCALE := 1.5

## Skips every wait and tween so a test can drive a battle synchronously.
var skip_presentation: bool = false

## Optional [ScreenTransition]. When one is set the battle covers the screen
## with it before closing, so whatever replaces the battle is never seen
## appearing. Left null the screen simply hides, which is what tests want.
var transition: ScreenTransition

var engine: BattleEngine

var _menu: Menu = Menu.NONE
var _entries: Array[MenuEntry] = []
var _cursor: int = 0
var _playing: bool = false
var _skip_requested: bool = false
var _party_menu_forced: bool = false
var _awaiting_dismiss: bool = false

var _visuals: Dictionary = {}
var _shadows: Dictionary = {}
var _homes: Dictionary = {}
var _hp_bars: Dictionary = {}
var _hp_fills: Dictionary = {}
var _hp_labels: Dictionary = {}
var _name_labels: Dictionary = {}
var _level_labels: Dictionary = {}
var _type_labels: Dictionary = {}
var _status_rows: Dictionary = {}
var _hp_tweens: Dictionary = {}
var _shake_tween: Tween
var _idle_row_style: StyleBoxEmpty
var _selected_row_style: StyleBoxFlat

@onready var root: Control = $Root
@onready var stage: Node2D = $Root/Stage
@onready var player_visual: CreatureVisual = %PlayerVisual
@onready var enemy_visual: CreatureVisual = %EnemyVisual
@onready var player_shadow: Node2D = $Root/Stage/PlayerShadow
@onready var enemy_shadow: Node2D = $Root/Stage/EnemyShadow
@onready var player_name: Label = %PlayerName
@onready var player_level: Label = %PlayerLevel
@onready var player_types: Label = %PlayerTypes
@onready var player_statuses: HBoxContainer = %PlayerStatuses
@onready var player_hp_bar: ProgressBar = %PlayerHpBar
@onready var player_hp: Label = %PlayerHp
@onready var player_xp_bar: ProgressBar = %PlayerXpBar
@onready var enemy_name: Label = %EnemyName
@onready var enemy_level: Label = %EnemyLevel
@onready var enemy_types: Label = %EnemyTypes
@onready var enemy_statuses: HBoxContainer = %EnemyStatuses
@onready var enemy_hp_bar: ProgressBar = %EnemyHpBar
@onready var enemy_hp: Label = %EnemyHp
@onready var command_list: VBoxContainer = %CommandList
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	root.hide()
	var player_side: int = BattleTeam.Side.PLAYER
	var enemy_side: int = BattleTeam.Side.ENEMY
	_visuals = {player_side: player_visual, enemy_side: enemy_visual}
	_shadows = {player_side: player_shadow, enemy_side: enemy_shadow}
	_homes = {player_side: player_visual.position, enemy_side: enemy_visual.position}
	_hp_bars = {player_side: player_hp_bar, enemy_side: enemy_hp_bar}
	_hp_labels = {player_side: player_hp, enemy_side: enemy_hp}
	_name_labels = {player_side: player_name, enemy_side: enemy_name}
	_level_labels = {player_side: player_level, enemy_side: enemy_level}
	_type_labels = {player_side: player_types, enemy_side: enemy_types}
	_status_rows = {player_side: player_statuses, enemy_side: enemy_statuses}
	_build_row_styles()
	for side: int in _shadows:
		(_shadows[side] as Node2D).add_child(StageShadow.new())
		# Each bar gets its own fill so the two HP colours can differ.
		var fill := StyleBoxFlat.new()
		fill.bg_color = HP_HEALTHY_COLOR
		fill.set_corner_radius_all(3)
		(_hp_bars[side] as ProgressBar).add_theme_stylebox_override("fill", fill)
		_hp_fills[side] = fill


func is_active() -> bool:
	return root.visible


## Opens the screen and runs the battle described by [param config]. Returns
## once the opening presentation is done and the player is choosing.
func start_battle(config: BattleConfig) -> void:
	engine = BattleEngine.new(config)
	_awaiting_dismiss = false
	_close_menu()
	for side: int in _visuals:
		(_visuals[side] as CreatureVisual).hide()
		(_shadows[side] as Node2D).hide()
	_say("")
	root.show()
	var events: Array[BattleEvent] = engine.start()
	if engine.phase == BattleEngine.Phase.ENDED:
		_finish()
		return
	await _play_events(events)
	_continue()


func current_menu() -> Menu:
	return _menu


func current_message() -> String:
	return message_label.text


func menu_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for entry: MenuEntry in _entries:
		labels.append(entry.label)
	return labels


## Activates a menu row, the same as moving the cursor there and confirming.
func press_entry(index: int) -> void:
	if _playing or _menu == Menu.NONE or index < 0 or index >= _entries.size():
		return
	var entry: MenuEntry = _entries[index]
	if not entry.enabled:
		_say(entry.disabled_reason)
		return
	entry.callback.call()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if _playing:
		if event.is_action_pressed(&"interact"):
			_skip_requested = true
			get_viewport().set_input_as_handled()
		return
	if _awaiting_dismiss:
		if event.is_action_pressed(&"interact"):
			get_viewport().set_input_as_handled()
			_finish()
		return
	if _menu == Menu.NONE:
		return
	if event.is_action_pressed(&"move_up"):
		_set_cursor(_cursor - 1)
	elif event.is_action_pressed(&"move_down"):
		_set_cursor(_cursor + 1)
	elif event.is_action_pressed(&"interact"):
		press_entry(_cursor)
	elif event.is_action_pressed(&"cancel"):
		_cancel_menu()
	else:
		return
	get_viewport().set_input_as_handled()


# --- Menus -------------------------------------------------------------------


func _continue() -> void:
	match engine.phase:
		BattleEngine.Phase.REPLACING:
			_open_party_menu(true)
		BattleEngine.Phase.ENDED:
			_awaiting_dismiss = true
			message_label.text += DISMISS_HINT
		_:
			_open_command_menu()


func _open_command_menu() -> void:
	var options: Dictionary = engine.options()
	var active: Battler = engine.player.active()
	_begin_menu(Menu.COMMAND)
	_add_entry("FIGHT", _open_moves_menu, "Choose one of %s's moves." % active.display_name())
	_add_entry(
		"SWITCH",
		_open_party_menu.bind(false),
		"Switch to another Oathbound. This uses your turn.",
		bool(options["can_switch"]),
		String(options["switch_reason"]),
	)
	_add_entry(
		"ITEM",
		Callable(),
		"Use an item.",
		bool(options["can_item"]),
		String(options["item_reason"]),
	)
	_add_entry(
		"BIND",
		_choose_bind,
		_bind_hint(),
		bool(options["can_bind"]),
		String(options["bind_reason"]),
	)
	_add_entry(
		"RUN",
		_choose_run,
		"Try to escape the battle.",
		bool(options["can_run"]),
		String(options["run_reason"]),
	)
	_end_menu()


func _open_moves_menu() -> void:
	var active: Battler = engine.player.active()
	_begin_menu(Menu.MOVES)
	for move: MoveData in active.creature.moves:
		var ready: bool = active.is_move_ready(move)
		var remaining: int = active.cooldown_remaining(move)
		var label: String = (
			move.display_name if ready else "%s (%d)" % [move.display_name, remaining]
		)
		_add_entry(
			label,
			_choose_move.bind(move),
			_move_hint(move),
			ready,
			"%s is cooling down for %d more turns." % [move.display_name, remaining],
		)
	if not active.has_ready_move():
		_add_entry("WAIT", _choose_wait, "Every move is cooling down. Wait out the turn.")
	_end_menu()


func _open_party_menu(forced: bool) -> void:
	_party_menu_forced = forced
	var team: BattleTeam = engine.player
	var bench: Array[int] = team.usable_bench_indices()
	_begin_menu(Menu.PARTY)
	for index: int in team.battlers.size():
		var creature: CreatureInstance = team.battlers[index].creature
		var label := "%s  Lv%d  %d/%d" % [
			creature.display_name(), creature.level, creature.current_hp, creature.max_hp()
		]
		var reason: String = (
			"%s is already fighting." % creature.display_name()
			if index == team.active_index
			else "%s has fainted." % creature.display_name()
		)
		var callback: Callable = (
			_choose_replacement.bind(index) if forced else _choose_switch.bind(index)
		)
		_add_entry(label, callback, "Send out %s." % creature.display_name(), bench.has(index), reason)
	_end_menu()
	if forced:
		_say("Choose your next Oathbound.")


func _cancel_menu() -> void:
	match _menu:
		Menu.MOVES:
			_open_command_menu()
		Menu.PARTY:
			if not _party_menu_forced:
				_open_command_menu()


func _begin_menu(menu: Menu) -> void:
	_clear_entries()
	_menu = menu
	_cursor = 0


func _add_entry(
	label: String,
	callback: Callable,
	hint: String,
	enabled: bool = true,
	disabled_reason: String = ""
) -> void:
	var entry := MenuEntry.new()
	entry.label = label
	entry.callback = callback
	entry.hint = hint
	entry.enabled = enabled and callback.is_valid()
	entry.disabled_reason = disabled_reason

	var button := Button.new()
	# Not `flat`: flat buttons skip their stylebox entirely, and the cursor row
	# is drawn as one.
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	_style_row(button, false)
	if not entry.enabled:
		button.add_theme_color_override("font_color", DISABLED_TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", DISABLED_TEXT_COLOR)
	var index: int = _entries.size()
	button.pressed.connect(press_entry.bind(index))
	button.mouse_entered.connect(_set_cursor.bind(index))
	entry.button = button
	command_list.add_child(button)
	_entries.append(entry)


func _end_menu() -> void:
	_set_cursor(0)


## Default buttons are tall enough to push the window over the stage, so rows
## use a bare style with tight padding. The selected row swaps in a filled
## style with the same margins, so nothing shifts as the cursor moves.
func _build_row_styles() -> void:
	_idle_row_style = StyleBoxEmpty.new()
	_apply_row_margins(_idle_row_style)
	_selected_row_style = StyleBoxFlat.new()
	_selected_row_style.bg_color = MENU_HIGHLIGHT_COLOR
	_selected_row_style.border_width_left = 3
	_selected_row_style.border_color = MENU_HIGHLIGHT_BORDER_COLOR
	_selected_row_style.set_corner_radius_all(4)
	_apply_row_margins(_selected_row_style)


func _apply_row_margins(style: StyleBox) -> void:
	style.content_margin_left = MENU_ROW_MARGIN
	style.content_margin_right = MENU_ROW_MARGIN
	style.content_margin_top = MENU_ROW_PADDING
	style.content_margin_bottom = MENU_ROW_PADDING


func _style_row(button: Button, selected: bool) -> void:
	var style: StyleBox = _selected_row_style if selected else _idle_row_style
	for state: String in ROW_STYLE_STATES:
		button.add_theme_stylebox_override(state, style)


func _set_cursor(index: int) -> void:
	if _entries.is_empty():
		return
	_cursor = posmod(index, _entries.size())
	for position: int in _entries.size():
		var entry: MenuEntry = _entries[position]
		var selected: bool = position == _cursor
		entry.button.text = (CURSOR_PREFIX if selected else IDLE_PREFIX) + entry.label
		_style_row(entry.button, selected)
		if entry.enabled:
			var text_color: Color = MENU_SELECTED_TEXT_COLOR if selected else MENU_TEXT_COLOR
			entry.button.add_theme_color_override("font_color", text_color)
			entry.button.add_theme_color_override("font_hover_color", text_color)
	_say(_entries[_cursor].hint)


func _clear_entries() -> void:
	for entry: MenuEntry in _entries:
		command_list.remove_child(entry.button)
		entry.button.queue_free()
	_entries.clear()
	_menu = Menu.NONE


func _close_menu() -> void:
	_clear_entries()
	_party_menu_forced = false


func _move_hint(move: MoveData) -> String:
	var parts: PackedStringArray = [Elements.display_name(move.type).to_upper()]
	parts.append("Power %d" % move.power if move.is_damaging() else "No damage")
	parts.append("Accuracy %d%%" % move.accuracy)
	if move.cooldown_turns > 0:
		parts.append("Cooldown %d" % move.cooldown_turns)
	var hint: String = " · ".join(parts)
	if move.is_damaging():
		var effectiveness: String = BattleRules.effectiveness_text(
			engine.effectiveness_against_enemy(move)
		)
		if not effectiveness.is_empty():
			hint += "  " + effectiveness
	return hint


func _bind_hint() -> String:
	var target: CreatureInstance = engine.enemy.active().creature
	var chance: float = BattleRules.bind_chance(target, engine.config.scroll_multiplier)
	return "Offer a Binding Scroll (%d left). Chance now: %d%%." % [
		engine.binding_scrolls, int(round(chance * 100.0))
	]


# --- Choices -----------------------------------------------------------------


func _choose_move(move: MoveData) -> void:
	_run_turn(BattleAction.use_move(move))


func _choose_wait() -> void:
	_run_turn(BattleAction.wait())


func _choose_switch(index: int) -> void:
	_run_turn(BattleAction.switch_to(index))


func _choose_bind() -> void:
	_run_turn(BattleAction.bind())


func _choose_run() -> void:
	_run_turn(BattleAction.run())


func _choose_replacement(index: int) -> void:
	_close_menu()
	await _play_events(engine.replace_fainted(index))
	_continue()


func _run_turn(action: BattleAction) -> void:
	_close_menu()
	await _play_events(engine.take_turn(action))
	_continue()


## Closes the screen. When a [member transition] is set the screen is covered
## first, so the caller only has to uncover whatever it put underneath.
func _finish() -> void:
	_awaiting_dismiss = false
	_close_menu()
	if transition != null:
		await transition.cover(ScreenTransition.Style.WORLD)
	root.hide()
	battle_finished.emit(engine)


# --- Presentation ------------------------------------------------------------


func _play_events(events: Array[BattleEvent]) -> void:
	_playing = true
	for event: BattleEvent in events:
		_say(event.text)
		await _present(event)
		await _hold(MESSAGE_HOLD_SECONDS)
	_playing = false


func _present(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.SEND_OUT:
			_show_creature(event.side)
			await _wait(SEND_OUT_SECONDS)
		BattleEvent.Kind.MOVE_USED:
			_visual_for(event.side).play_attack()
			_lunge(event.side)
			_play_move_vfx(event.side, event.data.get("move") as MoveData)
			await _wait(ATTACK_SECONDS)
		BattleEvent.Kind.HIT, BattleEvent.Kind.STATUS_DAMAGE:
			var target: CreatureVisual = _visual_for(event.side)
			var multiplier: float = float(event.data.get("multiplier", 1.0))
			target.play(CreatureVisual.STATE_HURT)
			_flash(target, HIT_FLASH_COLOR)
			_play_vfx(HIT_VFX, target)
			_show_damage(event.side, int(event.data.get("damage", 0)), multiplier)
			if event.kind == BattleEvent.Kind.HIT:
				_shake_stage(multiplier)
			_tween_hp(event.side)
			await _wait(HP_TWEEN_SECONDS)
		BattleEvent.Kind.MISSED:
			_dodge(event.side)
			await _wait(DODGE_SECONDS)
		BattleEvent.Kind.FAINTED:
			var fainted: CreatureVisual = _visual_for(event.side)
			fainted.play(CreatureVisual.STATE_DEATH)
			await _wait(FAINT_SECONDS)
			_take_off_stage(event.side)
			_refresh_panels()
		BattleEvent.Kind.BIND_ATTEMPT:
			_flash(enemy_visual, BIND_FLASH_COLOR)
			_play_vfx(BIND_VFX, enemy_visual)
			await _wait(BIND_SECONDS)
		BattleEvent.Kind.BIND_SUCCESS:
			_take_off_stage(BattleTeam.Side.ENEMY)
		_:
			_refresh_panels()


func _show_creature(side: int) -> void:
	var battler: Battler = _team(side).active()
	var visual: CreatureVisual = _visual_for(side)
	visual.set_creature(battler.creature)
	visual.position = _homes[side]
	visual.modulate = Color.WHITE
	visual.clear_dissolve()
	visual.show()
	(_shadows[side] as Node2D).show()
	visual.play(CreatureVisual.STATE_IDLE)
	if not skip_presentation:
		visual.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(visual, "scale", Vector2.ONE, SEND_OUT_SECONDS).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	else:
		visual.scale = Vector2.ONE
	_refresh_panels()


## A short step toward the opponent and back, so an attack reads as an attack
## even for a species whose sprite has no attack animation yet.
func _lunge(side: int) -> void:
	if skip_presentation:
		return
	var visual: CreatureVisual = _visual_for(side)
	var home: Vector2 = _homes[side]
	var direction: float = 1.0 if side == BattleTeam.Side.PLAYER else -1.0
	var tween := create_tween()
	tween.tween_property(visual, "position", home + Vector2(LUNGE_DISTANCE * direction, 0), 0.12)
	tween.tween_property(visual, "position", home, 0.16)


func _dodge(side: int) -> void:
	if skip_presentation:
		return
	var visual: CreatureVisual = _visual_for(side)
	var home: Vector2 = _homes[side]
	var tween := create_tween()
	tween.tween_property(visual, "position", home + Vector2(0, -14), 0.08)
	tween.tween_property(visual, "position", home, 0.12)


## A rising "-12" over the creature that was hit, coloured by how well the move
## landed. Presentation only: the exact numbers live in the status panels.
func _show_damage(side: int, amount: int, multiplier: float) -> void:
	if skip_presentation or amount <= 0:
		return
	var label := Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", _damage_color(multiplier))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 5)
	stage.add_child(label)
	label.size = Vector2(DAMAGE_NUMBER_WIDTH, float(DAMAGE_NUMBER_FONT_SIZE))
	var home: Vector2 = _homes[side]
	var start: Vector2 = home + DAMAGE_NUMBER_OFFSET - Vector2(DAMAGE_NUMBER_WIDTH * 0.5, 0.0)
	label.position = start

	var tween := create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(
			label, "position", start + Vector2(0.0, -DAMAGE_NUMBER_RISE), DAMAGE_NUMBER_SECONDS
		)
		. set_trans(Tween.TRANS_QUINT)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "modulate:a", 0.0, DAMAGE_NUMBER_SECONDS * 0.45).set_delay(
		DAMAGE_NUMBER_SECONDS * 0.55
	)
	tween.chain().tween_callback(label.queue_free)


func _damage_color(multiplier: float) -> Color:
	if multiplier > 1.0:
		return DAMAGE_STRONG_COLOR
	if multiplier > 0.0 and multiplier < 1.0:
		return DAMAGE_WEAK_COLOR
	return DAMAGE_NEUTRAL_COLOR


## A short knock on the whole stage, so a landed hit carries some weight. Only
## the stage moves; the status windows and the message log stay put.
func _shake_stage(multiplier: float) -> void:
	if skip_presentation:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var strength: float = SHAKE_STRENGTH * (SHAKE_STRONG_SCALE if multiplier > 1.0 else 1.0)
	var step: float = SHAKE_SECONDS / float(SHAKE_STEPS + 1)
	_shake_tween = create_tween()
	for index: int in SHAKE_STEPS:
		var falloff: float = 1.0 - float(index) / float(SHAKE_STEPS)
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		var offset := Vector2(strength * falloff * direction, strength * falloff * 0.4)
		_shake_tween.tween_property(stage, "position", offset, step)
	_shake_tween.tween_property(stage, "position", Vector2.ZERO, step)


func _flash(visual: CreatureVisual, color: Color) -> void:
	if skip_presentation:
		return
	var tween := create_tween()
	tween.tween_property(visual, "modulate", color, 0.08)
	tween.tween_property(visual, "modulate", Color.WHITE, 0.2)


## Plays a move's spell effect between the two creatures. The effect itself is
## content: see [VfxPreset]. A move with no preset still shows its element's
## stock effect, so this never has to check for one.
func _play_move_vfx(side: int, move: MoveData) -> void:
	if skip_presentation:
		return
	var target_side: int = _opposing(side)
	VfxPlayer.play_move(
		stage, move, _homes[side], _homes[target_side], side == BattleTeam.Side.ENEMY
	)


func _opposing(side: int) -> int:
	return BattleTeam.Side.ENEMY if side == BattleTeam.Side.PLAYER else BattleTeam.Side.PLAYER


## Takes a creature off the stage. Real art breaks apart into flecks of light;
## a placeholder has no canvas item of its own to dissolve, so it fades.
func _take_off_stage(side: int) -> void:
	var visual: CreatureVisual = _visual_for(side)
	(_shadows[side] as Node2D).hide()
	if skip_presentation:
		visual.hide()
		return
	_play_vfx(DEFEAT_VFX, visual)
	if visual.prepare_dissolve():
		create_tween().tween_property(visual, "dissolve", 1.0, DISSOLVE_SECONDS)
	else:
		create_tween().tween_property(visual, "modulate:a", 0.0, 0.3)


## Plays a one-off effect on top of a creature.
func _play_vfx(preset: VfxPreset, on: CreatureVisual) -> void:
	if skip_presentation:
		return
	VfxPlayer.play_global(stage, preset, on.global_position)


func _tween_hp(side: int) -> void:
	var creature: CreatureInstance = _team(side).active().creature
	var bar: ProgressBar = _hp_bars[side]
	if _hp_tweens.has(side) and (_hp_tweens[side] as Tween).is_valid():
		(_hp_tweens[side] as Tween).kill()
	if skip_presentation:
		_set_hp_display(float(creature.current_hp), side)
		return
	var tween := create_tween()
	tween.tween_method(
		_set_hp_display.bind(side), bar.value, float(creature.current_hp), HP_TWEEN_SECONDS
	)
	_hp_tweens[side] = tween


func _set_hp_display(value: float, side: int) -> void:
	var creature: CreatureInstance = _team(side).active().creature
	var bar: ProgressBar = _hp_bars[side]
	var max_hp: int = creature.max_hp()
	bar.max_value = max_hp
	bar.value = value
	(_hp_labels[side] as Label).text = "%d / %d" % [int(round(value)), max_hp]
	var fraction: float = value / float(maxi(1, max_hp))
	var fill: StyleBoxFlat = _hp_fills[side]
	if fraction <= HP_CRITICAL_FRACTION:
		fill.bg_color = HP_CRITICAL_COLOR
	elif fraction <= HP_WARY_FRACTION:
		fill.bg_color = HP_WARY_COLOR
	else:
		fill.bg_color = HP_HEALTHY_COLOR


func _refresh_panels() -> void:
	for side: int in _visuals:
		_refresh_panel(side)


## Everything Specification 22.5 asks for: name, level, types, exact HP.
func _refresh_panel(side: int) -> void:
	if engine == null:
		return
	var battler: Battler = _team(side).active()
	if battler == null:
		return
	var creature: CreatureInstance = battler.creature
	(_name_labels[side] as Label).text = creature.display_name().to_upper()
	(_level_labels[side] as Label).text = "Lv %d" % creature.level
	(_type_labels[side] as Label).text = creature.species.type_display_name().to_upper()
	_refresh_status_badges(side, battler)
	if not (_hp_tweens.has(side) and (_hp_tweens[side] as Tween).is_running()):
		_set_hp_display(float(creature.current_hp), side)
	if side == BattleTeam.Side.PLAYER:
		var into_level: int = creature.xp_into_current_level()
		var span: int = into_level + creature.xp_to_next_level()
		player_xp_bar.max_value = maxi(1, span)
		player_xp_bar.value = into_level if span > 0 else 1


## Status conditions are core to how a battle is going, so each active one
## shows as a coloured badge next to the creature's types (Specification 12).
func _refresh_status_badges(side: int, battler: Battler) -> void:
	var row: HBoxContainer = _status_rows[side]
	for badge: Node in row.get_children():
		row.remove_child(badge)
		badge.queue_free()
	for status: StatusIds.Status in StatusIds.ALL:
		if battler.has_status(status):
			row.add_child(_status_badge(status))


func _status_badge(status: StatusIds.Status) -> Label:
	var badge := Label.new()
	badge.text = String(STATUS_BADGE_TEXT.get(status, "???"))
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", STATUS_BADGE_FONT_SIZE)
	badge.add_theme_color_override("font_color", STATUS_BADGE_TEXT_COLOR)
	var style := StyleBoxFlat.new()
	var color: Color = STATUS_BADGE_COLORS.get(status, Color.GRAY)
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", style)
	return badge


func _say(text: String) -> void:
	message_label.text = text


func _wait(seconds: float) -> void:
	if skip_presentation or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout


## Waits for the message hold, or until the player presses interact.
func _hold(seconds: float) -> void:
	_skip_requested = false
	if skip_presentation or not is_inside_tree():
		return
	var elapsed: float = 0.0
	while elapsed < seconds and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_skip_requested = false


func _visual_for(side: int) -> CreatureVisual:
	return _visuals[side]


func _team(side: int) -> BattleTeam:
	return engine.player if side == BattleTeam.Side.PLAYER else engine.enemy
