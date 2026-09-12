class_name SaveSlotList
extends VBoxContainer
## One card per save slot, with the actions the host screen allows. The title
## screen loads and erases; the field menu also saves. Anything that throws
## progress away asks twice: the first press turns the button into the
## question, the second answers it, and moving focus away withdraws it.

signal save_requested(slot: int)
signal load_requested(slot: int)
signal erase_requested(slot: int)

const OVERWRITE_QUESTION := "Overwrite this save?"
const LOAD_QUESTION := "Leave unsaved progress behind?"
const ERASE_QUESTION := "Erase for good?"
const EMPTY_TEXT := "Empty"
const CARD_HEIGHT: int = 74

var can_save: bool = false
var can_load: bool = true
var can_erase: bool = true
## Whether loading needs a second press, as it does mid-journey.
var confirm_load: bool = false
## The slot outlined in gold: the one the journey came from.
var highlighted_slot: int = SaveService.NO_SLOT

var _armed: Button
var _first_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	refresh()


## Rebuilds every card from what is on disk right now.
func refresh() -> void:
	_armed = null
	_first_button = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for slot: int in SaveService.all_slots():
		add_child(_card(slot, SaveService.read(slot)))


func focus_first() -> void:
	if _first_button != null:
		_first_button.grab_focus()


## "Town  ·  2 companions  ·  Lead Lv 9  ·  77 coins  ·  Played 1h 02m".
static func summary_line(data: Dictionary) -> String:
	var party: Array = data.get("party", []) if data.get("party") is Array else []
	var lead_level: int = int(party[0].get("level", 1)) if not party.is_empty() and party[0] is Dictionary else 0
	var parts: PackedStringArray = [
		area_name(data),
		"%d companion%s" % [party.size(), "" if party.size() == 1 else "s"],
	]
	if lead_level > 0:
		parts.append("Lead Lv %d" % lead_level)
	parts.append("%d coins" % int(data.get("currency", 0)))
	parts.append("Played %s" % SaveService.describe_duration(int(data.get("play_seconds", 0))))
	return "  ·  ".join(parts)


static func area_name(data: Dictionary) -> String:
	var location: Dictionary = data.get("location", {}) if data.get("location") is Dictionary else {}
	var name := String(location.get("area", "")).get_file().get_basename().replace("_", " ").capitalize()
	return name if not name.is_empty() else "The Verdant Reach"


func _card(slot: int, data: Dictionary) -> Control:
	var empty: bool = data.is_empty()
	var highlighted: bool = slot == highlighted_slot and not empty
	var card := PanelContainer.new()
	card.custom_minimum_size.y = CARD_HEIGHT
	card.add_theme_stylebox_override(
		"panel",
		OathTheme.box(Color("283d37") if highlighted else Color.TRANSPARENT, OathTheme.GOLD if highlighted else OathTheme.LINE, 6, 12)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(OathTheme.label(SaveService.slot_title(slot), 9, OathTheme.GOLD if highlighted else OathTheme.MUTED))
	if empty:
		var heading := OathTheme.heading(EMPTY_TEXT, 20)
		heading.add_theme_color_override("font_color", OathTheme.MUTED)
		text.add_child(heading)
	else:
		text.add_child(OathTheme.heading(area_name(data), 20))
		text.add_child(OathTheme.label(summary_line(data).trim_prefix(area_name(data) + "  ·  "), 10, OathTheme.MUTED))
		text.add_child(OathTheme.label("Saved %s" % SaveService.describe_time(int(data.get("saved_at", 0))), 10, OathTheme.MUTED))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	if can_save and SaveService.is_manual_slot(slot):
		var save := _button("Save here", empty)
		if empty:
			save.pressed.connect(func() -> void: save_requested.emit(slot))
		else:
			_make_confirmable(save, OVERWRITE_QUESTION, func() -> void: save_requested.emit(slot))
		actions.add_child(save)
		_note_first(save)
	if can_load and not empty:
		var load_button := _button("Load", not can_save)
		if confirm_load:
			_make_confirmable(load_button, LOAD_QUESTION, func() -> void: load_requested.emit(slot))
		else:
			load_button.pressed.connect(func() -> void: load_requested.emit(slot))
		actions.add_child(load_button)
		_note_first(load_button)
	if can_erase and not empty:
		var erase := _button("Erase")
		_make_confirmable(erase, ERASE_QUESTION, func() -> void: erase_requested.emit(slot))
		actions.add_child(erase)
		_note_first(erase)
	return card


## A themed button whose action is wired afterwards, since the theme helper
## insists on connecting one.
func _button(text: String, primary: bool = false) -> Button:
	return OathTheme.button(text, func() -> void: pass, primary)


func _note_first(button: Button) -> void:
	if _first_button == null:
		_first_button = button


func _make_confirmable(button: Button, question: String, action: Callable) -> void:
	button.set_meta(&"label", button.text)
	button.pressed.connect(func() -> void: _press_confirmable(button, question, action))
	button.focus_exited.connect(func() -> void: if _armed == button: _disarm())


func _press_confirmable(button: Button, question: String, action: Callable) -> void:
	if _armed == button:
		_disarm()
		action.call()
		return
	_disarm()
	_armed = button
	button.text = question
	button.add_theme_color_override("font_color", OathTheme.GOLD)


func _disarm() -> void:
	if _armed == null or not is_instance_valid(_armed):
		_armed = null
		return
	_armed.text = String(_armed.get_meta(&"label", _armed.text))
	_armed.remove_theme_color_override("font_color")
	_armed = null
