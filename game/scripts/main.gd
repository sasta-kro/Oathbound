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
const INN_RESTED_TEXT := "You sleep soundly. Your companions wake fully rested."
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


func _ready() -> void:
	$HUD/Hint.hide()
	field_ui = FieldUI.new()
	add_child(field_ui)
	field_ui.changed.connect(_refresh_world_activity)
	evolution_screen = EvolutionScreen.new()
	add_child(evolution_screen)
	shop_menu = ShopMenu.new()
	add_child(shop_menu)
	shop_menu.closed.connect(_on_shop_closed)
	var opening: bool = GameState.take_opening_request()
	if GameState.take_resume_request() and _restore_saved_area():
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
	_evolve_ready_party.call_deferred()


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


func is_evolving() -> bool:
	return _evolving


## Evolves every companion that has reached its evolution level, one screen at
## a time (Specification 9.7). Evolution is automatic: it runs once the world
## is calm after whatever raised the level, and a creature whose new form is
## already past its own evolution level evolves again straight away.
func _evolve_ready_party() -> void:
	if _evolving or not _party_can_evolve():
		return
	_evolving = true
	_refresh_world_activity()
	while transition.is_busy() or battle_scene.is_active():
		await get_tree().process_frame
	if dialogue_panel.is_open():
		await dialogue_panel.dismissed
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


## The interact key in the overworld: it closes an open line of dialogue, or
## else acts on the nearest actor within reach. A line waiting on a reply
## takes the key itself, so it never arrives here.
func _interact() -> void:
	if dialogue_panel.is_asking():
		return
	if dialogue_panel.is_open():
		_close_dialogue()
		return

	# Between the opening's lines there is nobody else to talk to.
	if _in_opening or _staging_tutorial:
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


## Talking to an NPC: healing and small talk, or quest business when the
## actor has any (Specification 17, 18.4). Talking is itself something a
## quest can ask for, so it is reported before the actor's own quests are
## looked at and a "find the scout" errand completes on arrival. When a
## turn-in leaves the same person with the next step to offer, the
## conversation runs straight on into it.
func _talk_to(actor: WorldActor) -> void:
	actor.face_toward(player.global_position)
	if actor.heals_party:
		GameState.heal_party()
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
		var next: QuestData = actor.current_quest(GameState.quests, Content)
		if next == null or not GameState.quests.can_offer(next):
			_open_dialogue(quest.complete_text())
			_evolve_ready_party()
			return
		await _say(quest.complete_text())
		await _offer(next)
		_evolve_ready_party()
		return
	# A vendor or innkeeper with an errand running still serves: the errand is
	# usually to buy from them or sleep under their roof.
	if GameState.quests.is_active(quest.id) and _serves(actor):
		_serve(actor, quest.progress_text())
		return
	if GameState.quests.is_active(quest.id):
		var reply: int = await _ask(quest.progress_text(), [quest.continue_option, quest.abandon_option])
		if reply == 1:
			GameState.abandon_quest(quest)
			_open_dialogue(quest.abandoned_text())
			_autosave()
		elif reply == 0:
			_close_dialogue()
			# A lesson lost or cut short is picked up where it began.
			if _is_lesson(quest):
				_play_lesson(quest)
		return
	await _offer(quest)
	# Whatever the answer, a vendor still opens the counter once the reply
	# has been read.
	if _serves(actor):
		if dialogue_panel.is_open():
			await dialogue_panel.dismissed
		_serve(actor, actor.idle_line(GameState.quests, Content))


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
	await transition.cover(ScreenTransition.Style.WORLD)
	GameState.heal_party()
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
	return quest.id in [FieldBinding.QUEST_ID, FieldMending.QUEST_ID]


func _play_lesson(quest: QuestData) -> void:
	match quest.id:
		FieldBinding.QUEST_ID:
			_play_field_binding()
		FieldMending.QUEST_ID:
			_play_field_mending()


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
## and switching back. With no healer in the party the lesson is only told.
func _play_field_mending() -> void:
	var cast: Dictionary = FieldMending.roles(GameState.party)
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


## A one-off wild creature for a lesson, placed [param distance_cells] from
## the player on the side away from the Scout, and gone once the battle is
## over, whatever its outcome.
func _spawn_lesson_creature(species: CreatureSpecies, level: int, distance_cells: float) -> WildCreature:
	var away: Vector2 = Vector2.LEFT
	var scout: WorldActor = _actor_with_id(FieldMending.SCOUT_ID)
	if scout != null and not scout.global_position.is_equal_approx(player.global_position):
		away = scout.global_position.direction_to(player.global_position)
	var at: Vector2 = player.global_position + away * distance_cells * float(WorldArea.GRID_SIZE)
	var creature: WildCreature = WILD_CREATURE_SCENE.instantiate()
	creature.configure(species, level, at, 0.0, WildCreature.Disposition.NEUTRAL, 0.0)
	creature.ability_index = 0
	creature.defeated.connect(func(_c: WildCreature) -> void: creature.queue_free())
	var host: Node = area.get_node_or_null(^"Actors")
	(host if host != null else area).add_child(creature)
	creature.global_position = at
	creature.set_roaming(false)
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
	if dialogue_panel.is_asking():
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
	if routed:
		await _rout(target, defender)
		return
	_start_wild_battle(target, BattleConfig.Opening.ADVANTAGE)


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
	_evolve_ready_party()


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
	_start_wild_battle(creature, BattleConfig.Opening.DISADVANTAGE)


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
	# A lesson is fought with the Scout's borrowed party, so the satchel stays
	# shut for it.
	if lesson.is_empty():
		config.items = GameState.items.duplicate()
		for item: ItemData in Content.all_items():
			config.item_catalog[item.id] = item
	config.has_bind_destination = not GameState.party_is_full()
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
			GameState.add_to_party(engine.bound_creature)
			taken = creature
			was_bound = true
			GameState.report_quest_event(QuestObjective.Kind.BIND, species)
		BattleEngine.Outcome.DEFEAT when not lesson.is_empty():
			# Losing the lesson costs nothing; the Scout patches everyone up.
			GameState.heal_party()
			if creature != null:
				creature.mark_defeated()
		BattleEngine.Outcome.DEFEAT:
			# No revival location exists yet, so recovery happens in place
			# (Specification 20.1 steps 2, 4 and 5).
			GameState.apply_defeat_penalty()
			GameState.heal_party()
			# A boss recovers too, so the next attempt is a fair fight.
			if creature != null and creature.is_boss():
				creature.restore_encounter()
			_open_dialogue(
				"You wake by the road. Your Oathbound have been revived, but %d coins are gone."
				% GameState.DEFEAT_CURRENCY_PENALTY
			)
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
	if not lesson.is_empty():
		_open_dialogue(lesson.won_line if lesson_won else lesson.lost_line)
	_refresh_world_activity()
	_evolve_ready_party()


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
	player.movement_enabled = active
	player.strike_enabled = active
	partner.following_enabled = active
	get_tree().call_group(WildCreature.CREATURE_GROUP, &"set_roaming", active)
	get_tree().call_group(WorldActor.WANDERER_GROUP, &"set_roaming", active)
