class_name WorldActor
extends CharacterBody2D
## Anything the player can walk up to and press interact on: NPCs and wild
## creatures. Every actor joins the `world_actors` group so the main scene
## can find the nearest one without knowing the map layout.

const GROUP := &"world_actors"
## Actors that walk about on their own; the field pauses them with the world.
const WANDERER_GROUP := &"wandering_actors"
## Walking pace of a wandering NPC, well under the player's.
const WANDER_SPEED: float = 55.0
const WANDER_PAUSE_RANGE := Vector2(1.5, 4.5)
## A wanderer that has barely moved for this long gives up on its target.
const WANDER_STUCK_SECONDS: float = 0.6
const BARK_INTERVAL_RANGE := Vector2(7.0, 15.0)
const BARK_SECONDS: float = 3.2
const CELL_SIZE: float = 48.0

## What the mark over an NPC's head says: that they have a quest to offer or
## are waiting to hear about one ("!"), or that one is ready to hand in ("?").
enum QuestMarker { NONE, AVAILABLE, TURN_IN }

const QUEST_MARKER_TEXT: Dictionary = {QuestMarker.AVAILABLE: "!", QuestMarker.TURN_IN: "?"}
const MAIN_QUEST_MARKER_COLOR := Color("ffd23f")
const SIDE_QUEST_MARKER_COLOR := Color("4fa8ff")
## How far above the actor's origin the mark's foot sits, just over the name,
## and how far it bobs.
const QUEST_MARKER_HEIGHT: float = 44.0
const QUEST_MARKER_BOB: float = 4.0

## Name shown above the placeholder body.
@export var display_name: String = "NPC"
## Placeholder body colour, used only while `sprite_frames` is unset.
@export var body_color: Color = Color(0.8, 0.8, 0.8)
## Character art for this actor. Actors without art fall back to the coloured
## placeholder body.
@export var sprite_frames: SpriteFrames = null
## Which row of `sprite_frames` the actor stands in, as an `idle_*` animation.
@export var facing: StringName = &"down"
@export_multiline var dialogue_line: String = ""
## Talking to this actor restores the party, standing in for the Hub healing
## service until one exists.
@export var heals_party: bool = false
## Quests this actor gives and takes back in, by id, in the order they are
## offered. Talk-to objectives name actors by [method actor_id].
@export var quest_ids: Array[StringName] = []

@export_group("Services")
## Item ids this actor sells (Specification 16.5). Empty for anyone who is not
## a vendor. A vendor with quest business talks about that first.
@export var shop_stock: Array[StringName] = []
## Heading on the vendor's counter, such as "Scribe's Stall".
@export var shop_title: String = ""
## Talking to this actor offers a night's rest: a full heal and a save.
@export var runs_inn: bool = false

@export_group("Life")
## More small talk, taken in turn after [member dialogue_line] on each visit.
@export var chatter: PackedStringArray = []
## Short remarks shown over the actor's head now and then while the player is
## nearby. Nobody has to talk to them.
@export var barks: PackedStringArray = []
## How far, in cells, this actor strolls from where it was placed. 0 keeps it
## in place, as every service NPC stays (Specification 6.2).
@export var wander_radius_cells: float = 0.0

var _quest_marker_label: Label
var _chatter_index: int = 0
var _home: Vector2
var _stroll_target: Vector2
var _stroll_wait: float = 0.0
var _stuck_time: float = 0.0
var _roaming: bool = true
var _walking: bool = false
var _bark_wait: float = 0.0
var _bark_label: Label


func _ready() -> void:
	add_to_group(GROUP)
	var sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")
	var body: Polygon2D = get_node_or_null(^"Body")
	if sprite != null:
		sprite.sprite_frames = sprite_frames
		sprite.visible = sprite_frames != null
		if sprite_frames != null:
			var idle: StringName = StringName("idle_%s" % facing)
			if sprite_frames.has_animation(idle):
				sprite.play(idle)
	if body != null:
		body.color = body_color
		body.visible = sprite_frames == null
	var label: Label = get_node_or_null(^"Label")
	if label != null:
		label.text = display_name
	_home = position
	_stroll_target = position
	_stroll_wait = randf_range(WANDER_PAUSE_RANGE.x, WANDER_PAUSE_RANGE.y)
	_bark_wait = randf_range(BARK_INTERVAL_RANGE.x * 0.3, BARK_INTERVAL_RANGE.y)
	if wander_radius_cells > 0.0:
		add_to_group(WANDERER_GROUP)
	if _shows_quest_marker():
		GameState.quest_changed.connect(refresh_quest_marker.unbind(2))
		GameState.quest_objective_advanced.connect(refresh_quest_marker.unbind(3))
		refresh_quest_marker()


func _physics_process(delta: float) -> void:
	_tick_bark(delta)
	if wander_radius_cells <= 0.0 or not _roaming:
		return
	if _stroll_wait > 0.0:
		_stroll_wait -= delta
		if _stroll_wait <= 0.0:
			_pick_stroll_target()
		return
	var to_target: Vector2 = _stroll_target - position
	if to_target.length() < 3.0:
		_rest()
		return
	var before: Vector2 = position
	velocity = to_target.normalized() * WANDER_SPEED
	move_and_slide()
	_play_walk(to_target)
	if position.distance_to(before) < WANDER_SPEED * delta * 0.3:
		_stuck_time += delta
		if _stuck_time >= WANDER_STUCK_SECONDS:
			_rest()
	else:
		_stuck_time = 0.0


