extends GutTest
## Overworld combat: the blow landed before a battle starts, who it favours,
## and the encounter it produces (Specification 7.3, extended).

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

## A lead strong enough to rout anything the sample map spawns.
const STRONG_LEVEL := 20
## A lead too weak to rout a healthy creature, so the swing opens a battle.
const WEAK_LEVEL := 2


var _saved_party: Array[CreatureInstance] = []
var _saved_currency: int = 0


## GameState is an autoload, so a test that hands it a party has to hand the
## real one back before the next test file runs.
func before_each() -> void:
	_saved_party = GameState.party
	_saved_currency = GameState.currency


func after_each() -> void:
	GameState.party = _saved_party
	GameState.currency = _saved_currency
	await get_tree().process_frame


func _hero(at_level: int = 7) -> CreatureInstance:
	return Content.spawn_creature(&"creature_fire_01", at_level)


func _foe(at_level: int = 3) -> CreatureInstance:
	# Thick Hide rather than Stonewall, so damage stays predictable.
	return Content.spawn_creature(&"creature_earth_01", at_level, 1)


# --- Strike rules -------------------------------------------------------------


func test_a_strike_opens_with_the_move_that_hurts_this_defender_most() -> void:
	var hero: CreatureInstance = _hero()
	var foe: CreatureInstance = _foe()

	var chosen: MoveData = OverworldStrike.best_move_against(hero, foe, Content.type_chart)

	assert_not_null(chosen, "A creature with damaging moves must pick one.")
	for move: MoveData in hero.moves:
		if not move.is_damaging():
			continue
		assert_true(
			(
				BattleRules.damage(
					move,
					Battler.wrap(hero, BattleTeam.Side.PLAYER),
					Battler.wrap(foe, BattleTeam.Side.ENEMY),
					Content.type_chart,
				)
				<= OverworldStrike.player_strike_damage(hero, foe, Content.type_chart)
			),
			"No move may beat the one the strike chose.",
		)


func test_a_strike_lands_what_that_move_would_land_in_battle() -> void:
	var hero: CreatureInstance = _hero()
	var foe: CreatureInstance = _foe()
	var move: MoveData = OverworldStrike.best_move_against(hero, foe, Content.type_chart)

	assert_eq(
		OverworldStrike.player_strike_damage(hero, foe, Content.type_chart),
		BattleRules.damage(
			move,
			Battler.wrap(hero, BattleTeam.Side.PLAYER),
			Battler.wrap(foe, BattleTeam.Side.ENEMY),
			Content.type_chart,
		),
		"An overworld hit and a battle hit must use the same arithmetic.",
	)


func test_an_ambush_hits_softer_than_a_deliberate_swing() -> void:
	var hero: CreatureInstance = _hero()
	var foe: CreatureInstance = _foe()

	assert_lt(
		OverworldStrike.ambush_damage(foe, hero, Content.type_chart),
		OverworldStrike.player_strike_damage(foe, hero, Content.type_chart),
		"A creature's ambush trades damage for the first turn.",
	)


func test_an_ambush_can_never_knock_the_lead_out() -> void:
	var hero: CreatureInstance = _hero()
	hero.set_hp(1)

	assert_eq(
		OverworldStrike.hp_after_ambush(hero, 9999),
		OverworldStrike.AMBUSH_HP_FLOOR,
		"The player cannot answer a blow landed before the battle opens.",
	)


func test_a_strong_enough_lead_routs_a_creature_and_a_weak_one_does_not() -> void:
	var foe: CreatureInstance = _foe()

	assert_true(
		OverworldStrike.routs(_hero(STRONG_LEVEL), foe, Content.type_chart),
		"A lead that outclasses a creature must kill it in the overworld.",
	)
	assert_false(
		OverworldStrike.routs(_hero(WEAK_LEVEL), foe, Content.type_chart),
		"A weak lead must have to fight the battle.",
	)


func test_a_hurt_creature_becomes_routable() -> void:
	var hero: CreatureInstance = _hero(WEAK_LEVEL)
	var foe: CreatureInstance = _foe()
	assert_false(OverworldStrike.routs(hero, foe, Content.type_chart))

	foe.set_hp(1)

	assert_true(
		OverworldStrike.routs(hero, foe, Content.type_chart),
		"Damage carried out of an earlier encounter must count.",
	)


func test_a_downed_creature_cannot_be_routed_again() -> void:
	var foe: CreatureInstance = _foe()
	foe.set_hp(0)

	assert_false(OverworldStrike.routs(_hero(STRONG_LEVEL), foe, Content.type_chart))


