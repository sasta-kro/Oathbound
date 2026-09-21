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

enum Menu { NONE, COMMAND, MOVES, PARTY, TARGET, ITEMS, ITEM_TARGET }


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
## The scroll is offered, the seal closes twice, then the roll lands.
const BIND_SECONDS := 1.2
## Beat between the seal's closing and the bound creature leaving.
const BIND_SUCCESS_SECONDS := 0.35
const BIND_FAIL_SECONDS := 0.3
## When each extra seal closes during a bind attempt, in seconds.
const BIND_CLOSE_DELAYS: Array[float] = [0.3, 0.7]

const WILD_CAPTION := "W I L D   E N C O U N T E R"
const TRAINER_CAPTION := "O A T H K E E P E R   B A T T L E"
const BOSS_CAPTION := "B O S S   B A T T L E"

const HP_HEALTHY_COLOR := Color("a1cdb5")
const HP_WARY_COLOR := Color("e0b23a")
const HP_CRITICAL_COLOR := Color("d1453b")
const HP_WARY_FRACTION := 0.5
const HP_CRITICAL_FRACTION := 0.2

## Effects shared with the rest of the game: see [VfxPreset].
const HIT_VFX: VfxPreset = preload("res://content/vfx/vfx_hit_impact.tres")
const HIT_SPARKS_VFX: VfxPreset = preload("res://content/vfx/vfx_hit_sparks.tres")
const DEFEAT_VFX: VfxPreset = preload("res://content/vfx/vfx_defeat_sparks.tres")
const BIND_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_seal.tres")
const BIND_MOTES_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_motes.tres")
const BIND_CLOSE_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_seal_close.tres")
const BIND_SUCCESS_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_sparks.tres")
const BIND_BREAK_VFX: VfxPreset = preload("res://content/vfx/vfx_bind_break.tres")
## A hit that lands well is drawn bigger; one that barely lands, smaller.
const HIT_STRONG_SCALE := 1.4
const HIT_WEAK_SCALE := 0.75
## Poison and burn ticks are quieter than a landed blow.
const STATUS_DAMAGE_SCALE := 0.7
const DISSOLVE_SECONDS := 0.8

const HIT_FLASH_COLOR := Color(1.0, 0.45, 0.45)
const BIND_FLASH_COLOR := Color(1.0, 0.85, 0.35)
const BIND_SEALED_FLASH_COLOR := Color(1.0, 0.98, 0.9)
## Ash of a crumbled scroll.
const BIND_BREAK_SPARK_CORE := Color(0.85, 0.82, 0.78)
const BIND_BREAK_SPARK_EDGE := Color(0.4, 0.33, 0.3)
const DISABLED_TEXT_COLOR := Color(0.55, 0.55, 0.55)
const MENU_TEXT_COLOR := Color(0.87, 0.87, 0.83)
const MENU_SELECTED_TEXT_COLOR := Color(1.0, 0.97, 0.85)
const MENU_HIGHLIGHT_COLOR := Color("2b4037")
const MENU_HIGHLIGHT_BORDER_COLOR := Color("d9bb80")
## Every submenu ends in this row, so backing out is reachable with the mouse
## as well as with the cancel key.
const BACK_LABEL := "BACK"
const BACK_HINT := "Go back. (Q)"
const CURSOR_PREFIX := "▶ "
const IDLE_PREFIX := "  "
const DISMISS_HINT := "  ▼"
const MENU_FONT_SIZE := 14
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

## Turn-order indicator copy (Increment 10). Exactly one indicator is visible
## while a command is chosen: the forced overworld opening owns battle turn
## one, and every later turn defaults to the faster active creature at equal
## action priority.
const FIRST_STRIKE_TEXT := "FIRST STRIKE"
const AMBUSH_TEXT := "AMBUSHES FIRST"
const GOES_FIRST_TEXT := "GOES FIRST"
const SPEED_TIE_TEXT := "SPEED TIE"
const INITIATIVE_FONT_SIZE := 10
const INITIATIVE_SURFACE_COLOR := Color(OathTheme.INK, 0.85)
const INITIATIVE_BORDER_COLOR := Color(OathTheme.GOLD, 0.55)

