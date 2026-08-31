extends GutTest

const SETTINGS_MENU_SCENE: PackedScene = preload("res://scenes/settings_menu.tscn")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var _initial_window_size: Vector2i


func before_each() -> void:
	_initial_window_size = get_window().size


func after_each() -> void:
	get_window().size = _initial_window_size


func _add_menu() -> SettingsMenu:
	var menu: SettingsMenu = autofree(SETTINGS_MENU_SCENE.instantiate())
	add_child(menu)
	return menu


func test_open_settings_action_exists() -> void:
	assert_true(
		InputMap.has_action(&"open_settings"), "The settings screen needs a way to be opened."
	)


func test_main_scene_provides_a_settings_menu() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var menu: Node = main_scene.get_node_or_null("SettingsMenu")
	assert_not_null(menu, "The main scene must provide a settings menu.")
	assert_true(menu is SettingsMenu, "The settings node must use the settings menu script.")


func test_menu_starts_closed_and_toggles() -> void:
	var menu: SettingsMenu = _add_menu()
	assert_false(menu.is_open(), "The settings menu must start closed.")

	menu.open()
	assert_true(menu.is_open(), "Opening the settings menu must show it.")

	menu.close()
	assert_false(menu.is_open(), "Closing the settings menu must hide it.")


func test_window_size_options_list_every_scale_that_fits() -> void:
	var menu: SettingsMenu = _add_menu()
	menu.open()

	var available_scales: PackedInt32Array = DisplayService.available_window_scales()
	assert_gt(available_scales.size(), 0, "At least one window size must be offered.")
	for scale: int in available_scales:
		var item_index: int = menu.window_size_options.get_item_index(scale)
		assert_gt(item_index, -1, "Window size %dx must be selectable." % scale)
		var expected_size: Vector2i = DisplayService.window_size_for_scale(scale)
		assert_string_contains(
			menu.window_size_options.get_item_text(item_index),
			"%d x %d" % [expected_size.x, expected_size.y],
			"Each window size entry must show its pixel size.",
		)


func test_selecting_a_window_size_resizes_the_window() -> void:
	var menu: SettingsMenu = _add_menu()
	menu.open()

	var requested_scale: int = DisplayService.largest_window_scale()
	menu.window_size_options.select(menu.window_size_options.get_item_index(requested_scale))
	menu.window_size_options.item_selected.emit(menu.window_size_options.selected)

	assert_eq(
		get_window().size,
		DisplayService.window_size_for_scale(requested_scale),
		"Choosing a window size must resize the window to that exact multiple.",
	)


func test_window_scale_reports_custom_for_a_hand_resized_window() -> void:
	get_window().size = DisplayService.BASE_VIEWPORT_SIZE + Vector2i(37, 11)
	assert_eq(
		DisplayService.window_scale(),
		DisplayService.CUSTOM_WINDOW_SCALE,
		"A window that is not a whole multiple of the viewport has no exact scale.",
	)


func test_fullscreen_toggle_reflects_the_current_window_mode() -> void:
	var menu: SettingsMenu = _add_menu()
	menu.open()
	assert_eq(
		menu.fullscreen_toggle.button_pressed,
		DisplayService.is_fullscreen(),
		"The fullscreen toggle must show the current window mode.",
	)