# --- The opening the strike hands to the battle --------------------------------


## A deliberately lopsided matchup: a slow, bulky Loambuck against a fast
## Gustpip of the same level. Speed always favours the enemy, so any turn the
## player moves first is a turn the opening handed over, and neither side hits
## hard enough to end the battle before turn two.
func _engine(opening: BattleConfig.Opening) -> BattleEngine:
	var slow_lead: Array[CreatureInstance] = [Content.spawn_creature(&"creature_earth_01", 10, 1)]
	var fast_foe: CreatureInstance = Content.spawn_creature(&"creature_wind_01", 10, 0)
	var config := BattleConfig.wild(slow_lead, fast_foe, Content.type_chart, opening)
	config.rng_seed = 3
	var engine := BattleEngine.new(config)
	engine.start()
	return engine


## The side whose move resolved first in a turn, or -1 if neither moved.
func _first_mover(events: Array[BattleEvent]) -> int:
	for event: BattleEvent in events:
		if event.kind == BattleEvent.Kind.MOVE_USED:
			return event.side
	return -1


func _attack_with_lead(engine: BattleEngine) -> Array[BattleEvent]:
	return engine.take_turn(BattleAction.use_move(engine.player.active().creature.moves[0]))


func test_the_slow_lead_would_otherwise_lose_every_first_turn() -> void:
	var engine: BattleEngine = _engine(BattleConfig.Opening.NEUTRAL)

	assert_lt(
		engine.player.active().effective_speed(),
		engine.enemy.active().effective_speed(),
		"This matchup only proves anything if the player is the slower side.",
	)
	assert_eq(
		_first_mover(_attack_with_lead(engine)),
		BattleTeam.Side.ENEMY,
		"Without an opening, the faster creature moves first.",
	)


func test_an_advantage_gives_the_player_the_first_turn() -> void:
	var engine: BattleEngine = _engine(BattleConfig.Opening.ADVANTAGE)

	assert_eq(
		_first_mover(_attack_with_lead(engine)),
		BattleTeam.Side.PLAYER,
		"A strike landed in the overworld must outrank raw speed on turn one.",
	)


func test_a_disadvantage_gives_the_enemy_the_first_turn() -> void:
	var engine: BattleEngine = _engine(BattleConfig.Opening.DISADVANTAGE)

	assert_eq(
		_first_mover(_attack_with_lead(engine)),
		BattleTeam.Side.ENEMY,
		"The ambusher must move first.",
	)


func test_the_forced_first_turn_only_covers_turn_one() -> void:
	# The player would lose turn two on speed anyway, so the advantage is the
	# only thing that could still be handing them the turn.
	var engine: BattleEngine = _engine(BattleConfig.Opening.ADVANTAGE)
	_attack_with_lead(engine)

	assert_eq(engine.phase, BattleEngine.Phase.CHOOSING, "Turn two must actually happen.")
	assert_eq(
		_first_mover(_attack_with_lead(engine)),
		BattleTeam.Side.ENEMY,
		"From turn two, speed decides again.",
	)


func test_the_battle_says_why_a_side_starts_hurt() -> void:
	var advantage: String = _opening_message(BattleConfig.Opening.ADVANTAGE)
	assert_string_contains(advantage, "struck first")

	var disadvantage: String = _opening_message(BattleConfig.Opening.DISADVANTAGE)
	assert_string_contains(disadvantage, "ambushed you")

	assert_eq(_opening_message(BattleConfig.Opening.NEUTRAL), "", "A plain encounter says nothing.")


func _opening_message(opening: BattleConfig.Opening) -> String:
	var party: Array[CreatureInstance] = [_hero()]
	var config := BattleConfig.wild(party, _foe(), Content.type_chart, opening)
	config.rng_seed = 3
	var engine := BattleEngine.new(config)
	for event: BattleEvent in engine.start():
		if event.kind == BattleEvent.Kind.MESSAGE:
			return event.text
	return ""


# --- Rewards without a battle --------------------------------------------------


func test_a_rout_pays_the_same_currency_and_xp_a_battle_would() -> void:
	var hero: CreatureInstance = _hero()
	var foe: CreatureInstance = _foe()
	GameState.party = [hero]
	GameState.currency = 0
	var xp_before: int = hero.total_xp

	var lines: PackedStringArray = GameState.award_defeat_rewards(foe)

	assert_eq(GameState.currency, BattleRules.currency_for_defeating(foe))
	assert_eq(hero.total_xp - xp_before, BattleRules.xp_for_defeating(foe))
	assert_gt(lines.size(), 0, "A rout must report what it earned.")
	assert_string_contains(lines[0], "gained")