## Stops or restarts this actor's stroll along with the rest of the world.
func set_roaming(enabled: bool) -> void:
	_roaming = enabled
	if not enabled and _walking:
		_walking = false
		_play_idle()


## Turns to look at [param point], as anyone does when spoken to.
func face_toward(point: Vector2) -> void:
	var offset: Vector2 = point - global_position
	if offset.length() < 1.0:
		return
	facing = _direction_name(offset)
	_walking = false
	_play_idle()


func _pick_stroll_target() -> void:
	var radius: float = wander_radius_cells * CELL_SIZE
	var offset := Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
	# Mostly along one axis, so strolls read as walking a street rather than
	# drifting on a diagonal.
	if randf() < 0.7:
		if absf(offset.x) > absf(offset.y):
			offset.y *= 0.2
		else:
			offset.x *= 0.2
	_stroll_target = _home + offset
	_stuck_time = 0.0


func _rest() -> void:
	velocity = Vector2.ZERO
	_walking = false
	_stuck_time = 0.0
	_stroll_target = position
	_stroll_wait = randf_range(WANDER_PAUSE_RANGE.x, WANDER_PAUSE_RANGE.y)
	_play_idle()


func _play_walk(direction: Vector2) -> void:
	facing = _direction_name(direction)
	_walking = true
	_play_animation(StringName("walk_%s" % facing))


func _play_idle() -> void:
	_play_animation(StringName("idle_%s" % facing))


func _play_animation(animation: StringName) -> void:
	var sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation):
		return
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)


static func _direction_name(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
	return &"down" if direction.y > 0.0 else &"up"


## Counts down to the next remark and shows it while the actor is on screen.
func _tick_bark(delta: float) -> void:
	if barks.is_empty() or not _roaming:
		return
	_bark_wait -= delta
	if _bark_wait > 0.0:
		return
	_bark_wait = randf_range(BARK_INTERVAL_RANGE.x, BARK_INTERVAL_RANGE.y)
	if _is_on_screen():
		show_bark(barks[randi() % barks.size()])


func _is_on_screen() -> bool:
	var view: Rect2 = get_viewport().get_visible_rect()
	var screen_point: Vector2 = get_global_transform_with_canvas().origin
	return view.grow(-24.0).has_point(screen_point)


## Floats [param text] over the actor's head for a few seconds.
func show_bark(text: String) -> void:
	if _bark_label == null:
		_bark_label = Label.new()
		_bark_label.name = "Bark"
		_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bark_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_bark_label.size = Vector2(220, 20)
		_bark_label.position = Vector2(-110, -66)
		_bark_label.add_theme_font_size_override("font_size", 12)
		_bark_label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.86))
		_bark_label.add_theme_color_override("font_outline_color", Color(0.054902, 0.0901961, 0.0509804, 1))
		_bark_label.add_theme_constant_override("outline_size", 4)
		_bark_label.z_index = 10
		add_child(_bark_label)
	_bark_label.text = text
	# Above the quest mark when one is showing, so the two never overlap.
	var marked: bool = _quest_marker_label != null and _quest_marker_label.visible
	_bark_label.position.y = -QUEST_MARKER_HEIGHT - 60.0 if marked else -66.0
	_bark_label.modulate.a = 0.0
	_bark_label.show()
	var fade := _bark_label.create_tween()
	fade.tween_property(_bark_label, "modulate:a", 1.0, 0.25)
	fade.tween_interval(BARK_SECONDS)
	fade.tween_property(_bark_label, "modulate:a", 0.0, 0.5)


func bark_text() -> String:
	return _bark_label.text if _bark_label != null and _bark_label.visible else ""


func is_vendor() -> bool:
	return not shop_stock.is_empty()


## The items this vendor sells, in the order they were listed. Unknown ids
## are skipped.
func stock(registry: Node) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id: StringName in shop_stock:
		var item: ItemData = registry.get_item(id)
		if item != null:
			out.append(item)
	return out


## Whether this actor can carry a quest mark at all. Wild creatures cannot.
func _shows_quest_marker() -> bool:
	return true


## Whether the player can still interact with this actor.
func is_interactable() -> bool:
	return true


## Stable id quests refer to this actor by: the node name, lower-cased, so
## the "Elder" in the town is [code]&"elder"[/code].
func actor_id() -> StringName:
	return StringName(name.to_lower())


