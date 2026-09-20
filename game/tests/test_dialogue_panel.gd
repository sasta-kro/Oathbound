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


# --- Passages in several boxes ------------------------------------------------


func test_a_blank_line_starts_a_new_box() -> void:
	assert_eq(
		DialoguePanel.pages_of("First box.\n\nSecond box."),
		PackedStringArray(["First box.", "Second box."]),
	)


func test_a_passage_without_blank_lines_is_one_box() -> void:
	assert_eq(DialoguePanel.pages_of("All of it at once."), PackedStringArray(["All of it at once."]))


## Run-on blank lines and trailing whitespace are the shape of hand-edited
## Markdown, and must not turn into empty boxes the player has to click past.
func test_extra_blank_lines_do_not_make_empty_boxes() -> void:
	assert_eq(
		DialoguePanel.pages_of("\n\nFirst.\n\n\n\nSecond.\n\n"),
		PackedStringArray(["First.", "Second."]),
	)


func test_the_interact_key_walks_the_boxes_in_order() -> void:
	var panel: DialoguePanel = _panel()

	panel.show_line("Warden: The knight has stood aside.\n\nFind them. Do as they say.")

	assert_eq(panel.page_count(), 2, "Two boxes.")
	assert_eq(panel.dialogue_text.text, "The knight has stood aside.")
	assert_true(panel.has_more_pages(), "There is another box to come.")

	assert_true(panel.advance(), "The key is spent walking to the next box.")
	assert_eq(panel.dialogue_text.text, "Find them. Do as they say.")
	assert_false(panel.has_more_pages(), "That was the last of it.")
	assert_false(panel.advance(), "Past the last box the key closes the line instead.")
	panel.close()


## The name is taken off the front of the passage once, so it stands over
## every box rather than only the first.
func test_the_speaker_stands_over_every_box() -> void:
	var panel: DialoguePanel = _panel()

	panel.show_line("Warden: The knight has stood aside.\n\nFind them.")

	assert_eq(panel.speaker_label.text, "WARDEN")
	assert_eq(panel.dialogue_text.text, "The knight has stood aside.")
	panel.advance()
	assert_eq(panel.speaker_label.text, "WARDEN", "Still the Warden on the second box.")
	assert_true(panel.speaker_label.visible)
	assert_eq(panel.dialogue_text.text, "Find them.", "And the name is not read again.")
	panel.close()


## The replies belong on the box that actually asks, so the player reads the
## whole ask before being given the choice.
func test_the_replies_wait_for_the_last_box() -> void:
	var panel: DialoguePanel = _panel()

	panel.ask(
		"Warden: He is your last gate.\n\nWill you face him?",
		PackedStringArray(["I will.", "Not yet."]),
	)

	assert_false(panel.is_asking(), "The first box is still being read.")
	assert_eq(panel.dialogue_text.text, "He is your last gate.")

	assert_true(panel.advance(), "The key walks to the box that asks.")
	assert_true(panel.is_asking(), "Now the replies are up.")
	assert_eq(panel.dialogue_text.text, "Will you face him?")
	assert_false(panel.advance(), "A box waiting on a reply does not walk on.")
	panel.close()


## A question is still a question while its earlier boxes are being read, so
## anything that would close a plain line has to leave it alone.
func test_a_question_is_protected_before_its_replies_appear() -> void:
	var panel: DialoguePanel = _panel()

	panel.ask(
		"Elder: The bells rang.\n\nWill you go?",
		PackedStringArray(["I will.", "Not yet."]),
	)

	assert_false(panel.is_asking(), "The replies are a box away.")
	assert_true(panel.has_question(), "But there is still a question waiting.")
	panel.read_through()
	assert_true(panel.is_asking())
	assert_true(panel.has_question())
	panel.close()


func test_a_plain_line_is_not_a_question() -> void:
	var panel: DialoguePanel = _panel()
	panel.show_line("Elder: Good morning.\n\nMind the road.")
	assert_false(panel.has_question())
	panel.close()
