# Developing Secret of Evermore 2

Setup, commands, tests, the art pipeline and the project's rules. What the game
is and how it plays is in the [README](../README.md); what's next is in
[ROADMAP.md](ROADMAP.md).

## The one hard rule: no Square Enix material

This is a fan project. Nothing from *Secret of Evermore* or any other commercial
game goes in the repo: no ripped art, sound, music, text, maps or data. Names of
the original's characters and places are referenced as fan canon only. All art
comes from free libraries with licenses that allow redistribution (see
[CREDITS.md](../CREDITS.md)) or is written for this project.

## Setup

1. **Install Godot 4.7.x (standard build, not .NET)** from
   <https://godotengine.org/download>. It's a single executable; no installer needed.
   On Windows, keep the `*_console.exe` from the same zip: it's the one to use
   from a terminal (the normal exe is a GUI app and doesn't pass output or exit
   codes back to the shell).
2. Clone this repo.
3. Open Godot, click **Import**, pick this folder's `project.godot`.
   (First open takes a few seconds while Godot builds its `.godot/` cache.)
4. Press **F5** (or the ▶ Play button) to run. The main scene is
   `realms/big_yard/yard_hd.tscn`.

**Renderer:** use the default Forward+ (a GPU with Vulkan or Direct3D 12).
Light shafts, pond reflections and ambient occlusion need it. Older GPU or a VM?
Run with `--rendering-method gl_compatibility`: it works, with fewer effects
(table in [art-spec.md](art-spec.md)).

After adding or changing assets or `class_name` scripts from outside the editor,
run `godot --headless --path . --import` once so new classes resolve.

## Commands

Godot hands everything after a bare `--` to the game:

```bash
godot --path . -- --help       # list options and quit
godot --path . -- --debug      # start with the F3 overlay on
godot --path . -- --verbose    # extra log lines (AI state changes, time of day, ...)
godot --path . --rendering-method gl_compatibility   # a Godot flag, BEFORE the --
```

