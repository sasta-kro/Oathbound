# Oathbound Development Environment Setup

This document describes the development environment expected for Oathbound. It is intended for both human developers and coding agents.

The goal is for every developer to run the same Godot version while allowing individual choice of operating system, IDE, and coding agent.

## 1. Required Software

Install the following:

* **Godot 4.7.2 Stable**, Standard build
* **Git**
* **Git LFS**
* **Node.js 18+**
* An MCP-capable coding agent, such as Codex or Claude Code
* An IDE/editor of your choice

The project does not depend on a specific external IDE. VS Code, Cursor, JetBrains IDEs, and the built-in Godot script editor are all acceptable.

The authoritative engine version is exactly:

```text
Godot 4.7.2 Stable
```

Do not upgrade the project to another Godot version individually.

---

## 2. Make Godot Available From the Terminal

Coding agents and validation scripts must be able to invoke Godot using:

```bash
godot
```

Verify after setup:

```bash
godot --version
```

It must report Godot 4.7.2 Stable.

### macOS

If Godot is installed as `/Applications/Godot.app`:

```bash
sudo mkdir -p /usr/local/bin
sudo ln -sf /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot
```

Verify:

```bash
godot --version
```

If the application has a different filename or location, change the source path accordingly.

### Fedora / Linux

If `godot --version` already works, no additional setup is required.

If using the standalone Godot binary, make it executable:

```bash
chmod +x /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
```

Then expose it as `godot`:

```bash
sudo ln -sf /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot
```

Verify:

```bash
godot --version
```

The exact downloaded binary filename may differ. The important requirement is that `godot` resolves to the team's pinned Godot 4.7.2 executable.

---

## 3. Clone the Project and Initialize Git LFS

After cloning the repository:

```bash
git lfs install
git lfs pull
```

Large source assets tracked by Git LFS should not be manually copied around between developers.

The repository's `.gitattributes` defines which files use LFS.

---

## 4. Configure Godot for External Editing

Open the project in Godot.

Open:

**Editor Settings → Text Editor → Behavior**

Enable:

```text
Auto Reload Scripts on External Change
```

This is required because coding agents and external IDEs modify `.gd` files directly while the Godot editor is running.

Godot should automatically notice and reload those changes.

### External IDE

IDE choice is not standardized.

VS Code/Cursor users may install the official Godot extension.

JetBrains users may use their preferred Godot/GDScript integration.

The project's agent workflow must not depend on a particular IDE. Godot CLI, tests, repository files, and MCP are the shared interfaces.

---
## 5. Install gdtoolkit

Oathbound uses `gdtoolkit` for GDScript formatting and linting.

Install it through Homebrew or Linuxbrew:

```bash
brew install gdtoolkit
```

Verify the installation:

```bash
gdformat --version
gdlint --version
```

`gdtoolkit` provides:

* `gdformat` for consistent GDScript formatting.
* `gdlint` for automated GDScript linting and static checks.

Coding agents should format and lint modified GDScript before reporting implementation work as complete.

No project-local Python environment is required for the current Oathbound development toolchain.


---

## 6. Install GUT

Oathbound uses:

```text
GUT 9.7.1
```

This is the GUT version selected for Godot 4.7.x.

Copy:

```text
Gut/addons/gut/
```

into:

```text
<project-root>/addons/gut/
```

The resulting structure should contain:

```text
addons/
└── gut/
```

Open Godot and go to:

**Project → Project Settings → Plugins**

Enable:

```text
GUT
```

Restart Godot if necessary.

The pinned `addons/gut/` directory should be committed to the repository so every developer and agent uses the same version. If it already exists after cloning the repository, do not download another version over it.

---

## 7. Configure GUT

At the project root, create:

```text
.gutconfig.json
```

with:

```json
{
  "dirs": ["res://tests/"],
  "include_subdirs": true,
  "log_level": 2,
  "should_exit": true
}
```

Tests belong under:

```text
res://tests/
```

