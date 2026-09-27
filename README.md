# Oathbound

Oathbound is a small top-down 2D creature-collecting RPG built with Godot 4.7.2. Wild creatures roam the overworld in plain sight instead of hiding in random encounters, the first blow struck on the field decides how each battle opens, and new companions are bound to the party with oath scrolls. A complete story run takes roughly 40 to 60 minutes.

## Team

- Min Khaung Kyaw Swar
- Sai Aike Shwe Tun Aung
- Ekaterina Kazakova

## Repository structure

```text
docs/      Gameplay specification and development setup documentation.
game/      Godot project root. Open this directory in Godot.
tools/     External development tools, including the Godot MCP server.
```

## Source of truth

`docs/` is the source of truth for gameplay behavior, scope, deferred features, placeholder policy, and design constraints.

| Document | Read it for |
|---|---|
| `docs/implementation_status.md` | Current verified feature and content status. Start here. |
| `docs/audits/` | Dated point-in-time codebase status audits. Read the newest for the last full picture. |
| `docs/Oathbound_Specification_v0.6.md` | The gameplay rules, with an implementation status tag per section. |
| `docs/architecture.md` | How the Godot project is organised: autoloads, layers, content, saving, tests, conventions for contributors and agents. |
| `docs/map_authoring.md` | Painting areas, spawn zones, exits, NPCs and quests in the editor. |
| `docs/commit_hygiene.md` | Required serialization steps before committing editor and generated files. |
| `docs/Oathbound Dev Env Setup (Required).md` | Engine version, terminal `godot`, MCP server, formatters. |
| `docs/audits/spec_audit_2026-09-12.md` | The v0.4-to-v0.5 audit: every divergence between spec and code. |
| `docs/archive/` | Superseded specification versions. |

Implementation files must not silently change the specification. Conflicts, missing decisions, and non-trivial assumptions should be reported for review.

## Godot project

The project root is `game/`.

Important locations:

```text
game/scenes/title_screen.tscn   Main scene (project setting). Leads into main.tscn.
game/main.tscn                  The field: area, player, partner, HUD, battle, transition.
game/areas/                     Hand-painted overworld areas (one scene per area).
game/scenes/                    Reusable Godot scenes.
game/scripts/                   Typed GDScript gameplay code.
game/content/                   Game data as .tres resources (creatures, moves, abilities, quests, VFX).
game/tests/                     GUT tests.
game/addons/gut/                Pinned GUT installation.
game/addons/godot_mcp/          Godot-side MCP integration.
```

The project targets Godot 4.7.2 Stable with the Compatibility renderer. The project-specific MCP addon is development tooling only and is not a runtime dependency.

## Development tools

`tools/` contains the external Godot MCP server. The server connects coding agents to an open Godot editor for scene inspection, runtime checks, screenshots, and editor operations.

The MCP bridge is optional for command-line validation. Godot CLI, GUT, `gdformat`, and `gdlint` remain usable without an active MCP connection.

The server is registered per machine in a local, gitignored `.mcp.json` and runs from a local build that is not committed. Build it once per checkout, from the repository root:

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

The game launches into a title screen. In the field, use **F** to strike a
creature with your lead companion, **E** to talk, **Tab / P** for the
party, **J** for the creature journal, **L** for the quest log, and **Esc**
for the main menu. Menus
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
is damaged. **Save journey** in the field menu (Esc) writes any slot;
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

Specification v0.6 section 21.1 describes this model; v0.4 asked for a single
autosave slot, and manual slots were added on request.


## Credits

Oathbound uses third-party art, music and sound. Per-folder `SOURCE.md` files
under `game/assets/` record which file came from where.

### Music

All tracks are CC0 1.0 from OpenGameArt.org, used unedited.

| Track | Used for | Author | Source |
|---|---|---|---|
| Fantasy Orchestral Theme | Title screen | Joth | https://opengameart.org/content/fantasy-orchestral-theme |
| Town Theme RPG | Town | cynicmusic ([cynicmusic.com](https://cynicmusic.com), [pixelsphere.org](https://pixelsphere.org)) | https://opengameart.org/content/town-theme-rpg |
| The Field Of Dreams | Field areas | pauliuw | https://opengameart.org/content/the-field-of-dreams |
| Battle Theme A | Battles | cynicmusic | https://opengameart.org/content/battle-theme-a |

### Sound effects

All CC0 1.0 unless noted.

| Pack | Used for | Author | Source |
|---|---|---|---|
| Impact Sounds | Hit sounds | Kenney | https://kenney.nl/assets/impact-sounds |
| Magic Spell SFX | Bind attempt, bind success | JaggedStone | https://opengameart.org/content/magic-spell-sfx |
| 80 CC0 RPG SFX | Bind fail, faint | rubberduck | https://opengameart.org/content/80-cc0-rpg-sfx |
| Boss victory jingle | Boss victory | Original, made for Oathbound | n/a |

### Art

| Asset | Used for | Author | Source / license |
|---|---|---|---|
| Pixel Art Top Down - Basic | Town and field tiles, plants, props | Cainos | https://cainos.itch.io/pixel-art-top-down-basic |
| The Fan-tasy Tileset (Free) | Meadow terrain, roads, water, buildings, trees, street props | Ventilatore | https://ventilatore.itch.io/the-fantasy-tileset |
| Free Undead Tileset Top Down Pixel Art | Ruins, graves, dead wood | Free Game Assets (CraftPix.net) | https://free-game-assets.itch.io/free-undead-tileset-top-down-pixel-art |
| Rogue Fantasy Catacombs | Area Two catacomb tiles, torches, candles, spikes | Szadi art | https://szadiart.itch.io/rogue-fantasy-catacombs |
| Character pack | Player hero and all NPCs | superretroworld | https://gif-superretroworld.itch.io/character-pack |
| Tiny RPG Character Asset Pack 02 | All creature sprites, including the recoloured variants | Zerie | https://zerie.itch.io/tiny-rpg-character-asset-pack-02 |

`verdant_sanctum.svg`, the HUD icons and the boss victory jingle were made for
Oathbound.

### Fonts

Both under the SIL Open Font License; license files are in `game/assets/ui/fonts/`.

- Cormorant Garamond: https://github.com/google/fonts/tree/main/ofl/cormorantgaramond
- Manrope: https://github.com/google/fonts/tree/main/ofl/manrope

### Tools

- [Godot Engine](https://godotengine.org) 4.7.2 (MIT)
- [GUT](https://github.com/bitwes/Gut), the Godot Unit Test framework (MIT)
