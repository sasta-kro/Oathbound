## Fills `areas/area_two.tscn` with its cast, its wild creatures and its boss.
##
## Area Two is the folded kingdom under the altar: the people sealed in with
## it are still alive down here, and the champions the Order has sent for
## centuries are mostly not. The five NPC markers the plan bake laid down
## become the cast, the Boss marker becomes the Kingsworn, and the spawn
## anchors below become the wild creatures of the deep.
##
## This is a separate pass rather than part of `build_area_two_map.gd`,
## because that script still expects the Area One layer names and cannot run
## against this scene. It reads the markers the bake left, so re-running it is
## safe: the Actors and SpawnZones nodes are rebuilt from scratch each time.
##
## It runs as a scene rather than through `-s`, because `world_actor.gd` and
## `wild_creature.gd` read autoloads, and autoloads are only registered for a
## real main loop. Under `-s` those scripts fail to compile and every property
## set on their nodes is silently dropped.
##
##     Godot --headless --path game res://scenes/dev_tool.tscn
extends Node

const AREA_PATH := "res://areas/area_two.tscn"
const ACTOR_SCENE := preload("res://scenes/world_actor.tscn")
const CREATURE_SCENE := preload("res://scenes/wild_creature.tscn")
const SPAWN_SCENE := preload("res://scenes/spawn_zone.tscn")
const SPRITES := "res://content/sprites/npc_%s.tres"
const SPECIES := "res://content/creatures/creature_%s.tres"

## The cast, by the marker each one stands on. Aldric is the through-line, the
## Bellkeeper is the safe point, and the Nurse is deliberately the furthest
## from the stair, because what she knows should be the last thing learned.
const CAST := [
	{
		"marker": "NPC_1",
		"name": "Aldric",
		"display": "ALDRIC",
		"sprite": "old_man",
		"facing": &"down",
		"line": "Aldric: Another one. Put the scroll away, lad, I'm no wild thing. Aldric of the Order, champion of the ninth watch. I came down that same stair thirty years ago and did what you're here to do. The stair shut before I climbed back up. Come on. I'll show you what nobody upstairs can tell you.",
	},
	{
		"marker": "NPC_2",
		"name": "Bellkeeper",
		"display": "THE BELLKEEPER",
		"sprite": "elder",
		"facing": &"right",
		"line": "The Bellkeeper: Rest, and let me see to your Oathbound. You heard the bells, didn't you. Everyone up there thinks the seal rings them. It doesn't. I ring them. I have rung them every time the seal thinned since before your town had a name, because someone has to call you people down.",
		"heals": true,
	},
	{
		"marker": "NPC_3",
		"name": "Archivist",
		"display": "THE ARCHIVIST",
		"sprite": "scribe",
		"facing": &"down",
		"line": "The Archivist: Nine, they tell you. Nine times the dead king has been put back under. I have the ledger here and the ledger says otherwise. It says forty-one. It also says each watch is shorter than the one before it, and that the one before yours was eleven years.",
	},
	{
		"marker": "NPC_4",
		"name": "Gravewright",
		"display": "THE GRAVEWRIGHT",
		"sprite": "merchant",
		"facing": &"down",
		"line": "The Gravewright: Mind where you tread. They are all champions, every one of these. I dig for the ones who make it this far and no further, and I take the seal-iron off them so it can go home even when they can't. Bring me any you find. They should not be left lying in his halls.",
	},
	{
		"marker": "NPC_5",
		"name": "Nurse",
		"display": "THE NURSE",
		"sprite": "innkeeper",
		"facing": &"up",
		"line": "The Nurse: You came a long way to be told this, so I will say it plainly. You cannot end him. Nobody can, while the boy endures. The king bound his own death to his son's un-death, and that is the knot your Order has been tying a bow around for four hundred years. Seal him if you like. Then come back and find me, and we will talk about the boy.",
	},
]

