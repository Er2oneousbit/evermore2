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

1. **Ring menu, equipment and the first alchemy formula**: data-driven `.tres`
   resources; armor slots (kid: head, body, legs, boots, hands, arms; dog: collar).
2. **The rest of the prologue**: the mansion tutorial (foyer, library, study,
   kitchen, lab), the torn clipping, Carltron waking, the flash. Needs interior
   tiles and HD-2D height (stairs, a basement). Dinner deserves a real kitchen
   instead of a black screen.
3. **The first realm** (once the realms are designed): painted in the editor,
   finding the dog, the first boss, sniff mode.

Alongside: the dog's look (notched floppy ear, one ear up, the orange shelter
tag), and a real HUD in place of the placeholder text.

## Later

* Save system (human-readable JSON), dialogue, the hub (The Mansion That Was), the prologue
* The realms (being redesigned, see design-bible.md section 8)
* Player 2 controls the dog; rebinding, accessibility (text size, colorblind swaps, shake toggle)
* Graphics settings menu: renderer effects (fog, SSR, SSAO, DoF), aspect cap for the HUD and the view
* A web build (Compatibility renderer only, so without light shafts, reflections or blur)

## Decisions

| Date | Decision |
|---|---|
| 2026-10-08 | **Walk by default, hold Run to run, with a stamina meter** (owner: "like the original"). Running drains it; run it dry and you're winded until it refills. The AI partner doesn't use stamina |
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

## Done: running and stamina

* **Walk by default; hold Run to run** (Shift / gamepad LB, rebindable; or
  press-to-toggle in Settings > Gameplay > Run button). The kid walks at 85
  px/s and runs at 140; the dog walks at 95 and runs at 160. A partly tilted
  stick still walks slower
* **Stamina**: running drains a meter (about 4 s for the kid, 5 s for the
  dog); after a short breath it refills (2.5 s from empty). Run it dry and
  he's **winded**: he walks even holding Run until it's back to 35%
* The HUD shows a thin green bar above the charge bar of whoever you drive,
  only while it isn't full; winded, it turns orange and blinks
* Each has his own meter, and a switch doesn't refill it. The AI partner uses
  none: he has to keep up with you (the kid follows a running dog fine)
* The meter keeps refilling while the dog bites, digs or sniffs
* Toggle mode is forgiving: a toggled run ends after you stand still a
  quarter second (a keyboard turn-around passes through a frame with no key
  held), a swing doesn't cancel it, and pressing Run while standing readies
  it for your next move (found in review)
* Tests: `smoke_party` section 9 (walk pace and cycle, run pace and cycle,
  drain, winded walk, recovery, the bar showing and hiding, toggle mode and
  its turn-around, swing and arming cases, the dog's own meter, the AI using
  none and keeping up, no refill on a switch). Each was proven by breaking it
  (10 sabotages). `smoke_audio`'s footstep walk
  is longer now that the kid walks: at 85 px/s he didn't get past the dog. All
  12 runs pass

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
