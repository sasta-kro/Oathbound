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
##
## A passage with blank lines in it is a passage in several boxes. The panel
## shows one at a time and the interact key walks them, so a long speech is
## read at the player's pace instead of filling half the screen at once. The
## speaker's name is taken off the front of the whole passage, so the caption
## stands over every box of it. A question's replies appear on the last box,
## which is the one that actually asks.

## The reply the player picked from [method ask].
signal choice_made(index: int)
## A plain line was closed, whether by the player or by the field.
signal dismissed

const OPTION_PREFIX := "▸  "
const OPTION_IDLE_PREFIX := "    "
## Content writes a spoken line as "Elder: Good morning." The panel shows the
## name in the caption and the words on their own, so the speaker is never
## read twice.
const SPEAKER_SEPARATOR := ": "
## The longest a caption may be. Past this the colon belongs to the sentence
## rather than to a speaker ("One thing: the road is long").
const SPEAKER_MAX_LENGTH := 28
## Punctuation a name never contains, so a sentence that happens to hold a
## colon is left alone.
const SPEAKER_FORBIDDEN := ".!?,;\"\n"

@onready var panel: PanelContainer = $Panel
@onready var dialogue_text: Label = $Panel/Margin/DialogueText
## Who is talking, over the line. Hidden for narration.
var speaker_label: Label
var _entrance: Tween
var _prompt: Label
var _choices: VBoxContainer
var _option_buttons: Array[Button] = []
var _selected: int = 0
## Who is speaking the passage, taken off its front once and kept over every
## box of it.
var _speaker: String = ""
## The passage being read, already split into boxes, and which one is up.
var _pages: PackedStringArray = []
var _page: int = 0
## Replies waiting for the last box of the passage. Empty for plain speech.
var _pending_options: PackedStringArray = []

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
	speaker_label = OathTheme.label("", 9, OathTheme.GOLD)
	caption.add_child(speaker_label)
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
	_begin(line, PackedStringArray())
	_reveal()


## Splits a passage into its boxes on blank lines. A passage with no blank
## line in it is one box, so nothing that was written as a single line is
## broken up.
static func pages_of(body: String) -> PackedStringArray:
	var pages: PackedStringArray = []
	for chunk: String in body.split("\n\n", false):
		var page: String = chunk.strip_edges()
		if not page.is_empty():
			pages.append(page)
	if pages.is_empty():
		pages.append(body.strip_edges())
	return pages


## Moves to the next box of the passage. True when there was one, so the
## overworld knows the interact key was spent here rather than on closing.
func advance() -> bool:
	if not is_open() or is_asking():
		return false
	if _page + 1 >= _pages.size():
		return false
	_page += 1
	_render()
	return true


## Walks to the last box of the passage, which is where a question's replies
## live. What a player does by holding the interact key down.
func read_through() -> void:
	while advance():
		pass


## Whether the passage has more boxes after the one on screen.
func has_more_pages() -> bool:
	return is_open() and _page + 1 < _pages.size()


func page_count() -> int:
	return _pages.size()


## Takes the speaker off the passage and breaks the rest into boxes.
func _begin(line: String, options: PackedStringArray) -> void:
	var parts: PackedStringArray = split_speaker(line)
	_speaker = parts[0]
	_pages = pages_of(parts[1])
	_page = 0
	_pending_options = options
	_render()


## Draws the box that is up, with the replies if it is the last one.
func _render() -> void:
	_clear_choices()
	speaker_label.visible = not _speaker.is_empty()
	speaker_label.text = _speaker.to_upper()
	dialogue_text.text = _pages[_page] if _page < _pages.size() else ""
	if _pending_options.is_empty() or _page + 1 < _pages.size():
		_prompt.text = "E  /  MORE" if _page + 1 < _pages.size() else "E  /  CONTINUE"
		return
	_build_options(_pending_options)


## Splits "Elder: Good morning." into the speaker and what they said. A line
## with no name in front of it comes back with an empty speaker, and is shown
## as narration.
static func split_speaker(line: String) -> PackedStringArray:
	var at: int = line.find(SPEAKER_SEPARATOR)
	if at <= 0 or at > SPEAKER_MAX_LENGTH:
		return ["", line]
	var name: String = line.substr(0, at)
	for character: String in SPEAKER_FORBIDDEN:
		if character in name:
			return ["", line]
	return [name, line.substr(at + SPEAKER_SEPARATOR.length())]


## The words alone, without the speaker's name.
static func body_of(line: String) -> String:
	return split_speaker(line)[1]


## The first box of a passage, which is what the panel shows when the line
## opens. The same as [method body_of] for anything written as one box.
static func first_page_of(line: String) -> String:
	return pages_of(body_of(line))[0]


func _set_line(line: String) -> void:
	_begin(line, PackedStringArray())

## Shows [param line] and waits until it is closed, for scripted scenes that
## play several lines in a row.
func say(line: String) -> void:
	show_line(line)
	await dismissed

## Shows [param line] with [param options] to reply with and returns the
## index chosen. Awaiting it pauses the caller until the player decides.
func ask(line: String, options: PackedStringArray) -> int:
	if options.is_empty():
		show_line(line)
		return -1
	_begin(line, options)
	_reveal()
	var chosen: int = await choice_made
	return chosen


## Puts the replies on screen under the last box of the passage.
func _build_options(options: PackedStringArray) -> void:
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

## Closes the panel. A question still waiting on the player resolves as
## "no reply" (-1), so nothing awaiting it is left hanging.
func close() -> void:
	var was_asking: bool = is_asking()
	var was_open: bool = is_open()
	_clear_choices()
	panel.hide()
	if was_asking:
		choice_made.emit(-1)
	elif was_open:
		dismissed.emit()

func is_open() -> bool:
	return panel.visible

## Whether replies are on screen waiting for the player.
func is_asking() -> bool:
	return is_open() and not _option_buttons.is_empty()


## Whether the passage being read ends in a question, even while the replies
## are still boxes away. The overworld protects one of these from keys that
## would otherwise close a line, so a question cannot be lost by swinging
## part-way through the ask.
func has_question() -> bool:
	return is_open() and not _pending_options.is_empty()

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
