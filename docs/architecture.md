# Architecture

How the code is organized, why, and what comes next.

---

## 1. Big picture

```
GAME
├── Autoloads (global singletons, loaded in this order)
│   ├── Debug        CLI options, leveled logging, F3 overlay          [done]
│   ├── ScreenScaler Integer scaling that fills any monitor shape       [done]
│   ├── InputSetup   Every key/gamepad binding in one table             [done]
│   ├── Names        Proper nouns from data/names.json                  [done]
│   ├── EventBus     Game-wide signals                                  [done]
│   ├── GameState    Player names, current realm, story flags          [done]
│   ├── SaveManager  JSON save/load (human-readable for debugging)      [todo]
│   └── Economy      Per-realm currencies, exchange rates, trade routes [todo]
│
├── Actors
│   ├── Kid          LPC sprite, run/walk by stick tilt, flashlight     [done]
│   │                Weapons, charge attack, alchemy casting            [todo]
│   ├── Dog          Breadcrumb follow, string pulling, stay, sprite    [done]
│   │                Sniff, forms, P2 control, commands                 [todo]
│   └── Enemies      State machine: idle → patrol → chase → attack      [todo]
│
├── Systems
│   ├── GameCamera       World bounds; centers maps narrower than screen [done]
│   ├── SafeFrame        Keeps HUD in a centered, aspect-capped area     [done]
│   ├── DirectionalSprite 4-direction sheet animation (LpcSprite,        [done]
│   │                    AnimalSprite)
│   ├── Atmosphere       Time of day: tint, grade, clouds, particles     [done]
│   ├── Prop / PropData  Data-driven world props (.tres)                 [done]
│   ├── WangAutotiler    Terrain + fence autotiling from Tiled data      [done]
│   ├── Alchemy          Formula + Ingredient resources, mastery         [todo]
│   ├── RingMenu         The radial menu                                 [todo]
│   ├── DogForms         Per-realm form resources                        [todo]
│   └── Dialogue         Data-driven                                     [todo]
│
└── Content
    ├── realms/      One folder per realm (+ _shared/ building blocks)
    ├── assets/      Images, shaders (built by tools/art from original packs)
    └── data/        names.json, PropData .tres, tileset lookups
```

## 2. Conventions

| Rule | Why |
|---|---|
| No hardcoded names; use `Names.text("key")` | Renames and localization are a one-file edit |
| Bindings only in `input_setup.gd` | Readable, diffable, rebinding menu edits one place |
| Actor origin = feet | Y-sort works automatically |
| Y-sorted things live under a `y_sort_enabled` parent | Walking behind trees/props/fences |
| Draw layers by z_index: ground -20, decals -15, shadows -10, world 0 | Shadows never cover actors; decals never Y-sort |
| Game-wide events via `EventBus`, past-tense names | Systems don't need references to each other |
| Story flags: `"<realm>.<thing>"` via `GameState.set_flag()` | Groups nicely in save files |
| Logging via `Debug.log_info/verbose/warn/error` | Greppable prefixes, `--verbose` gating |
| Static typing in GDScript | Catches mistakes at parse time, faster code |
| Commit `.import` + `.uid` files, never `.godot/` | Stable asset IDs across machines |
| Imported art is only changed by `tools/art/build_art.py` | Reproducible; credits stay correct |
| Follow the any-screen rules in art-spec.md section 2 | 16:9 through 48:9 must all play right |

### Physics layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Fences, pond, tree trunks, rocks, bushes |
| 2 | kid | The kid's body |
| 3 | dog | The dog's body |
| 4 | enemies | (future) |

The kid and the dog only collide with **world**, so they never block each other.

### Rendering layers (CanvasLayer index)