const DAMAGE_NUMBER_FONT_SIZE := 30
const DAMAGE_NUMBER_WIDTH := 120.0
const DAMAGE_NUMBER_RISE := 34.0
const DAMAGE_NUMBER_SECONDS := 0.7
## Just above the sprite's head. Any higher and the number rises into the
## status windows, which sit in front of the stage.
const DAMAGE_NUMBER_OFFSET := Vector2(0.0, -78.0)
const DAMAGE_NEUTRAL_COLOR := Color(1.0, 0.95, 0.9)
const HEAL_NUMBER_COLOR := Color(0.6, 1.0, 0.6)
const HEAL_FLASH_COLOR := Color(0.6, 1.0, 0.6)
## The guide's banner, under the status windows and above the creatures.
const GUIDE_BANNER_RECT := Rect2(160, 162, 640, 40)
const GUIDE_FONT_SIZE := 14
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
## Optional [BattleGuide] narrowing the player's choices, for tutorials.
## Given to [method start_battle] and dropped when the battle closes.
var guide: BattleGuide
## SPEED TIE belongs to the matchup rather than one side, so it lives under the
## encounter caption instead of in a status panel. Kept as a field so tests and
## refresh logic can reach it.
var speed_tie_label: Label

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
## HP and max HP each bar is currently showing. The engine resolves a whole
## turn before any of it is played back, so a creature's own HP is already the
## end-of-turn value by then; the bars follow these instead and catch up one
## event at a time.
var _shown_hp: Dictionary = {}
var _shown_max_hp: Dictionary = {}
## Tweens currently moving, tinting or dissolving each side's creature. The
## visual node is reused from one creature to the next, so a creature arriving
## mid-turn has to cut short whatever was still playing on the one it replaced.
var _visual_tweens: Dictionary = {}
var _shake_tween: Tween
var _idle_row_style: StyleBoxEmpty
## The spaced-out heading above the stage; follows the kind of battle.
var _caption: Label
var _guide_banner: PanelContainer
var _guide_label: Label
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
@onready var player_initiative_badge: Label = %PlayerInitiativeBadge
@onready var enemy_initiative_badge: Label = %EnemyInitiativeBadge
@onready var command_list: VBoxContainer = %CommandList
@onready var message_label: Label = %MessageLabel


func _ready() -> void:
	root.theme = OathTheme.make()
	_polish_chrome()
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
	_style_initiative_badge(player_initiative_badge)
	_style_initiative_badge(enemy_initiative_badge)
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
## once the opening presentation is done and the player is choosing. A
## [param with_guide] walks the player through it; see [BattleGuide].
func start_battle(config: BattleConfig, with_guide: BattleGuide = null) -> void:
	engine = BattleEngine.new(config)
	guide = with_guide
	_refresh_guide_banner()
	_awaiting_dismiss = false
	_caption.text = caption_for(config)
	_close_menu()
	_hide_initiative_indicators()
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


## The heading shown above the stage for [param config].
static func caption_for(config: BattleConfig) -> String:
	if config.is_boss:
		return BOSS_CAPTION
	return WILD_CAPTION if config.is_wild else TRAINER_CAPTION


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
		# The command menu has nowhere to back out to, so the action remains
		# unhandled there.
		if not _cancel_menu():
			return
	else:
		return
	get_viewport().set_input_as_handled()


# --- Menus -------------------------------------------------------------------


func _continue() -> void:
	match engine.phase:
		BattleEngine.Phase.REPLACING:
			_open_party_menu(true)
		BattleEngine.Phase.ENDED:
			_finish()
		_:
			_open_command_menu()


func _open_command_menu() -> void:
	_refresh_initiative_indicators()
	_refresh_guide_banner()
	var options: Dictionary = engine.options()
	var active: Battler = engine.player.active()
	_begin_menu(Menu.COMMAND)
	_add_guided_entry(
		BattleGuide.FIGHT,
		"FIGHT",
		_open_moves_menu,
		"Choose one of %s's moves." % active.display_name(),
	)
	_add_guided_entry(
		BattleGuide.SWITCH,
		"SWITCH",
		_open_party_menu.bind(false),
		"Switch to another Oathbound. This uses your turn.",
		bool(options["can_switch"]),
		String(options["switch_reason"]),
	)
	_add_guided_entry(
		BattleGuide.ITEM,
		"ITEM",
		_open_item_menu,
		"Use an item from your satchel. This uses your turn.",
		bool(options["can_item"]),
		String(options["item_reason"]),
	)
	_add_guided_entry(
		BattleGuide.BIND,
		"BIND",
		_choose_bind,
		_bind_hint(),
		bool(options["can_bind"]),
		String(options["bind_reason"]),
	)
	_add_guided_entry(
		BattleGuide.RUN,
		"RUN",
		_choose_run,
		"Try to escape the battle.",
		bool(options["can_run"]),
		String(options["run_reason"]),
	)
	_end_menu()


