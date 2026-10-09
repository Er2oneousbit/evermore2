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
   `realms/podunk/ruffleberg_lot_hd.tscn` (the prologue). The test yard is
   `realms/big_yard/yard_hd.tscn` (run it with `godot --path . res://realms/big_yard/yard_hd.tscn`).

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
| F2 | Next time of day: morning / day / golden hour / night (with a fade) |
| F3 | Debug overlay: version, FPS, view size and scale, HD-2D or 2D, renderer, positions, dog AI state, breadcrumb trail |
| F4 | Warp the dog to the kid (unstick him) |
| F6 | Toggle the HD-2D view / classic 2D view |
| F7 | Stop / restart the game clock (a day is 24 minutes at x1; F3 shows phase, minutes, mode, speed) |
| F9 | Clock speed: x1 / x10 / x60 |

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

A run that prints a `SCRIPT ERROR` fails, even if the test printed PASS.

To prove a new check catches its bug, break the code and run the test:
`python tools/dev/sab.py FILE OLD NEW smoke_x` replaces OLD with NEW, runs
the test, prints its result and always restores the file.

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

## Dialogue and NPCs

Conversations are plain-text `.dlg` files in `data/dialogue/`. The full format
is in the header of `systems/dialogue/dialogue_script.gd`; the short version:

```
== maya                          a node (NPCs and triggers start one by name)
MAYA: You actually came.         SPEAKER: text  (speaker = data/characters/MAYA.tres)
MAYA (relieved): Good.           an emotion (portrait variant; falls back)
: The fridge hums.               narration
KID: Hi, {dog}.                  {kid}/{dog} = the player's names; {key} = data/names.json
* "Easy." -> dex_easy            a choice (consecutive * lines = one menu)
* [prologue.talked_to_maya] ...  [flag] / [!flag] = only when the flag is set / not set
@set prologue.dared              story flags (GameState); @clear flag
@time night 4                    any other @command goes to the scene
-> END                           jumps; a node ends when it runs out of lines
```

Mistakes are reported with file and line when the script loads, and
`tests/smoke_dialogue` loads every `.dlg` file and checks that every speaker has
a character file. Proper nouns go in `data/names.json`, never in the script text.

* **A new character:** build them with the LPC generator (add a recipe to
  `tools/lpc/characters.json`, run `node tools/lpc/build_character.js <key> <dir>`,
  copy the sheet to `assets/characters/<key>/` and the credits to `credits/<key>/`,
  credit them in `CREDITS.md`), add their name to `names.json`, then make
  `data/characters/<ID>.tres` (a `CharacterData`). The portrait is cropped from
  the sheet automatically. The character tool warns (exit code 3) if the
  generator ignored a part of the recipe because of a misspelled item or color.
* **An NPC in an AsciiRealm:** a letter in `LAYOUT` plus an `NPCS_BY_CHAR` entry
  (`{"id": "MAYA", "start": "maya", "facing": Vector2.DOWN}`) and the realm's
  `DIALOGUE` file. Elsewhere: drop `actors/npc/npc.tscn` in a scene.
* **A conversation that starts when you walk somewhere:** a `TRIGGERS_BY_CHAR`
  letter, or a `DialogueTrigger` node.
* **Scene commands** (`@time`, `@end_slice`, ...) are handled by the scene's
  script, connected to `Dialogue.command`.
* **Exports:** `.dlg` files aren't a Godot resource type, so when export presets
  are added, include `*.dlg` in the export's resource filter.

## Combat

* **Weapons** are `WeaponData` resources in `data/weapons/`: damage, reach, arc,
  the LPC swing animation and the frame the blow lands on, the highest charge
  level (1-3) and how fast the meter fills.
* **Enemies** are `EnemyData` resources in `data/enemies/`: the sprite sheet and
  its animations (idle, walk, attack, die), stats before difficulty, and the
  attack's timing (aggro and leash radius, telegraph length, cooldown). Place one
  with a letter in an AsciiRealm's `ENEMIES_BY_CHAR`, or `Enemy.create(data, pos)`.
* **Difficulty** levers are one table in `autoload/difficulty.gd`. Code asks for
  numbers (`Difficulty.enemy_hp(base)`), never "is this Hard?". Start on Hard
  with `godot --path . -- --hard`.
* **The arena** for trying it: `godot --path . res://realms/test/combat_arena_hd.tscn`.
* **Effects** (damage numbers, slash trails) go through `Fx`, which projects
  world positions through whichever camera is live, so they sit right in both
  the 2D and the HD-2D view. Anything timed (hit-stop, typing, guards) counts
  frame time, never the wall clock.

## The duo (Party)

* **Party** (autoload) knows the kid and the dog, who the player drives
  (`Party.leader`) and who the AI plays (`Party.partner()`), Stay put, and the
  stances (stored in `GameState.kid_stance` / `dog_stance`). Ask it, don't keep
  your own copy: `Party.switch_control()`, `Party.set_staying()`,
  `Party.stance_of(member)`.
