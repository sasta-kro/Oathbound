#!/usr/bin/env python3
"""Move every line of player-facing prose between the game and Markdown.

    python3 tools/dialogue.py export     # game  -> docs/dialogue/*.md
    python3 tools/dialogue.py import     # docs/dialogue/*.md -> game
    python3 tools/dialogue.py import DIR # a folder of edited copies -> game
    python3 tools/dialogue.py check      # round-trip without writing anything

The prose lives in three kinds of file, and this reaches all three:

  * quest resources  (game/content/quests/*.tres)
  * area scenes      (game/areas/*.tscn: NPCs, bosses, chests, doorways)
  * sequence scripts (game/scripts/world/*.gd: the opening, the lessons, the
    ending, which are const strings rather than data)

Only the prose is touched. Ids, levels, rewards, objectives, positions and
every other field are left exactly as they are, and a value that comes back
unedited is written out as the same bytes it was read as, so an export
followed by an import is a no-op.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DOCS = ROOT / "docs" / "dialogue"

# --- What counts as prose ----------------------------------------------------

QUEST_FIELDS = [
    "title",
    "summary",
    "offer_line",
    "accept_option",
    "refuse_option",
    "accepted_line",
    "refused_line",
    "reoffer_line",
    "progress_line",
    "continue_option",
    "abandon_option",
    "abandoned_line",
    "complete_line",
    "done_line",
    "caution_line",
]

# Scene node properties, by the thing that owns them. A node exports whichever
# of these it actually has, so one table covers actors, bosses, chests and exits.
SCENE_FIELDS = [
    "display_name",
    "dialogue_line",
    "chatter",
    "barks",
    "shop_title",
    "challenge_line",
    "sealed_line",
    "victory_line",
    "opened_line",
    "empty_line",
    "locked_line",
    "unreported_line",
    "signpost_text",
]
# Properties stored as PackedStringArray("a", "b") rather than a single string.
SCENE_ARRAY_FIELDS = {"chatter", "barks"}

SCENE_FILES = ["town.tscn", "area_one.tscn", "area_two.tscn", "area_three.tscn"]

SEQUENCE_FILES = [
    "scripts/world/game_opening.gd",
    "scripts/world/field_binding.gd",
    "scripts/world/field_mending.gd",
    "scripts/world/field_strike.gd",
    "scripts/world/field_ambush.gd",
    "scripts/world/field_rout.gd",
    "scripts/world/epilogue.gd",
]
# const names in those files that hold ids or node names rather than prose.
SEQUENCE_SKIP = {"TINT_NODE"}

AREA_TITLES = {
    "town.tscn": "Town",
    "area_one.tscn": "Area One — the meadow, the road and the ruins",
    "area_two.tscn": "Area Two — the catacombs",
    "area_three.tscn": "Area Three — the dead wood",
}

SEQUENCE_TITLES = {
    "game_opening.gd": "The opening: the prologue and the well",
    "field_binding.gd": "Lesson: binding a second Oathbound",
    "field_mending.gd": "Lesson: mending in the field",
    "field_strike.gd": "Lesson: striking first",
    "field_ambush.gd": "Lesson: being caught in the open",
    "field_rout.gd": "Lesson: routing without a battle",
    "epilogue.gd": "The ending",
}


# --- Speakers ----------------------------------------------------------------

# Mirrors DialoguePanel.split_speaker, so what the tool calls a speaker and
# what the game shows in the caption are the same thing.
SPEAKER_SEPARATOR = ": "
SPEAKER_MAX_LENGTH = 28
SPEAKER_FORBIDDEN = '.!?,;"\n'


def split_speaker(line: str) -> tuple[str, str]:
    """"Elder: Good morning." -> ("Elder", "Good morning.")"""
    at = line.find(SPEAKER_SEPARATOR)
    if at <= 0 or at > SPEAKER_MAX_LENGTH:
        return "", line
    name = line[:at]
    if any(char in name for char in SPEAKER_FORBIDDEN):
        return "", line
    return name, line[at + len(SPEAKER_SEPARATOR) :]


def join_speaker(speaker: str, body: str) -> str:
    return f"{speaker}{SPEAKER_SEPARATOR}{body}" if speaker else body


# --- Godot string literals ---------------------------------------------------

_UNESCAPE = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\"}


def decode(literal: str) -> str:
    """Turn the body of a Godot "..." literal into the text it stands for."""
    out: list[str] = []
    i = 0
    while i < len(literal):
        char = literal[i]
        if char == "\\" and i + 1 < len(literal):
            nxt = literal[i + 1]
            if nxt in _UNESCAPE:
                out.append(_UNESCAPE[nxt])
                i += 2
                continue
        out.append(char)
        i += 1
    return "".join(out)


def encode(text: str) -> str:
    """Turn text into the body of a Godot "..." literal."""
    out = text.replace("\\", "\\\\").replace('"', '\\"')
    return out.replace("\n", "\\n").replace("\t", "\\t").replace("\r", "\\r")


# --- The model ---------------------------------------------------------------


@dataclass
class Field:
    name: str
    text: str  # the words alone, with no speaker name in front
    literal: str  # exactly as it appeared, so an unedited value round-trips
    speaker: str = ""  # shown in the panel's caption, never in the words


@dataclass
class Record:
    key: str  # machine key, written into the Markdown as a comment
    heading: str  # what a human reads
    source: str  # repo-relative path, shown but never parsed back
    notes: list[str] = field(default_factory=list)
    fields: list[Field] = field(default_factory=list)


# --- Reading the game --------------------------------------------------------


def _quest_records() -> list[Record]:
    records = []
    for path in sorted((GAME / "content" / "quests").glob("*.tres")):
        text = path.read_text()
        quest_id = _scalar(text, "id") or path.stem
        giver = _scalar(text, "giver")
        turn_in = _scalar(text, "turn_in")
        requires = _scalar(text, "requires")
        kind = "Main" if _raw(text, "kind") == "0" else "Side"

        notes = [f"{kind} quest · **Giver:** {giver or '—'}"]
        if turn_in:
            notes[0] += f" · **Turn-in:** {turn_in}"
        if requires:
            notes.append(f"**Follows:** `{requires}`")
        level = _raw(text, "recommended_level")
        if level and level != "0":
            notes.append(f"**Recommended level:** {level} (`%d` in the caution line)")

        rec = Record(
            key=f"quest:{path.name}",
            heading=decode(_raw_string(text, "title") or quest_id),
            source=f"game/content/quests/{path.name}",
            notes=notes,
        )
        for name in QUEST_FIELDS:
            literal = _raw_string(text, name)
            if literal is None:
                continue
            rec.fields.append(_field(name, literal))
        if rec.fields:
            records.append(rec)
    return records


def _raw(text: str, name: str) -> str | None:
    match = re.search(rf"^{re.escape(name)} = (.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else None


def _raw_string(text: str, name: str) -> str | None:
    match = re.search(rf'^{re.escape(name)} = "((?:[^"\\]|\\.)*)"$', text, re.MULTILINE)
    return match.group(1) if match else None


def _scalar(text: str, name: str) -> str:
    """A StringName field (&"foo") as plain text."""
    raw = _raw(text, name)
    if not raw:
        return ""
    return raw.strip().lstrip("&").strip('"')


def _scene_records() -> list[Record]:
    records = []
    for filename in SCENE_FILES:
        path = GAME / "areas" / filename
        text = path.read_text()
        for block in _node_blocks(text):
            header, body = block
            name_match = re.search(r'name="([^"]+)"', header)
            parent_match = re.search(r'parent="([^"]+)"', header)
            if not name_match:
                continue
            node = name_match.group(1)
            parent = parent_match.group(1) if parent_match else "."
            node_path = node if parent == "." else f"{parent}/{node}"

            rec = Record(
                key=f"scene:{filename}:{node_path}",
                heading=f"{node} — {AREA_TITLES[filename].split(' — ')[0]}",
                source=f"game/areas/{filename} · `{node_path}`",
            )
            for name in SCENE_FIELDS:
                if name in SCENE_ARRAY_FIELDS:
                    literal = _raw(body, name)
                    if literal is None or not literal.startswith("PackedStringArray("):
                        continue
                    items = _split_array(literal)
                    for index, item in enumerate(items):
                        rec.fields.append(_field(f"{name}[{index}]", item))
                    continue
                literal = _raw_string(body, name)
                if literal is None:
                    continue
                rec.fields.append(_field(name, literal))
            if rec.fields:
                display = _raw_string(body, "display_name")
                if display:
                    rec.heading = (
                        f"{decode(display)} — {AREA_TITLES[filename].split(' — ')[0]}"
                    )
                records.append(rec)
    return records


def _node_blocks(text: str) -> list[tuple[str, str]]:
    """Every [node ...] header paired with the property lines under it."""
    blocks = []
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        if lines[index].startswith("[node "):
            header = lines[index]
            body: list[str] = []
            index += 1
            while index < len(lines) and not lines[index].startswith("["):
                body.append(lines[index])
                index += 1
            blocks.append((header, "\n".join(body)))
            continue
        index += 1
    return blocks


def _split_array(literal: str) -> list[str]:
    """The string bodies inside PackedStringArray("a", "b")."""
    inner = literal[len("PackedStringArray(") : literal.rindex(")")]
    return re.findall(r'"((?:[^"\\]|\\.)*)"', inner)


def _sequence_records() -> list[Record]:
    records = []
    for rel in SEQUENCE_FILES:
        path = GAME / rel
        text = path.read_text()
        filename = path.name
        rec = Record(
            key=f"script:{rel}",
            heading=SEQUENCE_TITLES[filename],
            source=f"game/{rel}",
            notes=["Each entry below is one page or line, shown in this order."],
        )
        for name, literal, is_array in _consts(text):
            if name in SEQUENCE_SKIP:
                continue
            if is_array:
                for index, item in enumerate(literal):
                    rec.fields.append(_field(f"{name}[{index}]", item))
            else:
                rec.fields.append(_field(name, literal))
        if rec.fields:
            records.append(rec)
    return records


def _consts(text: str):
    """Prose consts: plain strings and PackedStringArray literals."""
    for match in re.finditer(
        r'^const ([A-Z0-9_]+)(?:\s*:\s*String)?\s*:?=\s*"((?:[^"\\]|\\.)*)"\s*$',
        text,
        re.MULTILINE,
    ):
        yield match.group(1), match.group(2), False
    for match in re.finditer(
        r"^const ([A-Z0-9_]+)\s*:\s*PackedStringArray\s*=\s*\[(.*?)^\]",
        text,
        re.MULTILINE | re.DOTALL,
    ):
        items = re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(2))
        yield match.group(1), items, True
    for match in re.finditer(
        r"^const ([A-Z0-9_]+)\s*:\s*PackedStringArray\s*=\s*\[([^\]\n]*)\]\s*$",
        text,
        re.MULTILINE,
    ):
        items = re.findall(r'"((?:[^"\\]|\\.)*)"', match.group(2))
        yield match.group(1), items, True


def _field(name: str, literal: str) -> Field:
    """One passage, with the speaker's name lifted out of the words."""
    speaker, body = split_speaker(decode(literal))
    return Field(name, body, literal, speaker)