## A command row the guide, if any, may hold back. Its own reason wins when
## the rules already forbid the command.
func _add_guided_entry(
	command: StringName,
	label: String,
	callback: Callable,
	hint: String,
	enabled: bool = true,
	disabled_reason: String = ""
) -> void:
	if enabled and guide != null and not guide.allows_command(engine, command):
		enabled = false
		disabled_reason = guide.instruction(engine)
	_add_entry(label, callback, hint, enabled, disabled_reason)


func _open_moves_menu() -> void:
	var active: Battler = engine.player.active()
	_begin_menu(Menu.MOVES)
	for move: MoveData in active.creature.moves:
		var ready: bool = active.is_move_ready(move)
		var remaining: int = active.cooldown_remaining(move)
		var label: String = (
			move.display_name if ready else "%s (%d)" % [move.display_name, remaining]
		)
		var reason: String = "%s is cooling down for %d more turns." % [move.display_name, remaining]
		if ready and guide != null and not guide.allows_move(engine, move):
			ready = false
			reason = guide.instruction(engine)
		_add_entry(label, _choose_move.bind(move), _move_hint(move), ready, reason)
	if not active.has_ready_move():
		_add_entry("WAIT", _choose_wait, "Every move is cooling down. Wait out the turn.")
	_add_back_entry()
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
		var allowed: bool = bench.has(index)
		if allowed and guide != null and not guide.allows_switch(engine, index):
			allowed = false
			reason = guide.instruction(engine)
		_add_entry(label, callback, "Send out %s." % creature.display_name(), allowed, reason)
	if not forced:
		_add_back_entry()
	_end_menu()
	if forced:
		_hide_initiative_indicators()
		_say("Choose your next Oathbound.")


## Picking who a support move lands on (Specification 11.11, extended): every
## party member is listed, and any conscious one, benched or fighting, can be
## chosen.
func _open_target_menu(move: MoveData) -> void:
	var team: BattleTeam = engine.player
	_begin_menu(Menu.TARGET)
	for index: int in team.battlers.size():
		var creature: CreatureInstance = team.battlers[index].creature
		var where: String = "fighting" if index == team.active_index else "bench"
		var label := "%s  %d/%d  (%s)" % [
			creature.display_name(), creature.current_hp, creature.max_hp(), where
		]
		var allowed: bool = team.can_target_ally(index)
		var reason: String = "%s has fainted." % creature.display_name()
		if allowed and guide != null and not guide.allows_target(engine, move, index):
			allowed = false
			reason = guide.instruction(engine)
		_add_entry(
			label,
			_choose_move_on.bind(move, index),
			"Use %s on %s." % [move.display_name, creature.display_name()],
			allowed,
			reason,
		)
	_add_back_entry()
	_end_menu()


## The satchel's battle items (Specification 16.3). An item nobody in the
## party could use right now is listed but greyed out.
func _open_item_menu() -> void:
	var usable: Array[ItemData] = engine.usable_items()
	_begin_menu(Menu.ITEMS)
	for id: StringName in engine.config.item_catalog:
		var item: ItemData = engine.config.item_catalog[id]
		var count: int = engine.item_count(item)
		if count <= 0 or not item.usable_in_battle:
			continue
		_add_entry(
			"%s  x%d" % [item.display_name, count],
			_open_item_target_menu.bind(item),
			item.description,
			usable.has(item),
			"Nobody in your party needs a %s right now." % item.display_name,
		)
	_add_back_entry()
	_end_menu()


## Who the item goes to: every party member, benched or fighting.
func _open_item_target_menu(item: ItemData) -> void:
	var team: BattleTeam = engine.player
	_begin_menu(Menu.ITEM_TARGET)
	for index: int in team.battlers.size():
		var creature: CreatureInstance = team.battlers[index].creature
		var where: String = "fighting" if index == team.active_index else "bench"
		var label := "%s  %d/%d  (%s)" % [
			creature.display_name(), creature.current_hp, creature.max_hp(), where
		]
		var refusal: String = engine.item_refusal(item, index)
		_add_entry(
			label,
			_choose_item.bind(item, index),
			"Use the %s on %s." % [item.display_name, creature.display_name()],
			refusal.is_empty(),
			refusal,
		)
	_add_back_entry()
	_end_menu()


