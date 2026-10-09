# Roadmap

What exists, what comes next, and the decisions that shape it. New feature
ideas are added here first; bugs are fixed right away. Progress is tracked by
milestone, not version: the version stays frozen while the game is designed. Story and world
decisions live in [design-bible.md](design-bible.md).

## The plan

A sequel to *Secret of Evermore* (1995), thirty years on. A 13-year-old and his
shelter dog are pulled into Evermore 2.0, a world that grows from the dreams of
whoever enters it, and Carltron wants the kid back as his "anchor". The boy who
beat Carltron in 1995 is the kid's dad. Realms (being redesigned), a dog that
changes form in each, alchemy, and the ring menu (the outline is in the design
bible).

It's drawn in **HD-2D**: pixel-art sprites in a lit 3D world, the way Square
Enix remakes its own SNES games. All art is free and credited (the LPC library),
and the game runs pixel-perfect on any monitor shape.

The first goal is a **vertical slice**: the prologue (the dare, the mansion,
Carltron waking) into the first realm.

## Next up (suggested order)

1. **The rest of the prologue**: the mansion tutorial (foyer, library, study,
   kitchen, lab), the torn clipping, Carltron waking, the flash. Needs interior
   tiles and HD-2D height (stairs, a basement). Dinner deserves a real kitchen
   instead of a black screen.
2. **The first realm** (once the realms are designed): painted in the editor,
   finding the dog, the first boss, sniff mode.

Alongside: equipment perks that do something, more formulas (with the realms'
ingredients and alchemists), the dog's look (notched floppy ear, one ear up,
the orange shelter tag).

## Later

* Night-only enemies and items (the hook is there: `ENEMY_CLOCK` / `"clock"` per spawner)
* Save system (human-readable JSON), dialogue, the hub (The Mansion That Was), the prologue
* The realms (being redesigned, see design-bible.md section 8)
* Player 2 controls the dog; rebinding, accessibility (text size, colorblind swaps, shake toggle)
* Graphics settings menu: renderer effects (fog, SSR, SSAO, DoF), aspect cap for the HUD and the view
* A web build (Compatibility renderer only, so without light shafts, reflections or blur)

## Decisions

