extends Node2D
## Overworld driver: loads the current area, places the player, routes
## interaction and swings to the nearest actor, and hands the resulting
## encounter to the battle scene.
##
## Combat starts in the overworld rather than on the battle screen, and the
## Oathbound at the front of the party is the one who fights there, exactly as
## it would in a battle. A strike that connects does real damage: a creature
## that survives it is pulled into a battle it enters wounded and a turn
## behind, and one that does not is routed where it stands and pays out its
## rewards without a battle ever opening. A hostile creature that lands its
## own blow first turns the same rules around on the player.
##
## The scene knows nothing about a specific map. Areas are `WorldArea` scenes
## under `res://areas/`; actors, spawn zones and exits announce themselves
## through groups and signals. Walking into an [AreaExit] swaps the area for
## the one it names and puts the player on the matching entrance marker.

const INTERACTION_REACH_IN_CELLS: float = 1.5
## Shown after an overworld rout, ahead of the reward lines.
const ROUT_TEXT := "You cut down the wild %s before it could fight back."
const TITLE_SCENE_PATH := "res://scenes/title_screen.tscn"
const AUTOSAVED_TEXT := "Autosaved"
const SAVED_TEXT := "Saved to %s"
const BATTLE_MUSIC_ID: StringName = &"battle"
const BOSS_FIGHT_OPTIONS: PackedStringArray = ["Fight", "Not yet"]
## The beat between the starter appearing and the Elder speaking again.
const STARTER_ENTRANCE_SECONDS: float = 0.6
const WILD_CREATURE_SCENE: PackedScene = preload("res://scenes/wild_creature.tscn")
## How long the tutorial's ambusher takes to burst out of the grass.
const AMBUSHER_ENTRANCE_SECONDS: float = 0.35
const INN_OPTIONS: PackedStringArray = ["Rest for the night", "Not now"]
## A lesson that wants one swing and nothing else: the player is held in
## place, facing the creature it staged, and only the attack key answers.
const LOCK_ATTACK := &"attack"
## A lesson that wants the player to do nothing at all, because the thing
## being taught is what happens to somebody standing still.
const LOCK_STILL := &"still"
## Shown as the lid comes up, for a chest whose author wrote no line of its
## own: one for a chest with something in it, one for a chest without.
const CHEST_OPENED_TEXT := "The lid gives, and you empty the chest."
const CHEST_EMPTY_HANDED_TEXT := "The chest holds nothing but dust."
## How the player is told where they woke after a rout, with the keeper's
## name and the coins the road took.
const WOKEN_AT_HAVEN_TEXT := "You wake under %s's roof. Your Oathbound have been revived, but %d coins are gone."
const WOKEN_BY_THE_ROAD_TEXT := "You wake by the road. Your Oathbound have been revived, but %d coins are gone."
const INN_RESTED_TEXT := "You sleep soundly. Your companions wake fully rested."
## A mend is otherwise invisible: the party page is shut and the healer only
## makes small talk, so the service says outright what it did.
const PARTY_HEALED_TEXT := "Your party was fully healed."
const PARTY_ALREADY_WELL_TEXT := "Your party is already in good health."
## Shown when a newly bound Oathbound has nowhere to walk and is kept
## instead (Specification 9.3).
const KEPT_TEXT := "%s is kept for you. Call it out from your party page whenever you want it."
## How long the screen stays dark while the player sleeps at the inn.
const INN_NIGHT_SECONDS: float = 0.8

@onready var area: WorldArea = $Area
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var battle_scene: BattleScene = $BattleScene
@onready var transition: ScreenTransition = $ScreenTransition
@onready var partner: OverworldPartner = $OverworldPartner

var field_ui: FieldUI
var evolution_screen: EvolutionScreen
var move_learn_screen: MoveLearnScreen
var shop_menu: ShopMenu

var _battling_creature: WildCreature
## Species of the creature the open battle is against, for the quest log.
var _battling_species: StringName = &""
## Set while one area is being swapped for another, so a second exit trigger
## during the wipe cannot start a second swap.
var _travelling: bool = false
## Set while the opening scene with the Elder plays. The world stays still,
## nothing is saved, and the player can only read on.
var _in_opening: bool = false
## Set while companions that reached their evolution level are evolving.
var _evolving: bool = false
## The lesson the open battle teaches, as [method FieldBinding.stage] or
## [method FieldMending.stage] returns it: its guide, how it is won and what
## the Scout says after. Empty for every ordinary battle. A lesson costs
## nothing to lose.
var _lesson: Dictionary = {}
## Set while the tutorial's ambush plays out before its battle opens, so the
## player cannot walk off or swing at the ambusher between lines.
var _staging_tutorial: bool = false
## The overworld lesson waiting on the world (see [FieldStrike],
## [FieldAmbush] and [FieldRout]): the creature it staged, the event it
## reports when the lesson's one move happens, whether that move is the
## player's own swing or the creature's, whether the swing has to put the
## creature down outright, the instruction held on screen meanwhile, the
## battle the blow opens if it opens one, and how tightly the player is held
## while it plays out ([constant LOCK_ATTACK] or [constant LOCK_STILL]).
## Empty when no lesson is waiting. Unlike [member _lesson] this outlives no
## battle: it is answered out in the world, before any battle opens.
var _field_lesson: Dictionary = {}


func _ready() -> void:
	$HUD/Hint.hide()
	field_ui = FieldUI.new()
	add_child(field_ui)
	field_ui.changed.connect(_refresh_world_activity)
	evolution_screen = EvolutionScreen.new()
	add_child(evolution_screen)
	move_learn_screen = MoveLearnScreen.new()
	add_child(move_learn_screen)
	shop_menu = ShopMenu.new()
	add_child(shop_menu)
	shop_menu.closed.connect(_on_shop_closed)
	var opening: bool = GameState.take_opening_request()
	var jump: String = GameState.take_jump_area()
	if jump != "" and _open_area_path(jump):
		player.global_position = area.player_start_position()
	elif GameState.take_resume_request() and _restore_saved_area():
		player.global_position = GameState.player_position
		player.face(GameState.player_facing)
	elif opening:
		player.global_position = area.entrance_position(GameOpening.PLAYER_SPOT)
	else:
		player.global_position = area.player_start_position()
	partner.snap_to_player()
	GameState.play_time_running = true
	_fit_camera_to_area()
	settings_menu.opened.connect(_on_settings_opened)
	settings_menu.closed.connect(_on_settings_closed)
	battle_scene.battle_finished.connect(_on_battle_finished)
	# The battle screen owns the moment it closes, so it plays the cover half
	# of the transition itself and hides underneath it.
	battle_scene.transition = transition
	_wire_area()
	_play_area_music()
	_report_area_reached()
	if opening:
		# The opening saves once it is over, with the starter in hand.
		_play_opening()
		return
	# Entering the field is entering an area (Specification 21.2), so a fresh
	# journey can be continued from the title screen straight away.
	_autosave(false)
	# A journey saved before evolution was automatic may hold companions that
	# are already past their evolution level.
	_settle_growth.call_deferred()


