extends GutTest
## The dialogue box (Specification 18.2). Content writes a spoken line as
## "Elder: Good morning."; the panel shows the name in the caption and the
## words on their own, so the speaker is never read twice and the caption is
## never a place name that has nothing to do with who is talking.

const PANEL_SCENE := "res://scenes/dialogue_panel.tscn"


func _panel() -> DialoguePanel:
	var panel: DialoguePanel = autofree((load(PANEL_SCENE) as PackedScene).instantiate())
	add_child(panel)
	return panel


func test_a_named_line_splits_into_speaker_and_words() -> void:
	assert_eq(
		DialoguePanel.split_speaker("Elder: Good morning."),
		PackedStringArray(["Elder", "Good morning."]),
	)
	assert_eq(
		DialoguePanel.split_speaker("The Oathbreaker: So. She has the water."),
		PackedStringArray(["The Oathbreaker", "So. She has the water."]),
	)


func test_narration_keeps_every_word_and_names_nobody() -> void:
	for line: String in [
		"The lid gives, and you empty the chest.",
		"You sleep soundly. Your companions wake fully rested.",
		"The wild Emberling scorches Emberling before you can react!",
	]:
		assert_eq(DialoguePanel.split_speaker(line), PackedStringArray(["", line]), line)


## A colon inside a sentence is not a speaker, however tempting it looks.
func test_a_colon_in_the_middle_of_a_sentence_is_not_a_name() -> void:
	for line: String in [
		"Scout: one thing, though: the road is long.".substr(7),
		"You wake by the road, and the count is plain: twenty coins gone.",
		"Hm. Listen: a healer can mend a partner on the bench.",
	]:
		assert_eq(DialoguePanel.split_speaker(line)[0], "", line)


func test_the_panel_shows_the_name_over_the_line() -> void:
	var panel: DialoguePanel = _panel()

	panel.show_line("Scout: Swap, mend, swap back.")

	assert_eq(panel.speaker_label.text, "SCOUT", "The caption names who is talking.")
	assert_true(panel.speaker_label.visible)
	assert_eq(panel.dialogue_text.text, "Swap, mend, swap back.", "The name is not read twice.")


func test_the_panel_names_nobody_for_narration() -> void:
	var panel: DialoguePanel = _panel()

	panel.show_line("The chest holds nothing but dust.")

	assert_false(panel.speaker_label.visible, "Narration has no speaker to name.")
	assert_eq(panel.dialogue_text.text, "The chest holds nothing but dust.")


func test_a_question_names_its_speaker_too() -> void:
	var panel: DialoguePanel = _panel()

	panel.ask("Elder: Will you go?", PackedStringArray(["I will.", "Not yet."]))

	assert_eq(panel.speaker_label.text, "ELDER")
	assert_eq(panel.dialogue_text.text, "Will you go?")
	panel.close()


## Every quest in the game is spoken by somebody, so every offer line should
## come with a name the panel can put in the caption.
func test_every_quest_offer_names_its_speaker() -> void:
	for quest: QuestData in Content.all_quests():
		if quest.offer_line.is_empty():
			continue
		assert_ne(
			DialoguePanel.split_speaker(quest.offer_line)[0],
			"",
			"%s is spoken by someone." % quest.id,
		)
