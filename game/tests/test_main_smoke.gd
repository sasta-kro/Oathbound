extends GutTest

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
## The small test room the movement and layout checks below are measured
## against. The game itself opens in the town.
const TEST_AREA: PackedScene = preload("res://areas/test_01.tscn")

const PLAYER_START_CELL := Vector2i(5, 9)
const KNIGHT_CELL := Vector2i(5, 5)


## Tests that await physics_frame resume inside the physics step. Freeing
## tile bodies and moving creatures from there can crash the physics server,
## so every test settles on an idle frame before GUT tears the scene down.
func after_each() -> void:
	await get_tree().process_frame


func _load_main() -> Node2D:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	# Swap the town for the test room before the main scene wires itself up.
	var shipped_area: Node = main_scene.get_node("Area")
	var index: int = shipped_area.get_index()
	main_scene.remove_child(shipped_area)
	shipped_area.free()
	var test_area: Node = TEST_AREA.instantiate()
	test_area.name = "Area"
	main_scene.add_child(test_area)
	main_scene.move_child(test_area, index)
	add_child(main_scene)
	return main_scene


func test_main_scene_instantiates_with_area_and_player() -> void:
	var main_scene: Node2D = _load_main()

	var area: Node = main_scene.get_node_or_null("Area")
	assert_true(area is WorldArea, "Main must instance a WorldArea scene as Area.")
	var player: Node = main_scene.get_node_or_null("Player")
	assert_true(player is Player, "Main must provide the analog Player controller.")