## The first scene of a new journey (Specification 4.5): the Elder, waiting
## by the well, hands over the starter and sends the player to the scout.
## The prologue scene left the screen dark, so this opens by revealing it.
func _play_opening() -> void:
	_in_opening = true
	_refresh_world_activity()
	var elder: WorldActor = _actor_with_id(GameOpening.ELDER_ID)
	if elder != null:
		player.face(GameOpening.facing_toward(player.global_position, elder.global_position))
	await transition.reveal(ScreenTransition.Style.WORLD)

	for line: String in GameOpening.WELCOME:
		await _say(line)
	GameState.ensure_starter()
	var starter: CreatureInstance = GameState.lead_creature()
	if starter != null:
		# The partner follows the party on its own; this only makes it arrive,
		# at the player's side away from the Elder.
		var away: Vector2 = Vector2.RIGHT
		if elder != null and not elder.global_position.is_equal_approx(player.global_position):
			away = elder.global_position.direction_to(player.global_position)
		partner.place_at(player.global_position + away * float(WorldArea.GRID_SIZE))
		partner.scale = Vector2.ZERO
		create_tween().tween_property(partner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		field_ui.show_notice(GameOpening.STARTER_JOINED_TEXT % starter.display_name())
		await get_tree().create_timer(STARTER_ENTRANCE_SECONDS).timeout
	for line: String in GameOpening.STARTER_EXPLAINED:
		await _say(line)
	for line: String in GameOpening.THREAT:
		await _say(line)

	var reply: int = await _ask(GameOpening.ASK, GameOpening.REPLIES)
	var quest: QuestData = Content.get_quest(GameOpening.FIRST_QUEST_ID)
	if quest != null:
		GameState.accept_quest(quest)
	await _say(GameOpening.SEND_OFF[clampi(reply, 0, GameOpening.SEND_OFF.size() - 1)])
	_in_opening = false
	_autosave(false)
	_refresh_world_activity()


## Shows a line and waits for the player to read past it.
func _say(line: String) -> void:
	_open_dialogue(line)
	await dialogue_panel.dismissed


## The actor in the current area with [param id], or null.
func _actor_with_id(id: StringName) -> WorldActor:
	for actor: WorldActor in get_tree().get_nodes_in_group(WorldActor.GROUP):
		if actor.actor_id() == id:
			return actor
	return null


func is_settling_growth() -> bool:
	return _evolving


## Whether a growth screen is up. Kept under the old name for [FieldUI] and
## the tests that were written against it.
func is_evolving() -> bool:
	return is_settling_growth()


## Everything a level gain owes the player, once the world is calm enough to
## show it: first the moves that had no free slot (Specification 9.8), then
## the evolutions (Specification 9.7).
##
## Both are handled here rather than where the levels were won, because the
## battle screen, a wipe or an open line of dialogue would all be in the way.
## Evolution is automatic, and a creature whose new form is already past its
## own evolution level evolves again straight away.
func _settle_growth() -> void:
	if _evolving:
		return
	if not _party_can_evolve() and GameState.pending_move_learns.is_empty():
		return
	_evolving = true
	_refresh_world_activity()
	while transition.is_busy() or battle_scene.is_active():
		await get_tree().process_frame
	if dialogue_panel.is_open():
		await dialogue_panel.dismissed
	await _teach_pending_moves()
	for creature: CreatureInstance in GameState.party.duplicate():
		while GameState.party.has(creature) and creature.can_evolve():
			if not await evolution_screen.play(creature):
				break
			GameState.seen_species[creature.species_id()] = true
	GameState.party_changed.emit()
	partner.refresh_lead()
	_evolving = false
	_autosave(false)
	_refresh_world_activity()


## Puts every waiting replace-or-refuse offer to the player, one screen at a
## time. An offer whose creature has since left the party, or that has found
## room another way, is dropped by [method GameState.take_pending_move_learn]
## without a screen.
func _teach_pending_moves() -> void:
	var offer: Dictionary = GameState.take_pending_move_learn()
	while not offer.is_empty():
		await move_learn_screen.play(offer["creature"], offer["move"])
		offer = GameState.take_pending_move_learn()


func _party_can_evolve() -> bool:
	for creature: CreatureInstance in GameState.party:
		if creature.can_evolve():
			return true
	return false


func is_in_opening() -> bool:
	return _in_opening


func _exit_tree() -> void:
	GameState.play_time_running = false


## The window close button. The journey is saved on a normal quit
## (Specification 21.2) unless a battle or area swap is mid-flight, when the
## last boundary save is the coherent one to keep.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	if battle_scene.is_active() or _travelling or _in_opening:
		return
	_record_location()
	GameState.autosave()


## A continued journey opens in the area it was saved in rather than the one
## the scene ships with. Runs before the area is wired, so nothing has to be
## unhooked. Returns false when the saved area cannot be loaded, in which
## case the shipped area and its start marker are used.
## Swaps in the area at [param path], for a dev jump straight into it.
## Returns false, leaving the default area up, when the path is not a scene.
func _open_area_path(path: String) -> bool:
	if path == area.scene_file_path:
		return true
	# Checked before loading, so a shortcut naming an area that has not been
	# built yet turns into a warning rather than an engine error.
	if not ResourceLoader.exists(path):
		DevLog.info("Cannot jump to %s; there is no such scene." % path)
		return false
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		DevLog.info("Cannot jump to %s; it is not a scene." % path)
		return false
	_swap_area(packed)
	return true


func _restore_saved_area() -> bool:
	if not GameState.has_location():
		return false
	if GameState.area_path == area.scene_file_path:
		return true
	var packed: PackedScene = load(GameState.area_path) as PackedScene
	if packed == null:
		push_warning("The saved area %s is not a scene; starting in the default one." % GameState.area_path)
		GameState.clear_location()
		return false
	_swap_area(packed)
	return true


## Autosave (Specification 21.2). Called at state boundaries: arriving in an
## area, after a battle or rout, after a healing service, and on the way out
## to the title screen. Writes only the autosave slot, never one the player
## saved by hand. Silent when the disk refuses, since the warning is already
## logged and the player can do nothing about it mid-game.
func _autosave(announce: bool = true) -> void:
	# Mid-opening the party may still be empty; the scene saves when it ends.
	if _in_opening:
		return
	_record_location()
	if GameState.autosave() and announce:
		field_ui.show_notice(AUTOSAVED_TEXT)


## A save the player asked for from the menu. Returns whether it reached disk.
func save_to_slot(slot: int) -> bool:
	if _in_opening:
		return false
	_record_location()
	var ok: bool = GameState.save_game(slot)
	if ok:
		field_ui.show_notice(SAVED_TEXT % SaveService.slot_title(slot).capitalize())
	return ok


## Abandons the current session for the journey in [param slot]. The field is
## rebuilt from scratch, so nothing from the old one can leak into the new.
func load_from_slot(slot: int) -> bool:
	if not GameState.load_game(slot):
		return false
	get_tree().change_scene_to_file(scene_file_path)
	return true


func _record_location() -> void:
	GameState.record_location(area.scene_file_path, player.global_position, player.facing_direction)


## Leaves for the title screen, saving first so "Continue" picks up here.
func return_to_title() -> void:
	_autosave(false)
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


## Listens to whatever the current area contains. Spawn zones relay their
## creatures, hand-placed creatures speak for themselves, and exits ask for
## the next area.
func _wire_area() -> void:
	for zone: SpawnZone in get_tree().get_nodes_in_group(SpawnZone.GROUP):
		if not zone.creature_reached_player.is_connected(_on_creature_reached_player):
			zone.creature_reached_player.connect(_on_creature_reached_player)
	# Creatures placed by hand in the area rather than by a zone.
	for creature: WildCreature in get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP):
		# A beaten boss never comes back (Specification 19).
		if creature.is_boss() and GameState.has_defeated_boss(creature.boss_id):
			creature.mark_defeated()
			continue
		if not creature.reached_player.is_connected(_on_creature_reached_player):
			creature.reached_player.connect(_on_creature_reached_player)
	for exit: AreaExit in get_tree().get_nodes_in_group(AreaExit.GROUP):
		if not exit.player_entered.is_connected(_on_area_exit_entered):
			exit.player_entered.connect(_on_area_exit_entered)


