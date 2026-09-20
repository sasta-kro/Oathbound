## Fills `areas/area_three.tscn` with its guards, its wild dead and the king.
##
## Area Three is the dead city: the kingdom the altar swallowed. It holds no
## living people, so the only friendly face is the last champion's ghost at
## the arrival. Everything else between the stair and the seat is there to
## make the walk up the causeway feel like the last one.
##
## Run as a scene, not through `-s`: `wild_creature.gd` and `world_actor.gd`
## read autoloads, which only exist for a real main loop, and under `-s` every
## property set on them is silently dropped.
##
##     Godot --headless --path game res://scenes/dev_tool_area_three.tscn
extends Node

const AREA_PATH := "res://areas/area_three.tscn"
const ACTOR_SCENE := preload("res://scenes/world_actor.tscn")
const CREATURE_SCENE := preload("res://scenes/wild_creature.tscn")
const SPAWN_SCENE := preload("res://scenes/spawn_zone.tscn")
const SPECIES := "res://content/creatures/creature_%s.tres"

## Wild dead, as (species id, cell, radius, max alive, level band, hostile).
## The band runs 30 to 38, so the causeway carries a party from the Kingsworn
## up to the seat.
const SPAWNS := [
	["earth_03", Vector2i(46, 84), 4.0, 3, 30, 32, true],
	["wind_05", Vector2i(46, 60), 4.0, 2, 31, 33, true],
	["water_04", Vector2i(22, 54), 4.0, 2, 32, 34, true],
	["wind_06", Vector2i(68, 54), 4.0, 2, 33, 35, true],
	["earth_04", Vector2i(46, 44), 3.0, 2, 34, 36, true],
	["earth_06", Vector2i(34, 16), 4.0, 2, 35, 37, true],
	["fire_04", Vector2i(60, 16), 4.0, 2, 36, 38, true],
]

## The two elites of Specification 5.3, standing in the side chambers.
## Placeholders: they are meant to be hostile Oathkeepers with rosters, which
## do not exist yet, so for now they are lone champions of the king's household.
const ELITES := [
	{
		"marker": "Elite_West",
		"name": "HouseholdKnightWest",
		"species": "earth_07",
		"level": 34,
	},
	{
		"marker": "Elite_East",
		"name": "HouseholdKnightEast",
		"species": "earth_05",
		"level": 34,
	},
]

const BOSS_SPECIES := "rot_01"
const BOSS_LEVEL := 38
const BOSS_ID: StringName = &"boss_area_03"
const BOSS_CHALLENGE := "The Skeleton Lord: Another of the little wardens. Do you know what you are interrupting? I am waiting. I have been waiting on this seat since the hour I reached past the door of the world and took my son back through it. He is still coming. He has been coming for four hundred years. Put your oath down and wait with me, or put it to use. It makes very little difference which."
const BOSS_SEALED := "A crowned thing sits on the seat at the end of the hall, wrapped in green fire, and does not look up. Whatever is left of the Kingsworn's faith is the only reason it has not already noticed you."
const BOSS_VICTORY := "The Skeleton Lord: Ah. There. The green fire goes out of him one thread at a time, and the crown slides off a skull that is only a skull. Not gone, he says, as the seat empties. Only set down again. Come back in a hundred years and I will still be waiting on him, and so will whoever they send. The bells begin to ring somewhere far above, and for once nobody is pulling the rope."
## The champion who came down the stair before this one and did not come up.
const GHOST := {
	"name": "LastChampion",
	"display": "A DEAD CHAMPION",
	"sprite": "knight",
	"line": "A dead champion of the Order sits with her back to the wall, seal-iron still on her chest, and does not get up. You made it further than I did, she says, without much interest. He is up the causeway, past the gate, on the seat. Mind the two in the side chambers; they are his household, and they were knights once, same as us. Go on. I will keep the stair.",
}


