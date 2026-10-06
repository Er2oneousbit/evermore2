# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Fan sequel to *Secret of Evermore* (SNES, 1995): a top-down action RPG in **Godot 4.7.x, GDScript**, rendered in an **HD-2D** style (pixel-art sprites in a lit 3D world). There's no build step: open `project.godot` and press F5. Story and world decisions live in `docs/design-bible.md`; if something isn't there, it isn't decided. "Locked" rows there need the user's sign-off to change.

## Commands

Godot isn't on PATH. Every command takes the executable path. On Windows use `Godot_v4.7.2-stable_win64_console.exe`: the GUI exe doesn't pass output or exit codes back to the shell. Run `--headless --path . --import` once after adding or changing assets or `class_name` scripts, or new classes won't resolve.

```bash
tests/run_all.sh <godot>                                   # all headless tests (Linux/macOS)
pwsh tests/run_all.ps1 -Godot <godot_console.exe>          # same on Windows
<godot> --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_hd.tscn   # one test
tests/run_aspect_matrix.sh <godot> [shot_dir]              # live 13-resolution check (needs Xvfb)
EVERMORE_SHOT_DIR=<dir> <godot> --path . --resolution 1280x720 res://tests/screenshot_tour.tscn
#   tour env: EVERMORE_TOUR_SPOTS=start,pond,pen,garden  EVERMORE_TOUR_TIMES=day,golden,night  EVERMORE_TOUR_VIEW=2d
python3 tools/art/build_art.py [--only tileset,props,hd,dog,credits] [--offline]   # rebuild imported art
node tools/lpc/build_character.js kid <out_dir>            # re-export the kid from the LPC generator
```

Tests print `[TEST] PASS ...` or `[TEST] FAIL <reason>` and exit 0/1. The headless (dummy) renderer draws nothing, so anything visual (screenshots, aspect "part B", the HD ground bake) needs a real display. Judge looks from the screenshot tour, not from tests.

## Architecture

**Gameplay is 2D; the HD-2D picture is a view of it.** The main scene `realms/big_yard/yard_hd.tscn` holds a normal 2D realm (`prototype_yard.tscn`) plus an `HdView` node (`systems/hd2d/hd_view.gd`). HdView:
- bakes the 2D ground tiles and decals into one texture on a 3D plane
- turns every 2D `Prop` into a sprite quad and builds 3D fences from `LAYOUT`
- copies the kid's and dog's 2D sprite frame and position into `Sprite3D`s every frame

Collision, AI and tests all run on the 2D world. F6 toggles to the classic 2D view. Mapping: 32 px = 1 m, 2D `(x, y)` maps to 3D `(x, 0, y)`. Same-row 2D Y-sort ties would z-fight in 3D, so `PROP_DEPTH_BIAS`, `KID_DEPTH_BIAS` and `DOG_DEPTH_BIAS` order props < dog < kid. Keep that ordering for any new actor.

**Realms are built from ASCII.** `prototype_yard.gd` turns its `LAYOUT` const into the level:
- *Terrain:* `WangAutotiler` (`realms/_shared/`) reads `data/tilesets/lpc_summer_wang.json`, which `tools/tiled/tsx_wang_to_json.py` extracts from the LPC Revised Tiled `.tsx`. Corner sets cover grass/dirt/water, edge sets cover fences. A cell grid is converted to a corner grid where the strongest terrain wins, and A,B,A,B checkerboard corners are fixed up because LPC has no tiles for them.
- *Props:* placed from `PROPS_BY_CHAR`. Each is a `PropData` `.tres` in `data/props/` (texture/region, `base` ground point, footprint, shadow, sway, animation frames, `ground_decal`). A deterministic per-cell hash picks variants, jitter and flips.
- *Apron:* decorative woods outside the map, with no physics, so ultrawide screens never show void.

`HdView` reads `LAYOUT` and `FENCE_CHAR` through `get_script_constant_map()`; they're script constants, not properties.

