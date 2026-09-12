extends GutTest
## The shipped areas load, hang together and lead into each other.

const AREA_SCENES: Array[String] = [
	"res://areas/town.tscn",
	"res://areas/area_one.tscn",
	"res://areas/test_01.tscn",
]
const START_AREA: String = "res://areas/town.tscn"
const ALTAR_SPRITE_NAME: String = "prop_26"
const ALTAR_SOURCE: int = 3


func after_each() -> void:
	await get_tree().process_frame


func _load_area(path: String) -> WorldArea:
	var area: WorldArea = autofree((load(path) as PackedScene).instantiate())
	add_child(area)
	return area


func test_every_area_has_ground_and_a_player_start() -> void:
	for path: String in AREA_SCENES:
		var area: WorldArea = _load_area(path)
		assert_not_null(area.ground, "%s needs a Ground layer." % path)
		assert_true(area.bounds().size.x > 0.0, "%s must paint some ground." % path)
		assert_true(
			area.is_on_ground(area.player_start_position()),
			"%s must start the player on painted ground." % path
		)


func test_every_exit_leads_to_an_existing_entrance() -> void:
	for path: String in AREA_SCENES:
		var area: WorldArea = _load_area(path)
		for exit: AreaExit in area.find_children("*", "AreaExit", true, false):
			assert_true(
				ResourceLoader.exists(exit.target_area_path),
				"%s: exit %s points at missing scene %s." % [path, exit.name, exit.target_area_path]
			)
			if not ResourceLoader.exists(exit.target_area_path):
				continue
			var target: WorldArea = _load_area(exit.target_area_path)
			assert_true(
				target.has_entrance(exit.target_entrance),
				"%s: exit %s names entrance %s, which %s does not have."
				% [path, exit.name, exit.target_entrance, exit.target_area_path]
			)
			# Arriving inside an exit would bounce the player straight back.
			var arrival: Vector2 = target.entrance_position(exit.target_entrance)
			for return_exit: AreaExit in target.find_children("*", "AreaExit", true, false):
				var half: Vector2 = return_exit.size_in_pixels() / 2.0
				var trigger := Rect2(return_exit.global_position - half, half * 2.0)
				assert_false(
					trigger.grow(WorldArea.GRID_SIZE / 2.0).has_point(arrival),
					"%s: entrance %s lands inside exit %s." % [exit.target_area_path, exit.target_entrance, return_exit.name]
				)


func test_town_and_area_one_are_linked_both_ways() -> void:
	var town: WorldArea = _load_area("res://areas/town.tscn")
	var area_one: WorldArea = _load_area("res://areas/area_one.tscn")
	var town_exits: Array = town.find_children("*", "AreaExit", true, false)
	var area_exits: Array = area_one.find_children("*", "AreaExit", true, false)
	assert_eq(town_exits.size(), 1, "The town has one way out.")
	assert_eq(area_exits.size(), 1, "Area One has one way out.")
	assert_eq(town_exits[0].target_area_path, "res://areas/area_one.tscn")
	assert_eq(area_exits[0].target_area_path, "res://areas/town.tscn")


func test_unknown_entrance_falls_back_to_the_player_start() -> void:
	var area: WorldArea = _load_area("res://areas/town.tscn")
	assert_eq(area.entrance_position(&"NoSuchDoor"), area.player_start_position())


func test_area_one_ends_at_the_altar() -> void:
	var area: WorldArea = _load_area("res://areas/area_one.tscn")
	var decor: TileMapLayer = area.get_node("Decor")
	var manifest: Array = OverworldTiles.load_json(OverworldTiles.OBJECT_MANIFESTS[ALTAR_SOURCE])
	var altar_cell := Vector2i(-1, -1)
	for sprite: Dictionary in manifest:
		if sprite["name"] == ALTAR_SPRITE_NAME:
			altar_cell = Vector2i(int(sprite["cell"][0]), int(sprite["cell"][1]))
	var altar_positions: Array[Vector2] = []
	for cell: Vector2i in decor.get_used_cells_by_id(ALTAR_SOURCE, altar_cell):
		altar_positions.append(decor.to_global(decor.map_to_local(cell)))
	assert_eq(altar_positions.size(), 1, "Area One has exactly one altar.")
	if altar_positions.is_empty():
		return
	# "Near the end": the altar is well past the halfway point from the start.
	var start: Vector2 = area.player_start_position()
	var span: float = area.bounds().size.length()
	assert_gt(
		start.distance_to(altar_positions[0]),
		span * 0.5,
		"The altar sits at the far end of the area from where the player arrives."
	)


func test_main_scene_starts_in_the_town() -> void:
	var main_scene: Node2D = autofree((load("res://main.tscn") as PackedScene).instantiate())
	add_child(main_scene)
	var area: WorldArea = main_scene.get_node("Area")
	assert_eq(area.scene_file_path, START_AREA, "The game opens in the town square.")