* Both members have a `controlled` flag (Party sets it), a `Follower` (the
  breadcrumb follow, `systems/party/follower.gd`) and a `PartnerBrain`
  (stances, `systems/party/partner_brain.gd`). The Follower reads its tuning
  from the member's exports (`follow_distance`, `walk_speed`, ...).
* Keys: Tab / gamepad Back switches, Q / X is Stay put, R / RB cycles the
  partner's stance, C / B sniffs (driving the dog), Shift / LB runs.
* Running: `Running` (`systems/party/running.gd`) on the kid and the dog
  spends their `ChargeMeter`. After the usual `charge.tick(delta)`,
  `run.tick(delta, run.wants_run(moving, delta), moving)` returns whether he
  runs this frame (and then takes back the refill and drains). Tune with each
  actor's `move_speed` (walk), `run_speed`, `run_charge_drain` (levels per
  second). Tests that drive the kid somewhere move at the walk speed unless
  they hold `run`, and holding it empties his charge.
* In a test that measures one member's attack, freeze the other
  (`set_physics_process(false)`): the AI partner on Offensive joins any fight.

## Equipment and the ring menu

* A new piece of gear: a `data/items/<id>.tres` with script
  `systems/items/equipment_data.gd` (`EquipmentData`: `wearer` kid/dog,
  `slot`, `defense`, `weapon` for weapons, `perk`). It must be owned
  (`GameState.inventory`) to be worn. Slots per wearer: `Equipment.SLOTS`.
* Put things on in code with `Equipment.equip(who, slot, piece)`; the Kid and
  Dog re-apply on `EventBus.equipment_changed`. What's worn:
  `GameState.equipped`.
* Demo maps can hand out gear with `START_ITEMS` (once per run).
* A weapon's look in hand: `overlay_fg` / `overlay_bg` / `overlay_frame` on its
  WeaponData, from the LPC generator (add it to `WEAPON_ART` in
  `tools/art/build_art.py`, run `--only weapons,credits`). One row per
  direction, one column per frame of its `swing_anim` in play order (check
  the generator's `sources/custom-animations.ts` for which body frames the art
  was drawn against: the club's are the slash reversed).
* `RingMenu` (autoload, `ui/menus/ring_menu.gd`) pauses the tree; its
  directions are polled (a stick sends a stream of motion events). New rings
  go in `RINGS` and show as tabs.

## Items, alchemy and quick slots

* A usable item: `use_effect = "heal"` and `use_power` on its ItemData.
* A formula: `data/formulas/<id>.tres` (`FormulaData`: costs, effect, power,
  power_per_level, icon). The kid learns it with `Usables.learn(id)`; demo
  maps can teach some with `START_FORMULAS`.
* `Usables` (`systems/items/usables.gd`) is the one place that uses items,
  casts and fires quick slots; each returns "" or why it didn't work.
* Quick slots: `GameState.quick_slots` ("item:<id>" / "formula:<id>"),
  `quick_1`..`quick_4` actions (1-4, D-pad). The gamepad D-pad doesn't move.

## Hidden items and the dog's nose

* Hide items in a map with `HIDDEN_ITEMS` (see the header of
  `realms/_shared/ascii_realm.gd`): `{"cell": Vector2i(9, 3), "kind":
  "buried", "item": "old_key"}`. Kinds: `buried` (open ground; the dog digs),
  `tucked` (on a prop cell: under that bush or rock), `secret` (lying in a
  nook). The map refuses to load with a clear error if one sits somewhere it
  can't (a buried item on a fence, a tucked one with no prop).
* New items: a `data/items/<id>.tres` (`ItemData`: name, description, `item`
  or `ingredient`, `icon_cell` on `assets/items/lpc_items.png`, a 16x16 grid).
* `HiddenItem` (buried, tucked) and `ItemPickup` (on the ground; only
  `Party.leader` grabs it) live in `systems/items/`, with `Nose` (the dog's
  Search-stance finding and the sniff button). Found flags:
  `realm.hidden_key(cell)`; counts: `realm.hidden_counts()`.
* Interactables can say who may use them: `func can_interact(who) -> bool`.
  Without it, only the kid (talking is his).
* Effects for tells: `Fx.glint`, `Fx.scent_puff`, `Fx.dirt`, `Fx.scent_trail`.

## Settings and the pause menu

* Every option is a row in `Settings.SCHEMA` (`autoload/settings.gd`): key,
  tab, label, type (`choice`, `bool`, `range`) and default. The settings menu
  builds itself from that table, so a new row shows up with no UI work.
* Read options with `Settings.get_value("bloom")` and react to
  `Settings.changed(key, value)`. Settings applies its own (window, window
  size, V-Sync,
  frame cap, widest view, volumes, bindings); HdView, Atmosphere, Fx and the
  dialogue box apply theirs.
* Window size (windowed mode only): Auto picks the biggest whole multiple of
  640x360 that fits the screen's usable area (40 px kept for the title bar,
  minimum 1280x720) and centers the window; fixed sizes that don't fit fall
  back to it. An explicit `--resolution` on the command line wins; headless
  runs skip it. The math is `Settings.auto_window_size` / `resolve_window_size`.