## The current area's theme. Safe to call on every arrival and after every
## battle, since the service ignores a track that is already playing.
func _play_area_music() -> void:
	MusicService.play(area.music_id)


func _on_area_exit_entered(exit: AreaExit) -> void:
	if _world_is_paused() or _travelling:
		return
	# A way sealed behind a boss turns the player back with a line instead.
	if exit.is_locked():
		_open_dialogue(exit.locked_text())
		return
	travel_to(exit.target_area_path, exit.target_entrance)


## Swaps the current area for the scene at [param area_path] and puts the
## player on its [param entrance] marker, behind a screen wipe so the old map
## is never seen being torn down.
func travel_to(area_path: String, entrance: StringName) -> void:
	var packed: PackedScene = load(area_path) as PackedScene
	if packed == null:
		push_warning("Area exit points at %s, which is not a scene." % area_path)
		return
	_travelling = true
	# A lesson creature belongs to the area it was staged in and does not
	# follow; the Scout stages another when the player comes back to him.
	_abandon_field_lesson()
	_set_world_active(false)
	await transition.cover(ScreenTransition.Style.WORLD)

	_swap_area(packed)
	player.global_position = area.entrance_position(entrance)
	player.velocity = Vector2.ZERO
	partner.snap_to_player()
	_fit_camera_to_area()
	camera.reset_smoothing()
	_wire_area()
	_play_area_music()
	_report_area_reached()
	# Entering an area is a save boundary (Specification 21.2), and the
	# entrance marker is a safe spot to come back to.
	_autosave()
	await transition.reveal(ScreenTransition.Style.WORLD)
	_travelling = false
	_refresh_world_activity()


## Replaces the current area node with a fresh instance of [param packed],
## keeping it at the same place in the tree so draw order is unchanged.
func _swap_area(packed: PackedScene) -> void:
	var previous: WorldArea = area
	var index: int = previous.get_index()
	remove_child(previous)
	previous.queue_free()
	var next: WorldArea = packed.instantiate() as WorldArea
	next.name = "Area"
	add_child(next)
	move_child(next, index)
	area = next


func _unhandled_input(event: InputEvent) -> void:
	if transition.is_busy():
		get_viewport().set_input_as_handled()
		return

	# The counter takes its own keys, Escape included.
	if shop_menu.is_open():
		return

	if event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		_toggle_settings()
		return

	if settings_menu.is_open() or battle_scene.is_active() or field_ui.is_open():
		return

	if event.is_action_pressed(&"attack"):
		get_viewport().set_input_as_handled()
		_strike()
		return

	if not event.is_action_pressed(&"interact"):
		return

	get_viewport().set_input_as_handled()
	_interact()


func _toggle_settings() -> void:
	if settings_menu.is_open():
		settings_menu.close()
	else:
		settings_menu.open()


## The interact key in the overworld: it walks a passage that has more boxes
## to show, closes the line once it is read out, or else acts on the nearest
## actor within reach. A line waiting on a reply takes the key itself, so it
## never arrives here.
func _interact() -> void:
	if dialogue_panel.is_asking():
		return
	if dialogue_panel.is_open():
		if not dialogue_panel.advance():
			_close_dialogue()
		return

	# Between the opening's lines, and while a lesson holds the player to one
	# thing, there is nobody else to talk to.
	if _in_opening or _staging_tutorial or is_lesson_locked():
		return
	var chest: TreasureChest = nearest_chest_in_reach()
	if chest != null:
		_open_chest(chest)
		return
	var actor: WorldActor = nearest_actor_in_reach()
	if actor == null:
		return
	if actor is WildCreature:
		var creature := actor as WildCreature
		if creature.is_boss():
			_challenge_boss(creature)
		else:
			_start_wild_battle(creature)
		return
	_talk_to(actor)


## A chest on the map (Specification 16.1). The lid comes up, what was inside
## goes into the satchel as field notices, and the chest stays open for the
## rest of the journey. A chest waiting on a boss says so instead.
func _open_chest(chest: TreasureChest) -> void:
	player.face(GameOpening.facing_toward(player.global_position, chest.global_position))
	if chest.is_locked():
		_open_dialogue(chest.locked_text())
		return
	if chest.is_open():
		_open_dialogue(chest.empty_text())
		return
	var lines: PackedStringArray = chest.take()
	for line: String in lines:
		field_ui.show_notice(line)
	var told: String = chest.opened_line
	if told == "":
		told = CHEST_OPENED_TEXT if not lines.is_empty() else CHEST_EMPTY_HANDED_TEXT
	_open_dialogue(told)
	# What is in the satchel changed, and the chest must stay open across a
	# reload (Specification 21.2).
	_autosave(false)


## Talking to an NPC: healing and small talk, or quest business when the
## actor has any (Specification 17, 18.4). Talking is itself something a
## quest can ask for, so it is reported before the actor's own quests are
## looked at and a "find the scout" errand completes on arrival. When a
## turn-in leaves the same person with the next step to offer, the
## conversation runs straight on into it.
func _talk_to(actor: WorldActor) -> void:
	actor.face_toward(player.global_position)
	if actor.heals_party:
		field_ui.show_notice(
			PARTY_HEALED_TEXT if GameState.heal_party() else PARTY_ALREADY_WELL_TEXT
		)
		# A healer's table is somewhere to wake after a rout (Specification
		# 20.1), and the player is standing on a walkable spot beside it.
		GameState.record_haven(area.scene_file_path, player.global_position, actor.display_name)
		_autosave()
	GameState.report_quest_event(QuestObjective.Kind.TALK, actor.actor_id())
	var quest: QuestData = actor.current_quest(GameState.quests, Content)
	if quest == null:
		if _serves(actor):
			_serve(actor, actor.idle_line(GameState.quests, Content))
		else:
			_open_dialogue(actor.idle_line(GameState.quests, Content))
		return
	if GameState.quests.is_ready(quest):
		_show_reward_lines(GameState.complete_quest(quest))
		_autosave()
		# Handing the king in is the end of the story, and the ending plays
		# where the player is standing rather than in a scene of its own.
		if quest.id == Epilogue.QUEST_ID and not GameState.story_complete:
			await _say(quest.complete_text())
			# The last quest pays enough XP to evolve something, and the
			# ending takes the world away for good, so the evolution has to
			# be seen through before the wood starts to turn.
			await _settle_growth()
			await _play_epilogue()
			return
		var next: QuestData = actor.current_quest(GameState.quests, Content)
		if next == null or not GameState.quests.can_offer(next):
			_open_dialogue(quest.complete_text())
			_settle_growth()
			return
		await _say(quest.complete_text())
		await _offer(next)
		_settle_growth()
		return
	# A vendor or innkeeper with an errand running still serves: the errand is
	# usually to buy from them or sleep under their roof.
	if GameState.quests.is_active(quest.id) and _serves(actor):
		_serve(actor, quest.progress_text())
		return
	if GameState.quests.is_active(quest.id):
		# The main story is not something the player can hand back, so its
		# giver only says the step again. A lesson lost or cut short is
		# simply staged once more.
		if quest.is_main():
			if _is_lesson(quest):
				await _say(quest.progress_text())
				_play_lesson(quest)
			else:
				_open_dialogue(quest.progress_text())
			return
		var reply: int = await _ask(quest.progress_text(), [quest.continue_option, quest.abandon_option])
		if reply == 1:
			GameState.abandon_quest(quest)
			_open_dialogue(quest.abandoned_text())
			_autosave()
		elif reply == 0:
			_close_dialogue()
		return
	await _offer(quest)
	# Whatever the answer, a vendor still opens the counter once the reply
	# has been read.
	if _serves(actor):
		if dialogue_panel.is_open():
			await dialogue_panel.dismissed
		_serve(actor, actor.idle_line(GameState.quests, Content))


