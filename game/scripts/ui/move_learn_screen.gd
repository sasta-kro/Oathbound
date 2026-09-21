class_name MoveLearnScreen
extends CanvasLayer
## The replace-or-refuse choice a companion's fifth move asks for
## (Specification 9.8).
##
## Four move slots is the limit, so a move grown into with all four full has
## to take one of their places or be let go. A battle cannot stop to ask, so
## the offers wait in [member GameState.pending_move_learns] and the field
## hands them here one at a time once the world is calm, the same way it
## hands evolutions to [EvolutionScreen].
##
## The screen is built in code in the same visual language as [EvolutionScreen].

## The choice is made and the screen has closed.
signal finished

const KICKER_TEXT := "◇   A NEW TECHNIQUE"
const OFFER_TEXT := "%s wants to learn %s!"
const EXPLAIN_TEXT := (
	"Four moves is the limit. Choose the one to forget, or keep the set as it stands."
)
const KEEP_LABEL := "KEEP CURRENT MOVES"
const KEEP_HINT := "%s does not learn %s. It can be taught later in Hearthside."
const FORGET_HINT := "Forget %s to make room for %s."
const REPLACED_TEXT := "%s forgot %s and learned %s!"
const REFUSED_TEXT := "%s did not learn %s."
const CONTINUE_HINT := "PRESS ANY KEY TO CONTINUE"
const CONTROL_HINT := "W/S OR ARROWS  CHOOSE     E/ENTER  CONFIRM     Q  KEEP"
## Input arriving sooner than this is ignored, so a key still being mashed
## from the battle that just ended cannot answer the offer by itself.
const INPUT_GRACE_SECONDS := 0.8

const CURSOR_PREFIX := "▶ "
const IDLE_PREFIX := "  "
const ROW_FONT_SIZE := 14
const ROW_STYLE_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
const ROW_HIGHLIGHT_COLOR := Color("2b4037")
const COLUMN_WIDTH := 460.0

var _root: Control
var _kicker: Label
var _caption: Label
var _summary: Label
var _explain: Label
var _rows: VBoxContainer
var _hint: Label
var _tween: Tween

var _creature: CreatureInstance
var _move: MoveData
## One entry per row: the slot to replace, or -1 for the refusal row.
var _slots: Array[int] = []
var _buttons: Array[Button] = []
var _cursor: int = 0
var _playing := false
var _awaiting_dismiss := false
var _closing := false
var _started_at := 0
var _idle_row_style: StyleBoxEmpty
var _selected_row_style: StyleBoxFlat