| Date | Decision |
|---|---|
| 2026-10-09 | **Paths between the demo maps, to test scene swapping** (owner: "why not make a path between them? Good way to test scene swapping!"). The prologue street's road runs east to the test yard, the yard's shop street north to the combat arena, and back. Every future map uses the same exits |
| 2026-10-09 | **Smooth day/night enemy swap, bats in the trees** (owner). Day enemies stop respawning at dusk and leave (a hole, the edge, out of view), night enemies come in; never popping in or out in plain view. Bats hang in the oaks by day, drop out at dusk, fly back at dawn |
| 2026-10-09 | **Time of day: a clock that scripts can set or hold** (owner: "can we have it both?"). A scene can start the clock at a time, stop it for as long as the scene needs, or let it run as normal (outside villages, where the script doesn't care) |
| 2026-10-08 | **Alchemy: ingredients per cast, formulas level with use** (owner). Each cast uses up its ingredients and earns the formula experience; enough casts level it up and it gets stronger. Only the kid casts |
| 2026-10-08 | **Quick slots on the D-pad** (owner): four slots, D-pad on the gamepad, 1-4 on the keyboard; the gamepad moves with the left stick only |
| 2026-10-08 | **Ring menu, friendlier than the original** (owner: it "could be putsy"). The pain points: hunting across rings and opening it for everything. So every ring is a visible tab, and quick slots come with the Items and Alchemy rings. One menu for both: a button flips to the other's gear. First version: Equipment only |
| 2026-10-08 | **Shadows point north and stay light** (owner: "They make things hard to see"). Straight up the screen, about half strength, a higher sun (shorter shadows), cloud shadows faint. Contact shadows under characters stay |
| 2026-10-08 | **Walk by default, hold Run to run, and running costs the attack charge** (owner: "Original running took charge away from the attack"). At 0% you're winded (walking) until it refills partway. The dog pays a quarter as much ("Zoomies"). The AI partner pays nothing. (A separate stamina meter was tried first, the same day) |
| 2026-10-08 | **The sun sits in front** (camera side): shadows fall back, up the screen, and faces are lit. It was behind, throwing shadows toward the camera |
| 2026-10-07 | **Voices: one or two words, real voice actors** ("Hey!" when you talk to someone, short reactions). AI text-to-speech was tried and rejected (all of it sounded bad, the kids worst). Full voice acting is off the table for now; **babble** (per-character blips while text types) is the backup plan. The kid stays silent |
| 2026-10-07 | **Sound and music from free CC0 packs** (OpenGameArt), through a rebuildable pipeline like the art |
| 2026-10-07 | **A settings menu like a normal game**: rebindable controls, graphics, display, audio and gameplay options, saved between sessions |
| 2026-10-07 | **One public release, `tech-demo`**: a tech demo of the game mechanics for Windows and Linux, updated in place as mechanics are polished (no version numbers) |
| 2026-10-07 | **Normal and Hard playthroughs**: on Hard, prices are higher and enemies have more HP and armor and hit harder |
| 2026-10-07 | **Switch control between the kid and the dog any time**, and a **"Stay put" command** for the partner, so mazes and puzzles can need them to split up |
| 2026-10-07 | **Gameplay rules** (design-bible.md section 10): hidden items; the dog sniffs them out; stances (kid Offensive/Defensive, dog Offensive/Search); the weapon charge builds by itself, no holding a button; armor slots: head, body, legs, boots, hands, arms, and the dog's collar; text boxes fit their text |
| 2026-10-06 | **At least 8 hours of play** for the main story, with each realm built from multiple areas, challenges and mini-bosses, like the original |
| 2026-10-06 | **The first realm lineup is scrapped**, The Big Yard and Mission 1 included. Realms get redesigned; the story spine (Dad is the 1995 boy, one night, the torn clipping) stays |
| 2026-10-06 | **Versions frozen at 0.3.0 during iterative design.** No bump per change; progress is tracked by milestone below. The version moves only for a real release, when the owner asks |
| 2026-10-06 | **Public repo, bug reports only**, like Colonia: no pull requests (a workflow closes them), no feature requests. Code is MIT; art keeps its own licenses (CREDITS.md) |
| 2026-10-06 | **HD-2D presentation**: gameplay stays 2D, a 3D view draws it. F6 keeps the classic 2D view for debugging |
| 2026-10-06 | **Free assets only** (LPC library and similar); gaps are drawn in LPC style |
| 2026-10-06 | **32 px tiles, 640x360 base view** (was 16 px / 384x216), to use the LPC library |
| 2026-10-06 | **Any monitor shape**, 16:9 to 48:9 and Steam Deck, pixel-perfect: integer scaling that fills the window, no black bars |
| (design bible) | Story, cast, realms, dog forms and Mission 1 are locked in [design-bible.md](design-bible.md) section 2 |

## Done: a debug start menu

Owner's request: "Open the game with a 'Debug Menu' where you can select which
map to start with." The main scene is now `ui/debug_menu/debug_menu.tscn`,
styled like the pause and settings menus (same theme, keyboard and gamepad,
menu sounds, inside a SafeFrame):

* **Maps**: Prologue (from the start: title card, dinner, street; the
  `prologue.` flags are cleared), Prologue street (skip the intro: sets
  `prologue.intro_done`), Test yard, Combat arena. Starting one fades to black
  through `Travel.go` (new `carry` flag: nothing rides along, the party stands
  on the map's own spawn) and fades in
* **Options**: Start time (morning / day / golden / night; applies in free-clock
  maps, the prologue keeps its held story timing), Difficulty (Normal / Hard,
  the same as `--hard`), a panel of the debug keys read from `Debug.HELP_TEXT`,
  Settings and Quit. The last choice is remembered in `user://debug_menu.cfg`
  and the cursor starts on it
* `--yard` / `--arena` still skip the menu (`Debug.start_scene_for`); tests that
  load scenes directly are unaffected
* The pause menu has "Debug menu" next to Quit. When the prologue slice ends on
  "To be continued: the mansion.", the card stays 10 s (game time), then the game
  fades back to this menu with the cursor on the last choice
* Fixes: the yard's north signpost showed a right-pointing arrow (the art only
  mirrors for left); north now has its own board (`signpost_up`, built in
  `build_art.py`), and south signs show no text arrow (no art for it yet).
  `Audio.stop_music` with nothing playing no longer logs an empty-tween error
* Test: `smoke_debug_menu` (47 checks, 9 real map swaps): the pure --yard/--arena
  decision and key list, the menu builds and every map scene loads, night + Hard
  reach the yard, the pause menu returns with the cursor on the last choice, the
  start entry clears the intro flag and the street entry sets it, and the slice
  end returns to the menu. Sabotages checked (see the commit)

## Done: walking between maps

The three demo maps are joined by paths, on one shared map-exit system every
future map will use:

* Routes: the prologue street's road runs off the east edge (a signpost by it)
  to the test yard's new west path; the yard's shop street runs off the north
  edge to the combat arena; the arena's new south path leads back. The paths
  carry on through the apron woods as dirt, with no trees on them.
* A realm declares `EXITS` (an edge char -> scene + entry id), `ENTRIES` (id ->
  cell + facing; the partner stands a tile behind) and `SIGNS` in its config,
  like `TRIGGERS_BY_CHAR`. AsciiRealm validates them (exits on the edge, entries
  on open ground and never next to an exit) and builds a `MapExits` node plus an
  invisible wall past each gap.
* `Travel` (new autoload) runs the swap: input swallowed, 0.5 s fade to black
  (game time), scene change, the party placed on the entry facing into the map,
  both cameras snapped, 0.5 s fade in. It carries kid and dog HP, the attack
  charge, who you drive and Stay put (inventory, gear, stances, flags and the
  clock already lived in autoloads). Each map's CLOCK_MODE applies on arrival
  (leaving the prologue releases its hold); music crossfades from the old
  map's track (the yard's music set no longer cuts to silence first).
* No bounce back: exits ignore the leader until he has stood outside every
  exit once since arriving. Esc, the ring menu and dialogue can't start mid-swap.
* The prologue sets `prologue.intro_done` when the street fades in after dinner;
  coming back skips the title card, dinner and the arrival talk. The demo kit
  is handed out once between the yard and the arena (`START_ITEMS_FLAG`).
* Art: a signpost prop composed in `build_art.py` from the LPC Revised
  buildings siding (credited with the stalls); the place name is game text.
* Measured: new `smoke_travel` passes (4 real swaps: dog-driven street -> yard
  with HP 33/27, charge, leader and Stay put carried, clock hold -> free, HD
  camera off by 0.00 m, no bounce for 90 frames on the exit; Esc mid-fade
  ignored; yard -> arena -> yard; back to the street with no intro). Full suite
  passes. Three sabotages, each fails it: no-bounce guard off (bounced back), HP
  restore off (33 -> 40), intro flag ignored (intro replayed). Screenshots: the
  street's road east, the yard's west entrance.
* Not done: a knocked-out member arrives up at 30% HP (no carrying a KO across);
  the winded state of running isn't carried.

## Done: day and night enemies

The v0.4.0 `ENEMY_CLOCK` hook now does something. In the test yard (rats and
bats follow the clock) the cast changes with the time of day, always behind a
reason:

* Each enemy type says when it is out (`active`: day / night / always; morning
  and golden hour are day), how it goes (`leaves_by`: burrow / edge / fade /
  roost) and how it arrives (`arrives_by`: offscreen / burrow / drop / rise /
  fade), plus a `sound_cue`, `flies` and `respawn_seconds` (EnemyData).