func _add_back_entry() -> void:
	_add_entry(BACK_LABEL, func() -> void: _cancel_menu(), BACK_HINT)


## Steps back out of the open submenu. Returns false when there is nowhere to
## go: the command menu, or the forced menu that picks a replacement for a
## fainted creature.
func _cancel_menu() -> bool:
	match _menu:
		Menu.ITEM_TARGET:
			_open_item_menu()
		Menu.ITEMS:
			_open_command_menu()
		Menu.TARGET:
			_open_moves_menu()
		Menu.MOVES:
			_open_command_menu()
		Menu.PARTY:
			if _party_menu_forced:
				return false
			_open_command_menu()
		_:
			return false
	return true


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


## The cursor starts on the first row that can be chosen, so a guided menu
## opens on the row the guide wants.
func _end_menu() -> void:
	var first: int = 0
	for index: int in _entries.size():
		if _entries[index].enabled:
			first = index
			break
	_set_cursor(first)


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
	if move.targets_ally():
		if move.heals():
			parts.append("Heals %d%% HP" % move.heal_percent)
		for modifier: StatModifier in move.stat_modifiers:
			if modifier != null and modifier.target == StatModifier.Target.SELF:
				parts.append("%s %+d%%" % [Stats.display_name(modifier.stat), modifier.percent])
		parts.append("Any ally, benched or fighting")
	else:
		parts.append("Power %d" % move.power if move.is_damaging() else "No damage")
		parts.append("Accuracy %d%%" % move.accuracy)
	if move.cooldown_turns > 0:
		parts.append("Cooldown %d" % move.cooldown_turns)
	if move.priority > 0:
		parts.append("Priority +%d: resolves before lower-priority actions." % move.priority)
	elif move.priority < 0:
		parts.append("Priority %d: resolves after higher-priority actions." % move.priority)
	var hint: String = " · ".join(parts)
	if move.is_damaging():
		var effectiveness: String = BattleRules.effectiveness_text(
			engine.effectiveness_against_enemy(move)
		)
		if not effectiveness.is_empty():
			hint += "  " + effectiveness
	return hint


func _bind_hint() -> String:
	var chance: float = engine.bind_chance()
	return "Offer a Binding Scroll (%d left). Chance now: %d%%." % [
		engine.binding_scrolls, int(round(chance * 100.0))
	]


# --- Choices -----------------------------------------------------------------


func _choose_move(move: MoveData) -> void:
	# With nobody else able to take it, a support move lands on the user.
	if move.targets_ally() and engine.player.usable_bench_indices().size() > 0:
		_open_target_menu(move)
		return
	_run_turn(BattleAction.use_move(move))


func _choose_move_on(move: MoveData, ally_index: int) -> void:
	_run_turn(BattleAction.use_move(move, ally_index))


func _choose_wait() -> void:
	_run_turn(BattleAction.wait())


func _choose_switch(index: int) -> void:
	_run_turn(BattleAction.switch_to(index))


func _choose_item(item: ItemData, index: int) -> void:
	_run_turn(BattleAction.use_item(item, index))


func _choose_bind() -> void:
	_run_turn(BattleAction.bind())


func _choose_run() -> void:
	_run_turn(BattleAction.run())


func _choose_replacement(index: int) -> void:
	_close_menu()
	await _play_events(_observed(engine.replace_fainted(index)))
	_continue()


func _run_turn(action: BattleAction) -> void:
	_close_menu()
	await _play_events(_observed(engine.take_turn(action)))
	_continue()


## Lets the guide see what just happened before it is played back.
func _observed(events: Array[BattleEvent]) -> Array[BattleEvent]:
	if guide != null:
		guide.observe(engine, events)
	return events


## Closes the screen. When a [member transition] is set the screen is covered
## first, so the caller only has to uncover whatever it put underneath.
func _finish() -> void:
	_awaiting_dismiss = false
	_close_menu()
	_hide_initiative_indicators()
	_guide_banner.hide()
	if transition != null:
		await transition.cover(ScreenTransition.Style.WORLD)
	root.hide()
	battle_finished.emit(engine)


# --- Presentation ------------------------------------------------------------


