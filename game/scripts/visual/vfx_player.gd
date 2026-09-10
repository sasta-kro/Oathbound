class_name VfxPlayer
extends Node2D
## Plays one [VfxPreset] and then frees itself.
##
## This is the only place that knows how a preset becomes pixels: callers hand
## it a preset and two positions and forget about it. Nothing here is
## battle-specific, so the overworld plays its impacts and deaths the same way.

## Emitted when the effect has finished playing, just before it frees itself.
signal finished

const SHADER: Shader = preload("res://shaders/vfx_shapes.gdshader")

var _preset: VfxPreset
var _quad: ColorRect
var _material: ShaderMaterial
var _tween: Tween


## Spawns an effect under [param parent] and starts it.
##
## [param from] is the caster's position and [param to] the target's, both in
## [param parent]'s space. [param flip] mirrors directional shapes for a
## creature facing left. Returns the node so a caller can await
## [signal finished]; the node frees itself either way.
static func play(
	parent: Node, preset: VfxPreset, from: Vector2, to: Vector2, flip: bool = false
) -> VfxPlayer:
	var effect := VfxPlayer.new()
	effect._preset = preset if preset != null else VfxPreset.new()
	parent.add_child(effect)
	effect._begin(from, to, flip)
	return effect


## Plays an effect at one point in the world. [param host] is whatever node the
## effect should live under; a defeat effect wants the dying creature's parent
## rather than the creature, so it outlives the body being taken off the map.
static func play_global(host: Node2D, preset: VfxPreset, at: Vector2) -> VfxPlayer:
	var local: Vector2 = host.to_local(at)
	return play(host, preset, local, local)


## Plays a move's effect between two creatures. A move that names no preset
## falls back to the stock effect for its element, so every move presents
## (Specification 23.1). [VfxPreset] deliberately does not know about [MoveData];
## this is the seam between content and presentation.
static func play_move(
	parent: Node, move: MoveData, from: Vector2, to: Vector2, flip: bool = false
) -> VfxPlayer:
	return play(parent, preset_for(move), from, to, flip)


## The effect a move should play.
static func preset_for(move: MoveData) -> VfxPreset:
	if move == null:
		return VfxPreset.for_element(Elements.Type.FIRE)
	if move.vfx != null:
		return move.vfx
	return VfxPreset.for_element(move.type)


## Cuts the effect short, for example when presentation is being skipped.
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	queue_free()


func _begin(from: Vector2, to: Vector2, flip: bool) -> void:
	var beam: bool = _preset.pattern == VfxPreset.Pattern.BEAM
	# A beam is the one shape that spans the gap rather than sitting in it, so
	# it is stretched and aimed instead of being placed at one end.
	var span: Vector2 = to - from
	var size: Vector2 = _preset.size
	if beam:
		size = Vector2(maxf(span.length(), 1.0), _preset.size.y)

	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("pattern", int(_preset.pattern))
	_material.set_shader_parameter("core_color", _preset.core_color)
	_material.set_shader_parameter("edge_color", _preset.edge_color)
	_material.set_shader_parameter("thickness", _preset.thickness)
	_material.set_shader_parameter("softness", _preset.softness)
	_material.set_shader_parameter("ragged", _preset.ragged)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 0.001))
	_material.set_shader_parameter("variant", randf())
	_material.set_shader_parameter("progress", 0.0)

	_quad = ColorRect.new()
	_quad.color = Color.WHITE
	_quad.size = size
	# The beam starts at the caster and runs outwards; every other shape is
	# centred on wherever it was placed.
	_quad.position = Vector2(0.0, -size.y * 0.5) if beam else -size * 0.5
	_quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quad.material = _material
	add_child(_quad)

	modulate.a = _preset.opacity
	scale.x = -1.0 if flip and not beam else 1.0
	if beam:
		position = from
		rotation = span.angle()
	else:
		position = (from if _preset.delivery == VfxPreset.Delivery.ON_USER else to) + _preset.offset

	var seconds: float = _preset.play_seconds()
	_tween = create_tween()
	if _preset.smooth:
		_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_material, "shader_parameter/progress", 1.0, seconds).from(0.0)
	if _preset.delivery == VfxPreset.Delivery.TRAVEL and not beam:
		_tween.parallel().tween_property(self, "position", to + _preset.offset, seconds).from(
			from + _preset.offset
		)
	_tween.finished.connect(_on_finished)


func _on_finished() -> void:
	finished.emit()
	queue_free()