## The ending (see [Epilogue]): the world stops, the wood comes back, the
## caption is read, and the journey is handed back to the title screen with
## the finished save intact.
func _play_epilogue() -> void:
	if dialogue_panel.is_open():
		await dialogue_panel.dismissed
	_close_dialogue()
	_travelling = true
	_refresh_world_activity()
	GameState.story_complete = true
	_autosave(false)
	await Epilogue.play(self, area)
	await transition.cover(ScreenTransition.Style.WORLD)
	get_tree().change_scene_to_file(TITLE_SCENE_PATH)


func _serves(actor: WorldActor) -> bool:
	return actor.is_vendor() or actor.runs_inn


func _serve(actor: WorldActor, greeting: String) -> void:
	if actor.is_vendor():
		_open_shop(actor, greeting)
	else:
		_offer_rest(actor, greeting)


## A vendor's counter (Specification 16.5). The vendor's small talk is the
## greeting over their wares.
func _open_shop(actor: WorldActor, greeting: String) -> void:
	var title: String = actor.shop_title if not actor.shop_title.is_empty() else actor.display_name.capitalize()
	shop_menu.open(title, greeting, actor.stock(Content))
	_refresh_world_activity()


func _on_shop_closed() -> void:
	_autosave(false)
	_refresh_world_activity()


## The inn (Specification 16.5, 16.6): a night's rest heals the whole party
## and saves, free like every healing service in the MVP.
func _offer_rest(actor: WorldActor, greeting: String) -> void:
	var choice: int = await _ask(greeting, INN_OPTIONS)
	if choice != 0:
		_close_dialogue()
		return
	_close_dialogue()
	_travelling = true
	_refresh_world_activity()
	var bed: Vector2 = player.global_position
	await transition.cover(ScreenTransition.Style.WORLD)
	GameState.heal_party()
	field_ui.show_notice(PARTY_HEALED_TEXT)
	GameState.record_haven(area.scene_file_path, bed, actor.display_name)
	GameState.report_quest_event(QuestObjective.Kind.EVENT, GameState.EVENT_RESTED_AT_INN)
	await get_tree().create_timer(INN_NIGHT_SECONDS).timeout
	await transition.reveal(ScreenTransition.Style.WORLD)
	_travelling = false
	_autosave()
	_open_dialogue(INN_RESTED_TEXT)


## Puts [param quest] to the player and plays out their answer.
func _offer(quest: QuestData) -> void:
	var line: String = quest.reoffer_text() if GameState.quests.was_declined(quest.id) else quest.offer_line
	var choice: int = await _ask(line, [quest.accept_option, quest.refuse_option])
	if choice == 0:
		GameState.accept_quest(quest)
		_autosave()
		# A gentle word when the party is behind the quest's pace; it never
		# stops the player going.
		var lead: CreatureInstance = GameState.lead_creature()
		if lead != null and quest.is_underleveled(lead.level):
			await _say(quest.caution_text())
		# A lesson whose goal is already met (a Loambuck bound early) is
		# simply handed in next time.
		if _is_lesson(quest) and not GameState.quests.is_ready(quest):
			await _say(quest.accepted_text())
			_play_lesson(quest)
			return
		_open_dialogue(quest.accepted_text())
	elif choice == 1:
		GameState.refuse_quest(quest)
		_open_dialogue(quest.refused_text())
		_autosave()


## Whether [param quest] is taught by a scripted, guided battle.
func _is_lesson(quest: QuestData) -> bool:
	return quest.id in [
		FieldBinding.QUEST_ID,
		FieldMending.QUEST_ID,
		FieldStrike.QUEST_ID,
		FieldAmbush.QUEST_ID,
		FieldRout.QUEST_ID,
	]


func _play_lesson(quest: QuestData) -> void:
	# Staging a lesson takes back whatever an unfinished one left standing,
	# so the camp never fills up with practice creatures.
	_abandon_field_lesson()
	match quest.id:
		FieldBinding.QUEST_ID:
			_play_field_binding()
		FieldMending.QUEST_ID:
			_play_field_mending()
		FieldStrike.QUEST_ID:
			_play_field_strike()
		FieldAmbush.QUEST_ID:
			_play_field_ambush()
		FieldRout.QUEST_ID:
			_play_field_rout()


## The binding lesson (see [FieldBinding]): a wild Loambuck wanders up to the
## Scout's fire, and the battle that follows walks the player through wearing
## it down and offering it a Binding Scroll.
func _play_field_binding() -> void:
	if GameState.party_is_full():
		_open_dialogue(FieldBinding.PARTY_FULL_LINE)
		return
	var species: CreatureSpecies = Content.get_species(FieldBinding.SPECIES_ID)
	if species == null:
		return
	# The Scout sees the party rested before the lesson starts.
	GameState.heal_party()
	_staging_tutorial = true
	await _say(FieldBinding.APPROACH[0])
	var loambuck: WildCreature = _spawn_lesson_creature(species, FieldBinding.LEVEL, FieldBinding.APPROACH_DISTANCE_CELLS)
	await get_tree().create_timer(AMBUSHER_ENTRANCE_SECONDS).timeout
	for index: int in range(1, FieldBinding.APPROACH.size()):
		await _say(FieldBinding.APPROACH[index])
	_staging_tutorial = false
	_start_wild_battle(loambuck, BattleConfig.Opening.NEUTRAL, FieldBinding.stage())


