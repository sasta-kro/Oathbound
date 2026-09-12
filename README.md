# Oathbound

Oathbound is a small top-down 2D creature-collecting RPG built with Godot 4.7.2. Wild creatures roam the overworld in plain sight instead of hiding in random encounters, the first blow struck on the field decides how each battle opens, and new companions are bound to the party with oath scrolls. A complete story run takes roughly 40 to 60 minutes.

## Repository structure

```text
docs/      Gameplay specification and development setup documentation.
game/      Godot project root. Open this directory in Godot.
tools/     External development tools, including the Godot MCP server.
```

## Source of truth

`docs/` is the source of truth for gameplay behavior, scope, deferred features, placeholder policy, and design constraints.

`AGENTS.md` defines repository workflow and codebase conventions for human and agent contributors.

`docs/map_authoring.md` explains how to paint areas and place creature spawn zones in the Godot editor.

Implementation files must not silently change the specification. Conflicts, missing decisions, and non-trivial assumptions should be reported for review.

## Godot project

The project root is `game/`.

Important locations:

```text
game/main.tscn          Launch scene.
game/areas/             Hand-painted overworld areas (one scene per area).
game/scenes/            Reusable Godot scenes.
game/scripts/            Typed GDScript gameplay code.
game/tests/              GUT tests.
game/addons/gut/         Pinned GUT installation.
game/addons/godot_mcp/   Godot-side MCP integration.
```

The project targets Godot 4.7.2 Stable with the Compatibility renderer. The project-specific MCP addon is development tooling only and is not a runtime dependency.

## Development tools

`tools/` contains the external Godot MCP server. The server connects coding agents to an open Godot editor for scene inspection, runtime checks, screenshots, and editor operations.

The MCP bridge is optional for command-line validation. Godot CLI, GUT, `gdformat`, and `gdlint` remain usable without an active MCP connection.

The server is registered for this repository in `.mcp.json` and runs from a local build that is not committed. Build it once per checkout, from the repository root:

```bash
npm --prefix tools/godot-mcp/server install
npm --prefix tools/godot-mcp/server run build
```

Agent tools reach the editor only while the Godot editor is open on `game/` with the `godot_mcp` plugin enabled. The addon and the server meet on `GODOT_MCP_PORT` (6505 by default).

## Validation

Run commands from `game/`:

```bash
godot --headless --path . --import
godot --headless -d --path . -s addons/gut/gut_cmdln.gd
gdformat --check scripts tests
gdlint scripts tests
```

New gameplay should remain playable with labeled placeholder visuals when final assets are unavailable.

### Interface and navigation

The field HUD uses compact glass icons in the top-right corner. Hover an icon
for its name and shortcut. The area title fades after arrival, and the slim
companion health card opens its details when clicked.

The game launches into a title screen. In the field, use **Tab / P** for the
party, **J** for the creature journal, and **Esc** for the main menu. Menus
support mouse input and standard keyboard focus navigation: Tab opens the party
from the field, then cycles focus inside menus. Esc returns from a creature record
to its parent screen; P closes the party. Journal search and element filters are
retained when returning from a record. The party screen
opens creature details, lets a healthy companion become the lead, and offers
evolution when eligible. The journal searches names and elements and records
seen/bound species during the session.

EXP appears in non-blocking side cards with creature portraits, animated level
progress and level-up feedback. Victories return to exploration automatically;
overworld defeats also pay rewards without a dialogue prompt.

### Saving

Saves live in `user://saves/`: three manual slots (`slot_1.json` to
`slot_3.json`) and one autosave (`autosave.json`). Each file keeps its
previous contents beside it as `.backup`, which is read when the file itself
is damaged. **Save journey** in the field menu (Esc, entry 04) writes any slot;
overwriting, loading mid-journey and erasing all ask twice. The field also
autosaves into its own slot on entering the field or an area, after every
battle, rout and healing service, on the way back to the title screen, and
when the window is closed outside a battle. The autosave never touches a
manual slot. The title screen offers **Continue** for the most recent slot of
either kind, **Load a journey** to pick or erase one, and **Begin anew**,
which starts fresh without erasing anything. A loaded journey restores the
party, coins, scrolls, the journal, play time, and the player's position and
facing in the area it was saved in. Roaming creatures are respawned by the
area on load.

This goes past Specification 21.1, which asks for a single autosave slot and
no manual save command; manual slots were added on request.

