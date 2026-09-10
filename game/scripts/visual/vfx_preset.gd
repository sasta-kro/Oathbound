class_name VfxPreset
extends Resource
## A reusable effect preset (Specification 23).
##
## Effects are content, not code: every effect in the game draws through the
## one `vfx_shapes` shader, and a preset only chooses which shape it draws, in
## what colours, at what size and how fast. Giving a new move, impact or death
## its own look means duplicating a preset and changing two colours, not
## writing a shader.
##
## A move with no preset still gets an effect: [method for_element] supplies a
## typed default, so content added before this system existed keeps working.

## Shapes the shader can draw. Values match the `pattern` uniform in
## `res://shaders/vfx_shapes.gdshader` and must not be reordered.
enum Pattern {
	BURST,  ## Expanding ragged shell. Explosions, impacts, elemental hits.
	RING,  ## Flat ground ellipse. Quakes, stomps, anything from below.
	SLASH,  ## Sweeping crescent. Physical strikes and cutting winds.
	BEAM,  ## Lance that grows towards the target. Jets, bolts, breath.
	MOTES,  ## Rising specks over an area. Gusts, buffs, guards, lingering status.
	SPARKS,  ## Specks flying out from the centre. Something coming apart.
}

## Where the effect plays.
enum Delivery {
	ON_TARGET,  ## At whoever is being hit. The default for damage.
	ON_USER,  ## At the caster, for self-buffs and guards.
	TRAVEL,  ## Flies from the caster to the target.
}

## Stable content id, independent of the file name (Specification 25.2).
@export var id: StringName = &""
@export var pattern: Pattern = Pattern.BURST
@export var delivery: Delivery = Delivery.ON_TARGET

@export_group("Colour")
## Colour at the hot inner edge of the shape.
@export var core_color: Color = Color(1.0, 0.93, 0.60)
## Colour at its cooling outer edge.
@export var edge_color: Color = Color(0.95, 0.35, 0.10)
## Scales the whole effect's opacity, so one preset can be a flourish or a
## full-screen hit.
@export_range(0.0, 1.0) var opacity: float = 1.0

@export_group("Shape")
## Size of the drawn quad in stage pixels.
@export var size: Vector2 = Vector2(200, 200)
## Nudges the effect off the creature's origin, in stage pixels.
@export var offset: Vector2 = Vector2.ZERO
## Width of the drawn band, as a share of the quad. [constant Pattern.MOTES]
## and [constant Pattern.SPARKS] draw no band and read this as the size of one
## speck instead.
@export_range(0.02, 1.0) var thickness: float = 0.26
## How far the band fades at its edges. 0 draws hard, pixel-art edges.
@export_range(0.0, 0.5) var softness: float = 0.10
## Distorts the outline. 0 draws a clean geometric shape.
@export_range(0.0, 1.0) var ragged: float = 0.35

@export_group("Timing")
## How long the effect plays at speed 1, in seconds.
@export_range(0.05, 4.0) var duration: float = 0.45
## Divides [member duration]. 2.0 plays the same effect twice as fast.
@export_range(0.1, 4.0) var speed: float = 1.0
## Eases the effect in and out instead of running at a constant rate.
@export var smooth: bool = true

## Default colours per element, used when a move names no preset.
const ELEMENT_PALETTES: Dictionary = {
	Elements.Type.FIRE: [Color("ffe9a8"), Color("e8511a")],
	Elements.Type.EARTH: [Color("f0d9a8"), Color("8a5a2b")],
	Elements.Type.WATER: [Color("d6f4ff"), Color("2b7fd4")],
	Elements.Type.WIND: [Color("eafff0"), Color("4fbf7a")],
}
## Default shape per element, so the four types already read differently.
const ELEMENT_PATTERNS: Dictionary = {
	Elements.Type.FIRE: Pattern.BURST,
	Elements.Type.EARTH: Pattern.RING,
	Elements.Type.WATER: Pattern.BEAM,
	Elements.Type.WIND: Pattern.SLASH,
}


## How long this preset actually plays for.
func play_seconds() -> float:
	return duration / maxf(0.1, speed)


## A copy in different colours. The point of the preset system: a second fire
## move reuses the first one's shape and timing and only changes its palette.
func recoloured(new_core: Color, new_edge: Color) -> VfxPreset:
	var copy: VfxPreset = duplicate()
	copy.core_color = new_core
	copy.edge_color = new_edge
	return copy


## A copy drawn larger or smaller. The overworld draws creatures far smaller
## than the battle stage does, so it plays the same effects scaled down rather
## than keeping a second set of presets in step with the first.
func scaled(factor: float) -> VfxPreset:
	var copy: VfxPreset = duplicate()
	copy.size = size * factor
	copy.offset = offset * factor
	return copy


## A copy that plays faster or slower. [param factor] multiplies [member speed].
func at_speed(factor: float) -> VfxPreset:
	var copy: VfxPreset = duplicate()
	copy.speed = maxf(0.1, speed * factor)
	return copy


## The stock effect for an element, built in code so it needs no asset.
static func for_element(type: Elements.Type) -> VfxPreset:
	var preset := VfxPreset.new()
	preset.id = StringName("vfx_%s_default" % Elements.id(type))
	preset.pattern = ELEMENT_PATTERNS.get(type, Pattern.BURST)
	var palette: Array = ELEMENT_PALETTES.get(type, ELEMENT_PALETTES[Elements.Type.FIRE])
	preset.core_color = palette[0]
	preset.edge_color = palette[1]
	if preset.pattern == Pattern.BEAM:
		preset.delivery = Delivery.TRAVEL
		preset.size = Vector2(260, 120)
	return preset


## Content problems for this preset, empty when valid.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("Effect preset at '%s' has no id." % resource_path)
	if size.x <= 0.0 or size.y <= 0.0:
		problems.append("Effect preset '%s' has an empty size." % id)
	return problems