def read_game() -> list[Record]:
    return _quest_records() + _scene_records() + _sequence_records()


# --- Writing the Markdown ----------------------------------------------------

PREAMBLE = """<!-- Generated by tools/dialogue.py. Edit the prose under the
### headings and nothing else, then run:  python3 tools/dialogue.py import -->

**How to edit this file**

- Change only the text underneath a `###` heading. That text is what the game
  says.
- Leave the `##` headings, the `<!-- key: ... -->` comments and the `###`
  field names alone. They are how the text finds its way home.
- Keep any `%s` and `%d` exactly as they are. The game fills them in with a
  name or a level, and a line that loses one will break.
- Blank lines inside a passage are kept. Leading and trailing ones are not.
- Speaker names are part of the line ("Elder: Good morning."). The dialogue
  box splits them off itself, so keep the `Name: ` prefix.

---
"""


def write_markdown(records: list[Record], groups: dict[str, list[Record]]) -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    for filename, group in groups.items():
        lines = [f"# {filename_title(filename)}", "", PREAMBLE]
        for rec in group:
            lines.append("")
            lines.append(f"## {rec.heading}")
            lines.append("")
            lines.append(f"<!-- key: {rec.key} -->")
            lines.append("")
            lines.append(f"<sub>{rec.source}</sub>")
            for note in rec.notes:
                lines.append("")
                lines.append(note)
            for fld in rec.fields:
                lines.append("")
                lines.append(f"### {fld.name}")
                lines.append("")
                if fld.speaker:
                    lines.append(f"<!-- speaker: {fld.speaker} -->")
                    lines.append("")
                lines.append(fld.text if fld.text else "*(empty)*")
            lines.append("")
            lines.append("---")
        (DOCS / filename).write_text("\n".join(lines).rstrip() + "\n")