All log output also goes to `user://logs/godot.log`
(Windows: `%APPDATA%\Godot\app_userdata\<project name>\logs\`).

## Debug keys

| Key | Does |
|---|---|
| F2 | Cycle time of day: day / golden hour / night |
| F3 | Debug overlay: version, FPS, view size and scale, HD-2D or 2D, renderer, positions, dog AI state, breadcrumb trail |
| F4 | Warp the dog to the kid (unstick him) |
| F6 | Toggle the HD-2D view / classic 2D view |

## Tests

Run them before pushing anything that touches actors, the camera, the HUD, a
realm or the art plumbing. CI runs the headless set on every push
(`.github/workflows/ci.yml`). Exit code 0 = PASS, 1 = FAIL; failures print as
`[TEST] FAIL` lines that say what went wrong.

```bash
# Everything headless in one go
tests/run_all.sh /path/to/godot
pwsh tests/run_all.ps1 -Godot C:\path\to\Godot_v4.7.2-stable_win64_console.exe   # Windows

# One at a time
godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_follow.tscn   # dog follow AI
godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_visuals.tscn  # animation, Atmosphere, props
godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_hd.tscn       # HD-2D view mirrors the 2D game
godot --headless --path . --audio-driver Dummy res://tests/smoke_aspect.tscn                  # scaling math, 18 monitors

# Live any-monitor check at one size, or the 13-resolution matrix (needs a display; Xvfb on Linux)
godot --path . --resolution 5120x1440 res://tests/smoke_aspect.tscn
tests/run_aspect_matrix.sh /path/to/godot [screenshot_dir]
pwsh tests/run_aspect_matrix.ps1 -Godot C:\path\to\..._console.exe   # sizes up to your own desktop

# Screenshot tour: fixed viewpoints at each time of day (needs a display)
EVERMORE_SHOT_DIR=/tmp/shots godot --path . --resolution 1280x720 res://tests/screenshot_tour.tscn
#   EVERMORE_TOUR_SPOTS=start,pond,pen,garden  EVERMORE_TOUR_TIMES=day,golden,night  EVERMORE_TOUR_VIEW=2d
```

On Windows PowerShell, set variables first: `$env:EVERMORE_SHOT_DIR="C:\temp\shots"`.

The headless renderer draws nothing, so tests check logic and structure; how
things *look* is checked with the screenshot tour. A fix comes with a test that
fails without it (each existing check was proven that way; see
[architecture.md](architecture.md)).

## Art pipeline

All art is from the **LPC (Liberated Pixel Cup)** library and friends: free
licenses that need credit. Nothing imported is edited by hand; every crop,
recolor and composition is a script, so the art can be rebuilt and the license
trail never breaks.

| What | Source | Rebuild with |
|---|---|---|
| The kid | Universal LPC Character Generator (teen body, red longsleeve, jeans) | `node tools/lpc/build_character.js kid <out dir>` |
| The dog | LPC shiba by Sevarihk, recolored into a brown brindle mutt | `python3 tools/art/build_art.py --only dog` |
| Ground tiles + autotile data | LPC Revised summer tileset (JaidynReiman's Tiled build) | `python3 tools/art/build_art.py --only tileset` |
| Trees, bushes, flowers, rocks, pond plants | LPC Revised 4-Season Terrain (Eliza Wyatt et al.) | `python3 tools/art/build_art.py --only props` |
| 3D fence wood (HD-2D) | Crops of the LPC Revised tileset | `python3 tools/art/build_art.py --only hd` |

* **Change the kid's outfit:** build him in the
  [web generator](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/),
  put the URL part from `#` on into `tools/lpc/characters.json`, run the command
  above, and copy `sheet.png` / `credits.*` where the JSON says
  ([tools/lpc/README.md](../tools/lpc/README.md)).
* **Add a prop:** a few lines in `build_props()` in `tools/art/build_art.py`
  (crop box, sway, collision), or a `PropData` resource made in the inspector.
  Then use it from a realm's `PROPS_BY_CHAR`.
* **Redesign the test yard:** edit the ASCII `LAYOUT` in
  `realms/big_yard/prototype_yard.gd`. Shores, path edges, fences and the pond's
  lily pads and reeds all follow from it, in both views.
* **Credit it in the same commit:** `CREDITS.md` and `credits/`.

Art tools need Python 3.9+ with Pillow (`pip install pillow`) and, for the kid
only, Node 18+ with Playwright. Playing and testing the game needs neither.
On Windows, Python writes CRLF unless a file is opened with `newline=''`;
`.gitattributes` keeps the repo LF.

## Code style and rules

1. **No hardcoded names.** Characters, places and items come from
   `Names.text("key")`, backed by `data/names.json`.
2. **Bindings live in `autoload/input_setup.gd`**, not in Project Settings.
3. **Any-screen rules** in [art-spec.md](art-spec.md) section 2: safe frame,
   apron, GameCamera, SafeFrame HUD, enemies activate by distance.
4. **Origins at the feet.** Draw upward from (0, 0) under a `y_sort_enabled` parent.
5. **2D draw layers by z_index:** ground -20, flat decals -15, shadows -10,
   Y-sorted world 0. In HD-2D, same-row ties use the depth biases in `HdView`.
6. **Game-wide events go through `EventBus`** (past-tense names); local events
   use normal signals. Story flags: `"<realm>.<thing>"` via `GameState.set_flag()`.
7. **Logging** via `Debug.log_info/verbose/warn/error`.
8. **Static typing** in GDScript; match the surrounding code; comments explain why.
9. **File headers:** new scripts, shaders and tools open with a WHAT / WHY /
   HOW block ending in the "Written with help from Claude (Anthropic) via Claude
   Code." and "Made with ❤️ from your friendly hacker - er2oneousbit" lines.
   No model names in files. No em dashes in docs or comments.
10. **Commit `.import` and `.uid` files.** Never commit `.godot/`.

## Branches, versions and releases

* `main` is always green. Work happens on a branch, merged to `main` with a
  merge commit ("Merge <what>: <summary>"). No pull requests.
* Versions are `0.MINOR.PATCH` in `project.godot` (`application/config/version`,
  shown in the F3 overlay). After 0.9.x comes 0.10.0; 1.0 only when the owner
  says the game is ready.
* **Release checklist:** bump `config/version` in `project.godot`; add a
  "Done (vX)" entry at the top of the Done list in [ROADMAP.md](ROADMAP.md)
  (what changed, what was measured, test results); run the tests; commit as
  `vX.Y.Z: <summary>` on `main`.
* Commit messages say why, and what was measured.

## Where things live

```
evermore2/
├── project.godot        Engine settings (640x360 base, autoloads, version)
├── autoload/            Debug, ScreenScaler, InputSetup, Names, EventBus, GameState
├── actors/              kid/ (player), dog/ (companion AI)
├── systems/
│   ├── animation/         DirectionalSprite, LpcSprite (characters), AnimalSprite
│   ├── atmosphere/        Time of day: tint, color grade, clouds, pollen, fireflies
│   ├── camera/            GameCamera: map bounds + centering on wide screens
│   └── hd2d/              HdView: draws a 2D realm as an HD-2D 3D scene
├── realms/
│   ├── _shared/           Prop + PropData, WangAutotiler (used by every realm)
│   └── big_yard/          prototype_yard (2D game) + yard_hd (HD-2D view, main scene)
├── assets/              characters/, tilesets/, props/, shaders/, textures/hd/, fx/
├── data/                names.json, props/ (PropData .tres), tilesets/ (autotile lookups)
├── credits/             Original credit files from each art pack (Godot ignores this)
├── tools/               art/ (build_art.py), lpc/ (character export), tiled/ (tsx to JSON)
├── ui/                  debug_overlay/ (F3), hud/ (placeholder HUD + SafeFrame)
├── tests/               Smoke tests, runners, screenshot tour
└── docs/                design-bible, art-spec, architecture, ROADMAP, this file
```

## Troubleshooting (development)

| Symptom | Fix |
|---|---|
| A test run prints nothing on Windows | Use the `*_console.exe` Godot build |
| "Identifier not found" for a `class_name` after pulling | `godot --headless --path . --import` |
| A shader change does nothing / the scene is pink | Shader errors only show at runtime; check the log. (`flat` is a reserved word in Godot shaders) |
| Screenshots are blank in headless mode | Headless can't render; run with a display (Xvfb on Linux; Mesa lavapipe works for Forward+, slowly) |
| Godot warns about volumetric fog / SSR / DoF | You're on Compatibility or Mobile; HdView turns those off by itself, so a warning means a new effect skipped `renderer_caps()` |

## Recommended tools

| Tool | Why |
|---|---|
| VS Code + **godot-tools** extension | GDScript editing and debugging (the repo suggests it) |
| **Aseprite** (or free: Pixelorama / LibreSprite) | Drawing LPC-style art for gaps (no LPC squirrel exists) |
| Python 3 + Pillow | Running `tools/art/build_art.py` |
| [Tiled](https://www.mapeditor.org/) | Browsing the LPC Revised `.tsx` tilesets and their terrain sets |

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
