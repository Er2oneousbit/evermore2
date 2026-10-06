# Secret of Evermore 2: Return to Evermore

A fan sequel to *Secret of Evermore* (Square, 1995). Top-down action RPG,
modern pixel art, built in **Godot 4**.

> **Status: Prototype 0.1.** A kid walks around a placeholder backyard, the dog
> follows him, and you can flip day/night and the phone flashlight. Scales
> pixel-perfect to **any monitor: 16:9, 21:9, 32:9, 48:9 triple-wide, Steam
> Deck**. No combat, menus, or story yet. Everything is placeholder shapes.

| Golden hour + F3 overlay | Dog following through the fence maze | Night, phone flashlight on |
|---|---|---|
| ![golden hour](docs/screenshots/proto0_golden_hour.png) | ![maze follow](docs/screenshots/proto0_maze_follow.png) | ![night](docs/screenshots/proto0_night_flashlight.png) |

**32:9 super ultrawide (5120×1440):** fills the screen, hedge "apron" past the fence, HUD pulled into the middle.
![32:9](docs/screenshots/proto0_ultrawide_32x9.png)

**48:9 triple-wide (7680×1440):**
![48:9](docs/screenshots/proto0_triple_48x9.png)

---

## Quick start

1. **Install Godot 4.7.x (standard build, not .NET)** from
   <https://godotengine.org/download>. It's a single executable; no installer needed.
2. Clone this repo.
3. Open Godot, click **Import**, pick this folder's `project.godot`.
   (First open takes a few seconds while Godot builds its `.godot/` cache.)
4. Press **F5** (or the ▶ Play button) to run.

### Controls (Prototype 0)

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / Arrow keys | Left stick / D-pad |
| Toggle phone flashlight | F | Y |
| Dog: stay / follow | E | X |
| Attack (not wired up yet) | J / Space | A |

### Debug keys

| Key | Does |
|---|---|
| F2 | Cycle time of day: day / golden hour / night |
| F3 | Toggle debug overlay (FPS, positions, dog AI state, breadcrumb trail) |
| F4 | Warp the dog to the kid (unstick him) |

---

## Command line options

Godot hands everything after a bare `--` to the game:

```bash
godot --path . -- --help       # list options and quit
godot --path . -- --debug      # start with the F3 overlay on
godot --path . -- --verbose    # extra log lines (AI state changes, spawns, ...)
```

On Windows, `godot` is whatever you named the Godot executable, e.g.
`Godot_v4.7.2-stable_win64.exe`. All log output also goes to
`user://logs/godot.log` (Windows: `%APPDATA%\Godot\app_userdata\<project name>\logs\`).

---

## Tests

```bash
# Headless smoke test: walks the kid through the fenced maze and checks the
# dog keeps up (no stutter, no backtracking, no safety warps).
godot --headless --path . --fixed-fps 60 res://tests/smoke_follow.tscn
# exit code 0 = PASS, 1 = FAIL (reasons printed as [TEST] FAIL lines)

# Same test with screenshots (needs a display; on Linux CI use xvfb-run)
EVERMORE_SHOT_DIR=/tmp/shots godot --path . --fixed-fps 60 res://tests/smoke_follow.tscn
```

On Windows PowerShell, set the variable first: `$env:EVERMORE_SHOT_DIR="C:\temp\shots"`.

```bash
# Any-monitor scaling test. Headless: checks the math for 17 real monitors.
godot --headless --path . res://tests/smoke_aspect.tscn
# With a display: also checks the live window (bars, camera, HUD) at that size
godot --path . --resolution 5120x1440 res://tests/smoke_aspect.tscn

# Full matrix, 13 resolutions from Steam Deck to 48:9 triple-wide:
tests/run_aspect_matrix.sh /path/to/godot [screenshot_dir]          # Linux / CI (Xvfb)
pwsh tests/run_aspect_matrix.ps1 -Godot C:\path\to\Godot_v4.7.2-stable_win64_console.exe  # Windows
#   older GPU / VM?  add:  -ExtraArgs "--rendering-method gl_compatibility"
```

Run the tests before pushing anything that touches the kid, the dog, the
camera, the HUD, or the yard.

---

## Folder map

```
evermore2/
├── project.godot        Engine settings (384x216 pixel-perfect, autoloads)
├── autoload/            Global singletons, loaded before any scene
│   ├── debug.gd           CLI options, logging, F3 overlay
│   ├── screen_scaler.gd   Crisp integer scaling that fills ANY monitor shape
│   ├── input_setup.gd     ALL key/gamepad bindings (one readable table)
│   ├── names.gd           Every proper noun, loaded from data/names.json
│   ├── event_bus.gd       Game-wide signals (light toggled, time changed...)
│   └── game_state.gd      Player-chosen names, current realm, story flags
├── actors/
│   ├── kid/               Player character
│   └── dog/               Companion AI (breadcrumb follow + string pulling)
├── systems/camera/      GameCamera: map bounds + centering on wide screens
├── realms/
│   ├── _shared/           Pieces used by many realms (placeholder tree)
│   └── big_yard/          Prototype 0 test map (ASCII layout, throwaway)
├── ui/
│   ├── debug_overlay/     The F3 overlay
│   └── hud/               Placeholder HUD + SafeFrame (keeps HUD centered on ultrawide)
├── data/names.json      Character / place / item names (edit names HERE)
├── tests/               Automated smoke tests
└── docs/                Design bible, art spec, architecture notes
```

## Project rules (read before contributing)

1. **No hardcoded names.** Characters, places, and items come from
   `Names.text("key")`, backed by `data/names.json`.
2. **Bindings live in `autoload/input_setup.gd`**, not in Project Settings.
3. **Follow the any-screen rules** in [`docs/art-spec.md`](docs/art-spec.md) section 2
   (safe frame, apron, GameCamera, SafeFrame HUD, distance-based enemy activation).
4. **Origins at the feet.** Every actor/prop is drawn upward from (0, 0) so
   Y-sorting works. Put them under a node with `y_sort_enabled = true`.
5. **Game-wide events go through `EventBus`.** Local stuff uses normal signals.
6. **Commit `.import` and `.uid` files.** Never commit `.godot/`.
7. **Tests pass before push.**

## Docs

- [`docs/design-bible.md`](docs/design-bible.md): story, cast, realms, dog forms, mission 1
- [`docs/art-spec.md`](docs/art-spec.md): resolution, palettes, "Modern SNES" rules
- [`docs/architecture.md`](docs/architecture.md): systems overview, dog AI, roadmap

## Recommended tools

| Tool | Why |
|---|---|
| VS Code + **godot-tools** extension | GDScript editing and debugging (the repo suggests it automatically) |
| **Aseprite** (or free: Pixelorama / LibreSprite) | Pixel art and animation |
| Aseprite Wizard (Godot plugin) | Imports Aseprite animations directly |

---

*Secret of Evermore is © Square Enix. This is a non-commercial fan project.*

Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
