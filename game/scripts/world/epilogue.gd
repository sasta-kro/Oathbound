class_name Epilogue
extends RefCounted
## The ending: the wood comes back to life once the king is under.
##
## Deliberately quiet. Nobody makes a speech and nothing is explained again.
## The cold light the king kept over his own ground warms, everything he had
## standing in it thins away without dying, and a caption says what the
## victory actually was. Then the screen goes out.
##
## It plays where the player is standing rather than in a scene of its own,
## because the wood the player has spent an act crossing is the only stage
## that makes the change legible.

## Turned in to the Last Champion at the foot of the stair. Completing it is
## what starts the ending.
const QUEST_ID: StringName = &"quest_main_13_the_king_in_the_barrow"
## The [CanvasModulate] every area uses for its colour. Area Three's is the
## king's cold grey; the ending tweens it to daylight.
const TINT_NODE := "Tint"
const LIVING_LIGHT := Color(1.0, 0.99, 0.94)
## Over the HUD, which is layer 1.
const CAPTION_LAYER: int = 64
const CAPTION_TEXT := "The king sleeps once more. But in time he and his loyal men will rise again — forever damned to be villains, for daring to bargain with the god of the dead."
const CAPTION_COLOR := Color(0.94, 0.93, 0.88)
const CAPTION_FONT_SIZE: int = 20
const CAPTION_WIDTH_RATIO: float = 0.62

## A beat of nothing before the wood starts to turn, so the last line has
## room to land.
const QUIET_SECONDS: float = 1.4
## How long the king's own take to thin out of the wood.
const THINNING_SECONDS: float = 2.6
## The colour coming back. Slow enough to read as the wood waking rather
## than a light being switched on.
const GREENING_SECONDS: float = 7.0
const CAPTION_FADE_SECONDS: float = 2.4
const CAPTION_HOLD_SECONDS: float = 6.5


## Plays the ending over [param area] and returns when the caption has been
## read. [param host] only supplies the scene tree and outlives the tween.
static func play(host: Node, area: Node) -> void:
	_still_the_wood(host)
	await host.get_tree().create_timer(QUIET_SECONDS).timeout
	_thin_away(host)
	_green(host, area)
	await host.get_tree().create_timer(THINNING_SECONDS).timeout
	await _caption(host)


## Stops the spawn zones before anything is cleared, so the wood cannot
## quietly refill itself behind the caption.
static func _still_the_wood(host: Node) -> void:
	for zone: Node in host.get_tree().get_nodes_in_group(SpawnZone.GROUP):
		zone.process_mode = Node.PROCESS_MODE_DISABLED


## Everything the king had standing in his wood lets go at once. Routed
## rather than killed: they come apart into light with no death throe and no
## sound, because they were never alive in the way the wood is about to be.
static func _thin_away(host: Node) -> void:
	for creature: WildCreature in host.get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP):
		if not creature.was_defeated:
			creature.play_rout(false)


## The cold light the king kept over his ground warms back to daylight.
static func _green(host: Node, area: Node) -> void:
	var tint: CanvasModulate = area.get_node_or_null(TINT_NODE) as CanvasModulate
	if tint == null:
		return
	var tween: Tween = host.create_tween()
	tween.tween_property(tint, "color", LIVING_LIGHT, GREENING_SECONDS).set_trans(Tween.TRANS_SINE)


## The caption, faded up over the living wood and left long enough to read
## twice. Returns once it has faded out again.
static func _caption(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = CAPTION_LAYER
	host.add_child(layer)
	var frame := Control.new()
	frame.theme = OathTheme.make()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 0.0
	layer.add_child(frame)

	var label := Label.new()
	label.text = CAPTION_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", CAPTION_COLOR)
	label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", ScreenTransition.WORLD_COLOR)
	label.add_theme_constant_override("outline_size", 8)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	label.custom_minimum_size = Vector2(
		host.get_viewport().get_visible_rect().size.x * CAPTION_WIDTH_RATIO, 0
	)
	frame.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	var tween: Tween = host.create_tween()
	tween.tween_property(frame, "modulate:a", 1.0, CAPTION_FADE_SECONDS)
	tween.tween_interval(CAPTION_HOLD_SECONDS)
	tween.tween_property(frame, "modulate:a", 0.0, CAPTION_FADE_SECONDS)
	await tween.finished
	layer.queue_free()
