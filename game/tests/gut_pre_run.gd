extends GutHookScript
## Runs once before the suite. Tests that load the main scene autosave, so the
## slots are pointed at a scratch directory rather than the player's own.

const TEST_SAVE_DIR := "user://gut_scratch/saves"


func run() -> void:
	SaveService.save_dir = TEST_SAVE_DIR
	SaveService.erase_all()
