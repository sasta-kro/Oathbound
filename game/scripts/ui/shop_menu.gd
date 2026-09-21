class_name ShopMenu
extends CanvasLayer
## A vendor's counter (Specification 16.5): what they sell, what it costs, and
## how many the player already carries. Stock is unlimited.
##
## Move up and down to choose, interact to buy one, or cancel to walk
## away. Rows can be clicked too. While it is open the panel takes those keys
## itself, so the overworld never sees them.

signal closed

const ROW_FONT_SIZE := 14
const PANEL_WIDTH := 560.0
const FLASH_SECONDS := 1.6
const CURSOR_PREFIX := "▸  "
const IDLE_PREFIX := "    "

var _root: Control
var _panel: PanelContainer
var _title: Label
var _greeting: Label
var _rows: VBoxContainer
var _description: Label
var _coins: Label
var _status: Label
var _stock: Array[ItemData] = []
var _buttons: Array[Button] = []
var _selected: int = 0
var _status_tween: Tween


func _ready() -> void:
	layer = 7
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = OathTheme.make()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.035, 0.04, 0.55)
	_root.add_child(shade)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var frame := OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.5), 10, 18)
	frame.shadow_color = Color(0, 0, 0, 0.35)
	frame.shadow_size = 16
	_panel.add_theme_stylebox_override("panel", frame)
	_root.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_panel.add_child(content)
	var caption := HBoxContainer.new()
	content.add_child(caption)
	caption.add_child(OathTheme.label("◇   W A R E S", 9, OathTheme.GOLD))
	caption.add_child(OathTheme.spacer(false))
	_coins = OathTheme.label("", 12, OathTheme.GOLD)
	caption.add_child(_coins)
	_title = OathTheme.heading("", 26)
	content.add_child(_title)
	_greeting = OathTheme.paragraph("", 12)
	_greeting.custom_minimum_size.x = PANEL_WIDTH - 40
	content.add_child(_greeting)
	content.add_child(OathTheme.rule())
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	content.add_child(_rows)
	content.add_child(OathTheme.rule())
	_description = OathTheme.paragraph("", 12, OathTheme.PAPER)
	_description.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 34)
	content.add_child(_description)
	var footer := HBoxContainer.new()
	content.add_child(footer)
	_status = OathTheme.label("", 12, OathTheme.JADE)
	footer.add_child(_status)
	footer.add_child(OathTheme.spacer(false))
	footer.add_child(
		OathTheme.label("W/S OR ARROWS  CHOOSE   ·   E/ENTER  BUY   ·   Q  LEAVE", 9, OathTheme.MUTED)
	)
	_root.hide()


## Opens the counter of [param vendor], who greets the player with
## [param greeting] and sells [param stock].
func open(vendor: String, greeting: String, stock: Array[ItemData]) -> void:
	_stock = stock
	_title.text = vendor
	_greeting.text = greeting
	_status.text = ""
	_build_rows()
	_select(0)
	_root.show()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not is_open():
		return
	_root.hide()
	closed.emit()


func is_open() -> bool:
	return _root.visible


## The item under the cursor.
func selected_item() -> ItemData:
	return _stock[_selected] if _selected < _stock.size() else null


## Buys one of the selected item. Returns whether the coins changed hands.
func buy_selected() -> bool:
	var item: ItemData = selected_item()
	if item == null:
		return false
	if not GameState.buy_item(item):
		_flash("Not enough coins for a %s." % item.display_name, OathTheme.ELEMENT_COLORS[0])
		return false
	_flash("Bought a %s. You now carry %d." % [item.display_name, GameState.item_count(item.id)], OathTheme.JADE)
	_build_rows()
	_select(_selected)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"move_up"):
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact"):
		buy_selected()
	elif event.is_action_pressed(&"cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _build_rows() -> void:
	for button: Button in _buttons:
		_rows.remove_child(button)
		button.queue_free()
	_buttons.clear()
	for index: int in _stock.size():
		var item: ItemData = _stock[index]
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 28
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_row_pressed.bind(index))
		button.mouse_entered.connect(_select.bind(index))
		var columns := HBoxContainer.new()
		columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		columns.offset_left = 6
		columns.offset_right = -6
		columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(columns)
		var name_label := OathTheme.label(item.display_name, ROW_FONT_SIZE)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		columns.add_child(name_label)
		var owned := OathTheme.label("owned %d" % GameState.item_count(item.id), 11, OathTheme.MUTED)
		owned.custom_minimum_size.x = 70
		owned.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		columns.add_child(owned)
		var price := OathTheme.label("%d coins" % item.price, ROW_FONT_SIZE)
		price.custom_minimum_size.x = 84
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		columns.add_child(price)
		_rows.add_child(button)
		_buttons.append(button)
	_coins.text = "%d COINS" % GameState.currency


func _on_row_pressed(index: int) -> void:
	_select(index)
	buy_selected()


func _select(index: int) -> void:
	if _stock.is_empty():
		return
	_selected = wrapi(index, 0, _stock.size())
	for i: int in _buttons.size():
		var item: ItemData = _stock[i]
		var active: bool = i == _selected
		var columns: HBoxContainer = _buttons[i].get_child(0)
		var name_label: Label = columns.get_child(0)
		var price: Label = columns.get_child(2)
		name_label.text = (CURSOR_PREFIX if active else IDLE_PREFIX) + item.display_name
		var color: Color = OathTheme.GOLD if active else OathTheme.PAPER
		name_label.add_theme_color_override("font_color", color)
		var affordable: bool = GameState.currency >= item.price
		price.add_theme_color_override(
			"font_color", (OathTheme.GOLD if active else OathTheme.PAPER) if affordable else OathTheme.MUTED.darkened(0.2)
		)
	_description.text = _stock[_selected].description


func _flash(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
	_status.modulate.a = 1.0
	if _status_tween != null:
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(FLASH_SECONDS)
	_status_tween.tween_property(_status, "modulate:a", 0.0, 0.4)