TITLES = {
    "quests_town_and_area_one.md": "Quests — Town and Area One",
    "quests_area_two.md": "Quests — Area Two",
    "quests_area_three.md": "Quests — Area Three",
    "quests_side.md": "Quests — side quests",
    "npcs_town.md": "Town — NPCs, chests and doorways",
    "npcs_area_one.md": "Area One — NPCs, bosses, chests and doorways",
    "npcs_area_two.md": "Area Two — NPCs, bosses, chests and doorways",
    "npcs_area_three.md": "Area Three — NPCs, bosses, chests and doorways",
    "sequences.md": "Scripted sequences — the opening, the lessons, the ending",
}


def filename_title(filename: str) -> str:
    return TITLES.get(filename, filename)


def group_records(records: list[Record]) -> dict[str, list[Record]]:
    groups: dict[str, list[Record]] = {name: [] for name in TITLES}
    for rec in records:
        groups[_file_for(rec)].append(rec)
    return {name: group for name, group in groups.items() if group}


def _file_for(rec: Record) -> str:
    if rec.key.startswith("script:"):
        return "sequences.md"
    if rec.key.startswith("scene:"):
        scene = rec.key.split(":")[1]
        return {
            "town.tscn": "npcs_town.md",
            "area_one.tscn": "npcs_area_one.md",
            "area_two.tscn": "npcs_area_two.md",
            "area_three.tscn": "npcs_area_three.md",
        }[scene]
    name = rec.key.split(":")[1]
    if name.startswith("quest_side"):
        return "quests_side.md"
    number = re.match(r"quest_main_(\d+)", name)
    index = int(number.group(1)) if number else 0
    if index <= 3:
        return "quests_town_and_area_one.md"
    if index <= 9:
        return "quests_area_two.md"
    return "quests_area_three.md"


