extends GutTest
## Automatic evolution (Specification 9.7): the evolution screen, the field
## evolving every ready companion on its own, and the Evolutions page.

const FIRST_FORM := &"creature_fire_01"
const SECOND_FORM := &"creature_fire_02"

var main: Node
var _original_party: Array[CreatureInstance] = []


func before_each() -> void:
	_original_party = GameState.party.duplicate()
	main = autofree(load("res://main.tscn").instantiate())
	add_child(main)


func after_each() -> void:
	GameState.party = _original_party
	await get_tree().process_frame


func _ready_creature() -> CreatureInstance:
	var species: CreatureSpecies = Content.get_species(FIRST_FORM)
	return CreatureInstance.create(species, species.evolution_level)


func test_screen_evolves_the_creature_and_reports_finished() -> void:
	var screen: EvolutionScreen = main.evolution_screen
	var creature := _ready_creature()
	screen.play(creature)
	assert_true(screen.is_playing())
	assert_true(screen.visible)
	screen.skip()
	assert_eq(creature.species_id(), SECOND_FORM)
	screen.dismiss()
	await wait_for_signal(screen.finished, 2.0)
	assert_false(screen.is_playing())
	assert_false(screen.visible)


func test_screen_refuses_a_creature_that_cannot_evolve() -> void:
	var species: CreatureSpecies = Content.get_species(FIRST_FORM)
	var creature := CreatureInstance.create(species, species.evolution_level - 1)
	var played: bool = await main.evolution_screen.play(creature)
	assert_false(played)
	assert_false(main.evolution_screen.visible)
	assert_eq(creature.species_id(), FIRST_FORM)


func test_field_evolves_ready_companions_automatically_and_pauses_the_world() -> void:
	await get_tree().process_frame
	var creature := _ready_creature()
	GameState.party = [creature]
	main._settle_growth()
	await get_tree().process_frame
	assert_true(main.is_evolving())
	assert_false(main.player.movement_enabled)
	main.evolution_screen.skip()
	main.evolution_screen.dismiss()
	await wait_for_signal(main.evolution_screen.finished, 2.0)
	await get_tree().process_frame
	assert_eq(creature.species_id(), SECOND_FORM)
	assert_true(GameState.seen_species.has(SECOND_FORM))
	assert_false(main.is_evolving())


func test_companion_record_shows_evolution_instead_of_a_manual_button() -> void:
	var creature := _ready_creature()
	GameState.party = [creature]
	main.field_ui._details(creature)
	var buttons: Array = main.field_ui.body.find_children("*", "Button", true, false).map(func(b: Button): return b.text)
	for text: String in buttons:
		assert_false(text.begins_with("Evolve"), "no manual evolve button")
	var labels: Array = main.field_ui.body.find_children("*", "Label", true, false).map(func(l: Label): return l.text)
	assert_has(labels, "EVOLUTION")