**Mood.** Each realm's `Atmosphere` node (`systems/atmosphere/`) owns the time of day (F2) and announces it on `EventBus.time_of_day_changed`. In HD mode its 2D layers are off (`render_2d = false`) and HdView maps the same time names to its own `PRESETS`. `HdView.renderer_caps()` gates volumetric fog, SSR, SSAO and DoF by renderer: Forward+ gets everything, Compatibility gets none of those.

**Screens.** The `ScreenScaler` autoload picks the largest integer scale that fits the 640x360 base, then grows the view to fill any aspect, from Steam Deck up to 48:9. In HD mode `native_3d = true` renders 3D at window resolution while 2D stays integer-scaled. The HUD lives in a `SafeFrame` (centered 16:9).

**Sprites.** `DirectionalSprite` (`systems/animation/`) plays 4-direction sheet animations with the origin at the feet. Two layouts:
- `LpcSprite`: the Universal LPC 832x3456 sheet, used for the kid.
- `AnimalSprite`: LPC 2022 animal sheets, used for the dog.

**Dog AI** (`actors/dog/dog.gd`) follows a breadcrumb trail with periodic "string pulling": a shape-cast to the furthest reachable crumb. Hysteresis margins stop stop-go stutter. It warps to the kid only while off-screen. `tests/smoke_follow` fails if string pulling or anti-stutter is disabled; check it still does after changing either.

Autoloads load in this order: `Debug` (CLI `--debug`/`--verbose`/`--help`, logging, F3 overlay), `ScreenScaler`, `InputSetup`, `Names`, `EventBus`, `GameState`.

## Rules

- **No hardcoded proper nouns.** Use `Names.text("key")`, backed by `data/names.json`.
- **Input bindings live only in `autoload/input_setup.gd`'s `BINDINGS` table**, not in Project Settings.
- **Origin at the feet.** Draw upward from (0, 0) under a `y_sort_enabled` parent.
- **2D z_index layers:** ground -20, flat decals -15, shadows -10, Y-sorted world 0.
- **Game-wide events go through `EventBus`**, named in the past tense. Story flags are `"<realm>.<thing>"` via `GameState.set_flag()`.
- **Use `Debug.log_info/verbose/warn/error`**, not bare `print`.
- **Commit `.import` and `.uid` files; never commit `.godot/`.**
- **Never hand-edit imported art.** Crops, recolors and compositions go in `tools/art/build_art.py`. Every new third-party asset is credited in `CREDITS.md` and `credits/` in the same commit; LPC licenses require it.
- **Any-screen rules** (`docs/art-spec.md` section 2): gameplay-critical content fits a 640x360 frame around the kid, every map gets an apron, enemies activate by distance and never by "on screen", and the HUD sits inside a `SafeFrame`.
- **Prove fixes.** When fixing a behavior, add or adjust a test that fails with the fix disabled, and confirm it fails. That's how every existing check was validated.
- **File header style.** New scripts, shaders and tools start with a header block: WHAT / WHY / HOW or USAGE, ending with:
  - `Written with help from Claude (Anthropic) via Claude Code.`
  - `Made with ❤️ from your friendly hacker - er2oneousbit`

  (Shaders use `<3`.) Comments explain *why*. Don't put model names in files.
- **Docs and prose:** no em dashes. Update `README.md`, `docs/art-spec.md` and `docs/architecture.md` when behavior or structure changes.

## Gotchas

- `flat` is a reserved word in Godot shaders. Shader compile errors only appear at runtime, so load the scene to check.
- `.gitattributes` forces LF. Python on Windows writes CRLF unless you open files with `newline=''`.
- `git rm` of every file in a folder deletes the folder; recreate it before copying files back in.
- Long heredocs in the Bash tool can get truncated. Write scripts to the scratchpad with the Write tool and run them.
- The main scene's ground texture is baked at runtime, so screenshots and visual checks need a GPU or a virtual display. Under Xvfb, Forward+ works with Mesa lavapipe (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`), but slowly.
