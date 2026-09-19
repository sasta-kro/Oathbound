class_name EvolutionScreen
extends CanvasLayer
## The full-screen moment a companion evolves (Specification 9.7).
##
## Evolution is automatic: the field hands every companion that has reached
## its evolution level to [method play] once the world is calm again, and the
## screen changes its species halfway through the sequence, at the white
## flash. The player can hurry the animation along, but not refuse it.
##
## The screen is built in code in the same visual language as [FieldUI].

## The sequence closed and the field may carry on.
signal finished

const STAGE_SIZE := Vector2(240, 190)
## The shimmer swaps between the two forms faster and faster until the flash.
const SHIMMER_BEATS: PackedFloat32Array = [0.42, 0.36, 0.3, 0.25, 0.2, 0.16, 0.13, 0.1, 0.08, 0.07, 0.06, 0.05, 0.05]
## Input arriving sooner than this is ignored, so a key still being mashed
## from the battle that ended does not skip the moment.
const INPUT_GRACE_SECONDS := 0.8
const EVOLVING_TEXT := "%s is evolving!"
const EVOLVED_TEXT := "%s evolved into %s!"
const CONTINUE_HINT := "PRESS ANY KEY TO CONTINUE"
const FLASH_SHADER := preload("res://shaders/evolution_flash.gdshader")

var _root: Control
var _halo: Halo
var _stage: Control
var _old_view: Control
var _new_view: Control
var _kicker: Label
var _caption: Label
var _subline: Label
var _stats: HBoxContainer
var _hint: Label
var _flash: ColorRect
var _tween: Tween

var _creature: CreatureInstance
var _from: CreatureSpecies
var _to: CreatureSpecies
var _before: Dictionary = {}
var _playing := false
var _evolved := false
var _awaiting_dismiss := false
var _closing := false
var _started_at := 0


func _ready() -> void:
	layer = 8
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = OathTheme.make()
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(OathTheme.INK, 0.97)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	_kicker = _centered(OathTheme.label("", 9, OathTheme.GOLD))
	column.add_child(_kicker)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE_SIZE
	_stage.pivot_offset = STAGE_SIZE * 0.5
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage)
	_halo = Halo.new()
	_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_halo)
	_caption = _centered(OathTheme.heading("", 34))
	column.add_child(_caption)
	_subline = _centered(OathTheme.paragraph("", 11))
	_subline.custom_minimum_size.x = 420
	column.add_child(_subline)
	_stats = HBoxContainer.new()
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	_stats.add_theme_constant_override("separation", 8)
	column.add_child(_stats)
	_hint = _centered(OathTheme.label(CONTINUE_HINT, 9, OathTheme.MUTED))
	column.add_child(_hint)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0.98, 0.92, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	hide()


func is_playing() -> bool:
	return _playing


## Plays the evolution of [param creature] and evolves it. Resolves once the
## player has dismissed the result; returns false without showing anything
## when the creature cannot evolve.
func play(creature: CreatureInstance) -> bool:
	if _playing or creature == null or not creature.can_evolve():
		return false
	_playing = true
	_evolved = false
	_awaiting_dismiss = false
	_closing = false
	_creature = creature
	_from = creature.species
	_to = creature.species.evolves_into
	_before = _stat_line(creature)
	_started_at = Time.get_ticks_msec()
	_build_stage()
	show()
	_run_sequence()
	await finished
	return true


## Jumps to the end of the sequence, evolving the creature if the flash has
## not happened yet.
func skip() -> void:
	if not _playing or _awaiting_dismiss or _closing:
		return
	if _tween != null:
		_tween.kill()
	_root.modulate.a = 1.0
	_flash.color.a = 0.0
	_stage.scale = Vector2.ONE
	if not _evolved:
		_apply_evolution()
	_set_glow(0.0, _new_view)
	_new_view.show()
	_old_view.hide()
	_present_result()


## Closes the screen once the result is showing.
func dismiss() -> void:
	if not _awaiting_dismiss or _closing:
		return
	_closing = true
	_awaiting_dismiss = false
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_close)


func _close() -> void:
	hide()
	_playing = false
	_closing = false
	_creature = null
	finished.emit()