# --- Reading the Markdown back ----------------------------------------------


def read_markdown() -> dict[str, dict[str, dict[str, str]]]:
    """key -> {field name: {"text": ..., "speaker": ...}}."""
    out: dict[str, dict[str, dict[str, str]]] = {}
    for path in sorted(DOCS.glob("*.md")):
        if path.name == "README.md":
            continue
        key = None
        fld = None
        buffer: list[str] = []
        speaker = ""

        def flush() -> None:
            if key is not None and fld is not None:
                text = "\n".join(buffer).strip("\n")
                out.setdefault(key, {})[fld] = {
                    "text": "" if text == "*(empty)*" else text,
                    "speaker": speaker,
                }

        for line in path.read_text().splitlines():
            key_match = re.match(r"<!-- key: (.+?) -->", line)
            if key_match:
                flush()
                key, fld, buffer, speaker = key_match.group(1), None, [], ""
                continue
            field_match = re.match(r"### (.+)$", line)
            if field_match:
                flush()
                fld, buffer, speaker = field_match.group(1).strip(), [], ""
                continue
            speaker_match = re.match(r"<!-- speaker: (.+?) -->", line)
            if speaker_match and fld is not None:
                speaker = speaker_match.group(1).strip()
                continue
            if line.startswith("## "):
                flush()
                fld, buffer = None, []
                continue
            if fld is not None:
                # Trailing spaces are invisible in a Markdown editor and end
                # up inside the game's strings, so they never travel.
                line = line.rstrip()
                if line.strip() == "---":
                    flush()
                    fld, buffer = None, []
                    continue
                buffer.append(line)
        flush()
    return out


# --- Writing the game --------------------------------------------------------


def resolve(fld: Field, entry: dict[str, str]) -> str:
    """The full line to store, speaker and all, from an edited passage.

    The speaker is whatever the Markdown still says it is: a name typed in
    front of the words wins, then the `<!-- speaker: -->` note the export
    leaves, and failing both the name the game already had. That last one is
    what lets a writer delete "Elder: " from every line without the caption
    going with it.
    """
    typed, body = split_speaker(entry["text"])
    speaker = typed or entry.get("speaker") or fld.speaker
    return join_speaker(speaker, body)