* A `DayNightDirector` (systems/enemies/day_night.gd) runs it. Dusk: day enemies
  stop respawning, idle ones scurry to the nearest exit and are removed only
  once invisible (sunk into the hole) or outside the camera view plus a margin;
  anything fighting (aggro'd or hit in the last 6 s) stays. Dawn is the reverse.
  The swap is staggered over the 6 s fade plus 4 s, at least 0.7 s apart; night
  enemies wait 3 s into the dusk; a cue (rustle / wing flap) plays a second
  before a visible entrance.
* Bats (new, from the OGA "Bat (Rework)" sheet, OGA-BY 3.0, credited): four hang
  upside down in yard oaks by day (not hittable, an occasional twitch), drop at
  dusk, flutter, weave toward you and swoop (weak: 8 HP, 3 damage), and fly back
  and hang up at dawn.
* Measured: new `smoke_enemy_clock` passes (idle rat sank into its hole and was
  removed invisible, the fighting rat stayed, no rat respawn at night, four bats
  dropped one at a time, rats came back at dawn). Full suite passes. Three
  sabotages, each fails the test: removal guard (removed in plain view), stagger
  (gap 0.00 s), combat-stays (the fighting rat left). Screenshots: bats in oaks
  by day, a bat in flight at night.
* Found on the way: the AI partner went after hanging bats (`Enemy.is_active()`
  now excludes ENTER / LEAVE / ROOST); `smoke_follow` caught it.
* Not done: `rise` and `fade` entrances and `edge` exits exist but no map uses
  them yet; no hidden-in-the-leaves bat variant; bats share the rat's sounds.

## Released: v0.4.0 (2026-10-09)

The three milestones below: music that follows the time of day, a running
clock with two shops and night effects, and a bigger (borderless) window.

## Done: a bigger window (and borderless by default)

The window used to open at 1280x720 on every monitor. Settings > Display now has
**Window size**: Auto (default), 1280x720, 1920x1080, 2560x1440, 3840x2160.
Auto picks the largest whole multiple of 640x360 that fits the screen's usable
area with 40 px spare for the title bar (never under 1280x720) and centers the
window: 1080p monitor -> 1280x720, 1440p -> 1920x1080, 4K -> 3200x1800. Fixed
sizes too big for the screen fall back to Auto. Windowed mode only, saved with
the other settings, applied at startup; an explicit `--resolution` and headless
runs are untouched. The game now also **opens borderless fullscreen** at the
monitor's native resolution by default (`window_mode` default "borderless"; players
who saved "windowed" keep it; no hotkey); Window size applies when windowed. An
test and screenshot runs (a `res://tests/` scene) and `-- --windowed` keep a windowed, exact-size window. (First version checked for `--resolution`, but Godot strips its own options from the arguments the game sees, so screenshots came out fullscreen; fixed the same day.) `smoke_settings` checks the size math and the default.

## Done: a running clock, two shops, night effects

The day now goes by on its own: **morning, day, golden hour, night**, and
around again. A game day is 24 real minutes (6 a phase, one constant:
`Clock.DAY_MINUTES`), counted in game time, so it stops with the pause and
ring menus. Every change fades over 6 seconds (sky, sun, fog, music,
ambience, the flashlight). Owner's request: "Expand the area a bit and
include two shops. One that closes and one that stays open. Have the clock
and provide a debug button option to stop or change the clock. Make sure
there is a fade effect between day changes. Kid misses more, dog doesn't
change other than baddies might be a bit brighter or highlighted given dogs
could smell them."

* **The clock** (`autoload/clock.gd`, an autoload because time is game state:
  it outlives scene changes and shops/enemies/the kid ask it without a
  realm). Modes from the 2026-10-09 decision: *free*, *set* (jump, then run
  on), *hold* (frozen until released). Each realm picks one with
  `CLOCK_MODE`: the test yard runs free, the prologue holds (golden on the
  street, `@time night` at the dare, exactly as before).
* **Morning**, a new look in both views: soft, cool, a pale sun at 36
  degrees, a light mist. `@time morning` works in dialogue; music and
  ambience use the day tracks and birds.
* **Debug keys**: F2 next time of day (with a fade), **F7** stop/restart the
  clock, **F9** speed x1 / x10 / x60; the F3 overlay shows phase, minutes
  into it, mode and speed.