* Saved to `user://settings.cfg` (on Windows:
  `%APPDATA%\Godot\app_userdata\Secret of Evermore 2- Return to Evermore`).
  Delete it to get the defaults back.
* Tests never read or write it: a run whose scene is under `res://tests/`
  keeps settings in memory, on the defaults.
* Rebinding goes through `InputSetup` (`REBINDABLE`, `rebind`,
  `bindings_of`); `pause` (Esc / Start) is fixed so nobody can lock
  themselves out of the menu.
* F6 flips the View setting, so it's remembered like the menu option.

## Sound and music

* Play a sound by name: `Audio.play_at("swing", global_position)` in the
  world, `Audio.play("ui_move")` for menus and the HUD. Music:
  `Audio.play_music("lot")`, or set `const MUSIC := "lot"` on an AsciiRealm.
* The names live in `Audio.SOUNDS` (`autoload/audio.gd`): files, volume, pitch
  variation. Enemies name theirs in their EnemyData (`sound_windup`,
  `sound_attack`, `sound_hurt`, `sound_death`).
* New files come from `tools/audio/build_audio.py` (`SFX` and `MUSIC`
  tables): add a row, run it, commit the OGG files and
  `credits/audio/credits.txt`. Needs numpy, soundfile, ffmpeg and 7-Zip.
* Voices: give a character a voice in its CharacterData (`voice = "bright"`).
  It says hello when you start talking to it, and emotion tags in .dlg lines
  play reactions (`Audio.EMOTION_VOICE`). New voices: add clips to the
  pipeline's `VOICE` table and a set to `Audio.VOICES`.
* Ambience: `Audio.set_ambience("outdoor")` (or `const AMBIENCE := ""` on an
  AsciiRealm for silence). The loop follows the time of day by itself
  (`Audio.AMBIENCE_SETS`); the pipeline's `AMBIENCE` table makes the loops.
* Headless runs don't play anything; tests listen to `Audio.played` instead.

## The tech demo release

There's one release, **`tech-demo`**: a tech demo of the game mechanics,
updated in place (no version numbers while the design iterates). The Release
workflow (`.github/workflows/release.yml`) runs the tests, exports Windows and
Linux builds, starts each exported build on every demo map (any `ERROR`
fails it), packages them with the launchers and `README.txt` from
`tools/release/`, and replaces the files on the release.

To update it, either:

```sh
git tag -f tech-demo && git push -f origin tech-demo
```

or Actions → Release → **Run workflow** on `main`. The notes on the release
page come from `tools/release/release_notes.md`.

To export locally, install the Godot 4.7.2 export templates (Editor →
Manage Export Templates), then:

```sh
godot --headless --path . --export-release Windows export/windows/Evermore2.exe
godot --headless --path . --export-release Linux export/linux/Evermore2.x86_64
```

Exports only include Godot resources. Files the game reads itself (like the
`.dlg` dialogue scripts) must be listed in `include_filter` in
`export_presets.cfg`, or the exported game can't find them.

The demo maps can be started from the command line: `-- --arena`,
`-- --yard` (and `--hard`), in the editor build and the exported one.

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
* **Versions are frozen** at the value in `project.godot`
  (`application/config/version`, shown in the F3 overlay) while the game is
  being designed. Changes don't bump it.
* **Progress** goes in [ROADMAP.md](ROADMAP.md): when a piece of work lands, add
  a "Done: <milestone>" entry at the top of the Done list (what changed, what
  was measured, test results).
* **A real release** happens only when the owner asks for one: then the version
  is bumped (after 0.9.x comes 0.10.0; 1.0 only when the owner says the game is
  ready), the Done entry names the version, and the commit on `main` is
  `vX.Y.Z: <summary>`.
* Commit messages say why, and what was measured.

## Where things live

```
evermore2/
├── project.godot        Engine settings (640x360 base, autoloads, version)
├── autoload/            Debug, ScreenScaler, InputSetup, Names, EventBus, GameState,
│                        Dialogue (conversations, text box), Interaction (talk prompts)
├── actors/              kid/ (player), dog/ (companion AI), npc/ (people who talk)
├── systems/
│   ├── animation/         DirectionalSprite, LpcSprite (characters), AnimalSprite
│   ├── atmosphere/        Time of day: tint, color grade, clouds, pollen, fireflies
│   ├── camera/            GameCamera: map bounds + centering on wide screens
│   ├── dialogue/          .dlg parser, runner, CharacterData, DialogueTrigger
│   └── hd2d/              HdView: draws a 2D realm as an HD-2D 3D scene
├── realms/
│   ├── _shared/           AsciiRealm (builds maps from text), Prop + PropData, WangAutotiler
│   ├── podunk/            The prologue: ruffleberg_lot (+ _hd, the main scene)
│   └── big_yard/          The test yard (tech demo): prototype_yard + yard_hd
├── assets/              characters/, tilesets/, props/, shaders/, textures/hd/, fx/
├── data/                names.json, dialogue/ (.dlg), characters/ (CharacterData),
│                        props/ (PropData .tres), tilesets/ (autotile lookups)
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
