extends Control
## Cache idle frames and their shared crop, so animation never changes scale.
static var cache: Dictionary = {}
var textures: Array[Texture2D] = []
var frame := 0
var clock := 0.0
var fps := 6.0
var fallback := "?"

func setup(species: CreatureSpecies) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fallback = species.display_name.left(1)
	var frames := species.battle_sprite
	if frames == null or frames.get_animation_names().is_empty(): return
	var animation: StringName = &"idle" if frames.has_animation(&"idle") else frames.get_animation_names()[0]
	var key := str(frames.get_instance_id()) + String(animation)
	fps = maxf(1.0, frames.get_animation_speed(animation))
	if cache.has(key):
		textures.assign(cache[key])
		return
	var crop := Rect2i()
	for i in frames.get_frame_count(animation):
		var source := frames.get_frame_texture(animation, i)
		if source == null: continue
		var used := source.get_image().get_used_rect()
		crop = used if crop.size == Vector2i.ZERO else crop.merge(used)
	for i in frames.get_frame_count(animation):
		var source := frames.get_frame_texture(animation, i)
		if source == null: continue
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = crop
		textures.append(atlas)
	cache[key] = textures.duplicate()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or textures.size() < 2: return
	clock += delta
	if clock >= 1.0 / fps:
		clock = fmod(clock, 1.0 / fps)
		frame = (frame + 1) % textures.size()
		queue_redraw()

func _draw() -> void:
	if textures.is_empty():
		draw_string(ThemeDB.fallback_font, size * 0.5, fallback, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color("d9bb80"))
		return
	var tex := textures[frame]
	var factor := minf(size.x / tex.get_width(), size.y / tex.get_height())
	var extent := tex.get_size() * factor
	draw_texture_rect(tex, Rect2((size - extent) * 0.5, extent), false)
