class_name QuestCelebration
extends Control
## The moment a quest is turned in: the evolution's payoff chime, a gold flash, a banner that
## punches in with the quest's title, and confetti bursting from behind it.
##
## Built in code in the same visual language as [FieldUI]. It never takes
## input, so the dialogue carrying the giver's thanks stays usable under it,
## and frees itself when done.

const HOLD_SECONDS := 2.6
const BURST_COUNT := 120
## Pieces that drift down from above the screen after the burst.
const RAIN_COUNT := 80
const CONFETTI_LIFE := 3.4
const GRAVITY := 300.0
const BANNER_TOP := 96.0
const COLORS: Array[Color] = [OathTheme.GOLD, OathTheme.PAPER, OathTheme.JADE, Color("e9a078"), Color("83c5dc"), Color("b79ac9")]

var _banner: PanelContainer
var _rays: Rays
var _flash: ColorRect
var _confetti: Array[Dictionary] = []
var _age := 0.0


## Plays the celebration for [param quest] once and frees itself.
func play(quest: QuestData) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SfxService.play(&"bind_success")

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(OathTheme.GOLD, 0.28)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_rays = Rays.new()
	add_child(_rays)

	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := OathTheme.box(Color(OathTheme.INK, 0.94), OathTheme.GOLD, 10, 16)
	frame.content_margin_left = 34
	frame.content_margin_right = 34
	frame.set_border_width_all(2)
	frame.shadow_color = Color(OathTheme.GOLD, 0.35)
	frame.shadow_size = 14
	_banner.add_theme_stylebox_override("panel", frame)
	add_child(_banner)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	_banner.add_child(column)
	var kicker := OathTheme.label("✦   QUEST COMPLETE   ✦", 11, OathTheme.GOLD)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var title := OathTheme.heading(quest.title, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(title)

	# Size is only known once the container has laid out its children.
	_banner.reset_size()
	var banner_size := _banner.get_combined_minimum_size()
	var width := get_viewport_rect().size.x
	_banner.position = Vector2((width - banner_size.x) * 0.5, BANNER_TOP)
	_banner.size = banner_size
	_banner.pivot_offset = banner_size * 0.5
	var origin := _banner.position + banner_size * 0.5
	_rays.origin = origin
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spawn_confetti(origin, banner_size)

	_banner.scale = Vector2(0.4, 0.4)
	_banner.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_flash, "color:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_rays, "energy", 1.0, 0.4)
	tween.chain().tween_interval(HOLD_SECONDS)
	tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.45)
	tween.parallel().tween_property(_banner, "position:y", BANNER_TOP - 18, 0.45).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_rays, "energy", 0.0, 0.45)
	tween.chain().tween_callback(queue_free)


func _spawn_confetti(origin: Vector2, banner_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i: int in BURST_COUNT:
		# Out from the banner's ends and sides; the banner sits high, so
		# pieces lean sideways rather than straight up and off the screen.
		var side := -1.0 if i % 2 == 0 else 1.0
		var angle := rng.randf_range(-PI * 0.45, PI * 0.2)
		var dir := Vector2.from_angle(angle) * Vector2(side, 1.0)
		var start := origin + Vector2(side * rng.randf_range(0.2, 0.5) * banner_size.x, rng.randf_range(-0.3, 0.3) * banner_size.y)
		_confetti.append(_piece(rng, start, dir * rng.randf_range(180.0, 520.0), rng.randf() * 0.12))
	var width := get_viewport_rect().size.x
	for i: int in RAIN_COUNT:
		var start := Vector2(rng.randf_range(0.0, width), rng.randf_range(-60.0, -10.0))
		_confetti.append(_piece(rng, start, Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(20.0, 90.0)), rng.randf_range(0.15, 1.1)))


func _piece(rng: RandomNumberGenerator, start: Vector2, velocity: Vector2, delay: float) -> Dictionary:
	return {
		"pos": start,
		"vel": velocity,
		"spin": rng.randf_range(-10.0, 10.0),
		"rot": rng.randf() * TAU,
		"size": Vector2(rng.randf_range(7, 12), rng.randf_range(4, 6)),
		"color": COLORS[rng.randi() % COLORS.size()],
		"delay": delay,
	}


func _process(delta: float) -> void:
	_age += delta
	for piece: Dictionary in _confetti:
		if _age < piece.delay:
			continue
		var vel: Vector2 = piece.vel
		# Air drag caps the fall so strips flutter down instead of dropping.
		vel.y = minf(vel.y + GRAVITY * delta, 120.0 + absf(vel.x) * 0.2)
		vel.x *= 1.0 - 1.6 * delta
		vel.x += sin(_age * 3.0 + piece.rot) * 30.0 * delta
		piece.vel = vel
		piece.pos += vel * delta
		piece.rot += piece.spin * delta
	queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - (_age - CONFETTI_LIFE + 0.6) / 0.6, 0.0, 1.0)
	if fade <= 0.0:
		return
	for piece: Dictionary in _confetti:
		if _age < piece.delay:
			continue
		# Flutter: the visible width swings as the strip turns over.
		var flip := absf(cos(piece.rot))
		var half: Vector2 = piece.size * Vector2(maxf(flip, 0.2), 1.0) * 0.5
		draw_set_transform(piece.pos, piece.rot * 0.5, Vector2.ONE)
		var color: Color = piece.color
		draw_rect(Rect2(-half, half * 2.0), Color(color, fade * (0.65 + 0.35 * flip)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Soft gold light turning slowly behind the banner.
class Rays:
	extends Control

	const COUNT := 14
	var origin := Vector2.ZERO
	var energy := 0.0
	var _spin := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_spin = fmod(_spin + delta * 0.35, TAU)
		queue_redraw()

	func _draw() -> void:
		if energy <= 0.0:
			return
		var reach := 440.0 * energy
		for i: int in COUNT:
			var a := _spin + i * TAU / COUNT
			var spread := 0.07
			var points := PackedVector2Array([
				origin,
				origin + Vector2.from_angle(a - spread) * reach,
				origin + Vector2.from_angle(a + spread) * reach,
			])
			var colors := PackedColorArray([Color(OathTheme.GOLD, 0.34 * energy), Color(OathTheme.GOLD, 0.0), Color(OathTheme.GOLD, 0.0)])
			draw_polygon(points, colors)
		draw_circle(origin, 90.0 * energy, Color(OathTheme.GOLD, 0.12 * energy))