func _ready() -> void:
	var packed := load(AREA_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % AREA_PATH)
		get_tree().quit(1)
		return
	var area := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	var markers := area.get_node_or_null("MapMarkers")
	var ground := area.get_node("Ground") as TileMapLayer
	var actors := area.get_node("Actors") as Node2D
	var spawns := area.get_node("SpawnZones") as Node2D
	_clear(actors)
	_clear(spawns)

	var ghost := ACTOR_SCENE.instantiate()
	ghost.name = String(GHOST["name"])
	ghost.position = _cell_to_world(ground, Vector2i(42, 104))
	ghost.set("display_name", GHOST["display"])
	ghost.set("sprite_frames", load("res://content/sprites/npc_%s.tres" % GHOST["sprite"]))
	ghost.set("facing", &"right")
	ghost.set("dialogue_line", GHOST["line"])
	ghost.set("heals_party", true)
	actors.add_child(ghost)
	ghost.owner = area

	for row: Array in SPAWNS:
		var zone := SPAWN_SCENE.instantiate()
		zone.name = "Spawn_%s" % row[0]
		zone.position = _cell_to_world(ground, row[1])
		zone.set("species", load(SPECIES % row[0]))
		zone.set("radius_in_cells", row[2])
		zone.set("max_alive", row[3])
		zone.set("level_min", row[4])
		zone.set("level_max", row[5])
		if row[6]:
			zone.set("disposition", 1)
		spawns.add_child(zone)
		zone.owner = area

	for elite: Dictionary in ELITES:
		var marker := markers.get_node_or_null(String(elite["marker"])) as Marker2D
		if marker == null:
			push_error("No marker %s in Area Three." % elite["marker"])
			continue
		var guard := CREATURE_SCENE.instantiate()
		guard.name = String(elite["name"])
		guard.position = marker.position
		guard.set("species", load(SPECIES % elite["species"]))
		guard.set("level", elite["level"])
		guard.set("disposition", 1)
		guard.set("leash_radius", 240.0)
		actors.add_child(guard)
		guard.owner = area

	var boss_marker := markers.get_node_or_null("Boss") as Marker2D
	if boss_marker != null:
		var king := CREATURE_SCENE.instantiate()
		king.name = "SkeletonLord"
		king.position = boss_marker.position
		king.set("species", load(SPECIES % BOSS_SPECIES))
		king.set("level", BOSS_LEVEL)
		king.set("ability_index", 0)
		king.set("boss_id", BOSS_ID)
		king.set("challenge_line", BOSS_CHALLENGE)
		king.set("sealed_line", BOSS_SEALED)
		king.set("victory_line", BOSS_VICTORY)
		king.set("leash_radius", 0.0)
		actors.add_child(king)
		king.owner = area

	var uid: String = _scene_uid()
	var rebuilt := PackedScene.new()
	var error := rebuilt.pack(area)
	if error == OK:
		error = ResourceSaver.save(rebuilt, AREA_PATH)
	if error != OK:
		push_error("Failed to save %s (error %d)" % [AREA_PATH, error])
		get_tree().quit(1)
		return
	_restore_uid(uid)
	print(
		"Area Three populated: 1 NPC, %d spawn zones, %d elites, boss %s at level %d."
		% [SPAWNS.size(), ELITES.size(), BOSS_SPECIES, BOSS_LEVEL]
	)
	get_tree().quit(0)


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _cell_to_world(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	return ground.position + (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(ground.tile_set.tile_size) * ground.scale


func _scene_uid() -> String:
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return ""
	var header: String = file.get_line()
	file.close()
	if not (' uid="' in header):
		return ""
	return header.split(' uid="')[1].split('"')[0]


func _restore_uid(uid: String) -> void:
	if uid.is_empty():
		return
	var file := FileAccess.open(AREA_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	if ' uid="' in text.split("\n")[0]:
		return
	text = text.replace("[gd_scene format=4]", '[gd_scene format=4 uid="%s"]' % uid)
	file = FileAccess.open(AREA_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
