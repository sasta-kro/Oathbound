extends GutTest
## The wipe played between the overworld and the battle screen.

const SCENE: PackedScene = preload("res://scenes/screen_transition.tscn")

var _transition: ScreenTransition


func before_each() -> void:
	_transition = SCENE.instantiate()
	_transition.instant = true
	add_child_autofree(_transition)


func test_starts_clear_and_out_of_the_way() -> void:
	assert_false(_transition.root.visible)
	assert_false(_transition.is_busy())


func test_covering_fills_the_screen_and_holds_it() -> void:
	watch_signals(_transition)

	await _transition.cover(ScreenTransition.Style.BATTLE)

	assert_signal_emitted(_transition, "covered")
	assert_true(_transition.root.visible, "The cover holds until something reveals it again.")
	assert_true(_transition.is_busy(), "A covered screen still owns the world.")


func test_revealing_clears_the_screen() -> void:
	await _transition.cover()
	watch_signals(_transition)

	await _transition.reveal()

	assert_signal_emitted(_transition, "revealed")
	assert_false(_transition.root.visible)
	assert_false(_transition.is_busy())