func _input(event: InputEvent) -> void:
	if not _playing:
		return
	# Nothing reaches the field or its menus while the screen is up.
	get_viewport().set_input_as_handled()
	var pressed: bool = (
		(event is InputEventKey and event.pressed and not event.echo)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if not pressed or Time.get_ticks_msec() - _started_at < INPUT_GRACE_SECONDS * 1000:
		return
	if _awaiting_dismiss:
		dismiss()
	else:
		skip()


func _build_stage() -> void:
	for view: Control in [_old_view, _new_view]:
		if view != null:
			_stage.remove_child(view)
			view.queue_free()
	_old_view = _portrait(_from)
	_new_view = _portrait(_to)
	_new_view.hide()
	_halo.tint = OathTheme.element(_from)
	_halo.energy = 0.0
	_kicker.text = "◇   A BOND DEEPENS"
	_caption.text = EVOLVING_TEXT % _creature.display_name()
	_subline.text = "Level %d. Something new is taking shape." % _creature.level
	_clear_stats()
	_hint.modulate.a = 0.0
	_root.modulate.a = 0.0
	_flash.color.a = 0.0
	_stage.scale = Vector2.ONE


func _run_sequence() -> void:
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.4)
	_tween.tween_interval(0.5)
	_tween.tween_callback(SfxService.play.bind(&"bind_attempt"))
	_tween.parallel().tween_method(_set_glow.bind(_old_view), 0.0, 1.0, 1.0)
	_tween.parallel().tween_property(_halo, "energy", 1.0, 1.0)
	_tween.parallel().tween_property(_subline, "modulate:a", 0.0, 0.6)
	_tween.tween_callback(_set_glow.bind(1.0, _new_view))
	var showing_new := false
	for beat: float in SHIMMER_BEATS:
		showing_new = not showing_new
		_tween.tween_callback(_show_form.bind(showing_new))
		_tween.tween_property(_stage, "scale", Vector2.ONE * (1.06 if showing_new else 0.96), beat)
	_tween.tween_property(_flash, "color:a", 1.0, 0.25)
	_tween.tween_callback(_apply_evolution)
	_tween.tween_callback(_show_form.bind(true))
	_tween.tween_callback(SfxService.play.bind(&"bind_success"))
	_tween.tween_callback(func(): _stage.scale = Vector2.ONE * 0.82)
	_tween.tween_property(_flash, "color:a", 0.0, 0.7)
	_tween.parallel().tween_property(_stage, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_glow.bind(_new_view), 1.0, 0.0, 0.9)
	_tween.tween_callback(_present_result)


func _show_form(new_form: bool) -> void:
	_new_view.visible = new_form
	_old_view.visible = not new_form


func _apply_evolution() -> void:
	if _evolved:
		return
	_evolved = _creature.evolve()
	_halo.tint = OathTheme.element(_to)


func _present_result() -> void:
	_kicker.text = "◆   EVOLUTION COMPLETE"
	_caption.text = EVOLVED_TEXT % [_from.display_name, _to.display_name]
	_subline.text = "%s  ·  %s" % [_to.type_display_name(), "Level %d" % _creature.level]
	_subline.modulate.a = 1.0
	_clear_stats()
	var after := _stat_line(_creature)
	for key: String in ["HP", "ATTACK", "DEFENSE", "SPEED"]:
		_stats.add_child(_stat_chip(key, int(_before[key]), int(after[key])))
	_awaiting_dismiss = true
	_tween = create_tween()
	_tween.tween_property(_halo, "energy", 0.35, 0.8)
	_tween.parallel().tween_property(_hint, "modulate:a", 1.0, 0.6).set_delay(0.4)


func _stat_chip(stat: String, before: int, after: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 92
	panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.SURFACE, OathTheme.LINE, 5, 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	col.add_child(OathTheme.label(stat, 9, OathTheme.MUTED))
	col.add_child(OathTheme.heading(str(after), 22))
	var delta := after - before
	var tint := OathTheme.JADE if delta > 0 else (OathTheme.MUTED if delta == 0 else OathTheme.ELEMENT_COLORS[0])
	col.add_child(OathTheme.label("%s%d" % ["+" if delta >= 0 else "", delta], 10, tint))
	return panel


func _clear_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()


func _portrait(species: CreatureSpecies) -> Control:
	var view := OathTheme.portrait(species, 0)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := STAGE_SIZE.y * 0.12
	view.offset_left = inset
	view.offset_top = inset
	view.offset_right = -inset
	view.offset_bottom = -inset
	var glow := ShaderMaterial.new()
	glow.shader = FLASH_SHADER
	view.material = glow
	_stage.add_child(view)
	return view


func _set_glow(amount: float, view: Control) -> void:
	if view != null and view.material is ShaderMaterial:
		(view.material as ShaderMaterial).set_shader_parameter(&"flash", amount)


static func _stat_line(creature: CreatureInstance) -> Dictionary:
	return {"HP": creature.max_hp(), "ATTACK": creature.attack(), "DEFENSE": creature.defense(), "SPEED": creature.speed()}


static func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Rings of light behind the creature, brighter as the change builds.
class Halo:
	extends Control

	var tint := OathTheme.JADE:
		set(value):
			tint = value
			queue_redraw()
	var energy := 0.0:
		set(value):
			energy = value
			queue_redraw()
	var _spin := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_spin = fmod(_spin + delta * (0.4 + energy * 2.2), TAU)
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.48
		draw_circle(center, radius, Color(tint, 0.04 + energy * 0.08))
		draw_arc(center, radius, 0, TAU, 72, Color(tint, 0.18 + energy * 0.3), 1.0, true)
		for i in 3:
			var start := _spin * (1.0 if i % 2 == 0 else -1.3) + i * TAU / 3.0
			draw_arc(center, radius * (0.86 - i * 0.1), start, start + 1.9, 40, Color(tint, 0.22 + energy * 0.45), 1.0 + energy, true)
		for i in 8:
			var point := center + Vector2.from_angle(_spin + i * TAU / 8.0) * radius * (1.0 + energy * 0.06)
			draw_circle(point, 1.5 + energy * 1.5, Color(tint, 0.4 + energy * 0.6))
