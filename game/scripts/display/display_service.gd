extends Node
## Window sizing and fullscreen policy for the fixed logical viewport
## (Specification 22.3).
##
## The project stretches [code]canvas_items[/code] with a [code]keep[/code]
## aspect, so every screen renders the same 960x540 logical viewport and
## letterboxes whatever is left over. Gameplay code can therefore keep working
## in logical coordinates and ignore the real screen size entirely.
##
## This autoload owns the window rules that project settings cannot express:
## a minimum window size, a startup size that actually fits the current screen,
## the fullscreen toggle, and persistence of both between sessions
## (Specification 21).

## Emitted whenever the window mode or size changes, so open UI can refresh.
signal display_changed

## Logical viewport every screen size scales to. Mirrors
## [code]display/window/size/viewport_{width,height}[/code].
const BASE_VIEWPORT_SIZE: Vector2i = Vector2i(960, 540)

## Preferred windowed scale on a screen large enough for it.
const PREFERRED_WINDOW_SCALE: int = 2

const TOGGLE_FULLSCREEN_ACTION: StringName = &"toggle_fullscreen"

## Reported by [method window_scale] when the window is fullscreen or has been
## resized by hand, so it is not an exact multiple of the logical viewport.
const CUSTOM_WINDOW_SCALE: int = 0

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "display"
const FULLSCREEN_SETTING: String = "fullscreen"
const WINDOW_SCALE_SETTING: String = "window_scale"

## Size restored when leaving fullscreen.
var _windowed_size: Vector2i = BASE_VIEWPORT_SIZE * PREFERRED_WINDOW_SCALE

## Suppresses saving while startup applies the settings that were just loaded.
var _settings_loaded: bool = false


func _ready() -> void:
	var window: Window = get_window()
	window.min_size = _minimum_window_size(window)
	_apply_saved_settings(window)
	_settings_loaded = true
	_windowed_size = window.size
	window.size_changed.connect(_on_window_size_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(TOGGLE_FULLSCREEN_ACTION):
		return
	get_viewport().set_input_as_handled()
	set_fullscreen(not is_fullscreen())


func is_fullscreen() -> bool:
	var window_mode: Window.Mode = get_window().mode
	return window_mode == Window.MODE_FULLSCREEN or window_mode == Window.MODE_EXCLUSIVE_FULLSCREEN


## Borderless fullscreen is used rather than exclusive fullscreen so the window
## stays minimizable (Specification 22.3).
func set_fullscreen(enabled: bool) -> void:
	var window: Window = get_window()
	if enabled == is_fullscreen():
		return

	if enabled:
		_windowed_size = window.size
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		window.size = _windowed_size
		_center_on_screen(window)

	_save_settings()
	display_changed.emit()


## Resizes the window to an exact multiple of the logical viewport. Values that
## do not fit the current screen fall back to the largest multiple that does.
func set_window_scale(scale: int) -> void:
	var window: Window = get_window()
	var requested_scale: int = clampi(scale, 1, largest_window_scale())
	if is_fullscreen():
		set_fullscreen(false)
	window.size = BASE_VIEWPORT_SIZE * requested_scale
	_windowed_size = window.size
	_center_on_screen(window)
	_save_settings()
	display_changed.emit()


## Current windowed scale, or [constant CUSTOM_WINDOW_SCALE] when the window
## is fullscreen or sized to something other than a whole multiple.
func window_scale() -> int:
	if is_fullscreen():
		return CUSTOM_WINDOW_SCALE
	var window_size: Vector2i = get_window().size
	if window_size.x % BASE_VIEWPORT_SIZE.x != 0 or window_size.y % BASE_VIEWPORT_SIZE.y != 0:
		return CUSTOM_WINDOW_SCALE
	var horizontal_scale: int = window_size.x / BASE_VIEWPORT_SIZE.x
	if horizontal_scale != window_size.y / BASE_VIEWPORT_SIZE.y:
		return CUSTOM_WINDOW_SCALE
	return horizontal_scale


## Every whole viewport multiple the current screen can display, smallest first.
func available_window_scales() -> PackedInt32Array:
	var scales: PackedInt32Array = PackedInt32Array()
	for scale: int in range(1, largest_window_scale() + 1):
		scales.append(scale)
	return scales


func window_size_for_scale(scale: int) -> Vector2i:
	return BASE_VIEWPORT_SIZE * scale


func largest_window_scale() -> int:
	var usable_size: Vector2i = _usable_screen_size(get_window())
	var horizontal_scale: int = usable_size.x / BASE_VIEWPORT_SIZE.x
	var vertical_scale: int = usable_size.y / BASE_VIEWPORT_SIZE.y
	return maxi(1, mini(horizontal_scale, vertical_scale))


func _on_window_size_changed() -> void:
	if not is_fullscreen():
		_windowed_size = get_window().size
	display_changed.emit()


## Startup restores the saved window mode and size, falling back to the
## preferred scale for screens that have no settings file yet.
func _apply_saved_settings(window: Window) -> void:
	var settings: ConfigFile = ConfigFile.new()
	var load_error: Error = settings.load(SETTINGS_FILE_PATH)
	var saved_scale: int = PREFERRED_WINDOW_SCALE
	var saved_fullscreen: bool = false
	if load_error == OK:
		saved_scale = int(settings.get_value(SETTINGS_SECTION, WINDOW_SCALE_SETTING, saved_scale))
		saved_fullscreen = bool(
			settings.get_value(SETTINGS_SECTION, FULLSCREEN_SETTING, saved_fullscreen)
		)

	_windowed_size = BASE_VIEWPORT_SIZE * clampi(saved_scale, 1, largest_window_scale())
	if saved_fullscreen:
		if not is_fullscreen():
			window.mode = Window.MODE_FULLSCREEN
		return

	if is_fullscreen():
		window.mode = Window.MODE_WINDOWED
	window.size = _windowed_size
	_center_on_screen(window)


func _save_settings() -> void:
	if not _settings_loaded:
		return
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_FILE_PATH)
	settings.set_value(SETTINGS_SECTION, FULLSCREEN_SETTING, is_fullscreen())
	settings.set_value(
		SETTINGS_SECTION, WINDOW_SCALE_SETTING, _windowed_size.x / BASE_VIEWPORT_SIZE.x
	)
	settings.save(SETTINGS_FILE_PATH)


## The minimum size keeps one full logical viewport visible, unless the screen
## itself is smaller than that.
func _minimum_window_size(window: Window) -> Vector2i:
	var usable_size: Vector2i = _usable_screen_size(window)
	return Vector2i(
		mini(BASE_VIEWPORT_SIZE.x, usable_size.x), mini(BASE_VIEWPORT_SIZE.y, usable_size.y)
	)


## Falls back to the base viewport when the display server reports nothing
## usable, which happens on the headless server used by the test suite.
func _usable_screen_size(window: Window) -> Vector2i:
	var usable_size: Vector2i = DisplayServer.screen_get_usable_rect(window.current_screen).size
	if usable_size.x <= 0 or usable_size.y <= 0:
		return BASE_VIEWPORT_SIZE
	return usable_size


func _center_on_screen(window: Window) -> void:
	var usable_rectangle: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable_rectangle.size.x <= 0 or usable_rectangle.size.y <= 0:
		return
	window.position = usable_rectangle.position + (usable_rectangle.size - window.size) / 2
