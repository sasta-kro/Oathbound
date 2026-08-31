class_name SettingsMenu
extends CanvasLayer
## Settings screen for display options (Specification 22.4).
##
## Only the display section exists so far: window size and fullscreen. Audio
## volume (22.8) and control rebinding (22.2) are separate sections that plug
## into the same rows container when they are implemented.

signal opened
signal closed

## Item id used for the entry describing a hand-resized window.
const CUSTOM_SIZE_ITEM_ID: int = -1

@onready var root: Control = $Root
@onready var window_size_options: OptionButton = %WindowSizeOptions
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	root.hide()
	window_size_options.item_selected.connect(_on_window_size_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	close_button.pressed.connect(close)
	DisplayService.display_changed.connect(_on_display_changed)


func open() -> void:
	if is_open():
		return
	_refresh_display_controls()
	root.show()
	window_size_options.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open():
		return
	root.hide()
	closed.emit()


func is_open() -> bool:
	return root.visible


## Window sizes are whole multiples of the logical viewport, so the game never
## scales by a fraction of a pixel (Specification 22.3).
func _refresh_display_controls() -> void:
	var current_scale: int = DisplayService.window_scale()
	window_size_options.clear()
	for scale: int in DisplayService.available_window_scales():
		var size: Vector2i = DisplayService.window_size_for_scale(scale)
		window_size_options.add_item("%d x %d (%dx)" % [size.x, size.y, scale], scale)

	if current_scale == DisplayService.CUSTOM_WINDOW_SCALE:
		var window_size: Vector2i = get_window().size
		window_size_options.add_item(
			"Custom (%d x %d)" % [window_size.x, window_size.y], CUSTOM_SIZE_ITEM_ID
		)
		window_size_options.select(window_size_options.item_count - 1)
	else:
		window_size_options.select(window_size_options.get_item_index(current_scale))

	fullscreen_toggle.set_pressed_no_signal(DisplayService.is_fullscreen())


func _on_window_size_selected(item_index: int) -> void:
	var selected_scale: int = window_size_options.get_item_id(item_index)
	if selected_scale == CUSTOM_SIZE_ITEM_ID:
		return
	DisplayService.set_window_scale(selected_scale)


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayService.set_fullscreen(enabled)


func _on_display_changed() -> void:
	if is_open():
		_refresh_display_controls()