## The support-move lesson (see [FieldMending]): a wild Emberling bursts
## out of the grass by the Scout's camp, and the battle that follows walks the
## player through switching to their healer, mending the striker on the bench
## and switching back. When the pair is split between the party and the
## paddock the player is asked to call the missing one back; with no healer
## bound at all the lesson is only told.
func _play_field_mending() -> void:
	# The Scout sees the party rested first, so a fainted mender still teaches.
	GameState.heal_party()
	var cast: Dictionary = FieldMending.roles(GameState.party)
	var bound: Array[CreatureInstance] = []
	bound.append_array(GameState.party)
	bound.append_array(GameState.kept)
	if cast.is_empty() and not FieldMending.roles(bound).is_empty():
		_open_dialogue(FieldMending.CALL_BACK_LINE)
		return
	if cast.is_empty():
		GameState.report_quest_event(QuestObjective.Kind.EVENT, FieldMending.EVENT_ID)
		_open_dialogue(FieldMending.NO_HEALER_LINE)
		_autosave()
		return
	var species: CreatureSpecies = Content.get_species(FieldMending.ENEMY_SPECIES_ID)
	if species == null:
		return
	_staging_tutorial = true
	await _say(FieldMending.AMBUSH[0])
	var ambusher: WildCreature = _spawn_lesson_creature(
		species, FieldMending.ENEMY_LEVEL, FieldMending.AMBUSH_DISTANCE_CELLS
	)
	FieldMending.wear_down(ambusher.encounter_instance())
	SfxService.play(&"hit")
	await get_tree().create_timer(AMBUSHER_ENTRANCE_SECONDS).timeout
	for index: int in range(1, FieldMending.AMBUSH.size()):
		await _say(FieldMending.AMBUSH[index])
	_staging_tutorial = false
	_start_wild_battle(ambusher, BattleConfig.Opening.NEUTRAL, FieldMending.stage(cast))


## The overworld-strike lesson (see [FieldStrike]): a Loambuck is put in the
## grass a few paces off and then left entirely alone. Nothing else happens
## until the player closes the distance and swings, which is the lesson.
func _play_field_strike() -> void:
	var species: CreatureSpecies = Content.get_species(FieldStrike.SPECIES_ID)
	if species == null:
		return
	# The Scout sees the party rested before the lesson starts.
	GameState.heal_party()
	_staging_tutorial = true
	await _say(FieldStrike.SIGHTING[0])
	var quarry: WildCreature = _spawn_lesson_creature(
		species, FieldStrike.LEVEL, FieldStrike.DISTANCE_CELLS
	)
	FieldStrike.wear_down(quarry.encounter_instance())
	quarry.refresh_health()
	await get_tree().create_timer(AMBUSHER_ENTRANCE_SECONDS).timeout
	for index: int in range(1, FieldStrike.SIGHTING.size()):
		await _say(FieldStrike.SIGHTING[index])
	_staging_tutorial = false
	_begin_field_lesson(
		quarry,
		FieldStrike.EVENT_ID,
		true,
		FieldStrike.PROMPT % species.display_name,
		FieldStrike.stage(),
	)


## The ambush lesson (see [FieldAmbush]): a hostile Emberling is sent at the
## player, who is asked to stand still and let it arrive. Its blow lands in
## the overworld, and the battle opens with the lead already hurt and the
## creature moving first.
func _play_field_ambush() -> void:
	var species: CreatureSpecies = Content.get_species(FieldAmbush.SPECIES_ID)
	if species == null:
		return
	GameState.heal_party()
	_staging_tutorial = true
	await _say(FieldAmbush.CHARGE[0])
	var hunter: WildCreature = _spawn_lesson_creature(
		species,
		FieldAmbush.LEVEL,
		FieldAmbush.DISTANCE_CELLS,
		WildCreature.Disposition.HOSTILE,
		FieldAmbush.LEASH_RADIUS,
		FieldAmbush.DETECTION_RADIUS,
	)
	await get_tree().create_timer(AMBUSHER_ENTRANCE_SECONDS).timeout
	for index: int in range(1, FieldAmbush.CHARGE.size()):
		await _say(FieldAmbush.CHARGE[index])
	_staging_tutorial = false
	_begin_field_lesson(hunter, FieldAmbush.EVENT_ID, false, FieldAmbush.PROMPT, FieldAmbush.stage())


## The rout lesson (see [FieldRout]): a creature that has already lost a
## fight wanders up with almost nothing left, so the swing that lands on it
## finishes it in the grass and no battle screen ever opens.
func _play_field_rout() -> void:
	var species: CreatureSpecies = Content.get_species(FieldRout.SPECIES_ID)
	if species == null:
		return
	GameState.heal_party()
	_staging_tutorial = true
	await _say(FieldRout.SIGHTING[0])
	var spent: WildCreature = _spawn_lesson_creature(
		species, FieldRout.LEVEL, FieldRout.DISTANCE_CELLS
	)
	FieldRout.wear_down(spent.encounter_instance())
	spent.refresh_health()
	await get_tree().create_timer(AMBUSHER_ENTRANCE_SECONDS).timeout
	for index: int in range(1, FieldRout.SIGHTING.size()):
		await _say(FieldRout.SIGHTING[index])
	_staging_tutorial = false
	# Only a swing that puts it down counts: one that leaves it standing has
	# taught the player the opposite of the lesson.
	_begin_field_lesson(
		spent, FieldRout.EVENT_ID, true, FieldRout.PROMPT % species.display_name, {}, true
	)


## Hands the world an overworld lesson to watch for: [param quarry] is the
## creature it was staged around, [param on_strike] tells it whether the
## lesson is waiting on the player's swing or on the creature's own blow,
## [param prompt] is the instruction that stands on screen until one lands,
## [param battle] is what the blow's battle is staged with (empty when the
## blow is not meant to open one), and [param needs_rout] holds the lesson
## open until a swing puts the creature down where it stands.
func _begin_field_lesson(
	quarry: WildCreature,
	event: StringName,
	on_strike: bool,
	prompt: String,
	battle: Dictionary,
	needs_rout: bool = false,
) -> void:
	_field_lesson = {
		"creature": quarry,
		"event": event,
		"on_strike": on_strike,
		"prompt": prompt,
		"battle": battle,
		"needs_rout": needs_rout,
		# A lesson about the player's own swing leaves them the attack key
		# and nothing else; one about being swung at leaves them nothing, so
		# a stray step or a panicked swing cannot cost them the lesson.
		"lock": LOCK_ATTACK if on_strike else LOCK_STILL,
	}
	field_ui.show_prompt(prompt)
	# The staging held the world still through the Scout's lines. Unlike the
	# battle lessons, this one hands it straight back: walking up to the
	# quarry, or standing still while it comes, is the whole lesson.
	_refresh_world_activity()


## Whether the open lesson is waiting on this exact creature, and on a blow
## thrown by the player ([param by_strike]) rather than at them.
func _field_lesson_waits_on(creature: WildCreature, by_strike: bool) -> bool:
	if _field_lesson.is_empty() or bool(_field_lesson.on_strike) != by_strike:
		return false
	return _staged_creature() == creature


## The creature the open lesson staged, or null once it has been freed. Read
## untyped on purpose: assigning a freed object to a typed variable is itself
## an error, so this is the only place the record's creature is unpacked.
func _staged_creature() -> WildCreature:
	var quarry: Variant = _field_lesson.get("creature")
	return quarry if is_instance_valid(quarry) else null


## The blow the lesson was waiting for has landed. The quest hears about it
## and the instruction comes down; the battle it opens is an ordinary one.
func _complete_field_lesson() -> void:
	var event: StringName = _field_lesson.event
	_clear_field_lesson()
	GameState.report_quest_event(QuestObjective.Kind.EVENT, event)
	_autosave(false)


func _clear_field_lesson() -> void:
	_field_lesson = {}
	if field_ui != null:
		field_ui.hide_prompt()
	# The lesson was holding the player's keys; they get them back.
	_refresh_world_activity()


## How tightly a lesson is holding the player right now, or empty.
func lesson_lock() -> StringName:
	return _field_lesson.get("lock", &"")


