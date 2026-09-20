# Commit hygiene for editor and generated files

Required steps before committing scenes, resources, and tool-generated files.
Applies to every contributor and every agent working in this repository.

## Why this exists

Two kinds of writers produce files in this repo: the Godot editor and the
generator tools (the area baker at `game/scripts/dev/bake_area.gd` with
`area_painter.gd`, and `tools/import_monster_sprites.py`). Both write valid
files, but in different serialization styles. When a file written by one writer
is later saved by the other, the whole file re-serializes and the diff fills
with unrelated churn: `uid` attributes, node headers, default-valued
properties, animation flags. Following the rules below keeps every committed
file in editor style, so later saves produce diffs that contain only real
changes.

## Rules

1. Files edited only in the Godot editor: commit as saved. No extra step.
2. Files written by a generator, including baked area `.tscn` files and
   imported sprite `.tres` files: open each generated file in the Godot
   editor and save it once before committing. This converts the file to
   editor serialization. Commit the generator output and the editor save
   together in the same change.
3. Never strip serialization churn by hand or by script. The editor is the
   only approved serialization style. If a diff shows unexpected churn,
   re-save the file in the editor and commit that instead.
4. Before committing, check `git diff` contains only the intended changes.
   Large unexpected re-serialization of a file someone else last touched is a
   sign of stale editor memory: pull, reload the scene with
   Scene, Reload Saved Scene, and re-apply the change.

## Notes for agents

- After running a generator, generated files must pass through an editor save
  before they are committed. Do not commit raw generator output.
- After any pull, run `godot --headless --path . --import` from `game/`
  before running tests or the editor, so resource uids resolve.
