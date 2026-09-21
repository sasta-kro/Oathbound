class_name SettingsMenu
extends CanvasLayer
## Settings screen for display options (Specification 22.4).
##
## Display: window size and fullscreen. Audio: music and effects volume (22.8). Control
## rebinding (22.2) is a separate section that plugs into the same rows
## container when it is implemented.

signal opened
signal closed

## Item id used for the entry describing a hand-resized window.
const CUSTOM_SIZE_ITEM_ID: int = -1

@onready var root: Control = $Root
@onready var window_size_options: OptionButton = %WindowSizeOptions
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var sfx_volume_slider: HSlider = %SfxVolumeSlider
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	root.theme = OathTheme.make()
	$Root/Panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.55), 10, 0))
	var title: Label = $Root/Panel/Margin/Rows/Title
	title.text = "Make yourself at home."
	title.add_theme_font_override("font", OathTheme.SERIF)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", OathTheme.PAPER)
	$Root/Panel/Margin/Rows/DisplaySection.text = "DISPLAY PREFERENCES"
	$Root/Panel/Margin/Rows/DisplaySection.add_theme_font_size_override("font_size", 10)
	$Root/Panel/Margin/Rows/AudioSection.text = "AUDIO"
	$Root/Panel/Margin/Rows/AudioSection.add_theme_font_size_override("font_size", 10)
	close_button.text = "Done  →"
	root.hide()
	window_size_options.item_selected.connect(_on_window_size_selected)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	MusicService.music_volume_changed.connect(_on_service_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	# Released rather than dragged, so the sample plays once per adjustment.
	sfx_volume_slider.drag_ended.connect(_on_sfx_slider_released)
	SfxService.sfx_volume_changed.connect(_on_service_sfx_volume_changed)
	close_button.pressed.connect(close)
	DisplayService.display_changed.connect(_on_display_changed)


func open() -> void:
	if is_open():
		return
	_refresh_display_controls()
	_refresh_audio_controls()
	root.show()
	root.modulate.a = 0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.16)
	window_size_options.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open():
		return
	root.hide()
	closed.emit()


func is_open() -> bool:
	return root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


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


func _refresh_audio_controls() -> void:
	music_volume_slider.set_value_no_signal(MusicService.music_volume() * 100.0)
	sfx_volume_slider.set_value_no_signal(SfxService.sfx_volume() * 100.0)


func _on_music_volume_changed(value: float) -> void:
	MusicService.set_music_volume(value / 100.0)


func _on_service_music_volume_changed(_volume: float) -> void:
	if is_open():
		_refresh_audio_controls()


func _on_sfx_volume_changed(value: float) -> void:
	SfxService.set_sfx_volume(value / 100.0)


## A sample at the new level, so the slider can be set by ear.
func _on_sfx_slider_released(_changed: bool) -> void:
	SfxService.play(&"hit")


func _on_service_sfx_volume_changed(_volume: float) -> void:
	if is_open():
		_refresh_audio_controls()