## Whether a lesson is holding the player to one thing, so menus and the
## interact key stay shut until it is over.
func is_lesson_locked() -> bool:
	return lesson_lock() != &""


## Takes back a staged creature that is still standing, for a lesson the
## player walked away from or is about to be given again.
func _abandon_field_lesson() -> void:
	if _field_lesson.is_empty():
		return
	var quarry: WildCreature = _staged_creature()
	if quarry != null:
		quarry.queue_free()
	_clear_field_lesson()


## After a battle, the staged creature may be gone without the lesson's blow
## ever being thrown: fought the ordinary way, bound, or routed by someone
## else. The lesson is then over as far as the world goes, and the Scout
## stages it again the next time the player talks to him. One still standing
## gets its instruction back.
func _settle_field_lesson() -> void:
	if _field_lesson.is_empty():
		return
	var quarry: WildCreature = _staged_creature()
	if quarry != null and quarry.is_interactable():
		field_ui.show_prompt(_field_lesson.prompt)
		return
	_clear_field_lesson()


## A one-off wild creature for a lesson, placed [param distance_cells] from
## the player on the side away from the Scout, and gone once the battle is
## over, whatever its outcome. A hostile one needs a [param leash_radius] and
## a [param detection_radius] wide enough to carry it the whole way across.
func _spawn_lesson_creature(
	species: CreatureSpecies,
	level: int,
	distance_cells: float,
	disposition: WildCreature.Disposition = WildCreature.Disposition.NEUTRAL,
	leash_radius: float = 0.0,
	detection_radius: float = 0.0,
) -> WildCreature:
	var away: Vector2 = Vector2.LEFT
	var scout: WorldActor = _actor_with_id(FieldMending.SCOUT_ID)
	if scout != null and not scout.global_position.is_equal_approx(player.global_position):
		away = scout.global_position.direction_to(player.global_position)
	var at: Vector2 = player.global_position + away * distance_cells * float(WorldArea.GRID_SIZE)
	var creature: WildCreature = WILD_CREATURE_SCENE.instantiate()
	creature.configure(species, level, at, leash_radius, disposition, detection_radius)
	creature.ability_index = 0
	creature.defeated.connect(
		func(_c: WildCreature) -> void:
			# A lesson creature cut down without a battle (the rout lesson, or
			# a swing at the ambusher) leaves nothing to watch, and a freed
			# creature must never sit in the lesson record.
			_settle_field_lesson()
			creature.queue_free()
	)
	# Staged after the area was wired, so it is hooked up by hand: a hostile
	# one ([FieldAmbush]) reaches the player through this signal and nothing
	# else.
	creature.reached_player.connect(_on_creature_reached_player)
	var host: Node = area.get_node_or_null(^"Actors")
	(host if host != null else area).add_child(creature)
	creature.global_position = at
	creature.set_roaming(false)
	# A lesson that holds the player still has to leave them facing the thing
	# they are being told to hit, or told to wait for.
	player.face(GameOpening.facing_toward(player.global_position, at))
	creature.scale = Vector2.ZERO
	create_tween().tween_property(creature, "scale", Vector2.ONE, AMBUSHER_ENTRANCE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return creature


## Puts a line with replies to the player and waits for the answer. The
## world pauses with the dialogue open, as it does for any line.
func _ask(line: String, options: PackedStringArray) -> int:
	_set_world_active(false)
	var reply: int = await dialogue_panel.ask(line, options)
	_refresh_world_activity()
	return reply


## Reward lines the field shows as notices. XP is left out because the
## experience panel already animates it from [signal GameState.experience_awarded].
func _show_reward_lines(lines: PackedStringArray) -> void:
	for line: String in lines:
		if not "XP" in line and not "level" in line:
			field_ui.show_notice(line)


## Where the field's quest arrow should point, for [FieldUI]: the world
## position of whoever is waiting on the player, with their name, or an empty
## dictionary when nobody is. Someone standing in this area is pointed at
## directly; someone further off is pointed at through the doorway that leads
## towards them (see [QuestCompass]), so the arrow is always something the
## player can walk at.
func quest_arrow_point() -> Dictionary:
	var wanted: Dictionary = QuestCompass.destination(GameState.quests)
	if wanted.is_empty():
		return {}
	var goal_area: String = ""
	var caption: String = ""
	if wanted.has("actor"):
		var who: StringName = wanted.actor
		var here: WorldActor = _actor_with_id(who)
		caption = (here.display_name if here != null else String(who).capitalize()).to_upper()
		if here != null:
			return {"position": here.global_position, "label": caption}
		goal_area = QuestCompass.area_of(who, area.scene_file_path)
	else:
		goal_area = wanted.area
		caption = goal_area.get_file().get_basename().replace("_", " ").to_upper()
	if goal_area == "" or goal_area == area.scene_file_path:
		return {}
	var door: String = QuestCompass.step_toward_area(goal_area, area.scene_file_path)
	for exit: AreaExit in get_tree().get_nodes_in_group(AreaExit.GROUP):
		if exit.target_area_path == door:
			return {"position": exit.global_position, "label": caption}
	return {}


## Tells the quest log the player has arrived in the current area.
func _report_area_reached() -> void:
	GameState.report_quest_event(QuestObjective.Kind.REACH, StringName(area.scene_file_path))


## The overworld strike (Specification 7.3, extended).
##
## The player sets the direction and the timing; the Oathbound at the front of
## the party throws the actual blow, with its own best move against whatever
## is in front of it. The lunge always plays, whether or not anything is hit,
## so the player can feel the reach. What it connects with decides the rest: a
## creature that survives becomes a battle the player opens ahead on, and one
## that does not never sees a battle screen.
func _strike() -> void:
	# A question is never swung away from, whether or not its replies are on
	# screen yet: the ask may still have boxes to go.
	if dialogue_panel.has_question():
		return
	if dialogue_panel.is_open():
		_close_dialogue()
	if not player.strike():
		return

	var lead: CreatureInstance = GameState.lead_creature()
	var target: WildCreature = _creature_in_reach_of_strike()
	# The partner goes for whatever is actually there, and at empty air
	# otherwise, so a miss reads as a miss rather than as nothing happening.
	var struck_point: Vector2 = (
		target.global_position
		if target != null
		else player.global_position + player.strike_direction() * player.strike_reach()
	)
	if target == null:
		partner.strike_toward(struck_point)
		return
	if lead == null:
		# With nothing able to fight, contact is still an encounter; the battle
		# scene revives the party on the way in.
		partner.strike_toward(struck_point)
		_start_wild_battle(target)
		return

	if target.is_boss():
		# A boss is not cut down in the field; swinging at it is a challenge.
		await partner.strike_toward(struck_point)
		if _strike_can_still_land(target):
			_challenge_boss(target)
		return

	var defender: CreatureInstance = target.encounter_instance()
	var amount: int = OverworldStrike.player_strike_damage(lead, defender, Content.type_chart)
	# The dash is awaited so the blow visibly lands before the world changes
	# underneath it, rather than the screen wiping mid-lunge.
	await partner.strike_toward(struck_point)
	if not _strike_can_still_land(target):
		return

	var routed: bool = target.take_overworld_hit(amount, player.global_position)
	# The strike lesson counts the swing itself, whether or not it leaves
	# anything to fight; the rout lesson counts only a swing that finishes the
	# creature where it stands.
	var lesson: Dictionary = {}
	if _field_lesson_waits_on(target, true) and (routed or not bool(_field_lesson.needs_rout)):
		lesson = _field_lesson.battle
		_complete_field_lesson()
	if routed:
		await _rout(target, defender)
		return
	_start_wild_battle(target, BattleConfig.Opening.ADVANTAGE, lesson)


## Whether a strike that was already thrown should still resolve. The dash
## takes a moment, and a hostile creature can land its own blow inside it, so
## the target may be gone or a battle may already be opening by the time the
## strike arrives.
func _strike_can_still_land(target: WildCreature) -> bool:
	if not is_instance_valid(target) or not target.is_interactable():
		return false
	return not battle_scene.is_active() and not transition.is_busy()


## The creature a strike lands on: the nearest one inside the strike wedge.
func _creature_in_reach_of_strike() -> WildCreature:
	var best: WildCreature = null
	var best_distance: float = INF
	for creature: WildCreature in get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP):
		if not creature.is_interactable() or not player.strike_covers(creature.global_position):
			continue
		var distance: float = player.global_position.distance_to(creature.global_position)
		if distance < best_distance:
			best = creature
			best_distance = distance
	return best