## The quest this actor wants to talk about right now: one that is ready to
## turn in to them first, then one in progress, then the first that can be
## offered. A quest handed in to someone else ([member QuestData.turn_in])
## only counts as in progress here, and a quest handed in to this actor counts
## even when someone else gave it. Null when there is nothing but small talk.
func current_quest(log: QuestLog, registry: Node) -> QuestData:
	var me: StringName = actor_id()
	for quest: QuestData in log.active_quests():
		if quest.turn_in_actor() == me and log.is_ready(quest):
			return quest
	var offerable: QuestData = null
	var in_progress: QuestData = null
	for id: StringName in quest_ids:
		var quest: QuestData = registry.get_quest(id)
		if quest == null:
			continue
		if in_progress == null and log.is_active(quest.id):
			in_progress = quest
		elif offerable == null and log.can_offer(quest):
			offerable = quest
	return in_progress if in_progress != null else offerable


## What this actor says once they have nothing to offer: the done line of the
## last of their quests the player has finished, so a giver keeps pointing the
## way onward, or their own small talk when none is finished.
##
## A finished main quest wins over a finished side quest whatever order they
## are listed in. The story line is the one that names where to go next, and
## an actor who also gave a side quest would otherwise sign off with the side
## quest's line and leave the player with nowhere to go.
func idle_line(log: QuestLog, registry: Node) -> String:
	var side_line: String = ""
	for index: int in range(quest_ids.size() - 1, -1, -1):
		var quest: QuestData = registry.get_quest(quest_ids[index])
		if quest == null or not log.is_completed(quest.id) or quest.done_line.is_empty():
			continue
		if quest.is_main():
			return quest.done_line
		if side_line.is_empty():
			side_line = quest.done_line
	return side_line if not side_line.is_empty() else next_small_talk()


## [member dialogue_line], then each line of [member chatter] in turn, round
## and round, so a second visit is not the same conversation.
func next_small_talk() -> String:
	if chatter.is_empty():
		return dialogue_line
	var lines: PackedStringArray = [dialogue_line] if not dialogue_line.is_empty() else []
	lines.append_array(chatter)
	var line: String = lines[_chatter_index % lines.size()]
	_chatter_index += 1
	return line


## What this actor's mark should show, as
## [code]{marker: QuestMarker, main: bool}[/code]. Every quest the actor gives
## counts, and so does any active quest that asks the player to talk to them.
## A main quest outranks a side quest, and a turn-in outranks an offer, so an
## NPC with a story beat always shows it in the story colour.
func quest_marker(log: QuestLog, registry: Node) -> Dictionary:
	var best: Dictionary = {"marker": QuestMarker.NONE, "main": false}
	var me: StringName = actor_id()
	for id: StringName in quest_ids:
		var quest: QuestData = registry.get_quest(id)
		if quest != null and log.can_offer(quest):
			best = _stronger_marker(best, QuestMarker.AVAILABLE, quest.is_main())
	for quest: QuestData in log.active_quests():
		if quest.turn_in_actor() == me and log.is_ready(quest):
			best = _stronger_marker(best, QuestMarker.TURN_IN, quest.is_main())
	for quest: QuestData in log.active_quests():
		for index: int in quest.objectives.size():
			var objective: QuestObjective = quest.objectives[index]
			if objective == null or objective.kind != QuestObjective.Kind.TALK or objective.target != me:
				continue
			if not log.is_objective_done(quest, index):
				best = _stronger_marker(best, QuestMarker.AVAILABLE, quest.is_main())
	return best


func _stronger_marker(current: Dictionary, marker: QuestMarker, main: bool) -> Dictionary:
	var rank: int = (2 if main else 0) + (1 if marker == QuestMarker.TURN_IN else 0)
	var current_rank: int = -1
	if current.marker != QuestMarker.NONE:
		current_rank = (2 if current.main else 0) + (1 if current.marker == QuestMarker.TURN_IN else 0)
	return {"marker": marker, "main": main} if rank > current_rank else current


## Redraws the mark over this actor's head from the player's quest log.
func refresh_quest_marker() -> void:
	var state: Dictionary = quest_marker(GameState.quests, Content)
	if state.marker == QuestMarker.NONE:
		if _quest_marker_label != null:
			_quest_marker_label.hide()
		return
	if _quest_marker_label == null:
		_quest_marker_label = _build_quest_marker_label()
	_quest_marker_label.text = QUEST_MARKER_TEXT[state.marker]
	_quest_marker_label.add_theme_color_override(
		"font_color", MAIN_QUEST_MARKER_COLOR if state.main else SIDE_QUEST_MARKER_COLOR
	)
	_quest_marker_label.show()


func quest_marker_text() -> String:
	if _quest_marker_label == null or not _quest_marker_label.visible:
		return ""
	return _quest_marker_label.text


func _build_quest_marker_label() -> Label:
	var marker := Label.new()
	marker.name = "QuestMarker"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	marker.size = Vector2(40, 36)
	marker.position = Vector2(-20, -QUEST_MARKER_HEIGHT - 36)
	marker.add_theme_font_size_override("font_size", 30)
	marker.add_theme_color_override("font_outline_color", Color(0.054902, 0.0901961, 0.0509804, 1))
	marker.add_theme_constant_override("outline_size", 6)
	marker.z_index = 10
	add_child(marker)
	var bob := marker.create_tween().set_loops()
	bob.tween_property(marker, "position:y", marker.position.y - QUEST_MARKER_BOB, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(marker, "position:y", marker.position.y, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return marker