func _ready() -> void:
	layer = 8
	_build_row_styles()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = OathTheme.make()
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(OathTheme.INK, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	_kicker = _centered(OathTheme.label(KICKER_TEXT, 9, OathTheme.GOLD))
	column.add_child(_kicker)
	_caption = _centered(OathTheme.heading("", 26))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(_caption)
	_summary = _centered(OathTheme.paragraph("", 11, OathTheme.JADE))
	_summary.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(_summary)
	column.add_child(OathTheme.rule())
	_explain = _centered(OathTheme.paragraph(EXPLAIN_TEXT, 11))
	_explain.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(_explain)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	column.add_child(_rows)
	_hint = _centered(OathTheme.label(CONTROL_HINT, 9, OathTheme.MUTED))
	column.add_child(_hint)
	hide()


func is_playing() -> bool:
	return _playing


## Puts [param move] to [param creature] and applies the answer. Resolves once
## the player has dismissed the result; returns false without showing anything
## when there is nothing to ask, such as a move the creature already knows or
## one that would simply fit.
func play(creature: CreatureInstance, move: MoveData) -> bool:
	if _playing or creature == null or move == null:
		return false
	if creature.knows_move(move) or creature.has_free_move_slot():
		return false
	_playing = true
	_awaiting_dismiss = false
	_closing = false
	_creature = creature
	_move = move
	_started_at = Time.get_ticks_msec()
	_kicker.text = KICKER_TEXT
	_caption.text = OFFER_TEXT % [creature.display_name(), move.display_name]
	_summary.text = describe(move)
	_explain.text = EXPLAIN_TEXT
	_explain.show()
	_hint.text = CONTROL_HINT
	_build_rows()
	_root.modulate.a = 1.0
	show()
	await finished
	return true


## A one-line account of what [param move] does, the same facts the battle
## menu puts under a move it is offering.
static func describe(move: MoveData) -> String:
	var parts: PackedStringArray = [Elements.display_name(move.type).to_upper()]
	if move.is_damaging():
		parts.append("Power %d" % move.power)
		parts.append("Accuracy %d%%" % move.accuracy)
	elif move.heals():
		parts.append("Heals %d%% HP" % move.heal_percent)
	else:
		parts.append("No damage")
	for modifier: StatModifier in move.stat_modifiers:
		if modifier != null:
			parts.append("%s %+d%%" % [Stats.display_name(modifier.stat), modifier.percent])
	if move.cooldown_turns > 0:
		parts.append("Cooldown %d" % move.cooldown_turns)
	return " · ".join(parts)


## Answers the offer as the row under the cursor would.
func confirm() -> void:
	if not _playing or _awaiting_dismiss or _closing:
		return
	choose(_cursor)


## Answers the offer with the row at [param index].
func choose(index: int) -> void:
	if not _playing or _awaiting_dismiss or _closing:
		return
	if index < 0 or index >= _slots.size():
		return
	var slot: int = _slots[index]
	if slot < 0:
		_present_result(REFUSED_TEXT % [_creature.display_name(), _move.display_name])
		return
	var forgotten: String = _creature.moves[slot].display_name
	_creature.replace_move(slot, _move)
	GameState.party_changed.emit()
	_present_result(
		REPLACED_TEXT % [_creature.display_name(), forgotten, _move.display_name]
	)


## Keeps the current moves, as the refusal row does.
func refuse() -> void:
	if not _playing or _awaiting_dismiss or _closing:
		return
	choose(_slots.size() - 1)


## Closes the screen once the result is showing.
func dismiss() -> void:
	if not _awaiting_dismiss or _closing:
		return
	_closing = true
	_awaiting_dismiss = false
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(_close)


func _close() -> void:
	hide()
	_playing = false
	_closing = false
	_creature = null
	_move = null
	finished.emit()


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	# Nothing reaches the field or its menus while the screen is up.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _started_at < INPUT_GRACE_SECONDS * 1000:
		return
	if _awaiting_dismiss:
		var pressed: bool = (
			(event is InputEventKey and event.pressed and not event.echo)
			or (event is InputEventMouseButton and event.pressed)
			or (event is InputEventJoypadButton and event.pressed)
		)
		if pressed:
			dismiss()
		return
	if event.is_action_pressed(&"move_up"):
		_set_cursor(_cursor - 1)
	elif event.is_action_pressed(&"move_down"):
		_set_cursor(_cursor + 1)
	elif event.is_action_pressed(&"interact"):
		confirm()
	elif event.is_action_pressed(&"cancel"):
		refuse()


func _build_rows() -> void:
	for button: Button in _buttons:
		_rows.remove_child(button)
		button.queue_free()
	_buttons.clear()
	_slots.clear()
	for slot: int in _creature.moves.size():
		var known: MoveData = _creature.moves[slot]
		_add_row(
			"%s   %s" % [known.display_name, describe(known)],
			slot,
			FORGET_HINT % [known.display_name, _move.display_name],
		)
	_add_row(KEEP_LABEL, -1, KEEP_HINT % [_creature.display_name(), _move.display_name])
	_set_cursor(0)


func _add_row(label: String, slot: int, hint: String) -> void:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = hint
	button.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	button.text = IDLE_PREFIX + label
	var index: int = _buttons.size()
	button.pressed.connect(choose.bind(index))
	button.mouse_entered.connect(_set_cursor.bind(index))
	_style_row(button, false)
	_rows.add_child(button)
	_buttons.append(button)
	_slots.append(slot)


func _set_cursor(index: int) -> void:
	if _buttons.is_empty():
		return
	_cursor = posmod(index, _buttons.size())
	for position: int in _buttons.size():
		var selected: bool = position == _cursor
		var button: Button = _buttons[position]
		var label: String = button.text.substr(IDLE_PREFIX.length())
		if button.text.begins_with(CURSOR_PREFIX):
			label = button.text.substr(CURSOR_PREFIX.length())
		button.text = (CURSOR_PREFIX if selected else IDLE_PREFIX) + label
		_style_row(button, selected)


## Swaps the offer out for what the answer did, and waits to be dismissed.
func _present_result(text: String) -> void:
	_awaiting_dismiss = true
	_started_at = Time.get_ticks_msec()
	for button: Button in _buttons:
		button.hide()
	_kicker.text = KICKER_TEXT
	_caption.text = text
	_summary.text = ""
	_explain.hide()
	_hint.text = CONTINUE_HINT


func _build_row_styles() -> void:
	_idle_row_style = StyleBoxEmpty.new()
	_apply_row_margins(_idle_row_style)
	_selected_row_style = StyleBoxFlat.new()
	_selected_row_style.bg_color = ROW_HIGHLIGHT_COLOR
	_selected_row_style.border_width_left = 3
	_selected_row_style.border_color = OathTheme.GOLD
	_selected_row_style.set_corner_radius_all(4)
	_apply_row_margins(_selected_row_style)


func _apply_row_margins(style: StyleBox) -> void:
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4


func _style_row(button: Button, selected: bool) -> void:
	var style: StyleBox = _selected_row_style if selected else _idle_row_style
	for state: String in ROW_STYLE_STATES:
		button.add_theme_stylebox_override(state, style)
	var color: Color = OathTheme.PAPER if selected else OathTheme.MUTED
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
