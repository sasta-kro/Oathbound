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
## under `res://areas/`; actors and spawn zones announce themselves through
## groups and signals.

const INTERACTION_REACH_IN_CELLS: float = 1.5
## Shown after an overworld rout, ahead of the reward lines.
const ROUT_TEXT := "You cut down the wild %s before it could fight back."

@onready var area: WorldArea = $Area
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var dialogue_panel: DialoguePanel = $DialoguePanel
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var battle_scene: BattleScene = $BattleScene
@onready var transition: ScreenTransition = $ScreenTransition
@onready var partner: OverworldPartner = $OverworldPartner

var field_ui: FieldUI

var _battling_creature: WildCreature


func _ready() -> void:
	$HUD/Hint.hide()
	field_ui = FieldUI.new()
	add_child(field_ui)
	field_ui.changed.connect(_refresh_world_activity)
	player.global_position = area.player_start_position()
	partner.snap_to_player()
	_fit_camera_to_area()
	settings_menu.opened.connect(_on_settings_opened)
	settings_menu.closed.connect(_on_settings_closed)
	battle_scene.battle_finished.connect(_on_battle_finished)
	# The battle screen owns the moment it closes, so it plays the cover half
	# of the transition itself and hides underneath it.
	battle_scene.transition = transition
	for zone: SpawnZone in get_tree().get_nodes_in_group(SpawnZone.GROUP):
		zone.creature_reached_player.connect(_on_creature_reached_player)
	# Creatures placed by hand in the area rather than by a zone.
	for creature: WildCreature in get_tree().get_nodes_in_group(WildCreature.CREATURE_GROUP):
		if not creature.reached_player.is_connected(_on_creature_reached_player):
			creature.reached_player.connect(_on_creature_reached_player)


func _unhandled_input(event: InputEvent) -> void:
	if transition.is_busy():
		get_viewport().set_input_as_handled()
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
## else acts on the nearest actor within reach.
func _interact() -> void:
	if dialogue_panel.is_open():
		_close_dialogue()
		return

	var actor: WorldActor = nearest_actor_in_reach()
	if actor == null:
		return
	if actor is WildCreature:
		_start_wild_battle(actor as WildCreature)
		return
	if actor.heals_party:
		GameState.heal_party()
	_open_dialogue(actor.dialogue_line)


## The overworld strike (Specification 7.3, extended).
##
## The player sets the direction and the timing; the Oathbound at the front of
## the party throws the actual blow, with its own best move against whatever
## is in front of it. The lunge always plays, whether or not anything is hit,
## so the player can feel the reach. What it connects with decides the rest: a
## creature that survives becomes a battle the player opens ahead on, and one
## that does not never sees a battle screen.
func _strike() -> void:
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
	for line in reward_lines:
		if not "XP" in line and not "level" in line:
			field_ui.show_notice(line)
	_refresh_world_activity()


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


func _start_wild_battle(
	creature: WildCreature, opening: BattleConfig.Opening = BattleConfig.Opening.NEUTRAL
) -> void:
	if dialogue_panel.is_open():
		dialogue_panel.close()
	_battling_creature = creature
	if not GameState.has_usable_party_member():
		GameState.heal_party()

	var enemy: CreatureInstance = creature.encounter_instance()
	GameState.seen_species[enemy.species_id()] = true
	if opening == BattleConfig.Opening.DISADVANTAGE:
		_apply_ambush(enemy)

	var config := BattleConfig.wild(GameState.party, enemy, Content.type_chart, opening)
	config.binding_scrolls = GameState.binding_scrolls
	config.has_bind_destination = not GameState.party_is_full()
	config.level_cap = GameState.level_cap

	# The world stops the moment the encounter is decided, so the player is not
	# still walking behind the wipe.
	_set_world_active(false)
	await transition.cover(ScreenTransition.Style.BATTLE)
	# `start_battle` shows the screen before it awaits its opening messages, so
	# the reveal uncovers a battle that is already on screen.
	battle_scene.start_battle(config)
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
	GameState.currency += engine.currency_earned
	if engine.currency_earned > 0:
		field_ui.show_notice("+%d coins" % engine.currency_earned)
	var creature: WildCreature = _battling_creature
	_battling_creature = null
	# A creature the battle took leaves the map as light rather than simply
	# blinking out, but not yet: the wipe is still over the screen, and an
	# effect played under it would come and go unseen.
	var taken: WildCreature = null
	var was_bound: bool = false
	match engine.outcome:
		BattleEngine.Outcome.VICTORY:
			taken = creature
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
		BattleEngine.Outcome.DEFEAT:
			# No revival location exists yet, so recovery happens in place
			# (Specification 20.1 steps 2, 4 and 5).
			GameState.apply_defeat_penalty()
			GameState.heal_party()
			_open_dialogue(
				"You wake by the road. Your Oathbound have been revived, but %d coins are gone."
				% GameState.DEFEAT_CURRENCY_PENALTY
			)
	# A battle can faint the creature that was walking with the player, and
	# leaves the partner wherever it stood when the screen closed.
	partner.refresh_lead()
	partner.snap_to_player()
	# The battle screen covered the screen before it closed, so the world is
	# already swapped in underneath and only needs uncovering.
	await transition.reveal(ScreenTransition.Style.WORLD)
	# Not awaited: the world is the player's again while the light fades.
	if taken != null:
		taken.play_rout(not was_bound)
	_refresh_world_activity()


func _open_dialogue(line: String) -> void:
	dialogue_panel.show_line(line)
	_refresh_world_activity()


func _close_dialogue() -> void:
	dialogue_panel.close()
	_refresh_world_activity()


func _world_is_paused() -> bool:
	return (
		settings_menu.is_open()
		or (field_ui != null and field_ui.is_open())
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
