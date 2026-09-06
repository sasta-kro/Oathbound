## Writes the sample map `res://areas/area_one.tscn`.
##
## Paints the generated Area 1 layout into plain TileMapLayers, adds the
## knight, the player start and three spawn zones, and saves the result as an
## ordinary scene. After this runs once the scene is hand-edited in the
## editor; re-running overwrites those edits, so it is a starting point, not
## a build step.
##
## Run with:
##   godot --headless --path game --script res://scripts/dev/bake_area_one.gd
extends SceneTree

const OUTPUT_PATH: String = "res://areas/area_one.tscn"
const TILESET_PATH: String = "res://assets/tilesets/area_one.tres"
const WORLD_AREA_SCRIPT: String = "res://scripts/world/world_area.gd"
const ACTOR_SCENE: String = "res://scenes/world_actor.tscn"
const SPAWN_ZONE_SCENE: String = "res://scenes/spawn_zone.tscn"

## The 32 px sheets are drawn at 1.5x so one cell is 48 px.
const LAYER_SCALE := Vector2(1.5, 1.5)

const PLAYER_START_CELL := Vector2i(5, 9)
const KNIGHT_CELL := Vector2i(5, 5)

## Zones for the sample map. Cells are checked against the generator's wall
## and path rectangles by eye: each center sits on open grass.
const SPAWN_ZONES: Array[Dictionary] = [
	{
		"name": "LoambuckMeadow",
		"species": "res://content/creatures/creature_earth_01.tres",
		"cell": Vector2i(17, 3),
		"radius": 2.5,
		"max_alive": 3,
		"levels": Vector2i(2, 4),
		"hostile": false,
	},
	{
		"name": "EmberlingDen",
		"species": "res://content/creatures/creature_fire_01.tres",
		"cell": Vector2i(8, 4),
		"radius": 2.0,
		"max_alive": 2,
		"levels": Vector2i(3, 5),
		"hostile": true,
	},
	{
		"name": "PuddlePool",
		"species": "res://content/creatures/creature_water_01.tres",
		"cell": Vector2i(11, 11),
		"radius": 2.0,
		"max_alive": 2,
		"levels": Vector2i(2, 3),
		"hostile": false,
	},
]


var _generator: AreaOneGenerator


## The generator paints in `_ready`, which only runs once the tree starts
## iterating, so the bake itself waits for the first frame.
func _initialize() -> void:
	var tile_set: TileSet = load(TILESET_PATH)
	_generator = AreaOneGenerator.new()
	for layer_name: String in ["Ground", "Path", "Walls", "Decor"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		_generator.add_child(layer)
	root.add_child(_generator)


func _process(_delta: float) -> bool:
	_bake()
	return true


func _bake() -> void:
	var tile_set: TileSet = load(TILESET_PATH)
	var generator: AreaOneGenerator = _generator

	var area := Node2D.new()
	area.name = "AreaOne"
	area.set_script(load(WORLD_AREA_SCRIPT))

	for layer_name: String in ["Ground", "Path", "Walls", "Decor"]:
		var source: TileMapLayer = generator.get_node(layer_name)
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		layer.position = AreaOneGenerator.ROOM_RECTANGLE.position
		layer.scale = LAYER_SCALE
		layer.z_index = -1
		layer.tile_map_data = source.tile_map_data
		area.add_child(layer)
		layer.owner = area
	area.set("ground", area.get_node("Ground"))

	var player_start := Marker2D.new()
	player_start.name = "PlayerStart"
	player_start.position = AreaOneGenerator.cell_to_world(PLAYER_START_CELL)
	area.add_child(player_start)
	player_start.owner = area
	area.set("player_start", player_start)

	var knight: Node2D = (load(ACTOR_SCENE) as PackedScene).instantiate()
	knight.name = "Knight"
	knight.position = AreaOneGenerator.cell_to_world(KNIGHT_CELL)
	knight.set("display_name", "KNIGHT")
	knight.set("body_color", Color(0.247059, 0.72549, 0.34902, 1))
	knight.set("dialogue_line", "Knight: The northern ruins remain sealed. Keep to the marked path.")
	knight.set("heals_party", true)
	area.add_child(knight)
	knight.owner = area

	var zones := Node2D.new()
	zones.name = "SpawnZones"
	area.add_child(zones)
	zones.owner = area
	for definition: Dictionary in SPAWN_ZONES:
		var zone: Node2D = (load(SPAWN_ZONE_SCENE) as PackedScene).instantiate()
		zone.name = definition["name"]
		zone.position = AreaOneGenerator.cell_to_world(definition["cell"])
		zone.set("species", load(definition["species"]))
		zone.set("radius_in_cells", definition["radius"])
		zone.set("max_alive", definition["max_alive"])
		zone.set("level_min", (definition["levels"] as Vector2i).x)
		zone.set("level_max", (definition["levels"] as Vector2i).y)
		zone.set("disposition", 1 if definition["hostile"] else 0)
		zones.add_child(zone)
		zone.owner = area

	var packed := PackedScene.new()
	var error: int = packed.pack(area)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
		error = ResourceSaver.save(packed, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [OUTPUT_PATH, error])
	else:
		print("Wrote ", OUTPUT_PATH)
	quit(0 if error == OK else 1)
