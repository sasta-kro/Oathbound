class_name DialoguePanel
extends CanvasLayer
## The line of dialogue at the bottom of the field, with optional replies.
##
## [method show_line] is plain speech the interact key dismisses. [method ask]
## shows a line with a short list of replies (Specification 18.2) and
## resolves to the index the player picks: move up and down to choose,
## interact to confirm, or click. While replies are on screen the panel
## swallows those inputs itself, so the overworld never sees the confirm
## press as a "close dialogue".

## The reply the player picked from [method ask].
signal choice_made(index: int)

const OPTION_PREFIX := "▸  "
const OPTION_IDLE_PREFIX := "    "

@onready var panel: PanelContainer = $Panel
@onready var dialogue_text: Label = $Panel/Margin/DialogueText
var _entrance: Tween
var _prompt: Label
var _choices: VBoxContainer
var _option_buttons: Array[Button] = []
var _selected: int = 0

func _ready() -> void:
	panel.theme = OathTheme.make()
	panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.5), 8, 0))
	dialogue_text.add_theme_font_size_override("font_size", 16)
	var margin: MarginContainer = $Panel/Margin
	margin.remove_child(dialogue_text)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var caption := HBoxContainer.new()
	content.add_child(caption)
	caption.add_child(OathTheme.label("BY THE ROADSIDE", 9, OathTheme.GOLD))
	caption.add_child(OathTheme.spacer(false))
	_prompt = OathTheme.label("E  /  CONTINUE", 9, OathTheme.MUTED)
	caption.add_child(_prompt)
	content.add_child(dialogue_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	content.add_child(_choices)
	_choices.hide()
	panel.hide()

func show_line(line: String) -> void:
	_clear_choices()
	dialogue_text.text = line
	_prompt.text = "E  /  CONTINUE"
	_reveal()

## Shows [param line] with [param options] to reply with and returns the
## index chosen. Awaiting it pauses the caller until the player decides.
func ask(line: String, options: PackedStringArray) -> int:
	if options.is_empty():
		show_line(line)
		return -1
	_clear_choices()
	dialogue_text.text = line
	_prompt.text = "W / S  CHOOSE   ·   E  REPLY"
	for index: int in options.size():
		var button := Button.new()
		button.text = options[index]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 22
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_confirm.bind(index))
		button.mouse_entered.connect(_select.bind(index))
		_choices.add_child(button)
		_option_buttons.append(button)
	_choices.show()
	_select(0)
	_reveal()
	var chosen: int = await choice_made
	return chosen

## Closes the panel. A question still waiting on the player resolves as
## "no reply" (-1), so nothing awaiting it is left hanging.
func close() -> void:
	var was_asking: bool = is_asking()
	_clear_choices()
	panel.hide()
	if was_asking:
		choice_made.emit(-1)

func is_open() -> bool:
	return panel.visible

## Whether replies are on screen waiting for the player.
func is_asking() -> bool:
	return is_open() and not _option_buttons.is_empty()

func selected_index() -> int:
	return _selected

func _unhandled_input(event: InputEvent) -> void:
	if not is_asking():
		return
	if event.is_action_pressed(&"move_up"):
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact"):
		_confirm(_selected)
	else:
		return
	get_viewport().set_input_as_handled()

func _select(index: int) -> void:
	if _option_buttons.is_empty():
		return
	_selected = wrapi(index, 0, _option_buttons.size())
	for i: int in _option_buttons.size():
		var button: Button = _option_buttons[i]
		var active: bool = i == _selected
		button.text = (OPTION_PREFIX if active else OPTION_IDLE_PREFIX) + button.text.trim_prefix(OPTION_PREFIX).trim_prefix(OPTION_IDLE_PREFIX)
		button.add_theme_color_override("font_color", OathTheme.GOLD if active else OathTheme.MUTED)

func _confirm(index: int) -> void:
	if not is_asking():
		return
	_clear_choices()
	choice_made.emit(index)

func _clear_choices() -> void:
	for button: Button in _option_buttons:
		_choices.remove_child(button)
		button.queue_free()
	_option_buttons.clear()
	_selected = 0
	_choices.hide()

func _reveal() -> void:
	panel.show()
	if _entrance != null: _entrance.kill()
	panel.modulate.a = 0
	_entrance = create_tween()
	_entrance.tween_property(panel, "modulate:a", 1.0, 0.15)