| Layer | What | Graded? |
|---|---|---|
| 0 | The world (with the realm's CanvasModulate tint) | yes |
| 3 | Ambient particles (pollen, fireflies) - follow the camera, no tint | yes |
| 4 | Color grade full-screen pass (Atmosphere) | - |
| 10 | HUD | no |
| 100 | Debug overlay | no |

## 3. How a realm is built (the Big Yard test map)

`realms/big_yard/prototype_yard.gd` turns an ASCII `LAYOUT` into a world:

1. **Terrain.** Each cell's character maps to a terrain (grass, dirt, water).
   `WangAutotiler.vertices_from_cells()` turns that into a corner grid (the
   strongest terrain wins at each corner, then "checkerboard" corners LPC
   has no tiles for are fixed up). Tiles come from the LPC Revised Tiled
   terrain data, converted to JSON by `tools/tiled/tsx_wang_to_json.py`.
   Water goes on its own layer with animated tiles + a shimmer shader.
2. **Fences.** Edge-based autotiling (posts connect to neighbors), Y-sorted
   with actors, thin collision that hugs the rails, light occluders so the
   flashlight casts their shadows.
3. **Props.** Letters place `PropData` resources (`data/props/big_yard/`):
   sprite, ground point, collision, shadow, wind sway, animation frames.
   Deterministic hashes pick variants, nudges and flips, so the yard looks the
   same every run. Plain grass gets scattered flower/tuft decals; the pond
   gets lily pads and reeds automatically.
4. **Apron.** Woods beyond the fence (decor only, no physics) for wide screens.
5. **Mood.** The scene's `Atmosphere` node: CanvasModulate tint, color grade,
   cloud shadows, light shafts, particles. F2 cycles day / golden / night.

Real realms will be painted in the Godot editor with the same tileset and
PropData; the ASCII builder is scaffolding for prototypes.

## 4. Dog follow AI (how it works)

1. The kid drops a **breadcrumb** every 10 px of movement.
2. The dog walks crumb to crumb (it goes around fences the same way the kid did).
3. **String pulling:** every 0.1 s the dog sweeps its own collision box toward
   crumbs, newest first, and skips to the furthest reachable one. Open ground =
   straight line; fences = it still walks the corners.
4. **Anti-stutter:** a dead zone before getting up again (`resume_margin`),
   easing near the target gap (`slowdown_range`), and a walk/sprint dead zone
   (`catch_up_margin`).
5. **Safety net:** beyond `warp_distance` the dog warps to the kid, but only
   while off-screen (on ultrawide he can be visible 900+ px away, and a visible
   dog sprints instead). Past `hard_warp_distance` he warps regardless.
   `warp_count` shows on the F3 overlay; it should stay 0 in normal play.
6. **Animation:** walk while following, run while catching up, stand (facing
   the kid) when idle or told to stay.

`tests/smoke_follow.gd` checks all of this. Each fix was verified by disabling
it and confirming the test fails:

| Fix disabled | Test result |
|---|---|
| String pulling | FAIL: dog backtracks 31 px at the start (kid dips below him, then heads east) |
| Anti-stutter | FAIL: 157 state changes on the route |
| (all on) | PASS: max gap ~76 px, 1 state change, 0 warps (same at 30/60/120 render fps) |

## 5. Tests

| Test | Needs a display? | Checks |
|---|---|---|
| `tests/run_all.sh` / `.ps1` | no | Runs every headless test below in one go |
| `tests/smoke_follow.tscn` | no | Dog follow AI on the pen route, stay command, night + flashlight |
| `tests/smoke_visuals.tscn` | no | LPC animation rows, Atmosphere presets/particles, Prop building |
| `tests/smoke_aspect.tscn` | part B only | Scaling math (18 monitors); live bars, void, camera, HUD |
| `tests/run_aspect_matrix.sh` / `.ps1` | yes (Xvfb on Linux) | smoke_aspect at 13 resolutions |
| `tests/screenshot_tour.tscn` | yes | Not a test: renders docs screenshots from fixed viewpoints |

## 6. Roadmap

| Milestone | Contents |
|---|---|
| **Prototype 0** (done) | Kid movement, dog follow, Y-sort, lighting, debug tools, smoke test |
| **Prototype 0.1** (done) | Any-screen scaling (16:9 to 48:9), GameCamera, apron, HUD SafeFrame, aspect tests |
| **Prototype 0.2** (done) | Real art: LPC kid/dog/tiles/props at 32 px, art pipeline + credits, Atmosphere (grade, clouds, particles), animated water |
| Prototype 1 | Combat: weapon swing + charge meter, a squirrel enemy (LPC-style art), hit-stop, damage numbers |
| Prototype 2 | Ring menu + first alchemy formula (data-driven `.tres` resources) |
| Prototype 3 | The real Big Yard map painted in the editor; wading in shallow water |
| Prototype 4 | Mission 1 vertical slice: alternating kid/dog control, the Vacuum boss |
| Later | Save system, dialogue, hub mansion, prologue |

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
