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
│   ├── Dialogue     Runs .dlg conversations, owns the text box          [done]
│   ├── Interaction  What the kid would talk to; drives the HUD prompt   [done]
│   ├── Settings     Player options (one table), saved, applied live     [done]
│   ├── Audio        Sounds by name, world/menu pools, music crossfade   [done]
│   ├── PauseMenu    Esc / Start: Resume, Settings, Quit                 [done]
│   ├── Difficulty   Normal/Hard levers in one table                     [done]
│   ├── Fx           Damage numbers, slash trails, hit-stop, shake       [done]
│   ├── Party        Kid + dog: switching, Stay put, stances, knockouts  [done]
│   └── Economy      Per-realm currencies, exchange rates, trade routes [todo]
│   (Audio: "SFX" and "Music" buses under Master; Settings sets their volume)
│
├── Actors
│   ├── Kid          LPC sprite, run/walk by stick tilt, flashlight     [done]
│   │                Weapon swing, auto charge, health                   [done]
│   │                Alchemy casting                                     [todo]
│   ├── Dog          AI partner or driven, bite, sniff, sprite          [done]
│   │                Sniff, forms, P2 control, commands                 [todo]
│   ├── Npc          Talks when interacted with, faces the kid           [done]
│   └── Enemy        Data-driven: wake by distance, chase, telegraph,    [done]
│                    attack, recover, hurt, return home, die
│
├── Systems
│   ├── GameCamera       World bounds; centers maps narrower than screen [done]
│   ├── SafeFrame        Keeps HUD in a centered, aspect-capped area     [done]
│   ├── DirectionalSprite 4-direction sheet animation (LpcSprite,        [done]
│   │                    AnimalSprite)
│   ├── Atmosphere       Time of day: tint, grade, clouds, particles     [done]
│   ├── HdView           HD-2D presentation of a 2D realm (3D view)      [done]
│   ├── Prop / PropData  Data-driven world props (.tres)                 [done]
│   ├── WangAutotiler    Terrain + fence autotiling from Tiled data      [done]
│   ├── Alchemy          Formula + Ingredient resources, mastery         [todo]
│   ├── RingMenu         The radial menu                                 [todo]
│   ├── DogForms         Per-realm form resources                        [todo]
│   ├── AsciiRealm       Builds a realm from an ASCII LAYOUT + constants  [done]
│   └── DialogueScript/Runner  .dlg parsing and playback (data-driven)   [done]
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
| 0 | The 2D world (with the realm's CanvasModulate tint); in HD-2D mode the 3D view renders underneath and the 2D world is hidden | yes |
| 3 | Ambient particles (pollen, fireflies) - follow the camera, no tint | yes |
| 5 | Combat FX (Fx): damage numbers, slash trails, projected through the live camera | no |
| 4 | Color grade full-screen pass (Atmosphere) | - |
| 10 | HUD | no |
| 100 | Debug overlay | no |

## 3. How a realm is built

Every map is an `AsciiRealm` (`realms/_shared/ascii_realm.gd`): a subclass
declares constants (`LAYOUT`, `PROPS_BY_CHAR`, `FENCES`, `NPCS_BY_CHAR`,
`TRIGGERS_BY_CHAR`, `DIALOGUE`...) and the base class builds the rest; settings
a realm leaves out come from `AsciiRealm.DEFAULTS`. The test yard
(`realms/big_yard/prototype_yard.gd`) and the prologue
(`realms/podunk/ruffleberg_lot.gd`) share every line of builder code. The steps:

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

## 3b. HD-2D view (`systems/hd2d/hd_view.gd`)

**Gameplay is 2D, the picture is 3D.** `realms/big_yard/yard_hd.tscn` (the
main scene) holds the normal 2D realm plus an `HdView` node that draws it:

```
YardHD (Node)
├── Yard (the 2D realm: tiles, props, kid, dog, collision, Atmosphere, HUD)
│     └── World / Ground / Water   <- hidden while HD is on, still simulated
└── HdView (Node3D)
      ├── Ground   plane with the 2D ground baked into a texture (once, at load)
      ├── Water    glossy plane over the water pixels (SSR reflections)
      ├── Props    one sprite quad per 2D Prop (shared mesh/material per type)
      ├── Fences   3D posts + rails built from LAYOUT
      ├── Kid/Dog  Sprite3Ds copying the 2D sprites' frame + position each frame
      ├── Camera   perspective, follows the kid, clamped to the map
      └── Sun, flashlight, phone glow, WorldEnvironment, particles, cloud shadows
```

Why mirror instead of rewriting gameplay in 3D: collision, the dog AI, every
test, and the ASCII level builder keep working unchanged, and the 2D view
stays one key away (F6) for debugging. Height (stairs, cliffs) can come later
as per-tile elevation in the view without touching the simulation.

Time of day still comes from the realm's `Atmosphere` (F2). In HD mode its 2D
layers are switched off (`render_2d = false`) and `HdView` maps the same time
names to its own 3D presets.

**Same-row depth ties.** 2D Y-sort settles ties by draw order; in 3D, two
upright sprites on the same row sit at the same depth and z-fight. HdView
nudges props 3 cm back and actors 1-2 cm forward. Verified by parking the kid
on an oak's row: without the nudge he disappears into the trunk.

## 3c. Dialogue and NPCs

```
.dlg file ──DialogueScript (parse, line-numbered errors)──> nodes
                                   │
Npc.interact() / DialogueTrigger ──> Dialogue.start(file, node)
                                   │      (autoload, one conversation at a time)
                       DialogueRunner.advance() ──> line / choices / end
                          │ @set/@clear -> GameState flags
                          │ @command    -> Dialogue.command -> the scene
                                   v
                       DialogueBox (CanvasLayer 20, inside a SafeFrame)
                       portrait (CharacterData crop), name, typed text, choices
```

* **Who's talking** comes from `data/characters/<ID>.tres` (`CharacterData`):
  name key, sprite sheet, portrait crop. The ID is the speaker in `.dlg` files.
* **While someone talks** the kid ignores movement (it reads
  `Dialogue.is_active()`), the HUD hides, and the box takes interact/attack and
  up/down. The box's open guard and typing use game time, never the wall clock,
  so they behave the same at any frame rate and in headless tests.
* **Interaction** (autoload) picks the nearest node in group `interactable`
  within reach and not behind the kid; the HUD shows its `interact_label()`.
  It checks each node's *own* visibility: in HD-2D mode the 2D World is hidden
  on purpose and its NPCs must stay talkable (a bug the screenshots caught).
* **HdView** mirrors every node in group `hd_actor` (kid, dog, NPCs), with the
  same rule: the actor's own visibility, not the hidden World's.

## 3d. Combat

```
attack pressed -> Kid.attack(): ChargeMeter.spend() -> [multiplier, level]
   LPC swing animation ... frame == WeaponData.hit_frame
   -> Combat.strike(origin, facing, reach, arc, "player", _make_hit, level)
        Combat.hits_in_arc(): every Hurtbox of the other team inside the slice
        Hurtbox.receive(HitInfo) -> Health.take_hit() (armor, i-frames)
                                 -> actor.on_hit() (knockback, flash, stagger)
        Fx: damage numbers, hit-stop, shake        (Enemy attacks use the same path)
```

* **No physics overlaps for hits.** At the impact frame the attacker asks for
  every hurtbox in its arc: exact, frame-rate proof, and easy to test.
* **Teams** ("player", "enemy") decide who can hurt whom.
* **Enemy** is one generic actor reading an `EnemyData` resource; its stats
  pass through `Difficulty`. It wakes by distance from the party, never by
  being on screen (ultrawide players must not wake more enemies).
* **Party** (autoload) knows the kid and the dog; a knocked-out member gets back
  up after 8 s with 30% HP, both down restarts the scene. Control switching,
  Stay put and stances come next (phase B).
* **HD-2D**: enemies are `hd_actor`s; HdView picks up actors that appear after
  load (every 0.2 s) and drops them when they leave. Hit flashes and the orange
  telegraph mirror through `modulate`. Keep sprite colors at or below 1.0:
  brighter-than-white trips the bloom and haloes everything nearby.

## 3e. The duo: who drives, who follows

```
Party (autoload)  leader = the one the stick drives, partner() = the other
   switch_control -> controlled flags, partner's Follower.target = leader,
                     Camera2D reparented to the leader and glides (HdView
                     follows Party.leader's 3D sprite)
   staying        -> partner's Follower in STAY (survives a switch)
   stances        -> GameState.kid_stance / dog_stance

Kid / Dog each frame:
   controlled ? stick input
              : PartnerBrain.think(stance, staying)
                  enemy worth fighting? (awake, near the leader / within reach)
                     -> approach, face, attack() when the charge is ready
                  else -> Follower.steer()  (the breadcrumb follow below)
```

### Hidden items and the nose

```
AsciiRealm HIDDEN_ITEMS -> HiddenItem (buried / tucked) or ItemPickup (secret),
                           skipped if its found flag is set
Dog, AI on Search, nothing after him:
   Nose.think: item near him AND near the leader? GO -> POINT (bark)
               -> buried: Dog.dig -> HiddenItem.reveal
               -> tucked: pointed = true, HOLD until the kid comes
Dog, driven: sniff -> Nose.sniff -> Fx.scent_trail x3, buried ones sniffed
             interact on a sniffed spot -> Dog.dig
HiddenItem.reveal -> ItemPickup.pop (hops toward Party.leader)
ItemPickup: Party.leader touches it -> GameState inventory + flag,
            EventBus.item_found -> HUD "Found X  n/m here"
```

## 4. Follow AI (how it works)

`systems/party/follower.gd`, used by whichever member the AI plays (the dog
behind the kid, or the kid behind the dog after a switch).

1. The leader drops a **breadcrumb** every 10 px of movement.
2. The follower walks crumb to crumb (it goes around fences the same way the
   leader did).
3. **String pulling:** every 0.1 s the follower sweeps its own collision box
   toward crumbs, newest first, and skips to the furthest reachable one. Open
   ground = straight line; fences = it still walks the corners.
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
| `tests/smoke_dialogue.tscn` | no | .dlg parsing and errors, the runner (choices, flags, conditions, commands, loop guard), every game script loads, talking to Maya in 2D and HD-2D |
| `tests/smoke_combat.tscn` | no | Charge meter math, health/armor, difficulty levers, the swing (front only, x1 to x4), enemies (wake by distance, telegraph, bite, team rules, death), talk beats attack, rats and late spawns in HD-2D |
| `tests/smoke_party.tscn` | no | Switching (camera glide, following), Stay put through a switch and call-back, knockout hand-off, every stance, the dog's bite, the HUD marker and partner arrow, talking belongs to the kid, the HD-2D camera follows the leader |
| `tests/smoke_settings.tscn` | no | Settings values and presets, save/load round trip, every graphics switch reaching HdView, gameplay options, rebinding, pause and settings menus driven by key presses |
| `tests/smoke_audio.tscn` | no | Every sound and music file loads, per-frame limit, every gameplay hook makes its sound (swing, hits, rat, dog, footsteps by surface, whistle, switch), music per map and crossfades, menu ticks and the text blip |
| `tests/smoke_items.tscn` | no | Hidden items: placement and the count, the dog finding and digging on Search, the leash and Offensive leaving items alone, tucked search and pointing, sniff trails then dig while driving the dog, only the driven one picks up, found items stay found, the pause menu line, HD-2D mirroring and the hop |
| `tests/smoke_ring.tscn` | no | Equipment data and rules (only owned pieces that fit, the weapon slot never empty, armor adding up and cutting damage, a new weapon's swing and charge), the demo kit once, the ring menu (pause, tabs, one step per push, hold to spin, instant change and its panel, Tab to the dog, Esc, not mid-conversation, HD-2D placement) |
| `tests/smoke_rings.tscn` | no | The Items, Alchemy and Party rings (use, cast, cost, experience and levels, stances, Stay put), quick slots (assign, move, fire on whoever you drive, notices, not mid-conversation), the D-pad moving to quick slots and old saves, dialogue keys |
| `tests/smoke_hd.tscn` | no | HD-2D view mirrors every prop/fence/actor, depth tie order, camera on map, F6 swap, time of day reaches 3D lights |
| `tests/smoke_aspect.tscn` | part B only | Scaling math (18 monitors); live bars, void, camera, HUD |
| `tests/run_aspect_matrix.sh` / `.ps1` | yes (Xvfb on Linux) | smoke_aspect at 13 resolutions |
| `tests/screenshot_tour.tscn` | yes | Not a test: renders docs screenshots from fixed viewpoints (HD-2D by default, `EVERMORE_TOUR_VIEW=2d` for 2D) |

## 6. Roadmap

Moved to [ROADMAP.md](ROADMAP.md): the plan, what's next, decisions, and a
"Done" entry per milestone. Developer setup and the release checklist are in
[DEVELOPMENT.md](DEVELOPMENT.md).

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
