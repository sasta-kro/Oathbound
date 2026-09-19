extends Control
## The prologue a new journey opens with (Specification 4.5): the Elder,
## alone on a dark stage, tells the player what the Reach is and what an
## Oathbound is before the world is shown.
##
## Interact or a click reads on, finishing a line that is still being written
## first; Escape skips the rest. The last page fades to the same colour the
## overworld's screen transition starts from, so the field can reveal itself
## out of it and the two scenes read as one.

const FIELD_SCENE_PATH := "res://main.tscn"
const ELDER_SPRITE_FRAMES := preload("res://content/sprites/npc_elder.tres")
const BACKDROP_COLOR := ScreenTransition.WORLD_COLOR
const STAGE_CENTER := Vector2(480, 215)
const ELDER_SCALE: float = 5.0
## Where the Elder steps aside to once the starter is on stage.
const ELDER_ASIDE_X: float = 370.0
const CREATURE_SIDE: float = 150.0
const CREATURE_CENTER := Vector2(600, 205)
const CHARACTERS_PER_SECOND: float = 45.0
const FADE_IN_SECONDS: float = 1.0
const FADE_OUT_SECONDS: float = 0.9

var _page: int = -1
var _stage: Control
var _elder: AnimatedSprite2D
var _creature: Control
var _text: Label
var _typing: Tween
var _leaving: bool = false


func _ready() -> void:
	theme = OathTheme.make()
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.add_child(_build_glow())
	var motes := Control.new()
	motes.set_script(preload("res://scripts/ui/title_seal.gd"))
	_stage.add_child(motes)

	_elder = AnimatedSprite2D.new()
	_elder.sprite_frames = ELDER_SPRITE_FRAMES
	_elder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_elder.scale = Vector2.ONE * ELDER_SCALE
	_elder.position = STAGE_CENTER
	_elder.play(&"idle_down")
	_stage.add_child(_elder)

	var species: CreatureSpecies = Content.get_species(GameState.STARTER_SPECIES_ID)
	if species != null:
		_creature = OathTheme.portrait(species, CREATURE_SIDE)
		_creature.size = Vector2.ONE * CREATURE_SIDE
		_creature.position = CREATURE_CENTER - _creature.size / 2.0
		_creature.modulate.a = 0.0
		_stage.add_child(_creature)

	_stage.add_child(_build_text_box())
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, FADE_IN_SECONDS)
	_next_page()


func _build_text_box() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", OathTheme.box(OathTheme.INK, OathTheme.GOLD.darkened(0.5), 8, 0))
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 42
	panel.offset_right = -42
	panel.offset_top = -135
	panel.offset_bottom = -36
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	margin.add_child(content)
	var caption := HBoxContainer.new()
	content.add_child(caption)
	caption.add_child(OathTheme.label(GameOpening.PROLOGUE_SPEAKER, 9, OathTheme.GOLD))
	caption.add_child(OathTheme.spacer(false))
	caption.add_child(OathTheme.label("E  /  CONTINUE    ·    ESC  /  SKIP", 9, OathTheme.MUTED))
	_text = OathTheme.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_text)
	return panel


## A warm pool of light for the Elder to stand in.
func _build_glow() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.85, 0.72, 0.45, 0.22))
	gradient.set_color(1, Color(0.85, 0.72, 0.45, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var glow := TextureRect.new()
	glow.texture = texture
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.size = Vector2(480, 480)
	glow.position = STAGE_CENTER + Vector2(0, 20) - glow.size / 2.0
	return glow


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		_leave()
		return
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not (clicked or event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		return
	get_viewport().set_input_as_handled()
	advance()


## Finishes the line being written, or turns to the next page.
func advance() -> void:
	if _leaving:
		return
	if _typing != null and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		return
	_next_page()


func current_page() -> int:
	return _page


func _next_page() -> void:
	_page += 1
	if _page >= GameOpening.PROLOGUE.size():
		_leave()
		return
	if _page == GameOpening.PROLOGUE_CREATURE_PAGE:
		_bring_on_creature()
	_text.text = GameOpening.PROLOGUE[_page]
	_text.visible_ratio = 0.0
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / CHARACTERS_PER_SECOND)


func _bring_on_creature() -> void:
	if _creature == null:
		return
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_elder, "position:x", ELDER_ASIDE_X, 0.6)
	tween.tween_property(_creature, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tween.tween_property(_creature, "position:y", _creature.position.y, 0.8).from(_creature.position.y + 16).set_delay(0.3)


## Fades the stage out and opens the field, where the opening goes on.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if _typing != null:
		_typing.kill()
	var fade := create_tween()
	fade.tween_property(_stage, "modulate:a", 0.0, FADE_OUT_SECONDS)
	await fade.finished
	get_tree().change_scene_to_file(FIELD_SCENE_PATH)
