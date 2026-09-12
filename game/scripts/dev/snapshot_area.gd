@tool
class_name SnapshotArea
extends Node
## Renders a whole area scene to a PNG, for checking a map without walking it.
##
## Development only. Works from the editor and from a running game. The MCP
## bridge only evaluates expressions on the edited scene's root, so from there
## the way in is to add a Node with this script to the scene, call
## `get_node("Snapshot").snapshot(...)`, and delete the node again:
##
##   SnapshotArea.new().snapshot("res://areas/town.tscn", "/tmp/town.png", 0.5)
##
## The scene is instanced under a private SubViewport sized to the painted
## ground, drawn at [param scale], saved, and torn down again. Editor-only
## gizmos (spawn circles, exit rectangles) show up when called from the editor,
## which is the point: they are what a map author wants to check.

const MAX_SIDE: int = 16384


func snapshot(scene_path: String, output_path: String, scale: float = 0.5) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("SnapshotArea: %s is not a scene." % scene_path)
		return
	var area: Node2D = packed.instantiate()
	var host: Node = Engine.get_main_loop().root
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	host.add_child(viewport)
	viewport.add_child(area)

	var bounds: Rect2 = _bounds(area)
	viewport.size = Vector2i(
		mini(int(bounds.size.x * scale), MAX_SIDE), mini(int(bounds.size.y * scale), MAX_SIDE)
	)
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE * scale
	camera.position = bounds.get_center()
	viewport.add_child(camera)
	camera.make_current()

	# Two draws: one for the tree to settle, one with everything visible.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var error: int = image.save_png(output_path)
	if error != OK:
		push_error("SnapshotArea: could not write %s (error %d)" % [output_path, error])
	else:
		print("SnapshotArea: wrote %s (%dx%d)" % [output_path, image.get_width(), image.get_height()])
	viewport.queue_free()


func _bounds(area: Node2D) -> Rect2:
	var ground: TileMapLayer = area.get_node_or_null(^"Ground") as TileMapLayer
	if ground == null:
		return Rect2(-960, -540, 1920, 1080)
	var used: Rect2i = ground.get_used_rect()
	var top_left: Vector2 = ground.position + Vector2(used.position * ground.tile_set.tile_size) * ground.scale
	var size: Vector2 = Vector2(used.size * ground.tile_set.tile_size) * ground.scale
	return Rect2(top_left, size)