* **The test yard grew east**: through a gate in the garden fence, a dirt
  street with **two stalls** composed from the LPC Revised buildings tileset
  and two new shopkeepers (LPC generator). The corner store follows the
  clock: closed at night (keeper gone, a shutter down that says "Open again
  in the morning"). The all-night stand never closes. No money in the game,
  so each keeper hands over an item (apple, soda) once per phase. The open
  rule is per shop (`follow_clock` / `always_open` / `always_closed`) and a
  scene can override it. Two rats wait in the far corner.
* **The kid misses more at night**: a swing at something outside his
  flashlight beam misses 20% of the time ("Miss" pops up, the swing whiffs).
  In the beam, or by day: normal. The beam is the real HD spotlight (a 2D
  cone in the classic view).
* **The dog's nose at night**: while you drive the dog at night, enemies glow
  softly (2D halo, HD shader). No stat changes; off by day and while
  driving the kid.
* **Enemies and the clock**: a per-realm `ENEMY_CLOCK` and per-spawner
  setting (`follow_clock` / `unchanged`), only a hook for now; the yard's
  rats are `unchanged`.
* Test: new `smoke_clock` (phase order and wrap on game time, the fade
  measured on the HD sun mid-way, pause, hold/set/release, F7/F9, the
  prologue held, both shops by night and morning, one item per phase, night
  misses only outside the beam with seeded dice: 1000 swings miss about
  20%, the dog's glow only at night while driving him). Sabotaged: clock
  order swapped, hold ignored, beam ignored: each fails. All 15 test runs pass.

## Done: music follows the time of day

Outdoor music now follows day, golden hour and night like the ambience does.
`Audio.MUSIC_SETS` maps a place to a track list per time; `Audio.set_music_set("outdoor")`
turns it on, and a `time_of_day_changed` crossfades to that time's list. Each trip into a time
plays the next track of its list, so F2 day, night, day plays the other day track (golden shares
the day list and keeps playing). A plain `play_music()` clears the set (dinner stays "home").

* Day: "Grasslands" (Exploration1) and "Tropical Island" (Exploration6). Night: "Childhood
  Friends" (Calm2) and "Innocence" (Calm6). All Juhani Junkala's JRPG packs, CC0; two new files
  built by `tools/audio/build_audio.py`, credits updated.
* The prologue street starts at golden hour, so it opens on "Grasslands" (it used "Childhood
  Friends"); Dex's dare still sets night, which now brings the night track. The test yard uses
  the set (new realm const `MUSIC_SET`).
* Test: `smoke_audio` (day, night, day, night, day gives yard, lot, tropical, innocence, yard;
  golden keeps the day track; `play_music` clears the set). Sabotaged (rotation broken, time
  hookup removed): both fail.

## Done: a real HUD

* The text HUD is gone. Each of the duo has a **card** in a bottom corner
  (the kid left, the dog right):
  * the name, with "> " and a gold border on the one you drive; the
    partner's card shows his stance and "Stay"
  * a **health bar** that goes green, yellow, red, with the numbers beside
    it; a hit leaves a pale **ghost** of the lost health that drains away
    after a moment, so you see how much that hit took, and the bar flashes
  * his charge bar underneath (pips, winded blink)
  * knocked out: the card dims and says **KO, back in 8**, counting down
* The quick slots stay top left, the found / notice lines top middle, the
  "[E] Talk to Maya" prompt bottom middle; the cards, prompt and quick slots
  tuck away while people talk
* Found while testing: if a scene changed while someone was knocked out,
  the revive code read the freed member afterwards (a script error the
  tests didn't fail on). Fixed, and **the test runners now fail any run that
  prints a SCRIPT ERROR**, even if the test printed PASS (every test was
  clean)
* Tests: `smoke_party` HUD section (the driven marker, stance and Stay, the
  ghost appearing and draining, KO with the countdown, both cards inside the
  frame, apart, kid left). Each was proven by breaking it (5 sabotages). All
  14 runs pass
* Review fixes before merging: the taller cards could cover the kid on the
  bottom row in the classic 2D view (the 2D camera now stops a card's height
  past the bottom edge, and HdView's margin comes from the card's size); a
  heal used in the ring menu didn't show on the card until the menu closed
  (the cards keep drawing while paused). `smoke_hd` checks the bottom row
  against the cards' real top edge

## Done: the Items, Alchemy and Party rings, and quick slots

* The ring menu has all four rings as tabs (Equipment, Items, Alchemy,
  Party); Z / X or LB / RB go to the previous / next one
* **Items**: everything the party carries that isn't gear, usable things
  first, then ingredients, then key items. Confirm (E / A) uses one on
  whoever is shown; an apple isn't wasted at full health. New: apples (heal
  12) and soda (heal 30)
* **Alchemy** (owner: ingredients per cast, levels with use): the kid's
  formulas, what each costs and what you have, its level and casts to the
  next. Confirm casts it on whoever is shown (the kid can heal the dog). The
  first formula: **Heal** (1 wild carrot; 14 HP at level 1, +4 a level;
  levels at 3, 5, 8... casts). A knocked-out kid can't cast
* **Party**: both stances and Stay put; up / down change them (R / RB still
  cycle the partner's stance as a shortcut)
* **Quick slots** (owner: on the D-pad): select an item or formula and press
  1-4 / a D-pad direction to put it in a slot; outside the menu the same key
  uses it on whoever you drive. An entry lives in one slot. The HUD shows
  the four slots top left (icon, count, faded when out); a slot that can't
  fire says why ("Not enough wild carrot", "Slot 2 is empty")
* The gamepad moves with the left stick; the D-pad is the quick slots. Old
  saved controls with the D-pad on movement give it up. Dialogue choices
  also take the menu keys (the D-pad's up / down)
* The demo maps now also hand out apples, a soda and wild carrots, and the
  kid knows Heal there
* Not yet: more formulas (they wait on the realms' ingredients and
  alchemists), a casting animation, sounds for healing (the pickup sound for
  now)
* Tests: `smoke_rings` (tabs, the Items order and use, full health, key
  items, Heal on the dog, its cost, experience and level 2 healing more, no
  ingredients, a knocked-out kid, the Party ring, quick slots: assigning,
  moving, firing on the kid and the dog, an empty slot's notice on the HUD,
  nothing mid-conversation, the D-pad and old saves, dialogue keys). Each was
  proven by breaking it (13 sabotages). `smoke_items` counts carrots on top
  of the demo kit's. All 14 runs pass
* Review fixes before merging: using up the last of something could jump
  the selection past the next entry; a rebound confirm or quick-slot key
  could switch rings instead; notices covered the "Found ..." line (they
  have their own line now); the heal number showed the formula's power, not
  the HP restored; item and formula lookups are cached (the ring and the
  quick bar ask every frame); quick-slot hints show the bound keys

## Done: a weapon in his hand when he swings

* The kid used to swing empty-handed (owner: "there should be an actual stick
  in his hand"). Now the weapon is drawn with the swing: a layer behind him
  and one in front, on the swing's frame and facing, in 2D and HD-2D
* The stick is the LPC **club** (bluecarrot16), a backhand: the body's slash
  played in reverse, which is how the generator lines up that art. The rusty
  sword is the LPC **arming sword** in bronze (ElizaWy), a forward slash
* Weapons carry their art (`WeaponData.overlay_fg`, `overlay_bg`,
  `overlay_frame`); a new weapon brings its own. The art pipeline fetches the
  layers from the generator's repo, pinned to one commit
  (`tools/art/build_art.py --only weapons`), and writes the credits
* HdView mirrors extra layers an actor lists in its `hd_layers` meta, and
  swaps their texture when it changes
* Found while testing: the weapon trailed the body by one frame (the body
  animates after the kid's physics step); it now follows the body's
  `frame_changed`
* Tests: `smoke_ring` section 8 (art in the layers, behind and in front,
  hidden until the swing, following the swing frame by frame and the facing,
  put away after, a new weapon's art and frame size, HD-2D mirroring and the
  swap). Each was proven by breaking it (6 sabotages). All 13 runs pass

## Fixed: a crash when one choice menu follows another

* "Out of bounds get index '2' (on base: 'PackedStringArray')" (owner): when
  a choice menu followed another in the same frame (the prologue does), the
  old menu's labels were only queued for deletion, so the list counted old
  and new labels and read past the new options. The editor's debugger stops
  on that error, so the game seemed to crash. Old labels are detached at once
* Test: `smoke_dialogue` 4c (a menu right after a menu lists only its own
  options; moving through it stays inside them). Without the fix it fails
  with the exact same error

## Fixed: the camera lets the kid walk off the bottom of the screen

* Walking south in HD-2D, the camera stopped following about 2.7 m before
  the map's bottom edge, and the kid walked off screen (owner). The stop was
  a flat estimate of how much ground shows below the camera's center; with
  the camera tilted, the near ground fills more of the picture, so much less
  shows below than above. The south stop is now measured from the camera's
  real angle and lens, up to the top of the HUD. On the arena the camera now
  follows north-south too (it was locked to the middle)
* Measured: the kid on the last row of the yard went from y=404 (off a 360 px
  screen) to y=283; the lot and the arena the same
* Test: `smoke_hd` section 6 (the kid on the first and last rows, on screen
  and clear of the HUD, in HD-2D, classic 2D and on the short arena). It
  fails with the old estimate

## Done: the ring menu (Equipment) and equipment

* **I / gamepad Y opens the ring menu** and pauses the game: a ring of gear
  slots around whoever you drive (kid: weapon, head, body, arms, hands, legs,
  boots; dog: collar), each showing what he wears, or a faded picture of
  what goes there
* **Friendlier than the original** (the owner's pain points: hunting across
  rings, opening the menu for everything):
  * every ring is a tab you can see at the top (just Equipment for now)
  * left / right turn the ring quickly; hold to keep spinning
  * up / down change what's in the slot right away, no confirm step; the
    panel says what it is, what it does, and how your total changed ("Total
    defense 20 (+8)")
  * Tab / Back flips to the other one's gear, without switching who you drive
  * it reopens where you left off
* **Equipment**: pieces are items (`data/items/<id>.tres`, `EquipmentData`:
  wearer, slot, defense, a WeaponData for weapons, a perk line). Armor adds
  up on Health (100 halves damage); the weapon slot can't be empty; a new
  weapon changes the swing and the charge meter (and what running spends)
* **The demo kit**: the yard and the arena hand out a rusty sword (hits
  harder, charges slower, up to x2), a bike helmet, a thick hoodie, hiking
  boots, gardening gloves and a studded collar for the dog, once per run
* The gamepad flashlight moved from Y to L3 (clicking the left stick): the
  pad had no free buttons left
* Not yet: the Items, Alchemy and Party rings; quick slots; perks that do
  something (they're text for now); arms and legs pieces (the slots are there)
* Tests: `smoke_ring` (the data, a new run and the kit once, the equipment
  rules and armor cutting damage, a new weapon's swing and charge, the menu:
  opening and pausing, tabs, one step per push, hold to spin and wrap, instant
  change and the panel, taking a piece off, Tab to the dog without switching,
  Esc closing without the pause menu, reopening where you left off, not
  mid-conversation, opening on the dog when you drive him, HD-2D placement,
  and the three review fixes). Each was proven by breaking it (14 sabotages).
  All 13 runs pass
* Review fixes before merging: swapping weapons refilled an empty charge
  (swing, swap twice, swing again at full power); a weapon changed mid-swing
  hit with the new weapon's damage at the old charge (now it waits for the
  swing to end); an old saved control file kept gamepad Y on the flashlight,
  so Y did two things (saved bindings now give up anything a newer action
  uses by default)
* **Shadows, readability** (owner: "They make things hard to see"): they
  point straight north, at about half strength, with a higher sun (shorter
  shadows) and faint cloud shadows. Contact shadows under characters stay

## Done: running costs your attack charge

* **Running drains the attack charge** (owner: "Original running took charge
  away from the attack"). While you run, the charge meter doesn't fill, it
  empties: the kid spends a full level (100%) every 2 s. Run it to 0% and
  he's **winded**: he walks, even holding Run, until the charge is back to
  50%. So it's a choice: get there fast, or arrive with a big swing ready
* **The dog pays a quarter as much** (owner: "Zoomies am I right???"): a
  full level lasts him 8 s of running
* The separate stamina meter and its green bar are gone. Winded shows on the
  charge bar itself: it turns orange and blinks
* The AI partner never pays: he has to keep up with you
* Tests: `smoke_party` section 9 rewritten (walking is free, running drains
  at the set rate, 0% winds him into a walk, the charge bar shows it, the
  breath comes back at 50% with a weak swing still, the toggle cases, the dog
  at a quarter of the kid's rate, the AI kid spending nothing and keeping
  up). Each was proven by breaking it (7 sabotages). All 12 runs pass

## Done: running (walk by default)

* **Walk by default; hold Run to run** (Shift / gamepad LB, rebindable; or
  press-to-toggle in Settings > Gameplay > Run button). The kid walks at 85
  px/s and runs at 140; the dog walks at 95 and runs at 160. A partly tilted
  stick still walks slower
* First built with its own stamina meter; replaced the same day by the
  attack-charge cost above
* Toggle mode is forgiving: a toggled run ends after you stand still a
  quarter second (a keyboard turn-around passes through a frame with no key
  held), a swing doesn't cancel it, and pressing Run while standing readies
  it for your next move (found in review)
* `smoke_audio`'s footstep walk is longer now that the kid walks: at 85 px/s
  he didn't get past the dog

## Done: hidden items and the dog's nose

* **Three kinds of hidden item**, placed per map in `HIDDEN_ITEMS` (a list,
  not layout characters, because a bush cell can hide something):
  * *Buried*: only the dog finds it. Nothing shows until he's smelled it
  * *Tucked*: under a bush or rock. A glint now and then is the tell; the kid
    searches it (interact: "Search")
  * *Secret*: an item lying in a nook off the path, found by looking
* **The dog on Search stance finds them by himself**: when nothing's after him
  and an item is near him and the kid, he trots over, stops, points and barks,
  then digs a buried one up (dirt flies) or keeps pointing at the bush until
  the kid comes over. Same leash as fighting: never far from the kid, and an
  item he can't reach (a fence in the way) is skipped for a while
* **Driving the dog**: sniff (C / gamepad B) puts his nose down and shows
  scent trails, colored wisps flowing from him to the nearest three things he
  can smell: items gold, ingredients green, people blue. A buried spot he's
  smelled puffs scent and can be dug up with interact (E / A)
* **Picking up**: a found item hops out toward whoever you're driving and
  lands on the ground; walk over it to take it. The AI partner never grabs
  it, so the dog can't snatch what he dug up before you've seen it
* **The count**: finding one says "Found Old key  2/5 here" at the top of the
  screen, and the pause menu shows "Hidden items: 2 / 5" for the map you're
  in. Found items never come back (a GameState flag per item)
* Items are data (`data/items/<id>.tres`: name, description, item or
  ingredient, icon on the LPC item sheet) and go into `GameState.inventory`.
  The test yard has five demo items (an old key, a coin pouch, a shiny stone,
  a torn map, wild carrots); the real ones come with the realms
* Interaction now serves whoever you drive: things can say who may use them
  (`can_interact`). NPCs stay the kid's. The prompt shows the actual bound key
* Not yet: secret items behind breakable things (nothing breaks yet); scent
  trails run in a straight line, even through a fence; no sniff or bush-rustle
  sounds; nothing to do with ingredients until alchemy; no inventory screen
  until the ring menu; found flags last until you quit (no saves yet)
* Tests: `smoke_items` (placement and the count, buried hidden from the kid,
  the AI dig from walk-over to pickup, Offensive and the leash leave items
  alone, tucked search and pointing, sniff trails then dig while driving the
  dog, the secret item, found items stay found, the pause menu line, HD-2D
  mirroring and the hop, a stance change mid-dig, a conversation, mistakes in
  HIDDEN_ITEMS). Each was proven by breaking it: AI search off, any member
  grabbing, no sniff gate, no offset sync, no instant 3D mirror, found items
  respawning, no leash, the nose stuck after a dig, digging or picking up
  mid-conversation, an unknown item id. All 12 runs pass
* Review fixes before merging: a dig cut short by a stance change left his
  nose stuck (he stopped watching the kid); the dog could dig, and the kid
  pick up, in the middle of a conversation; a mistyped item id counted toward
  the total but never spawned (a 5/5 you could never reach)

## Done: voices (one or two words)

* Walk up and talk to someone: they say hello in their own voice. A line's
  emotion tag can add a voiced reaction ("(relieved)" -> "Okay", "(surprised)"
  -> a gasp, "(laughing)" -> a laugh, "(confused)" -> "What?")
* Characters pick a voice in their CharacterData (`voice`); Audio.VOICES lists
  each voice's clips by kind (greet, question, agree, disagree, laugh,
  surprise, bye). A missing kind plays nothing: silence beats a wrong word
* Maya: cicifyre's bright female voice (hey, hello, what, why, okay, bye, a
  laugh, a gasp). Dad: the male adventurer voice (hello, yes, no). The kid is
  silent (the player's character, like the original). Dex has no voice yet:
  there's no free boy's voice pack
* Tried first: Kokoro (a free local AI voice) reading prologue lines. Rejected
  on listening

## Done: ambience, and assets for hidden items

* **Birds by day, crickets at night**: an Ambience bus (with its own volume
  slider) and two loop players that crossfade when the time of day changes;
  a bird calls now and then by day. Maps choose it (`AMBIENCE`, "outdoor" by
  default); dinner in the prologue is indoors, so it's quiet
* The audio pipeline makes seamless loops (the end is crossfaded into the
  start: the birds track faded out at its end) and writes byte-identical files
  on a rebuild (ffmpeg's random stream serial made every rebuild rewrite every
  sound in git)
* Ready for the hidden items milestone: a digging sound, a pickup sound, and
  the LPC item icon sheet (weapons, armor, potions, food, keys, tools, maps)
  through the art pipeline

## Done: sound and music

* **An audio pipeline** (`tools/audio/build_audio.py`), like the art one: it
  downloads the CC0 packs from OpenGameArt, cuts the clips (the dog takes have
  several barks each; the cut points come from measuring them), trims, mixes
  to mono, normalizes and writes OGG files plus a credits file. Three sounds
  are generated by the script (text blip, whistle, switch chime)
* **`Audio` (autoload)**: one table of sound names, a random take each time
  and a little pitch variation so nothing repeats robotically; world sounds
  pan and fade with distance from the camera and pause with the game; menu
  sounds keep playing in the pause menu; music crossfades and loops. The
  volume sliders in Settings drive the Music and SFX buses
* **What makes noise**: the swing (deeper when charged), hits (plus the
  stick's crack on charged hits), the kid getting hurt, the rat's squeak
  before it bites (a warning you can hear), its bite, pain and death, the
  dog's bite, yelp, whine when knocked out, and bark when told to Stay put,
  the kid's whistle calling him back, footsteps (grass or the dirt road) and
  the dog's lighter paws, the switch chime, menu ticks, the text box blip
* **Music**: dinner plays "A Place I Call Home", the dare "Childhood
  Friends", the test yard "Grasslands", the arena "Preparing For Battle"
  (Juhani Junkala's JRPG packs)
* Headless runs pick and log sounds but don't play them (no audio device;
  starting them anyway leaked playbacks at exit). A new audio test checks
  every file loads and every hook fires; each hook was broken on purpose to
  confirm it fails. 11 headless runs pass

## Done: settings, and a readable golden hour

* **Pause menu** (Esc / gamepad Start): Resume, Settings, Quit to desktop. The
  game stops underneath
* **Settings**, saved to the player's settings file and applied as you change
  them, every option from one table (`autoload/settings.gd`):
  * Graphics: HD-2D or classic 2D; Low / Medium / High / Ultra presets; each
    effect on its own (shadows, light shafts and haze, water reflections,
    ambient occlusion, tilt-shift blur, bloom, pollen and fireflies, cloud
    shadows); brightness
  * Display: windowed / borderless / exclusive fullscreen, V-Sync, frame rate
    limit, widest view (for players who'd rather not see 32:9)
  * Audio: master, music, effects (the buses are ready for when sound arrives)
  * Gameplay: text speed (up to instant), screen shake (down to off), damage
    numbers
  * Controls: two keys and a gamepad button per action, rebound by pressing
    the new one; a key another action had moves over (talk and attack share
    gamepad A on purpose); reset per page
  * Works with mouse, keyboard or gamepad: left/right changes a value, LB/RB
    switches tabs
* **Golden hour was washing the screen out**: a low sun shining through thick,
  warm haze toward the camera turned everything yellow and flat. The sun sits
  higher now, the haze is thin and the shadows are lifted. The combat arena
  starts in daylight
* **Characters were dark**: the sun shines from the top of the screen toward
  the camera, so camera-facing sprites were always backlit. Characters now use
  their own material, lit like the ground they stand on, with a little lift so
  they stay the clearest thing on screen
* Tests: a new settings test (values, presets, saving and loading, every
  graphics switch reaching the 3D view, gameplay options, rebinding, the menus
  driven by key presses); each check broken on purpose to confirm it fails.
  Test runs never touch the player's settings file. 10 headless runs pass

## Done: combat, phase B (the duo)

* **Switching control**: Tab / gamepad Back hands the stick to the dog and
  back. The camera glides over in both views; the one you left follows you
  along your breadcrumb trail (the dog's follow brain is shared now:
  `systems/party/follower.gd`). If the one you drive is knocked out, control
  jumps to the other; you can't switch to a knocked-out partner
* **Stay put**: Q / gamepad X. The partner holds his spot, and it stays on
  through a switch, so the two can split up for puzzles. Press again to call
  him back (he retraces your path, or warps in if he's stuck out of sight)
* **Stances** drive the AI partner (`systems/party/partner_brain.gd`): the kid
  Offensive or Defensive, the dog Offensive or Search; R / gamepad RB cycles
  the partner's. The AI never wakes sleeping enemies and stays within 240 px
* **The dog's bite**: his own weapon data and charge meter (two levels), a
  lunge, and the hit on the bite's frame
* **HUD**: "> " marks the one you drive; the partner shows his stance and
  "Stay"; both have a charge bar; an arrow points to an off-screen partner and
  flashes red while he's being hit
* Conversations belong to the kid: starting one hands control back to him, and
  nothing is in reach to talk to while you drive the dog
* Tests: a new duo test (switching, the glide, following, Stay put through a
  switch, call-back, knockouts, every stance, the bite, the HUD, talking, the
  HD-2D camera); each check was broken on purpose to confirm it fails. The
  dog's follow numbers are unchanged after the refactor (max gap 76 px,
  1 state change, 0 warps at 30/60/120 fps). 9 headless runs pass

## Done: combat, phase A

* **The swing**: attack (J / Space / gamepad A) swings the kid's weapon with his
  LPC slash animation; the blow lands on the weapon's hit frame, in an arc in
  front of him. Talking still wins the shared button when someone's in reach
* **The auto charge**: the meter refills by itself after a swing (0.9 s per
  level for the stick) and climbs to level 2 and 3 if the weapon allows: x1, x2,
  x4 damage. Nobody holds a button. A hurried swing still does a quarter
* **Enemies**: data-driven (`EnemyData` .tres). The first is the LPC giant rat:
  it sleeps until a kid or dog comes close (distance, never "on screen"),
  chases, flashes an orange warning, lunges, rests, staggers when hit, gives up
  past its leash and walks home, and dies with its animation
* **Feel**: hit-stop on every hit (longer for bigger swings), camera shake in
  both views, damage numbers (gold for charged hits, red for hits on the kid),
  slash trails, red hit flashes, knockback
* **Health**: HP, armor, invulnerability after a hit; the HUD shows live HP for
  the kid and the dog and the kid's charge bar with level pips. Knocked out
  means down for 8 seconds, then back with 30% HP; both down restarts the scene
* **Normal and Hard**: one table of difficulty levers (enemy HP, armor, damage,
  prices); `-- --hard` starts on Hard
* **A combat arena** test map with five rats (`realms/test/combat_arena_hd.tscn`)
* Bugs caught on the way, each with a test: hit-stop ran on the wall clock and
  never ended in fast headless runs (the game stuck at 5% speed); enemies
  spawned after loading were invisible in HD-2D; effects were projected to the
  wrong spot in HD-2D (the screenshots caught it); HdView re-created the
  flashlight five times a second after a refactor, stacking 28 lights on the
  kid (the new "nothing piles up" check fails on that); a bright telegraph
  flash bloomed over the kid, so it's an orange pulse now
* Tests: 8 headless runs pass, including the new combat test

## Done: the text box fits its text

* The box grows and shrinks with the line, in both directions: as wide as its
  widest line (centered, at least a small minimum, at most the 16:9 frame) and
  as tall as the page (a portrait sets the minimum height); the name tab and
  choices follow its edges. Long text turns into pages: a press
  finishes the typing, the next turns the page, and only then does the
  conversation move on
* The wrapping is measured in the box's own font and handed to the label
  line by line, so nothing can spill out
* Tests: the dialogue test checks narrow vs wide and short vs tall boxes, centering,
  the name tab hugging the name, the portrait minimum,
  that every page fits, that no word is lost across pages, and the page-turn
  order; a fixed-size box, a stretched name tab or no paging makes it fail

## Done: dialogue, NPCs, and the prologue's first scene

* **Dialogue system**: conversations in a plain-text `.dlg` format (lines,
  narration, emotions, choices, story flags, conditions, scene commands,
  `{name}` substitution), with mistakes reported by file and line at load
* **SNES-style text box**: portrait, name tab, letter-by-letter text, choices;
  kept inside the 16:9 safe frame on ultrawide screens
* **NPCs and triggers**: walk up and press E (gamepad A) to talk; NPCs turn to
  face the kid; the HUD shows "[E] Talk to ..."; walking onto a trigger starts a
  conversation. The dog's stay command moved to Q
* **The cast**: Dad, Maya and Dex built with the LPC generator (Dad shares the
  kid's hair and skin, for the photo reveal); portraits cropped from the sprites
* **The prologue's first scene** (the new main scene): title card, dinner with
  Dad, then the street outside the overgrown Ruffleberg lot at dusk. Talk to
  Maya and Dex, take the dare, the sun sets, and the gate ends the slice
* Maps are now built by one shared `AsciiRealm` class (the test yard and the
  prologue), with several fence kinds per map (wood, wrought iron in 3D)
* Bugs caught on the way: a duplicate node name hid a broken jump from the
  error report; the text box's open guard used the wall clock and swallowed
  presses in fast headless runs; in HD-2D, the actors and NPCs were invisible
  and NPCs couldn't be talked to (the hidden 2D World made them count as
  hidden). Each has a test that fails without its fix
* Tests: 7 headless runs pass, including the new dialogue test

## Done: HD-2D, and the repo goes public

* **HD-2D**: the yard is drawn as pixel-art sprites in a lit 3D world, with real
  sun shadows, volumetric light shafts, tilt-shift depth of field, bloom, a
  reflective pond, and invisible clouds that cast drifting shadows. Day, golden
  hour and night each have their own sun, sky, fog and grade; at night the
  phone's flashlight and its screen glow keep the kid readable
* Gameplay stays 2D: the 3D view mirrors the 2D world every frame, so collision,
  the dog AI and every test work unchanged. F6 switches to the classic 2D view
* Sprites on the same row no longer z-fight: parked on an oak's row, the kid
  vanished into the trunk; with props nudged back and actors forward he draws in
  front, and the kid in front of the dog
* Effects follow the renderer: Compatibility runs the HD-2D view with no warnings
* The repo is set up for going public, like Colonia: player-facing README, bug
  report form, CONTRIBUTING, code of conduct, security policy, MIT license for
  the code, a workflow that closes outside pull requests, CI that runs the
  headless tests on every push, this roadmap, and [DEVELOPMENT.md](DEVELOPMENT.md)
* Measured: the yard renders a screenshot set in about 20 s on an RTX 5060 Ti
  (Forward+); 659 3D sprite props, 166 fence posts
* Tests: 6 headless runs pass (follow at 30/60/120 fps, visuals, HD-2D view,
  scaling math); the new HD-2D test fails when the actor sync or the view toggle
  is broken

## Done: real art

* **Real art** from the LPC library at 32 px: the kid from the LPC character
  generator, the dog (an LPC shiba recolored into a brown brindle mutt), the LPC
  Revised summer tileset and its trees, bushes, roses, rocks and pond plants
* Grass, dirt, water and fences autotile from the tileset's own terrain data; the
  test yard has a meadow, paths, a koi pond, a fenced pen and a rose garden
* Time of day with a color grade, cloud shadows, light shafts, pollen and fireflies;
  wind sway on plants; animated water, lily pads and reeds
* An art pipeline that rebuilds every imported asset from the original packs, and
  CREDITS.md with every artist and license
* Base view 640x360: 1080p, 1440p and 4K scale exactly 3x, 4x and 6x
* Dog follow test: max gap 76 px, 1 state change, 0 warps; disabling string
  pulling fails it (31 px backtrack), disabling anti-stutter fails it (157 state changes)

## Done: any monitor shape

* **Any monitor shape**, pixel-perfect: integer scaling that fills the window
  (Godot's own "expand" left 256 px bars at 5120x1440); the view grows sideways
  on ultrawide, up to 48:9 triple-wide
* An apron of scenery past the map edge, a HUD kept in a centered 16:9 frame,
  and a dog that only warps while off-screen
* Live test at 13 resolutions from Steam Deck to 48:9; removing the apron fails
  it with the empty void showing

## Done: first prototype

* Godot 4 project: the kid walks a test yard, the dog follows his path around
  fences (breadcrumbs plus string pulling, no stop-go stutter), Y-sorting, day /
  golden hour / night with a phone flashlight
* Debug tools: F3 overlay, F4 warp, `--help` / `--debug` / `--verbose`
* All names in one file (`data/names.json`)

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