## Wild creatures of the deep, as (species id, anchor cell, radius, max alive,
## level band, hostile). Levels run 16 to 28, so the walk from the stair to
## the Kingsworn carries a party from the Black Knight up to him.
const SPAWNS := [
	["earth_03", Vector2i(34, 44), 3.0, 2, 16, 18, true],
	["water_06", Vector2i(30, 70), 3.5, 3, 16, 19, false],
	["wind_05", Vector2i(62, 34), 3.0, 2, 18, 21, true],
	["water_03", Vector2i(78, 62), 3.5, 2, 19, 22, false],
	["earth_04", Vector2i(96, 40), 2.5, 2, 21, 24, true],
	["fire_04", Vector2i(104, 74), 3.0, 2, 22, 25, true],
	["water_04", Vector2i(118, 84), 3.0, 2, 23, 26, false],
	["wind_06", Vector2i(116, 40), 2.5, 2, 24, 27, true],
	["earth_06", Vector2i(128, 34), 2.5, 1, 25, 28, true],
]

const BOSS_SPECIES := "earth_07"
const BOSS_LEVEL := 28
const BOSS_ID: StringName = &"boss_area_02"
## The quest that should gate him once the Area Two chain exists. Left empty
## on the node for now: a required_quest naming a quest the registry does not
## have would seal him for good, and there would be no way to fight him.
const BOSS_QUEST: StringName = &""
const BOSS_CHALLENGE := "The Kingsworn: Far enough. I know what you are; one comes every few winters now, and each of you is younger than the last. My brother keeps the door above. I keep this one. He chose what he keeps. I did not have to choose, because my oath was never broken - it held, through all of it, and it holds now. That is the whole horror of me, and it will not move me aside. Draw."
const BOSS_SEALED := "A knight in gold-white fire stands between you and the stair down, unmoving. He does not draw. Not yet, he says. You have not seen what is below, and I will not spend you for nothing. Go and be told first. Then come back and mean it."
const BOSS_VICTORY := "The Kingsworn: Ah. Held, and still not enough. He lowers his sword and steps off the stair, and the blue fire on him gutters low. Go down, then. He is through there, on the seat, where he has been since the hour he unmade us. Tell him his knight kept faith. He will not care. He never did."


func _ready() -> void:
	var packed := load(AREA_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % AREA_PATH)
		get_tree().quit(1)
		return
	var area := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED) as Node2D
	var markers := area.get_node_or_null("MapMarkers")
	if markers == null:
		push_error("Area Two has no MapMarkers to build on.")
		get_tree().quit(1)
		return
	var ground := area.get_node("Ground") as TileMapLayer

	var actors := area.get_node("Actors") as Node2D
	var spawns := area.get_node("SpawnZones") as Node2D
	_clear(actors)
	_clear(spawns)
	spawns.visible = true

	for entry: Dictionary in CAST:
		var marker := markers.get_node_or_null(String(entry["marker"])) as Marker2D
		if marker == null:
			push_error("No marker %s in Area Two." % entry["marker"])
			continue
		var actor := ACTOR_SCENE.instantiate()
		actor.name = String(entry["name"])
		actor.position = marker.position
		actor.set("display_name", entry["display"])
		actor.set("sprite_frames", load(SPRITES % entry["sprite"]))
		actor.set("facing", entry["facing"])
		actor.set("dialogue_line", entry["line"])
		if entry.get("heals", false):
			actor.set("heals_party", true)
		actors.add_child(actor)
		actor.owner = area

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

	var boss_marker := markers.get_node_or_null("Boss") as Marker2D
	if boss_marker != null:
		var boss := CREATURE_SCENE.instantiate()
		boss.name = "Kingsworn"
		boss.position = boss_marker.position
		boss.set("species", load(SPECIES % BOSS_SPECIES))
		boss.set("level", BOSS_LEVEL)
		boss.set("ability_index", 0)
		boss.set("boss_id", BOSS_ID)
		boss.set("required_quest", BOSS_QUEST)
		boss.set("challenge_line", BOSS_CHALLENGE)
		boss.set("sealed_line", BOSS_SEALED)
		boss.set("victory_line", BOSS_VICTORY)
		boss.set("leash_radius", 0.0)
		actors.add_child(boss)
		boss.owner = area

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
		"Area Two populated: %d NPCs, %d spawn zones, boss %s at level %d."
		% [CAST.size(), SPAWNS.size(), BOSS_SPECIES, BOSS_LEVEL]
	)
	get_tree().quit(0)


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _cell_to_world(ground: TileMapLayer, cell: Vector2i) -> Vector2:
	return ground.position + (Vector2(cell) + Vector2(0.5, 0.5)) * Vector2(ground.tile_set.tile_size) * ground.scale


## Saving a repacked scene drops the uid, and anything referring to the area
## by uid:// then resolves to whichever scene the cache saw last.
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