func _play_events(events: Array[BattleEvent]) -> void:
	_playing = true
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.XP_GAINED:
			GameState.experience_awarded.emit(event.data["creature"], event.data["before_xp"], event.data["before_level"], event.data["xp"])
			continue
		if event.kind == BattleEvent.Kind.LEVEL_UP:
			continue
		_say(event.text)
		await _present(event)
		await _hold(MESSAGE_HOLD_SECONDS)
	_playing = false
	# Anything the playback deliberately held back, a level-up's larger HP bar
	# among it, lands now that there is nothing left to animate.
	_refresh_panels()


func _present(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.SEND_OUT:
			_show_creature(event.side, event.data)
			await _wait(SEND_OUT_SECONDS)
		BattleEvent.Kind.MOVE_USED:
			var used: MoveData = event.data.get("move") as MoveData
			# A support move is cast in place; only an attack steps forward.
			if used == null or not used.targets_ally():
				_visual_for(event.side).play_attack()
				_lunge(event.side)
			_play_move_vfx(event.side, used)
			await _wait(ATTACK_SECONDS)
		BattleEvent.Kind.HEALED:
			# A benched ally is healed off stage; only its line says so.
			if bool(event.data.get("on_field", false)):
				_flash(event.side, HEAL_FLASH_COLOR)
				_show_number(event.side, "+%d" % int(event.data.get("amount", 0)), HEAL_NUMBER_COLOR)
				_tween_hp(event.side, event.data)
				await _wait(HP_TWEEN_SECONDS)
		BattleEvent.Kind.HIT, BattleEvent.Kind.STATUS_DAMAGE:
			var target: CreatureVisual = _visual_for(event.side)
			var multiplier: float = float(event.data.get("multiplier", 1.0))
			target.play(CreatureVisual.STATE_HURT)
			_flash(event.side, HIT_FLASH_COLOR)
			_play_hit_vfx(target, multiplier, event.kind == BattleEvent.Kind.HIT)
			_play_sfx(_hit_sound(multiplier, event.kind == BattleEvent.Kind.HIT))
			_show_damage(event.side, int(event.data.get("damage", 0)), multiplier)
			if event.kind == BattleEvent.Kind.HIT:
				_shake_stage(multiplier)
			_tween_hp(event.side, event.data)
			await _wait(HP_TWEEN_SECONDS)
		BattleEvent.Kind.MISSED:
			_dodge(event.side)
			await _wait(DODGE_SECONDS)
		BattleEvent.Kind.FAINTED:
			var fainted: CreatureVisual = _visual_for(event.side)
			fainted.play(CreatureVisual.STATE_DEATH)
			_play_sfx(&"faint")
			await _wait(FAINT_SECONDS)
			_take_off_stage(event.side)
			_refresh_panels()
		BattleEvent.Kind.BIND_ATTEMPT:
			_play_bind_attempt_vfx()
			_play_sfx(&"bind_attempt")
			await _wait(BIND_SECONDS)
		BattleEvent.Kind.BIND_SUCCESS:
			_flash(BattleTeam.Side.ENEMY, BIND_SEALED_FLASH_COLOR)
			_play_vfx(BIND_SUCCESS_VFX, enemy_visual)
			_play_sfx(&"bind_success")
			await _wait(BIND_SUCCESS_SECONDS)
			_take_off_stage(BattleTeam.Side.ENEMY, BIND_SUCCESS_VFX.at_speed(1.3))
		BattleEvent.Kind.BIND_FAILED:
			_play_sfx(&"bind_fail")
			_play_vfx(BIND_BREAK_VFX, enemy_visual)
			_play_vfx(
				HIT_SPARKS_VFX.recoloured(BIND_BREAK_SPARK_CORE, BIND_BREAK_SPARK_EDGE), enemy_visual
			)
			_dodge(BattleTeam.Side.ENEMY)
			await _wait(BIND_FAIL_SECONDS)
		_:
			_refresh_panels()


## Puts [param side]'s active creature on the stage. [param snapshot] is the
## send-out event's data: the arriving creature's HP at that point in the turn,
## which is not what its own HP says once the whole turn has been resolved.
func _show_creature(side: int, snapshot: Dictionary = {}) -> void:
	var battler: Battler = _team(side).active()
	var visual: CreatureVisual = _visual_for(side)
	# The node outlives the creature standing in it, so the one leaving takes
	# its lunge, flash and fade with it rather than playing them over the
	# newcomer.
	_stop_visual_tweens(side)
	visual.set_creature(battler.creature)
	visual.position = _homes[side]
	visual.modulate = Color.WHITE
	visual.clear_dissolve()
	visual.show()
	(_shadows[side] as Node2D).show()
	visual.play(CreatureVisual.STATE_IDLE)
	if not skip_presentation:
		visual.scale = Vector2(0.6, 0.6)
		(
			_visual_tween(side)
			. tween_property(visual, "scale", Vector2.ONE, SEND_OUT_SECONDS)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	else:
		visual.scale = Vector2.ONE
	var creature: CreatureInstance = battler.creature
	_set_hp_snapshot(
		side,
		int(snapshot.get("hp", creature.current_hp)),
		int(snapshot.get("max_hp", creature.max_hp())),
	)
	_refresh_panels()


## A short step toward the opponent and back, so an attack reads as an attack
## even for a species whose sprite has no attack animation yet.
func _lunge(side: int) -> void:
	if skip_presentation:
		return
	var visual: CreatureVisual = _visual_for(side)
	var home: Vector2 = _homes[side]
	var direction: float = 1.0 if side == BattleTeam.Side.PLAYER else -1.0
	var tween := _visual_tween(side)
	tween.tween_property(visual, "position", home + Vector2(LUNGE_DISTANCE * direction, 0), 0.12)
	tween.tween_property(visual, "position", home, 0.16)


func _dodge(side: int) -> void:
	if skip_presentation:
		return
	var visual: CreatureVisual = _visual_for(side)
	var home: Vector2 = _homes[side]
	var tween := _visual_tween(side)
	tween.tween_property(visual, "position", home + Vector2(0, -14), 0.08)
	tween.tween_property(visual, "position", home, 0.12)


## A rising "-12" over the creature that was hit, coloured by how well the move
## landed. Presentation only: the exact numbers live in the status panels.
func _show_damage(side: int, amount: int, multiplier: float) -> void:
	if amount <= 0:
		return
	_show_number(side, "-%d" % amount, _damage_color(multiplier))


## A number rising over a creature: damage taken or HP restored.
func _show_number(side: int, text: String, color: Color) -> void:
	if skip_presentation or text.is_empty():
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", DAMAGE_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
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


func _flash(side: int, color: Color) -> void:
	if skip_presentation:
		return
	var visual: CreatureVisual = _visual_for(side)
	var tween := _visual_tween(side)
	tween.tween_property(visual, "modulate", color, 0.08)
	tween.tween_property(visual, "modulate", Color.WHITE, 0.2)


## A tween on [param side]'s creature, tracked so [method _stop_visual_tweens]
## can cut it short when that creature leaves the stage.
func _visual_tween(side: int) -> Tween:
	var running: Array = []
	for tween: Tween in _visual_tweens.get(side, []):
		if tween.is_valid():
			running.append(tween)
	var fresh := create_tween()
	running.append(fresh)
	_visual_tweens[side] = running
	return fresh


func _stop_visual_tweens(side: int) -> void:
	for tween: Tween in _visual_tweens.get(side, []):
		if tween.is_valid():
			tween.kill()
	_visual_tweens[side] = []


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


## A landed blow: an impact burst with sparks flying off it, sized by how well
## the move landed. A status tick is the burst alone, smaller, since nothing
## struck the creature.
func _play_hit_vfx(target: CreatureVisual, multiplier: float, struck: bool) -> void:
	if skip_presentation:
		return
	if not struck:
		_play_vfx(HIT_VFX.scaled(STATUS_DAMAGE_SCALE), target)
		return
	var factor: float = 1.0
	if multiplier > 1.0:
		factor = HIT_STRONG_SCALE
	elif multiplier > 0.0 and multiplier < 1.0:
		factor = HIT_WEAK_SCALE
	_play_vfx(HIT_VFX.scaled(factor), target)
	_play_vfx(HIT_SPARKS_VFX.scaled(factor), target)


## The scroll is offered: light gathers over the creature while the seal
## spreads under it, then closes in twice. The roll's result follows as its
## own event.
func _play_bind_attempt_vfx() -> void:
	if skip_presentation:
		return
	_flash(BattleTeam.Side.ENEMY, BIND_FLASH_COLOR)
	_play_vfx(BIND_MOTES_VFX, enemy_visual)
	_play_vfx(BIND_VFX, enemy_visual)
	for index: int in BIND_CLOSE_DELAYS.size():
		# Each closing is tighter and quicker than the one before it.
		var preset: VfxPreset = BIND_CLOSE_VFX.scaled(1.0 - 0.2 * index).at_speed(1.0 + 0.4 * index)
		_play_vfx_after(BIND_CLOSE_DELAYS[index], preset, enemy_visual)


## Plays [param preset] on [param on] after [param seconds], unless the battle
## has closed in the meantime.
func _play_vfx_after(seconds: float, preset: VfxPreset, on: CreatureVisual) -> void:
	if skip_presentation or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
	if not is_active() or not on.visible:
		return
	_play_vfx(preset, on)


## Takes a creature off the stage. Real art breaks apart into flecks of light;
## a placeholder has no canvas item of its own to dissolve, so it fades.
## [param vfx] is what the creature leaves behind: a beaten creature's sparks
## by default, a bound one's seal light when the oath took.
func _take_off_stage(side: int, vfx: VfxPreset = DEFEAT_VFX) -> void:
	var visual: CreatureVisual = _visual_for(side)
	(_shadows[side] as Node2D).hide()
	if skip_presentation:
		visual.hide()
		return
	_play_vfx(vfx, visual)
	if visual.prepare_dissolve():
		_visual_tween(side).tween_property(visual, "dissolve", 1.0, DISSOLVE_SECONDS)
	else:
		_visual_tween(side).tween_property(visual, "modulate:a", 0.0, 0.3)


## The sound of a blow, matched to how well it landed. A status tick is the
## soft one, since nothing struck.
func _hit_sound(multiplier: float, struck: bool) -> StringName:
	if not struck or (multiplier > 0.0 and multiplier < 1.0):
		return &"hit_weak"
	if multiplier > 1.0:
		return &"hit_strong"
	return &"hit"


func _play_sfx(id: StringName) -> void:
	if skip_presentation:
		return
	SfxService.play(id)


## Plays a one-off effect on top of a creature.
func _play_vfx(preset: VfxPreset, on: CreatureVisual) -> void:
	if skip_presentation:
		return
	VfxPlayer.play_global(stage, preset, on.global_position)


## Runs the bar down (or up) to the HP [param snapshot] an event reported.
func _tween_hp(side: int, snapshot: Dictionary) -> void:
	var creature: CreatureInstance = _team(side).active().creature
	var target_hp: int = int(snapshot.get("hp", creature.current_hp))
	var bar: ProgressBar = _hp_bars[side]
	_kill_hp_tween(side)
	_shown_hp[side] = target_hp
	_shown_max_hp[side] = maxi(1, int(snapshot.get("max_hp", creature.max_hp())))
	if skip_presentation:
		_set_hp_display(float(target_hp), side)
		return
	var tween := create_tween()
	tween.tween_method(_set_hp_display.bind(side), bar.value, float(target_hp), HP_TWEEN_SECONDS)
	_hp_tweens[side] = tween


## Puts the bar straight onto [param hp] out of [param max_hp], animating
## nothing. This is where the bar starts from, so a hit has somewhere to fall.
func _set_hp_snapshot(side: int, hp: int, max_hp: int) -> void:
	_kill_hp_tween(side)
	_shown_hp[side] = hp
	_shown_max_hp[side] = maxi(1, max_hp)
	_set_hp_display(float(hp), side)


## The active creature's own max HP, for the moment before any event has
## reported one: the opening of a battle, where the second send-out has not
## been played back yet.
func _live_max_hp(side: int) -> int:
	if engine == null:
		return 1
	var battler: Battler = _team(side).active()
	return battler.creature.max_hp() if battler != null else 1


func _kill_hp_tween(side: int) -> void:
	if _hp_tweens.has(side) and (_hp_tweens[side] as Tween).is_valid():
		(_hp_tweens[side] as Tween).kill()


func _set_hp_display(value: float, side: int) -> void:
	var bar: ProgressBar = _hp_bars[side]
	var max_hp: int = int(_shown_max_hp.get(side, _live_max_hp(side)))
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
		# Mid-playback the creature's own HP is already the end-of-turn value,
		# so only the events may move the bar; between turns the two agree.
		if _playing:
			_set_hp_display(float(_shown_hp.get(side, creature.current_hp)), side)
		else:
			_set_hp_snapshot(side, creature.current_hp, creature.max_hp())
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


# --- Turn-order indicators (Increment 10) -------------------------------------


## Decides which initiative indicator the upcoming turn carries. The forced
## overworld opening owns battle turn one; after that the faster active
## creature is the default actor at equal action priority. Called only when
## the command menu opens, so an indicator never changes while the previous
## turn's events are still playing.
func _refresh_initiative_indicators() -> void:
	var player_text := ""
	var enemy_text := ""
	var tie_visible := false
	if engine != null and engine.phase == BattleEngine.Phase.CHOOSING:
		var opening_turn: bool = engine.turn_number == 0
		if opening_turn and engine.config.opening == BattleConfig.Opening.ADVANTAGE:
			player_text = FIRST_STRIKE_TEXT
		elif opening_turn and engine.config.opening == BattleConfig.Opening.DISADVANTAGE:
			enemy_text = AMBUSH_TEXT
		else:
			var leader: int = engine.speed_leader()
			if leader == BattleTeam.Side.PLAYER:
				player_text = GOES_FIRST_TEXT
			elif leader == BattleTeam.Side.ENEMY:
				enemy_text = GOES_FIRST_TEXT
			else:
				tie_visible = true
	_show_initiative(player_text, enemy_text, tie_visible)


func _hide_initiative_indicators() -> void:
	_show_initiative("", "", false)


func _show_initiative(player_text: String, enemy_text: String, tie_visible: bool) -> void:
	_set_initiative_badge(player_initiative_badge, player_text)
	_set_initiative_badge(enemy_initiative_badge, enemy_text)
	speed_tie_label.visible = tie_visible


func _set_initiative_badge(badge: Label, text: String) -> void:
	badge.text = text
	badge.visible = not text.is_empty()


## The compact gold-on-dark chip both side badges share, styled in code like
## the status badges so no art asset is involved.
func _style_initiative_badge(badge: Label) -> void:
	badge.add_theme_font_size_override("font_size", INITIATIVE_FONT_SIZE)
	badge.add_theme_color_override("font_color", OathTheme.GOLD)
	var style := StyleBoxFlat.new()
	style.bg_color = INITIATIVE_SURFACE_COLOR
	style.border_color = INITIATIVE_BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", style)


func _say(text: String) -> void:
	message_label.text = text


## Shows the guide's current instruction, or hides the banner when there is
## no guide or nothing to say.
func _refresh_guide_banner() -> void:
	var text: String = guide.instruction(engine) if guide != null and engine != null else ""
	_guide_label.text = text
	_guide_banner.visible = not text.is_empty()


func guide_text() -> String:
	return _guide_label.text if _guide_banner.visible else ""


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


func _polish_chrome() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.texture = preload("res://assets/ui/verdant_sanctum.svg")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color(0.65, 0.72, 0.69)
	root.add_child(backdrop)
	root.move_child(backdrop, 1)
	$Root/Ground.hide()
	$Root/Horizon.hide()
	for path in ["PlayerPanel", "EnemyPanel", "BottomBar/CommandPanel", "BottomBar/MessagePanel"]:
		var panel: PanelContainer = root.get_node(path)
		panel.add_theme_stylebox_override("panel", OathTheme.box(Color(OathTheme.INK, 0.96), OathTheme.LINE, 8, 0))
	for title in [player_name, enemy_name]:
		title.add_theme_font_override("font", OathTheme.SERIF)
		title.add_theme_font_size_override("font_size", 27)
	for label in [player_level, enemy_level]:
		label.add_theme_color_override("font_color", OathTheme.GOLD)
		label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_font_size_override("font_size", 16)
	_caption = OathTheme.label(WILD_CAPTION, 9, OathTheme.GOLD)
	_caption.position = Vector2(362, 36)
	_caption.size.x = 236
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_caption)
	speed_tie_label = OathTheme.label(SPEED_TIE_TEXT, INITIATIVE_FONT_SIZE, OathTheme.GOLD)
	speed_tie_label.position = Vector2(362, 50)
	speed_tie_label.size.x = 236
	speed_tie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_tie_label.hide()
	root.add_child(speed_tie_label)
	_guide_banner = PanelContainer.new()
	_guide_banner.position = GUIDE_BANNER_RECT.position
	_guide_banner.size = GUIDE_BANNER_RECT.size
	_guide_banner.add_theme_stylebox_override(
		"panel", OathTheme.box(Color(OathTheme.INK, 0.94), OathTheme.GOLD, 6, 8)
	)
	_guide_label = OathTheme.label("", GUIDE_FONT_SIZE, OathTheme.GOLD)
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_guide_banner.add_child(_guide_label)
	_guide_banner.hide()
	root.add_child(_guide_banner)
