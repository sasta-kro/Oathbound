extends GutTest

const MAIN_SCENE: PackedScene = preload("res://main.tscn")


func test_main_scene_instantiates_with_player() -> void:
	var main_scene: Node = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var player: Node = main_scene.get_node_or_null("Area1/Player")
	assert_not_null(player, "Main scene must provide an Area1 player.")
	assert_true(player is GridPlayer, "Area1 player must use grid movement.")


func test_required_input_actions_exist() -> void:
	var required_actions: PackedStringArray = [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"interact",
		"toggle_fullscreen",
	]

	for action_name: StringName in required_actions:
		assert_true(
			InputMap.has_action(action_name), "Missing required input action: %s" % action_name
		)


func test_display_scales_from_the_configured_base_viewport() -> void:
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/mode"),
		"canvas_items",
		"2D content must scale with the game window.",
	)
	assert_eq(
		ProjectSettings.get_setting("display/window/stretch/aspect"),
		"keep",
		"The logical aspect ratio is fixed, so mismatched screens letterbox.",
	)
	assert_true(
		bool(ProjectSettings.get_setting("display/window/size/resizable")),
		"The window must be resizable.",
	)
	assert_eq(
		Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width")),
			int(ProjectSettings.get_setting("display/window/size/viewport_height")),
		),
		DisplayService.BASE_VIEWPORT_SIZE,
		"DisplayService must scale windows from the configured base viewport.",
	)


func test_base_viewport_uses_the_specified_sixteen_by_nine_aspect() -> void:
	var base_size: Vector2i = DisplayService.BASE_VIEWPORT_SIZE
	assert_almost_eq(
		float(base_size.x) / float(base_size.y),
		16.0 / 9.0,
		0.001,
		"Specification 22.3 fixes the logical aspect ratio at 16:9.",
	)


func test_ui_anchors_to_the_viewport_edges_rather_than_fixed_pixels() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var panel: PanelContainer = main_scene.get_node("DialoguePanel/Panel")
	assert_eq(panel.anchor_bottom, 1.0, "The dialogue panel must anchor to the viewport bottom.")
	assert_eq(panel.anchor_right, 1.0, "The dialogue panel must stretch to the viewport width.")


func test_world_actors_are_centered_in_grid_cells() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var expected_actor_cells: Dictionary[NodePath, Vector2i] = {
		NodePath("Area1/Player"): Vector2i(5, 9),
		NodePath("Area1/Knight"): Vector2i(5, 5),
		NodePath("Area1/Creature"): Vector2i(14, 9),
	}
	for actor_path: NodePath in expected_actor_cells:
		var actor: Node2D = main_scene.get_node(actor_path)
		var expected_position: Vector2 = AreaOneRoom.cell_to_world(expected_actor_cells[actor_path])
		assert_eq(
			actor.position,
			expected_position,
			"%s must be centered in its grid cell." % actor_path,
		)


func test_right_wall_collision_matches_visible_geometry() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: GridPlayer = main_scene.get_node("Area1/Player")
	player.global_position = Vector2(144, 96)
	var visible_wall_collision: KinematicCollision2D = player.move_and_collide(
		Vector2.RIGHT * player.grid_size
	)
	assert_not_null(
		visible_wall_collision, "The player must not move through the visible right wall."
	)

	player.global_position = Vector2(144, -96)
	var open_tile_collision: KinematicCollision2D = player.move_and_collide(
		Vector2.RIGHT * player.grid_size
	)
	assert_null(
		open_tile_collision, "The player must move through tiles outside the visible right wall."
	)
