extends GutTest

const MAIN_SCENE: PackedScene = preload("res://main.tscn")


func test_main_scene_instantiates_with_player() -> void:
	var main_scene: Node = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var player: Node = main_scene.get_node_or_null("Area1/Player")
	assert_not_null(player, "Main scene must provide an Area1 player.")
	assert_true(player is Player, "Area1 player must use the analog Player controller.")


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


func test_world_actors_occupy_complete_grid_cells() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var half_grid_size: float = AreaOneRoom.GRID_SIZE / 2.0
	var expected_body_polygon: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-half_grid_size, -half_grid_size),
			Vector2(half_grid_size, -half_grid_size),
			Vector2(half_grid_size, half_grid_size),
			Vector2(-half_grid_size, half_grid_size),
		]
	)
	var actor_paths: Array[NodePath] = [
		NodePath("Area1/Player"),
		NodePath("Area1/Knight"),
		NodePath("Area1/Creature"),
	]
	for actor_path: NodePath in actor_paths:
		var body: Polygon2D = main_scene.get_node(NodePath("%s/Body" % actor_path))
		assert_eq(
			body.polygon,
			expected_body_polygon,
			"%s placeholder must fill one complete grid cell." % actor_path,
		)

	for actor_path: NodePath in [NodePath("Area1/Knight"), NodePath("Area1/Creature")]:
		var rectangle: RectangleShape2D = _collision_rectangle(main_scene, actor_path)
		assert_eq(
			rectangle.size,
			Vector2(AreaOneRoom.GRID_SIZE, AreaOneRoom.GRID_SIZE),
			"%s must occupy one complete grid cell." % actor_path,
		)

	# The player slides freely, so its hitbox is inset a little from the visual
	# to keep it from snagging on cell-wide gaps.
	var player_rectangle: RectangleShape2D = _collision_rectangle(
		main_scene, NodePath("Area1/Player")
	)
	assert_true(
		(
			player_rectangle.size.x < AreaOneRoom.GRID_SIZE
			and player_rectangle.size.y < AreaOneRoom.GRID_SIZE
		),
		"The player's hitbox must be inset from the grid cell.",
	)


func test_player_moves_continuously_rather_than_by_whole_cells() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Area1/Player")
	player.global_position = Vector2(-336, 0)
	var position_before_movement: Vector2 = player.global_position

	assert_true(player.move_with(Vector2.RIGHT), "An open direction must move the player.")
	var displacement: Vector2 = player.global_position - position_before_movement
	assert_gt(displacement.x, 0.0, "Moving right must increase x.")
	assert_lt(
		displacement.x,
		float(player.grid_size),
		"A single step must cover less than one grid cell.",
	)
	assert_almost_eq(displacement.y, 0.0, 0.001, "Moving right must not change y.")


func test_diagonal_movement_is_normalized() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Area1/Player")
	player.global_position = Vector2(-192, 96)
	var position_before_movement: Vector2 = player.global_position

	assert_true(player.move_with(Vector2(1, 1)), "An open diagonal must move the player.")
	var displacement: Vector2 = player.global_position - position_before_movement
	assert_gt(displacement.x, 0.0)
	assert_almost_eq(displacement.x, displacement.y, 0.001, "Diagonal input moves evenly on both axes.")
	assert_eq(player.facing_direction, Vector2i(1, 1), "Facing must follow the diagonal.")


func test_walls_stop_the_player_and_let_it_slide_along_them() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Area1/Player")
	# RightWall spans x 168..216; the player's hitbox is 40 wide.
	player.global_position = Vector2(144, 96)
	for _step: int in 60:
		player.move_with(Vector2.RIGHT)
	var blocked_x: float = player.global_position.x
	assert_lt(blocked_x, 168.0, "The player's hitbox must stay outside the wall.")
	assert_gt(blocked_x, 144.0, "The player must close the gap up to the wall.")

	var y_before_slide: float = player.global_position.y
	assert_true(
		player.move_with(Vector2(1, -1)),
		"Pushing into a wall diagonally must still move along it.",
	)
	assert_almost_eq(player.global_position.x, blocked_x, 0.5, "The wall must hold x.")
	assert_lt(player.global_position.y, y_before_slide, "The player must slide up the wall.")


func test_moved_signal_only_fires_when_the_player_actually_moves() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Area1/Player")
	player.global_position = Vector2(-336, 0)
	watch_signals(player)

	assert_false(player.move_with(Vector2.ZERO), "No input must not move the player.")
	assert_signal_not_emitted(player, "moved")

	player.move_with(Vector2.LEFT)
	assert_signal_emitted(player, "moved")


func test_disabled_movement_ignores_held_input() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Area1/Player")
	player.global_position = Vector2(-336, 0)
	player.movement_enabled = false
	Input.action_press(&"move_right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_right")

	assert_eq(
		player.global_position,
		Vector2(-336, 0),
		"Held input must not move the player while movement is disabled.",
	)


func test_interaction_reach_covers_touching_actors_from_any_side() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)

	var player: Player = main_scene.get_node("Area1/Player")
	var knight: WorldActor = main_scene.get_node("Area1/Knight")
	var touching_offset: float = (AreaOneRoom.GRID_SIZE + 40) / 2.0

	player.global_position = knight.global_position + Vector2(touching_offset, 0)
	assert_true(main_scene._is_adjacent_to(knight), "Touching from the side is in reach.")

	player.global_position = knight.global_position + Vector2(touching_offset, touching_offset)
	assert_true(main_scene._is_adjacent_to(knight), "Touching at a corner is in reach.")

	player.global_position = knight.global_position + Vector2(2 * AreaOneRoom.GRID_SIZE, 0)
	assert_false(main_scene._is_adjacent_to(knight), "Two cells away is out of reach.")


func _collision_rectangle(main_scene: Node, actor_path: NodePath) -> RectangleShape2D:
	var collision_shape: CollisionShape2D = main_scene.get_node(
		NodePath("%s/CollisionShape2D" % actor_path)
	)
	return collision_shape.shape as RectangleShape2D