## A creature killed outright by a strike. The rewards are the same ones the
## battle would have paid, so skipping the battle costs the player nothing but
## the chance to bind it.
func _rout(creature: WildCreature, defeated: CreatureInstance) -> void:
	_set_world_active(false)
	await creature.play_rout()
	GameState.seen_species[defeated.species_id()] = true
	var reward_lines := GameState.award_defeat_rewards(defeated)
	field_ui.show_notice("+%d coins" % BattleRules.currency_for_defeating(defeated))
	_show_reward_lines(reward_lines)
	GameState.report_quest_event(QuestObjective.Kind.DEFEAT, defeated.species_id())
	_autosave()
	_refresh_world_activity()
	_settle_growth()


## Stepping up to a boss. It names the fight and lets the player walk away,
## and refuses outright until its required quest is under way
## (Specification 5.3).
func _challenge_boss(creature: WildCreature) -> void:
	var can_fight: bool = (
		creature.required_quest == &"" or GameState.quests.is_active(creature.required_quest)
	)
	if not can_fight:
		_open_dialogue(creature.challenge_text(false))
		return
	var reply: int = await _ask(creature.challenge_text(true), BOSS_FIGHT_OPTIONS)
	if reply == 0 and creature.is_interactable() and not battle_scene.is_active():
		_start_wild_battle(creature)
	elif reply == 1:
		_close_dialogue()


## The closest interactable actor the player can touch, or null.
## The chest within reach, nearest first. Chests block movement, so at most
## one is ever close enough to matter.
func nearest_chest_in_reach() -> TreasureChest:
	var best: TreasureChest = null
	var best_distance: float = INF
	for chest: TreasureChest in get_tree().get_nodes_in_group(TreasureChest.GROUP):
		if not _is_adjacent_to(chest):
			continue
		var distance: float = player.global_position.distance_to(chest.global_position)
		if distance < best_distance:
			best = chest
			best_distance = distance
	return best


func nearest_actor_in_reach() -> WorldActor:
	var best: WorldActor = null
	var best_distance: float = INF
	for actor: WorldActor in get_tree().get_nodes_in_group(WorldActor.GROUP):
		if not actor.is_interactable() or not _is_adjacent_to(actor):
			continue
		var distance: float = player.global_position.distance_to(actor.global_position)
		if distance < best_distance:
			best = actor
			best_distance = distance
	return best


## Movement is analog, so "adjacent" means within reach rather than on a
## neighbouring cell: close enough to touch the actor from any side or corner,
## but not from two tiles away.
func _is_adjacent_to(actor: Node2D) -> bool:
	var reach: float = player.grid_size * INTERACTION_REACH_IN_CELLS
	return player.global_position.distance_to(actor.global_position) <= reach


func _fit_camera_to_area() -> void:
	var limits: Rect2 = area.bounds()
	if limits.size == Vector2.ZERO:
		return
	camera.limit_left = int(limits.position.x)
	camera.limit_top = int(limits.position.y)
	camera.limit_right = int(limits.end.x)
	camera.limit_bottom = int(limits.end.y)


func _on_settings_opened() -> void:
	_refresh_world_activity()


## Dialogue and battle also own movement, so closing the menu must not hand
## control back while either is still on screen.
func _on_settings_closed() -> void:
	_refresh_world_activity()


## A hostile creature's overworld strike landing on the player. The blow is
## real: the encounter opens with the player's lead already hurt and the
## creature taking the first turn.
func _on_creature_reached_player(creature: WildCreature) -> void:
	if _world_is_paused() or not creature.is_interactable():
		return
	# Standing still for the blow is what the ambush lesson asks for.
	var lesson: Dictionary = {}
	if _field_lesson_waits_on(creature, false):
		lesson = _field_lesson.battle
		_complete_field_lesson()
	_start_wild_battle(creature, BattleConfig.Opening.DISADVANTAGE, lesson)


## [param lesson] is what a lesson's [code]stage()[/code] returns, for a
## guided battle (see [member _lesson]). Empty for every ordinary encounter.
func _start_wild_battle(
	creature: WildCreature,
	opening: BattleConfig.Opening = BattleConfig.Opening.NEUTRAL,
	lesson: Dictionary = {},
) -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close()
	_battling_creature = creature
	_lesson = lesson
	# An instruction left standing would hang over the battle screen; it comes
	# back afterwards if the lesson is still waiting on this creature.
	field_ui.hide_prompt()
	if not GameState.has_usable_party_member():
		GameState.heal_party()

	var enemy: CreatureInstance = creature.encounter_instance()
	GameState.seen_species[enemy.species_id()] = true
	_battling_species = enemy.species_id()
	if opening == BattleConfig.Opening.DISADVANTAGE:
		_apply_ambush(enemy)

	var party: Array[CreatureInstance] = GameState.party
	if lesson.has("party"):
		party = lesson.party
	var config := (
		BattleConfig.boss(party, enemy, Content.type_chart, opening)
		if creature.is_boss()
		else BattleConfig.wild(party, enemy, Content.type_chart, opening)
	)
	config.binding_scrolls = GameState.binding_scrolls
	# A lesson fought with the Scout's borrowed party keeps the satchel shut;
	# one fought with the player's own party ([FieldStrike], [FieldAmbush])
	# asks for it back.
	if lesson.is_empty() or bool(lesson.get("satchel", false)):
		config.items = GameState.items.duplicate()
		for item: ItemData in Content.all_items():
			config.item_catalog[item.id] = item
	# A full party is no longer a reason to refuse a scroll: whatever will not
	# walk with the player is kept for them (Specification 9.3).
	config.has_bind_destination = not GameState.party_is_full() or GameState.has_keeping_room()
	config.level_cap = GameState.level_cap
	var guide: BattleGuide = null
	if not lesson.is_empty():
		guide = lesson.guide
		(lesson.prepare as Callable).call(config, enemy, party)

	# The world stops the moment the encounter is decided, so the player is not
	# still walking behind the wipe.
	_set_world_active(false)
	MusicService.play(BATTLE_MUSIC_ID)
	await transition.cover(ScreenTransition.Style.BATTLE)
	# `start_battle` shows the screen before it awaits its opening messages, so
	# the reveal uncovers a battle that is already on screen.
	battle_scene.start_battle(config, guide)
	await transition.reveal(ScreenTransition.Style.BATTLE)
	_refresh_world_activity()


