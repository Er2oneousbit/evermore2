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

1. **Combat**: a weapon swing with the **auto-filling charge meter** (no
   holding a button), using the kid's LPC slash animations; one test enemy;
   hit-stop, damage numbers, enemy activation by distance; the **stances**
   (kid: Offensive/Defensive, dog: Offensive/Search) for whoever the AI plays.
2. **Hidden items and the dog's nose**: buried, tucked and secret items; the
   dog's Search stance points and digs; sniff mode shows scent trails; a found
   counter per area.
3. **Ring menu, equipment and the first alchemy formula**: data-driven `.tres`
   resources; armor slots (kid: head, body, legs, boots, hands, arms; dog: collar).
4. **The rest of the prologue**: the mansion tutorial (foyer, library, study,
   kitchen, lab), the torn clipping, Carltron waking, the flash. Needs interior
   tiles and HD-2D height (stairs, a basement). Dinner deserves a real kitchen
   instead of a black screen.
5. **The first realm** (once the realms are designed): painted in the editor,
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