def apply(records: list[Record], edits: dict[str, dict[str, dict[str, str]]]) -> list[str]:
    """Writes changed prose back. Returns a line per change made."""
    changes: list[str] = []
    by_file: dict[Path, list[tuple[Record, Field, str]]] = {}

    for rec in records:
        wanted = edits.get(rec.key)
        if not wanted:
            continue
        for fld in rec.fields:
            entry = wanted.get(fld.name)
            if entry is None:
                continue
            new = resolve(fld, entry)
            if new == decode(fld.literal):
                continue
            path = _path_of(rec)
            by_file.setdefault(path, []).append((rec, fld, new))
            changes.append(f"{rec.key} :: {fld.name}")

    for path, items in by_file.items():
        text = path.read_text()
        for rec, fld, new in items:
            text = _replace(text, rec, fld, new)
        path.write_text(text)
    return changes


def _path_of(rec: Record) -> Path:
    kind, rest = rec.key.split(":", 1)
    if kind == "quest":
        return GAME / "content" / "quests" / rest
    if kind == "scene":
        return GAME / "areas" / rest.split(":")[0]
    return GAME / rest


def _replace(text: str, rec: Record, fld: Field, new: str) -> str:
    """Swaps one prose value, matching on the literal it was exported from."""
    base = re.sub(r"\[\d+\]$", "", fld.name)
    old_literal = fld.literal
    new_literal = encode(new)

    if rec.key.startswith("script:"):
        target = f'"{old_literal}"'
        if text.count(target) != 1:
            raise SystemExit(
                f"Could not place {rec.key} :: {fld.name} (found "
                f"{text.count(target)} matches). Nothing written."
            )
        return text.replace(target, f'"{new_literal}"')

    # Resource and scene properties are one line each. Narrow to that line so
    # the same sentence used twice in a file cannot be crossed over.
    pattern = rf'^({re.escape(base)} = .*?)"{re.escape(old_literal)}"'
    matches = list(re.finditer(pattern, text, re.MULTILINE))
    if len(matches) != 1:
        raise SystemExit(
            f"Could not place {rec.key} :: {fld.name} (found {len(matches)} "
            f"matches). Nothing written."
        )
    match = matches[0]
    return text[: match.start()] + match.group(1) + f'"{new_literal}"' + text[match.end() :]


# --- Commands ----------------------------------------------------------------


def cmd_export() -> None:
    records = read_game()
    groups = group_records(records)
    write_markdown(records, groups)
    total = sum(len(r.fields) for r in records)
    print(f"Exported {len(records)} entries, {total} passages:")
    for name, group in groups.items():
        passages = sum(len(r.fields) for r in group)
        print(f"  docs/dialogue/{name:<32} {len(group):>3} entries, {passages:>4} passages")


def cmd_import() -> None:
    records = read_game()
    edits = read_markdown()
    known = {rec.key for rec in records}
    for key in edits:
        if key not in known:
            print(f"  ! unknown key, skipped: {key}")
    changes = apply(records, edits)
    if not changes:
        print("No changes. The game already says what the Markdown says.")
        return
    print(f"Wrote {len(changes)} changed passages:")
    for line in changes:
        print(f"  {line}")


def cmd_check() -> None:
    """Exports, reads straight back, and reports any value that did not survive."""
    records = read_game()
    write_markdown(records, group_records(records))
    edits = read_markdown()
    bad = 0
    for rec in records:
        got = edits.get(rec.key)
        if got is None:
            print(f"  ! missing from Markdown: {rec.key}")
            bad += 1
            continue
        for fld in rec.fields:
            if fld.name not in got:
                print(f"  ! missing field: {rec.key} :: {fld.name}")
                bad += 1
                continue
            came_back = resolve(fld, got[fld.name])
            if came_back != decode(fld.literal):
                print(f"  ! changed by round-trip: {rec.key} :: {fld.name}")
                print(f"      was: {decode(fld.literal)[:90]!r}")
                print(f"      now: {came_back[:90]!r}")
                bad += 1
    total = sum(len(r.fields) for r in records)
    if bad:
        print(f"\n{bad} of {total} passages did not survive the round trip.")
        sys.exit(1)
    print(f"All {total} passages survive export and re-import unchanged.")


def main() -> None:
    global DOCS
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if len(sys.argv) > 2:
        # An import may be pointed at a folder of hand-edited copies, so a
        # revision pass does not have to overwrite the export first.
        DOCS = Path(sys.argv[2])
        if not DOCS.is_absolute():
            DOCS = ROOT / DOCS
    if command == "export":
        cmd_export()
    elif command == "import":
        cmd_import()
    elif command == "check":
        cmd_check()
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