## The damage a creature's overworld strike does to the party's lead. It is
## deliberately softer than the player's own swing and can never knock the
## lead out, because the player has no way to answer a blow landed before the
## battle screen even opens.
func _apply_ambush(attacker: CreatureInstance) -> void:
	var lead: CreatureInstance = GameState.lead_creature()
	if lead == null:
		return
	var amount: int = OverworldStrike.ambush_damage(attacker, lead, Content.type_chart)
	lead.set_hp(OverworldStrike.hp_after_ambush(lead, amount))


func _on_battle_finished(engine: BattleEngine) -> void:
	GameState.binding_scrolls = engine.binding_scrolls
	if not engine.config.item_catalog.is_empty():
		GameState.set_item_counts(engine.items)
	for used: StringName in engine.items_used:
		GameState.report_quest_event(QuestObjective.Kind.EVENT, StringName(GameState.EVENT_USED_ITEM % used))
	GameState.currency += engine.currency_earned
	if engine.currency_earned > 0:
		field_ui.show_notice("+%d coins" % engine.currency_earned)
	var creature: WildCreature = _battling_creature
	_battling_creature = null
	var species: StringName = _battling_species
	_battling_species = &""
	var lesson: Dictionary = _lesson
	_lesson = {}
	var lesson_won: bool = not lesson.is_empty() and engine.outcome == lesson.success
	if lesson_won and lesson.event != &"":
		GameState.report_quest_event(QuestObjective.Kind.EVENT, lesson.event)
	# A creature the battle took leaves the map as light rather than simply
	# blinking out, but not yet: the wipe is still over the screen, and an
	# effect played under it would come and go unseen.
	var taken: WildCreature = null
	var was_bound: bool = false
	## Set when the party went down and has to be carried back to its haven.
	var routed: bool = false
	var boss_lines: PackedStringArray = []
	match engine.outcome:
		BattleEngine.Outcome.VICTORY:
			taken = creature
			if creature != null and creature.is_boss():
				boss_lines = GameState.record_boss_defeat(creature.boss_id)
			GameState.report_quest_event(QuestObjective.Kind.DEFEAT, species)
		BattleEngine.Outcome.ESCAPED:
			# The creature keeps whatever damage the battle did to it, and is
			# held off for a moment so fleeing is not instantly undone
			# (Specification 7.4).
			if creature != null:
				creature.back_off()
				creature.refresh_health()
		BattleEngine.Outcome.BOUND:
			var went: StringName = GameState.take_in(engine.bound_creature)
			if went == GameState.WENT_TO_KEEPING:
				field_ui.show_notice(KEPT_TEXT % engine.bound_creature.display_name())
			taken = creature
			was_bound = true
			GameState.report_quest_event(QuestObjective.Kind.BIND, species)
		BattleEngine.Outcome.DEFEAT when not lesson.is_empty():
			# Losing the lesson costs nothing; the Scout patches everyone up.
			GameState.heal_party()
			if creature != null:
				creature.mark_defeated()
		BattleEngine.Outcome.DEFEAT:
			# The party is carried back to the last bed or healer's table they
			# used and patched up there (Specification 20.1 steps 2, 4 and 5).
			GameState.apply_defeat_penalty()
			GameState.heal_party()
			# A boss recovers too, so the next attempt is a fair fight.
			if creature != null and creature.is_boss():
				creature.restore_encounter()
			routed = true
	# The screen is still covered by the battle's own wipe, so the way home is
	# never seen being walked.
	if routed:
		_wake_at_haven()
	# A battle can faint the creature that was walking with the player, and
	# leaves the partner wherever it stood when the screen closed.
	partner.refresh_lead()
	partner.snap_to_player()
	# Every outcome above is a save boundary (Specification 21.2): the party,
	# scrolls and coins are settled, and a bound creature is already home.
	_autosave()
	# The battle screen covered the screen before it closed, so the world is
	# already swapped in underneath and only needs uncovering.
	_play_area_music()
	await transition.reveal(ScreenTransition.Style.WORLD)
	# Not awaited: the world is the player's again while the light fades.
	if taken != null:
		taken.play_rout(not was_bound)
		if taken.is_boss():
			SfxService.play(&"boss_victory")
			MusicService.duck(2.6)
			if not taken.victory_line.is_empty():
				_open_dialogue(taken.victory_line)
			# Shown directly: the reward filter would drop a line about levels.
			for line: String in boss_lines:
				field_ui.show_notice(line)
	if routed:
		_open_dialogue(_waking_text())
	if not lesson.is_empty():
		_open_dialogue(lesson.won_line if lesson_won else lesson.lost_line)
	_settle_field_lesson()
	_refresh_world_activity()
	_settle_growth()


## Carries the beaten party back to the last inn bed or healer's table they
## used, or to the town when they have used neither (Specification 20.1).
## Called while the battle's wipe still covers the screen.
func _wake_at_haven() -> void:
	var path: String = GameState.haven_area_path if GameState.has_haven() else GameState.DEFAULT_HAVEN_AREA
	if path != area.scene_file_path:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_warning("The haven at %s is not a scene; waking in place." % path)
			return
		_swap_area(packed)
	player.global_position = (
		GameState.haven_position if GameState.has_haven() else area.player_start_position()
	)
	player.velocity = Vector2.ZERO
	partner.snap_to_player()
	_fit_camera_to_area()
	camera.reset_smoothing()
	_wire_area()
	_report_area_reached()


func _waking_text() -> String:
	if GameState.has_haven() and GameState.haven_name != "":
		return WOKEN_AT_HAVEN_TEXT % [GameState.haven_name.capitalize(), GameState.DEFEAT_CURRENCY_PENALTY]
	return WOKEN_BY_THE_ROAD_TEXT % GameState.DEFEAT_CURRENCY_PENALTY


func _open_dialogue(line: String) -> void:
	dialogue_panel.show_line(line)
	_refresh_world_activity()


func _close_dialogue() -> void:
	dialogue_panel.close()
	_refresh_world_activity()


func _world_is_paused() -> bool:
	return (
		_travelling
		or _in_opening
		or _staging_tutorial
		or _evolving
		or settings_menu.is_open()
		or (field_ui != null and field_ui.is_open())
		or (shop_menu != null and shop_menu.is_open())
		or battle_scene.is_active()
		or dialogue_panel.is_open()
		or transition.is_busy()
	)


## The player and every roaming creature stop together while a menu, dialogue
## or battle is on screen, and resume together when the last one closes.
func _refresh_world_activity() -> void:
	_set_world_active(not _world_is_paused())


func _set_world_active(active: bool) -> void:
	# A lesson can hold the player still while the world keeps moving: the
	# ambush has to arrive, and the swing has to be the only answer to it.
	var lock: StringName = lesson_lock()
	player.movement_enabled = active and lock == &""
	player.strike_enabled = active and lock != LOCK_STILL
	partner.following_enabled = active
	get_tree().call_group(WildCreature.CREATURE_GROUP, &"set_roaming", active)
	get_tree().call_group(WorldActor.WANDERER_GROUP, &"set_roaming", active)
