#!/usr/bin/env python3
"""Split long passages into dialogue boxes, matching the hand-made pacing."""
import re, sys
sys.path.insert(0, "tools")
import dialogue as D

TARGET = 120
MAXBOX = 200
FLOOR = 200
OPENER = 70

SENT = re.compile(r'(?<=[.!?])\s+(?=[A-Z"—])')


def sentences(text: str) -> list[str]:
    return [s.strip() for s in SENT.split(text) if s.strip()]


def split_passage(text: str) -> str:
    if len(text) <= FLOOR or "\n\n" in text:
        return text
    sents = sentences(text)
    if len(sents) < 2:
        return text

    boxes: list[list[str]] = []
    cur: list[str] = []
    rest = sents

    # A short opening sentence is a beat of its own, as in the hand splits.
    if len(sents) > 2 and 15 <= len(sents[0]) <= OPENER and len(text) > 250:
        boxes.append([sents[0]])
        rest = sents[1:]

    for s in rest:
        if not cur:
            cur = [s]
            continue
        joined = " ".join(cur)
        candidate = f"{joined} {s}"
        too_long = len(candidate) > MAXBOX
        past_target = len(candidate) > TARGET and len(joined) >= TARGET * 0.55
        if too_long or past_target:
            boxes.append(cur)
            cur = [s]
        else:
            cur = cur + [s]
    if cur:
        boxes.append(cur)

    # A lone trailing scrap reads as a dropped thought; fold it backwards,
    # but never into a box that would then overrun.
    if len(boxes) > 1 and len(" ".join(boxes[-1])) < 45:
        merged = len(" ".join(boxes[-2] + boxes[-1]))
        if merged <= MAXBOX:
            tail = boxes.pop()
            boxes[-1] = boxes[-1] + tail

    flat = [s for box in boxes for s in box]
    assert flat == sents, "splitter dropped or duplicated a sentence"
    return "\n\n".join(" ".join(b) for b in boxes)


def rewrite(path, preview, shown):
    text = path.read_text()
    out, buf = [], []
    key = fld = None
    changed = 0

    def emit():
        nonlocal changed, shown
        if key and fld and buf:
            body = "\n".join(buf).strip("\n")
            if body and body != "*(empty)*":
                new = split_passage(body)
                if new != body:
                    changed += 1
                    if preview and shown < 3:
                        shown += 1
                        print(f"\n=== {key} :: {fld}")
                        for i, b in enumerate(new.split("\n\n"), 1):
                            print(f"  [{i}] ({len(b)}) {b}")
                    return [""] + new.split("\n") + [""]
        return buf

    for line in text.splitlines():
        m = re.match(r"<!-- key: (.+?) -->", line)
        if m:
            out += emit(); buf = []
            key, fld = m.group(1), None
            out.append(line); continue
        m = re.match(r"### (.+)$", line)
        if m:
            out += emit(); buf = []
            fld = m.group(1).strip()
            out.append(line); continue
        if line.startswith("## ") or line.strip() == "---":
            out += emit(); buf = []
            fld = None
            out.append(line); continue
        if fld is not None and not line.startswith("<!-- speaker:"):
            buf.append(line); continue
        out.append(line)
    out += emit()
    if not preview:
        body = "\n".join(out)
        body = re.sub(r"\n{3,}", "\n\n", body)
        path.write_text(body.rstrip() + "\n")
    return changed, shown


def main():
    preview = "--apply" not in sys.argv
    total = shown = 0
    for path in sorted(D.DOCS.glob("*.md")):
        if path.name == "README.md":
            continue
        n, shown = rewrite(path, preview, shown)
        total += n
    print(f"\n{'Would split' if preview else 'Split'} {total} passages.")


main()