Verify GUT from the command line:

```bash
godot --headless -d --path . -s addons/gut/gut_cmdln.gd
```

This command must be usable by both developers and coding agents.

---

## 8. Install the Godot MCP Bridge

Oathbound currently uses:

```text
mkdevkit/godot-mcp
```

The MCP server itself should live outside the actual game repository.

Recommended local workspace:

```text
workspace/
├── oathbound/
└── tools/
    └── godot-mcp/
```

Clone the MCP repository into `tools/`:

```bash
cd workspace/tools
git clone https://github.com/mkdevkit/godot-mcp.git
```

Build the Node server:

```bash
cd godot-mcp/server
npm install
npm run build
```

The resulting MCP entry point is:

```text
godot-mcp/server/build/index.js
```

---

## 9. Install the Godot MCP Editor Addon

Copy:

```text
godot-mcp/addons/godot_mcp/
```

into:

```text
<project-root>/addons/godot_mcp/
```

The project should now contain:

```text
addons/
├── gut/
└── godot_mcp/
```

Open:

**Project → Project Settings → Plugins**

Enable:

```text
Godot MCP
```

The pinned Godot-side MCP addon should be committed with the project. Developers should not independently replace it with another version.

The external Node MCP server remains a per-machine development tool.

---

## 10. Connect the Coding Agent

The MCP server communicates with the Godot editor on port:

```text
6505
```

The Godot project must be open in the editor with the Godot MCP plugin enabled when editor-level MCP functionality is required.

### Codex

Register the server:

```bash
codex mcp add godot-mcp --env GODOT_MCP_PORT=6505 -- node "/ABSOLUTE/PATH/TO/godot-mcp/server/build/index.js"
```

Verify the MCP registration using the Codex client.

Codex-based applications using the same local Codex configuration may reuse this registration.

### Claude Code

Claude Code can use a project or user MCP configuration pointing to the same server:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": [
        "/ABSOLUTE/PATH/TO/godot-mcp/server/build/index.js"
      ],
      "env": {
        "GODOT_MCP_PORT": "6505"
      }
    }
  }
}
```

Each developer must replace the absolute path with the location of their own MCP checkout.

Do not commit machine-specific absolute paths to the game repository.

---

## 11. Test the MCP Connection

Open the Oathbound project in Godot and keep the editor running.

Start the coding agent and ask it to inspect the project without modifying anything.

A useful smoke test is:

```text
Use the Godot MCP connection to inspect the currently open project.

Do not modify anything.

Report:
- project name
- current scene
- current scene tree
- editor errors
- configured input actions
```

If this succeeds, the complete connection is working:

```text
Coding agent
→ MCP server
→ Godot MCP plugin
→ Godot editor
```

For a second test, ask the agent to create a trivial scene, save it, inspect it again, and then revert/delete the test scene.

---

## 12. Verify the Development Loop

Before beginning production work, every developer should be able to perform all of the following:

```bash
godot --version
```

```bash
godot --headless --path . --import
```

```bash
godot --headless -d --path . -s addons/gut/gut_cmdln.gd
```

```bash
gdlint scripts/
```

The coding agent should also be able to:

* Read and edit repository files.
* Edit `.gd`, `.tscn`, and `.tres`.
* Run terminal commands.
* Run Godot headlessly.
* Run GUT tests.
* Format and lint GDScript.
* Inspect the open Godot editor through MCP.
* Inspect editor errors.
* Start and stop the game.
* Inspect runtime state where supported.
* Capture screenshots for visual verification.

The intended iterative development loop is:

```text
Agent reads specification and existing code
→ modifies project files
→ formats/lints
→ runs Godot validation
→ runs tests
→ inspects editor errors
→ runs the affected scene/game
→ inspects runtime result
→ fixes discovered problems
→ repeats until clean
→ reports changes and assumptions
```

CLI validation must continue to work even if the MCP bridge is unavailable. MCP improves the development loop, but it is not a dependency of the game itself.
