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
│   ├── Kid          Movement, facing, flashlight                       [done]
│   │                Weapons, charge attack, alchemy casting            [todo]
│   ├── Dog          Breadcrumb follow, string pulling, stay            [done]
│   │                Sniff, forms, P2 control, commands                 [todo]
│   └── Enemies      State machine: idle → patrol → chase → attack      [todo]
│
├── Systems
│   ├── GameCamera   World bounds; centers maps narrower than screen    [done]
│   ├── SafeFrame    Keeps HUD in a centered, aspect-capped area        [done]
│   ├── Alchemy      Formula + Ingredient resources, mastery            [todo]
│   ├── RingMenu     The radial menu                                    [todo]
│   ├── DogForms     Per-realm form resources                           [todo]
│   └── Dialogue     Data-driven                                        [todo]
│
└── Content
    ├── realms/      One folder per realm
    └── data/        .tres resources + names.json
```

## 2. Conventions

| Rule | Why |
|---|---|
| No hardcoded names; use `Names.text("key")` | Renames and localization are a one-file edit |
| Bindings only in `input_setup.gd` | Readable, diffable, rebinding menu edits one place |
| Actor origin = feet | Y-sort works automatically |
| Y-sorted things live under a `y_sort_enabled` parent | Walking behind trees/props |
| Game-wide events via `EventBus`, past-tense names | Systems don't need references to each other |
| Story flags: `"<realm>.<thing>"` via `GameState.set_flag()` | Groups nicely in save files |
| Logging via `Debug.log_info/verbose/warn/error` | Greppable prefixes, `--verbose` gating |
| Static typing in GDScript | Catches mistakes at parse time, faster code |
| Commit `.import` + `.uid` files, never `.godot/` | Stable asset IDs across machines |
| Follow the any-screen rules in art-spec.md section 2 | 16:9 through 48:9 must all play right |

### Physics layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | Fences, water, tree trunks, walls |
| 2 | kid | The kid's body |
| 3 | dog | The dog's body |
| 4 | enemies | (future) |

The kid and the dog only collide with **world**, so they never block each other.

## 3. Dog follow AI (how it works)

1. The kid drops a **breadcrumb** every 6 px of movement.
2. The dog walks crumb to crumb (it goes around fences the same way the kid did).
3. **String pulling:** every 0.1 s the dog sweeps its own collision box toward
   crumbs, newest first, and skips to the furthest reachable one. Open ground =
   straight line; fences = it still walks the corners.
4. **Anti-stutter:** a dead zone before getting up again (`resume_margin`),
   easing near the target gap (`slowdown_range`), and a walk/sprint dead zone
   (`catch_up_margin`).
5. **Safety net:** beyond `warp_distance` the dog warps to the kid, but only
   while off-screen (on ultrawide he can be visible 600+ px away, and a visible
   dog sprints instead). Past `hard_warp_distance` he warps regardless.
   `warp_count` shows on the F3 overlay; it should stay 0 in normal play.

`tests/smoke_follow.gd` checks all of this. Each fix was verified by disabling
it and confirming the test fails:

| Fix disabled | Test result |
|---|---|
| String pulling | FAIL: dog backtracks at start |
| Anti-stutter | FAIL: 100+ state changes on the route |
| (all on) | PASS: max gap ~52 px, 3 state changes, 0 warps |

## 4. Roadmap

| Milestone | Contents |
|---|---|
| **Prototype 0** (done) | Kid movement, dog follow, Y-sort, lighting, debug tools, smoke test |
| **Prototype 0.1** (done) | Any-screen scaling (16:9 to 48:9), GameCamera, apron, HUD SafeFrame, aspect tests |
| Prototype 1 | Combat: weapon swing + charge meter, one enemy type, hit-stop, damage |
| Prototype 2 | Ring menu + first alchemy formula (data-driven `.tres` resources) |
| Prototype 3 | Real tileset + TileMapLayer for the Big Yard; first real sprites |
| Prototype 4 | Mission 1 vertical slice: alternating kid/dog control, the Vacuum boss |
| Later | Save system, dialogue, hub mansion, prologue |

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