func test_a_rout_skips_fainted_party_members() -> void:
	var lead: CreatureInstance = _hero()
	var fainted: CreatureInstance = _hero()
	fainted.set_hp(0)
	GameState.party = [lead, fainted]
	var fainted_xp_before: int = fainted.total_xp

	GameState.award_defeat_rewards(_foe())

	assert_eq(fainted.total_xp, fainted_xp_before, "A fainted Oathbound earns nothing.")


func test_the_lead_is_the_first_party_member_still_able_to_fight() -> void:
	var fainted: CreatureInstance = _hero()
	fainted.set_hp(0)
	var healthy: CreatureInstance = _hero()
	GameState.party = [fainted, healthy]

	assert_eq(GameState.lead_creature(), healthy)

	healthy.set_hp(0)
	assert_null(GameState.lead_creature(), "A wiped party has no lead.")


# --- The partner on the map ---------------------------------------------------


## The partner reads the party at _ready, so the party has to be in place
## before the scene is instantiated.
func _main_with_party(party: Array[CreatureInstance]) -> Node2D:
	GameState.party = party
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	return main_scene


func _walk(player: Player, direction: Vector2, steps: int) -> void:
	for _step: int in steps:
		player.move_with(direction)
		await get_tree().physics_frame


func test_the_lead_oathbound_walks_the_overworld_with_the_player() -> void:
	var lead: CreatureInstance = _hero()
	var main_scene: Node2D = _main_with_party([lead])

	assert_true(main_scene.partner.visible, "The lead is on the map before anything happens.")
	assert_eq(main_scene.partner.creature(), lead)
	assert_eq(
		main_scene.partner.visual.species,
		lead.species,
		"The creature shown must be the one whose move does the damage.",
	)


func test_the_partner_starts_at_the_player_rather_than_walking_in() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")

	assert_almost_eq(
		main_scene.partner.global_position.distance_to(player.global_position),
		0.0,
		1.0,
		"The partner is already at the player's side on the first frame.",
	)


func test_the_partner_follows_the_player_and_stays_behind() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")
	await get_tree().physics_frame
	player.global_position = Vector2(-336, 0)
	main_scene.partner.snap_to_player()

	await _walk(player, Vector2.RIGHT, 40)

	var gap: float = player.global_position.distance_to(main_scene.partner.global_position)
	assert_gt(gap, 0.0, "The partner trails the player rather than standing on them.")
	assert_lt(gap, float(WorldArea.GRID_SIZE) * 3.0, "It must not be left behind.")
	assert_lt(
		main_scene.partner.global_position.x,
		player.global_position.x,
		"Walking right leaves the partner on the left.",
	)


func test_a_partner_left_far_behind_reappears_at_the_player() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")
	await get_tree().physics_frame

	player.global_position = Vector2(400, 200)
	await _walk(player, Vector2.RIGHT, 2)

	assert_lt(
		main_scene.partner.global_position.distance_to(player.global_position),
		OverworldPartner.SNAP_DISTANCE,
		"A teleport must not strand the partner across the map.",
	)


func test_a_party_that_cannot_fight_has_nobody_walking_with_it() -> void:
	var fainted: CreatureInstance = _hero()
	fainted.set_hp(0)
	var main_scene: Node2D = _main_with_party([fainted])

	assert_false(main_scene.partner.visible, "A wiped party leaves nobody on the map.")
	assert_null(main_scene.partner.creature())


func test_the_partner_changes_when_the_lead_does() -> void:
	var first: CreatureInstance = _hero()
	var main_scene: Node2D = _main_with_party([first])
	var replacement: CreatureInstance = Content.spawn_creature(&"creature_water_01", 5)

	first.set_hp(0)
	GameState.party = [first, replacement]
	main_scene.partner.refresh_lead()

	assert_eq(main_scene.partner.creature(), replacement, "The next able creature steps up.")
	assert_eq(main_scene.partner.visual.species, replacement.species)


func test_a_frozen_world_stops_the_partner_with_the_player() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")
	await get_tree().physics_frame
	main_scene._open_dialogue("Hello")

	var parked: Vector2 = main_scene.partner.global_position
	player.global_position += Vector2(120, 0)
	await _walk(player, Vector2.ZERO, 6)

	assert_eq(main_scene.partner.global_position, parked, "A frozen partner does not walk.")


# --- The strike ----------------------------------------------------------------


