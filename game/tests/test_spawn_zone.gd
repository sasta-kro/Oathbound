extends GutTest
## Spawn zones and wild creature behaviour (Specification 7.2 and 7.3).

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
## The small test room these checks are measured against; the game itself
## opens in the town, which has no spawn zones.
const TEST_AREA: PackedScene = preload("res://areas/test_01.tscn")
const CREATURE_SCENE: PackedScene = preload("res://scenes/wild_creature.tscn")
const SPAWN_ZONE_SCENE: PackedScene = preload("res://scenes/spawn_zone.tscn")
const SPECIES: CreatureSpecies = preload("res://content/creatures/creature_fire_01.tres")


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


func _zones(main_scene: Node2D) -> Array[SpawnZone]:
	var zones: Array[SpawnZone] = []
	for node: Node in main_scene.get_node("Area/SpawnZones").get_children():
		if node is SpawnZone:
			zones.append(node)
	return zones


func test_sample_map_zones_fill_to_their_population_on_free_ground() -> void:
	var main_scene: Node2D = _load_main()
	var area: WorldArea = main_scene.get_node("Area")
	var walls: TileMapLayer = area.get_node("Walls")
	for _frame: int in 3:
		await get_tree().physics_frame

	var zones: Array[SpawnZone] = _zones(main_scene)
	assert_gt(zones.size(), 0, "The sample map must ship with spawn zones.")
	for zone: SpawnZone in zones:
		assert_eq(
			zone.alive_count(),
			zone.max_alive,
			"%s must fill to max_alive; there is plenty of room." % zone.name,
		)
		for creature: WildCreature in zone.alive_creatures():
			assert_eq(creature.species, zone.species, "Spawns use the zone's species.")
			assert_between(creature.level, zone.level_min, zone.level_max)
			assert_true(
				creature.global_position.distance_to(zone.global_position) <= zone.radius() + 0.5,
				"%s spawned outside its zone." % creature.name,
			)
			assert_true(area.is_on_ground(creature.global_position), "Spawns sit on ground.")
			var cell: Vector2i = area.world_to_cell(creature.global_position)
			assert_eq(walls.get_cell_source_id(cell), -1, "Spawns never sit inside a wall.")
			assert_eq(
				creature.global_position,
				area.cell_to_world(cell),
				"Spawns start centered on a cell.",
			)


func test_creatures_are_interactable_actors_and_hostility_follows_the_zone() -> void:
	var main_scene: Node2D = _load_main()
	for _frame: int in 3:
		await get_tree().physics_frame

	for zone: SpawnZone in _zones(main_scene):
		for creature: WildCreature in zone.alive_creatures():
			assert_true(creature.is_in_group(WorldActor.GROUP))
			assert_true(creature.is_interactable())
			assert_eq(creature.disposition, zone.disposition)


func test_defeated_creature_is_removed_and_replaced_after_the_respawn_delay() -> void:
	var main_scene: Node2D = _load_main()
	for _frame: int in 3:
		await get_tree().physics_frame

	var zone: SpawnZone = _zones(main_scene)[0]
	zone.respawn_seconds = 0.05
	var before: int = zone.alive_count()
	var victim: WildCreature = zone.alive_creatures()[0]

	victim.mark_defeated()
	assert_eq(zone.alive_count(), before - 1, "A defeated creature leaves the population.")
	assert_false(victim.is_interactable(), "A defeated creature cannot be fought again.")

	await wait_seconds(0.2)
	await get_tree().physics_frame
	assert_eq(zone.alive_count(), before, "The zone refills after respawn_seconds.")
	assert_false(is_instance_valid(victim), "The old body is freed.")


func test_zone_without_species_spawns_nothing() -> void:
	var zone: SpawnZone = autofree(SPAWN_ZONE_SCENE.instantiate())
	add_child(zone)
	for _frame: int in 3:
		await get_tree().physics_frame
	assert_eq(zone.alive_count(), 0)


func test_neutral_creature_wanders_inside_its_leash() -> void:
	var creature: WildCreature = autofree(CREATURE_SCENE.instantiate())
	creature.species = SPECIES
	creature.leash_radius = 96.0
	creature.idle_time_range = Vector2(0.0, 0.0)
	add_child(creature)
	creature.global_position = Vector2(1000, 1000)
	creature.home_position = creature.global_position

	var farthest: float = 0.0
	var moved: bool = false
	for _frame: int in 90:
		await get_tree().physics_frame
		if creature.velocity != Vector2.ZERO:
			moved = true
		farthest = maxf(farthest, creature.global_position.distance_to(creature.home_position))
	assert_true(moved, "A neutral creature must roam on its own.")
	assert_lt(farthest, creature.leash_radius + 8.0, "It must stay within its leash.")


func test_hostile_creature_chases_the_player_and_reports_contact() -> void:
	var player: Player = autofree(preload("res://scenes/player.tscn").instantiate())
	add_child(player)
	player.global_position = Vector2(2000, 2000)
	player.movement_enabled = false

	var creature: WildCreature = autofree(CREATURE_SCENE.instantiate())
	creature.species = SPECIES
	creature.disposition = WildCreature.Disposition.HOSTILE
	creature.detection_radius = 300.0
	creature.leash_radius = 300.0
	add_child(creature)
	creature.global_position = player.global_position + Vector2(200, 0)
	creature.home_position = creature.global_position
	watch_signals(creature)

	var start_distance: float = creature.global_position.distance_to(player.global_position)
	for _frame: int in 5:
		await get_tree().physics_frame
	assert_eq(creature.state, WildCreature.State.CHASE, "The player is in detection range.")
	assert_lt(
		creature.global_position.distance_to(player.global_position),
		start_distance,
		"A chasing creature closes in.",
	)

	for _frame: int in 120:
		await get_tree().physics_frame
		if get_signal_emit_count(creature, "reached_player") > 0:
			break
	assert_signal_emitted(creature, "reached_player")


func test_roaming_can_be_switched_off() -> void:
	var creature: WildCreature = autofree(CREATURE_SCENE.instantiate())
	creature.species = SPECIES
	creature.idle_time_range = Vector2(0.0, 0.0)
	add_child(creature)
	creature.global_position = Vector2(3000, 3000)
	creature.home_position = creature.global_position
	creature.set_roaming(false)

	var start: Vector2 = creature.global_position
	for _frame: int in 30:
		await get_tree().physics_frame
	assert_eq(creature.global_position, start, "A frozen creature does not move.")
