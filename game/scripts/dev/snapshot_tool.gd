## Renders whole areas to PNGs from a real run of the game.
##
## The editor keeps scenes and tilesets it has already loaded in memory, so a
## snapshot taken through the MCP bridge can show the map as it was before the
## last bake. A fresh run has no such cache, which makes this the honest way
## to look at a map after rebuilding it.
##
## Run it windowed (rendering needs a real display) with the areas to shoot
## after `--`, or with no arguments for every shipped area:
##
##     Godot --path game res://scenes/dev_tool_snapshot.tscn -- area_three
##
## The PNGs land in `user://snapshots/<area>.png`, and the path of each one is
## printed as it is written.
extends Node

const AREAS: Dictionary = {
	"town": "res://areas/town.tscn",
	"area_one": "res://areas/area_one.tscn",
	"area_two": "res://areas/area_two.tscn",
	"area_three": "res://areas/area_three.tscn",
}
const OUTPUT_DIR := "user://snapshots"
## Whole maps are big; half scale keeps every one of them under the 16384 px
## a viewport can be.
const SCALE: float = 0.5


func _ready() -> void:
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if wanted.is_empty():
		wanted = PackedStringArray(AREAS.keys())
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	# The tree is still being built in _ready, and a viewport that is not in
	# it yet renders nothing, so everything waits for the first frame.
	await get_tree().process_frame
	var snapshots := SnapshotArea.new()
	add_child(snapshots)
	await RenderingServer.frame_post_draw
	for name: String in wanted:
		if not AREAS.has(name):
			push_error("No area called %s. Known: %s" % [name, AREAS.keys()])
			continue
		var output: String = ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name])
		await snapshots.snapshot(AREAS[name], output, SCALE)
	get_tree().quit(0)
