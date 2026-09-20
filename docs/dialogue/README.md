# Dialogue export

Every line of player-facing prose in the game, pulled out into Markdown so it
can be edited as writing rather than as data, and put back afterwards.

## The loop

```bash
python3 tools/dialogue.py export   # game  -> these files
# ... edit the .md files ...
python3 tools/dialogue.py import   # these files -> game
python3 tools/dialogue.py check    # round-trip without writing to the game
```

`export` overwrites these files from the game, so run it only when the game is
the newer of the two. `import` writes only the passages that actually changed,
and a value that comes back unedited is written as the same bytes it was read
as, so importing an untouched export changes nothing at all.

## What is in here

| File | Holds |
| --- | --- |
| `quests_town_and_area_one.md` | Main quests 01–03, the whole first hour |
| `quests_area_two.md` | Main quests 04–09, the catacombs |
| `quests_area_three.md` | Main quests 10 and 13, the wood and the king |
| `quests_side.md` | The six side quests |
| `npcs_town.md` | Town NPCs, chests and doorways |
| `npcs_area_one.md` | Area One NPCs, the Guardian, chests, doorways |
| `npcs_area_two.md` | Area Two NPCs, the Kingsworn, chests, doorways |
| `npcs_area_three.md` | The Last Champion, the king, chests, doorways |
| `sequences.md` | The opening, the five field lessons, the ending |

## Editing rules

- Change only the text underneath a `###` heading.
- Leave `##` headings, `<!-- key: ... -->` comments and `###` field names
  alone. They are how a passage finds its way back to the right file.
- Keep every `%s` and `%d`. The game substitutes a creature name or a level
  into them, and a line that loses one will break at runtime.
- Do not type the speaker's name into the words. It lives in the
  `<!-- speaker: Elder -->` note above each passage, and the game puts it in
  the gold caption over the box. Typing `Elder: ` in front of the words still
  works (it is read as the speaker and moved to the note), but it is not
  needed, and deleting the note is what removes a caption.
- `*(empty)*` means the field is deliberately blank. Replace it with real text
  to fill the field in, or leave it to keep the field empty.
- **A blank line starts a new dialogue box.** The player reads the first box,
  presses E, and the next one replaces it, with the speaker's caption staying
  put across all of them. This is how a long speech is paced; split anything
  that would otherwise fill half the screen. Around 120 characters a box
  reads well.
- A question's replies appear on its **last** box, so everything before the
  ask is read first.
- Leading and trailing blank lines are dropped, as are trailing spaces.

## Field names

Quest fields follow the step the giver is at: `offer_line` is the ask,
`accepted_line` / `refused_line` answer the two options, `reoffer_line` is the
ask again after a refusal, `progress_line` is every visit while the quest is
live, `complete_line` is the turn-in, and `done_line` is every visit after
that. `caution_line` is said on accepting while under-levelled and is the one
line that must keep its `%d`.

Scene fields: `dialogue_line` is what an NPC says first, `chatter[n]` is taken
in turn on later visits, `barks[n]` are the remarks shown over their head
without being talked to. `challenge_line` / `sealed_line` / `victory_line`
belong to bosses, `opened_line` / `empty_line` / `locked_line` to chests, and
`locked_line` / `unreported_line` to doorways.

Sequence fields are the const names in the script, and the `[n]` suffix is the
page order they play in.

## Splitting long passages

`tools/dialogue_split.py` breaks any passage over 200 characters into boxes of
about 120, cutting only at sentence ends and never moving a word. Run it
without arguments to preview and with `--apply` to write:

```bash
python3 tools/dialogue_split.py            # preview
python3 tools/dialogue_split.py --apply    # write into the .md files
```

It leaves anything already split alone, so hand-paced passages keep their
pacing.

## After importing

Run the tests. A broken format string or a missing speaker prefix shows up
there rather than in the file.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -d --path game -s addons/gut/gut_cmdln.gd
```