func test_striking_sends_the_partner_at_the_target() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")
	await get_tree().physics_frame
	player.facing_direction = Vector2i.RIGHT
	var start_x: float = main_scene.partner.global_position.x

	main_scene._strike()
	assert_true(main_scene.partner.is_striking(), "The strike belongs to the partner.")

	for _frame: int in 12:
		await get_tree().physics_frame
	assert_gt(
		main_scene.partner.global_position.x,
		start_x,
		"The partner dashes the way the strike goes.",
	)


func test_the_partner_faces_the_way_it_strikes() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	var player: Player = main_scene.get_node("Player")
	await get_tree().physics_frame

	player.facing_direction = Vector2i.LEFT
	main_scene._strike()

	assert_true(main_scene.partner.visual.flip_h, "A partner striking left is mirrored.")


func test_the_partner_goes_back_to_following_after_a_strike() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	await get_tree().physics_frame

	main_scene._strike()
	for _frame: int in 40:
		await get_tree().physics_frame
		if not main_scene.partner.is_striking():
			break

	assert_false(main_scene.partner.is_striking(), "A strike must end and hand control back.")


func test_a_strike_thrown_at_a_creature_that_is_already_gone_does_nothing() -> void:
	var main_scene: Node2D = _main_with_party([_hero()])
	# Spawn zones only fill a couple of physics steps in, so this test brings
	# its own creature rather than waiting for the map to populate.
	var creature: WildCreature = autofree(preload("res://scenes/wild_creature.tscn").instantiate())
	creature.species = Content.get_species(&"creature_earth_01")
	main_scene.add_child(creature)

	assert_true(main_scene._strike_can_still_land(creature), "A live creature can be hit.")

	creature.mark_defeated()

	assert_false(
		main_scene._strike_can_still_land(creature),
		"A creature that went down during the dash must not be hit again.",
	)


# --- Reach --------------------------------------------------------------------


func test_a_strike_covers_the_wedge_the_player_faces() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")
	player.global_position = Vector2.ZERO
	player.facing_direction = Vector2i.RIGHT
	var reach: float = player.strike_reach()

	assert_true(player.strike_covers(Vector2(reach * 0.9, 0.0)), "Straight ahead is covered.")
	assert_true(
		player.strike_covers(Vector2(reach * 0.6, reach * 0.6)),
		"A creature well off to one side is still inside the wedge.",
	)
	assert_false(player.strike_covers(Vector2(-reach * 0.9, 0.0)), "Behind is never covered.")
	assert_false(player.strike_covers(Vector2(reach * 1.5, 0.0)), "Beyond the reach is a whiff.")


func test_a_creature_on_top_of_the_player_is_hit_whatever_way_they_face() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")
	player.global_position = Vector2.ZERO
	player.facing_direction = Vector2i.RIGHT
	var touching: float = player.point_blank_reach() * 0.9

	assert_true(
		player.strike_covers(Vector2(-touching, 0.0)),
		"Facing only updates while walking, so point blank cannot depend on it.",
	)
	assert_true(player.strike_covers(Vector2(0.0, touching)), "Nor on which side it stands.")


func test_the_strike_outranges_both_talking_and_being_hit() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")

	assert_gt(
		player.strike_reach(),
		float(player.grid_size) * main_scene.INTERACTION_REACH_IN_CELLS,
		"A creature must be hittable from further out than it can be talked to.",
	)
	assert_gt(
		player.strike_reach(),
		WildCreature.REACH_IN_CELLS * WorldArea.GRID_SIZE,
		"A creature must never be able to hit the player from outside their reach.",
	)


func test_a_strike_reaches_past_where_two_bodies_touch() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")
	# Both bodies are 40 px wide, so their centres are this far apart when the
	# two are touching. Landing a hit must not mean standing exactly there.
	var touching_distance: float = 40.0

	assert_gt(
		player.strike_reach(),
		touching_distance * 2.0,
		"Aiming must have room for error rather than needing pixel accuracy.",
	)


func test_a_strike_cools_down_before_the_next_one() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")

	assert_true(player.strike(), "The first swing goes out.")
	assert_false(player.strike(), "A second swing must wait for the cooldown.")


func test_a_frozen_world_stops_the_strike_with_the_movement() -> void:
	var main_scene: Node2D = autofree(MAIN_SCENE.instantiate())
	add_child(main_scene)
	var player: Player = main_scene.get_node("Player")

	main_scene._open_dialogue("Hello")

	assert_false(player.movement_enabled)
	assert_false(player.can_strike(), "Dialogue must hold the swing as well as the feet.")