func test_required_input_actions_exist() -> void:
	var required_actions: PackedStringArray = [
		"move_up",
		"move_down",
		"move_left",
		"move_right",
		"interact",
		"attack",
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
	var main_scene: Node2D = _load_main()

	var panel: PanelContainer = main_scene.get_node("DialoguePanel/Panel")
	assert_eq(panel.anchor_bottom, 1.0, "The dialogue panel must anchor to the viewport bottom.")
	assert_eq(panel.anchor_right, 1.0, "The dialogue panel must stretch to the viewport width.")


func test_player_starts_on_the_area_marker_and_actors_sit_on_cell_centers() -> void:
	var main_scene: Node2D = _load_main()
	var area: WorldArea = main_scene.get_node("Area")

	var player: Player = main_scene.get_node("Player")
	assert_eq(
		player.global_position,
		area.cell_to_world(PLAYER_START_CELL),
		"The player must start on the area's PlayerStart marker.",
	)
	var knight: Node2D = area.get_node("Knight")
	assert_eq(
		knight.global_position,
		area.cell_to_world(KNIGHT_CELL),
		"The knight must be centered in its grid cell.",
	)


func test_camera_limits_follow_the_painted_ground() -> void:
	var main_scene: Node2D = _load_main()
	var area: WorldArea = main_scene.get_node("Area")
	var camera: Camera2D = main_scene.get_node("Player/Camera2D")

	var limits: Rect2 = area.bounds()
	assert_eq(limits, Rect2(-552, -312, 1056, 624), "The test room is 22x13 cells of 48 px.")
	assert_eq(camera.limit_left, -552)
	assert_eq(camera.limit_top, -312)
	assert_eq(camera.limit_right, 504)
	assert_eq(camera.limit_bottom, 312)


func test_area_knows_which_cells_are_ground() -> void:
	var main_scene: Node2D = _load_main()
	var area: WorldArea = main_scene.get_node("Area")

	assert_true(area.is_on_ground(area.cell_to_world(Vector2i(3, 3))), "Inside the room is ground.")
	assert_false(area.is_on_ground(area.cell_to_world(Vector2i(-1, 3))), "Left of the room is not.")
	assert_false(area.is_on_ground(area.cell_to_world(Vector2i(22, 3))), "Right of the room is not.")


func test_player_moves_continuously_rather_than_by_whole_cells() -> void:
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
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
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	player.global_position = Vector2(-192, 96)
	var position_before_movement: Vector2 = player.global_position

	assert_true(player.move_with(Vector2(1, 1)), "An open diagonal must move the player.")
	var displacement: Vector2 = player.global_position - position_before_movement
	assert_gt(displacement.x, 0.0)
	assert_almost_eq(displacement.x, displacement.y, 0.001, "Diagonal input moves evenly on both axes.")
	assert_eq(player.facing_direction, Vector2i(1, 1), "Facing must follow the diagonal.")


func test_painted_walls_stop_the_player_and_let_it_slide_along_them() -> void:
	var main_scene: Node2D = _load_main()
	for _frame: int in 3:
		await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	# The wall column at cell x 15 spans world x 168..216; the hitbox is 40 wide.
	player.global_position = Vector2(144, 96)
	for _step: int in 60:
		player.move_with(Vector2.RIGHT)
	var blocked_x: float = player.global_position.x
	assert_lt(blocked_x, 168.0, "The player's hitbox must stay outside the wall tiles.")
	assert_gt(blocked_x, 144.0, "The player must close the gap up to the wall.")

	var y_before_slide: float = player.global_position.y
	assert_true(
		player.move_with(Vector2(1, -1)),
		"Pushing into a wall diagonally must still move along it.",
	)
	assert_almost_eq(player.global_position.x, blocked_x, 0.5, "The wall must hold x.")
	assert_lt(player.global_position.y, y_before_slide, "The player must slide up the wall.")


func test_hero_sprite_walks_and_faces_the_way_it_moves() -> void:
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	assert_not_null(sprite.sprite_frames, "The player must carry the hero sprite frames.")
	for facing: String in ["down", "up", "left", "right"]:
		assert_true(
			sprite.sprite_frames.has_animation(StringName("walk_%s" % facing)),
			"The hero sheet must define walk_%s." % facing,
		)
		assert_true(
			sprite.sprite_frames.has_animation(StringName("idle_%s" % facing)),
			"The hero sheet must define idle_%s." % facing,
		)

	player.global_position = Vector2(-336, 0)
	player.move_with(Vector2.LEFT)
	assert_eq(sprite.animation, &"walk_left", "Moving left plays the left walk cycle.")
	player.move_with(Vector2.ZERO)
	assert_eq(sprite.animation, &"idle_left", "Standing still returns to idle.")

	player.move_with(Vector2.DOWN)
	assert_eq(sprite.animation, &"walk_down", "Moving down plays the front walk cycle.")
	player.move_with(Vector2.UP)
	assert_eq(sprite.animation, &"walk_up", "Moving up plays the back walk cycle.")


func test_diagonal_movement_uses_the_side_view_rows() -> void:
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	player.global_position = Vector2(-336, 0)
	player.move_with(Vector2(1, -1))
	assert_eq(sprite.animation, &"walk_right", "Up-right walks in the right-facing row.")
	player.move_with(Vector2(-1, 1))
	assert_eq(sprite.animation, &"walk_left", "Down-left walks in the left-facing row.")


func test_moved_signal_only_fires_when_the_player_actually_moves() -> void:
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	player.global_position = Vector2(-336, 0)
	watch_signals(player)

	assert_false(player.move_with(Vector2.ZERO), "No input must not move the player.")
	assert_signal_not_emitted(player, "moved")

	player.move_with(Vector2.LEFT)
	assert_signal_emitted(player, "moved")


func test_disabled_movement_ignores_held_input() -> void:
	var main_scene: Node2D = _load_main()
	await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	player.global_position = Vector2(-336, 0)
	player.movement_enabled = false
	Input.action_press(&"move_right")
	for _frame: int in 3:
		await get_tree().physics_frame
	Input.action_release(&"move_right")

	assert_eq(
		player.global_position,
		Vector2(-336, 0),
		"Held input must not move the player while movement is disabled.",
	)


func test_interaction_reach_covers_touching_actors_from_any_side() -> void:
	var main_scene: Node2D = _load_main()

	var player: Player = main_scene.get_node("Player")
	var knight: WorldActor = main_scene.get_node("Area/Knight")
	var touching_offset: float = (WorldArea.GRID_SIZE + 40) / 2.0

	player.global_position = knight.global_position + Vector2(touching_offset, 0)
	assert_true(main_scene._is_adjacent_to(knight), "Touching from the side is in reach.")
	assert_eq(main_scene.nearest_actor_in_reach(), knight, "The knight is the nearest actor.")

	player.global_position = knight.global_position + Vector2(touching_offset, touching_offset)
	assert_true(main_scene._is_adjacent_to(knight), "Touching at a corner is in reach.")

	player.global_position = knight.global_position + Vector2(2 * WorldArea.GRID_SIZE, 0)
	assert_false(main_scene._is_adjacent_to(knight), "Two cells away is out of reach.")
	assert_null(main_scene.nearest_actor_in_reach(), "Nothing else is within reach there.")


func test_dialogue_freezes_the_player_and_every_roaming_creature() -> void:
	var main_scene: Node2D = _load_main()
	for _frame: int in 3:
		await get_tree().physics_frame

	var player: Player = main_scene.get_node("Player")
	var creatures: Array[Node] = get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP)
	assert_gt(creatures.size(), 0, "The sample map must spawn creatures.")

	main_scene._open_dialogue("Hello")
	assert_false(player.movement_enabled)
	for creature: WildCreature in creatures:
		assert_false(creature.roaming_enabled, "%s must stop while dialogue is open." % creature.name)

	main_scene._close_dialogue()
	assert_true(player.movement_enabled)
	for creature: WildCreature in creatures:
		assert_true(creature.roaming_enabled, "%s must resume after dialogue." % creature.name)
