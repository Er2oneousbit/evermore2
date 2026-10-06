# Roadmap

What exists, what comes next, and the decisions that shape it. New feature
ideas are added here first; bugs are fixed right away. Story and world
decisions live in [design-bible.md](design-bible.md).

## The plan

A sequel to *Secret of Evermore* (1995), thirty years on. A 13-year-old and his
shelter dog are pulled into Evermore 2.0, a world that grows from the dreams of
whoever enters it, and Carltron wants the kid back as his "anchor". Five realms
plus a hub and a finale, a dog that changes form in each, alchemy, and the ring
menu (the full outline is in the design bible).

It's drawn in **HD-2D**: pixel-art sprites in a lit 3D world, the way Square
Enix remakes its own SNES games. All art is free and credited (the LPC library),
and the game runs pixel-perfect on any monitor shape.

The first goal is **Mission 1, "Lost Dog"**, as a vertical slice: the Big Yard,
control alternating between kid and dog, and the Vacuum boss.

## Next up (suggested order)

1. **Combat (v0.4)**: a weapon swing with the charge meter, using the kid's LPC
   slash animations; one enemy (a squirrel, drawn in LPC style because none
   exists); hit-stop, damage numbers, enemy activation by distance.
2. **Ring menu + the first alchemy formula (v0.5)**: data-driven `.tres` resources.
3. **The real Big Yard (v0.6)**: painted in the editor with the same tileset and
   PropData; HD-2D height (stairs, ledges, a raised patio); wading in shallow water.
4. **Mission 1 vertical slice (v0.7)**: alternating kid/dog control, sniff mode,
   the Vacuum boss.

Alongside: the dog's look (notched floppy ear, one ear up, the orange "Kennel 13"
tag), and a real HUD in place of the placeholder text.

## Later

* Save system (human-readable JSON), dialogue, the hub (The Mansion That Was), the prologue
* The other realms: Saltreach, Frostheim, Vernia, The Grand Carlton, The Off Switch
* Player 2 controls the dog; rebinding, accessibility (text size, colorblind swaps, shake toggle)
* Graphics settings menu: renderer effects (fog, SSR, SSAO, DoF), aspect cap for the HUD and the view
* A web build (Compatibility renderer only, so without light shafts, reflections or blur)

## Decisions

| Date | Decision |
|---|---|
| 2026-10-06 | **Public repo, bug reports only**, like Colonia: no pull requests (a workflow closes them), no feature requests. Code is MIT; art keeps its own licenses (CREDITS.md) |
| 2026-10-06 | **HD-2D presentation**: gameplay stays 2D, a 3D view draws it. F6 keeps the classic 2D view for debugging |
| 2026-10-06 | **Free assets only** (LPC library and similar); gaps are drawn in LPC style |
| 2026-10-06 | **32 px tiles, 640x360 base view** (was 16 px / 384x216), to use the LPC library |
| 2026-10-06 | **Any monitor shape**, 16:9 to 48:9 and Steam Deck, pixel-perfect: integer scaling that fills the window, no black bars |
| (design bible) | Story, cast, realms, dog forms and Mission 1 are locked in [design-bible.md](design-bible.md) section 2 |

## Done (v0.3.0)

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

## Done (v0.2.0)

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

## Done (v0.1.0)

* **Any monitor shape**, pixel-perfect: integer scaling that fills the window
  (Godot's own "expand" left 256 px bars at 5120x1440); the view grows sideways
  on ultrawide, up to 48:9 triple-wide
* An apron of scenery past the map edge, a HUD kept in a centered 16:9 frame,
  and a dog that only warps while off-screen
* Live test at 13 resolutions from Steam Deck to 48:9; removing the apron fails
  it with the empty void showing

## Done (v0.0.1)

* Godot 4 project: the kid walks a test yard, the dog follows his path around
  fences (breadcrumbs plus string pulling, no stop-go stutter), Y-sorting, day /
  golden hour / night with a phone flashlight
* Debug tools: F3 overlay, F4 warp, `--help` / `--debug` / `--verbose`
* All names in one file (`data/names.json`)

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
