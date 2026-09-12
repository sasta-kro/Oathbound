## Writes an area scene from one of the layouts in `scripts/dev/layouts/`.
##
## The layout paints into an [AreaPainter], which packs the result as an
## ordinary scene under `res://areas/`. After that the scene is hand-edited
## in the editor; running this again overwrites those edits, so it is a
## starting point, not a build step.
##
## Run from `game/` with the layout name after `--`:
##   godot --headless --path . --script res://scripts/dev/bake_area.gd -- town
##   godot --headless --path . --script res://scripts/dev/bake_area.gd -- area_one
extends SceneTree

const LAYOUTS: Dictionary = {
	"town": "res://scripts/dev/layouts/town_layout.gd",
	"area_one": "res://scripts/dev/layouts/area_one_layout.gd",
}


func _initialize() -> void:
	var names: PackedStringArray = OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(LAYOUTS.keys())
	var failed: bool = false
	for name: String in names:
		if not LAYOUTS.has(name):
			push_error("No layout called %s. Known: %s" % [name, LAYOUTS.keys()])
			failed = true
			continue
		var layout: RefCounted = (load(LAYOUTS[name]) as GDScript).new()
		var painter: AreaPainter = layout.call("build")
		# The painter's nodes need a tree for the packed scene to resolve
		# instance paths; adding them to the root does that.
		root.add_child(painter.area)
		if painter.save("res://areas/%s.tscn" % name) != OK:
			failed = true
		root.remove_child(painter.area)
		painter.area.free()
	quit(1 if failed else 0)
