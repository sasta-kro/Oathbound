extends GutTest
## The replace-or-refuse choice a fifth move asks for (Specification 9.8):
## the queue a battle leaves behind, the screen that puts the choice, and the
## field draining both once the world is calm.

const SPECIES := &"creature_emberling"

var main: Node
var _original_party: Array[CreatureInstance] = []


func before_each() -> void:
	_original_party = GameState.party.duplicate()
	GameState.pending_move_learns.clear()
	main = autofree(load("res://main.tscn").instantiate())
	add_child(main)


func after_each() -> void:
	GameState.party = _original_party
	GameState.pending_move_learns.clear()
	await get_tree().process_frame


## A companion with every move slot full, and a move it does not know.
func _full_creature() -> CreatureInstance:
	var creature: CreatureInstance = Content.spawn_creature(SPECIES, 5)
	var slots: Array[MoveData] = []
	for move: MoveData in Content.all_moves():
		if slots.size() >= CreatureRules.MAX_MOVE_SLOTS:
			break
		slots.append(move)
	creature.moves = slots
	return creature


func _unknown_move(creature: CreatureInstance) -> MoveData:
	for move: MoveData in Content.all_moves():
		if not creature.knows_move(move):
			return move
	return null


func test_a_move_with_nowhere_to_go_waits_for_the_field() -> void:
	var creature := _full_creature()
	GameState.party = [creature]
	var move := _unknown_move(creature)

	GameState.queue_move_learn(creature, move)

	assert_eq(GameState.pending_move_learns.size(), 1)
	assert_eq(GameState.pending_move_learns[0]["move"], move)


func test_the_same_offer_is_never_queued_twice() -> void:
	var creature := _full_creature()
	GameState.party = [creature]
	var move := _unknown_move(creature)

	GameState.queue_move_learn(creature, move)
	GameState.queue_move_learn(creature, move)

	assert_eq(GameState.pending_move_learns.size(), 1)


func test_a_borrowed_lesson_creature_is_never_offered_a_choice() -> void:
	var creature := _full_creature()
	GameState.party = []

	GameState.queue_move_learn(creature, _unknown_move(creature))

	assert_true(
		GameState.pending_move_learns.is_empty(),
		"Only the player's own companions are reshaped.",
	)


func test_an_offer_that_found_room_is_taken_without_asking() -> void:
	var creature := _full_creature()
	GameState.party = [creature]
	var move := _unknown_move(creature)
	GameState.queue_move_learn(creature, move)

	creature.forget_move(creature.moves[0])
	var offer: Dictionary = GameState.take_pending_move_learn()

	assert_true(offer.is_empty(), "A move that now fits needs no screen.")
	assert_true(creature.knows_move(move))


func test_an_offer_for_a_departed_companion_is_dropped() -> void:
	var creature := _full_creature()
	GameState.party = [creature]
	GameState.queue_move_learn(creature, _unknown_move(creature))

	GameState.party = []

	assert_true(GameState.take_pending_move_learn().is_empty())


func test_the_screen_replaces_the_chosen_move() -> void:
	var creature := _full_creature()
	var forgotten: MoveData = creature.moves[1]
	var move := _unknown_move(creature)
	var screen: MoveLearnScreen = main.move_learn_screen

	screen.play(creature, move)
	assert_true(screen.is_playing())
	assert_true(screen.visible)
	screen.choose(1)

	assert_true(creature.knows_move(move))
	assert_false(creature.knows_move(forgotten))
	assert_eq(creature.moves.size(), CreatureRules.MAX_MOVE_SLOTS)
	screen.dismiss()
	await wait_for_signal(screen.finished, 2.0)
	assert_false(screen.is_playing())


func test_refusing_keeps_the_current_moves() -> void:
	var creature := _full_creature()
	var before: Array[MoveData] = creature.moves.duplicate()
	var move := _unknown_move(creature)
	var screen: MoveLearnScreen = main.move_learn_screen

	screen.play(creature, move)
	screen.refuse()

	assert_eq(creature.moves, before)
	assert_false(creature.knows_move(move))
	screen.dismiss()
	await wait_for_signal(screen.finished, 2.0)


func test_the_screen_refuses_a_move_that_would_simply_fit() -> void:
	var creature: CreatureInstance = Content.spawn_creature(SPECIES, 5)
	var one: Array[MoveData] = [creature.moves[0]]
	creature.moves = one
	var played: bool = await main.move_learn_screen.play(creature, _unknown_move(creature))

	assert_false(played)
	assert_false(main.move_learn_screen.visible)


func test_the_field_puts_every_waiting_offer_before_evolving() -> void:
	await get_tree().process_frame
	var creature := _full_creature()
	GameState.party = [creature]
	var move := _unknown_move(creature)
	GameState.queue_move_learn(creature, move)

	main._settle_growth()
	await get_tree().process_frame

	assert_true(main.move_learn_screen.is_playing(), "The offer is put to the player.")
	assert_false(main.player.movement_enabled, "The world waits on the answer.")
	main.move_learn_screen.choose(0)
	main.move_learn_screen.dismiss()
	await wait_for_signal(main.move_learn_screen.finished, 2.0)
	await get_tree().process_frame

	assert_true(creature.knows_move(move))
	assert_true(GameState.pending_move_learns.is_empty())
	assert_false(main.is_settling_growth())


func test_a_battle_level_up_leaves_the_offer_behind_rather_than_skipping_it() -> void:
	var creature := _full_creature()
	creature.level = 1
	GameState.party = [creature]
	var move := _unknown_move(creature)
	# The species learns it at the level the XP below reaches.
	creature.species = creature.species.duplicate()
	var entry := LearnsetEntry.new()
	entry.level = 2
	entry.move = move
	var learnset: Array[LearnsetEntry] = [entry]
	creature.species.learnset = learnset

	var result: XpResult = creature.gain_xp(500, GameState.level_cap)
	for pending: MoveData in creature.resolve_new_moves(result):
		GameState.queue_move_learn(creature, pending)

	assert_gt(creature.level, 1, "Precondition: the XP is enough to level.")
	assert_eq(GameState.pending_move_learns.size(), 1)
	assert_eq(GameState.pending_move_learns[0]["move"], move)
