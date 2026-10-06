# Secret of Evermore 2: Return to Evermore

[![CI](https://github.com/Er2oneousbit/evermore2/actions/workflows/ci.yml/badge.svg)](https://github.com/Er2oneousbit/evermore2/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A fan sequel to *Secret of Evermore* (Square, 1995): a top-down action RPG
about a kid, his shelter dog, and a world built from dreams. Thirty years after
the original, Professor Ruffleberg's machine wakes up again, and so does Carltron.

It's drawn the way Square Enix remakes its own SNES classics (Octopath
Traveler, Dragon Quest III HD-2D): pixel-art sprites standing in a lit 3D world,
with real sun shadows, light shafts through the trees, tilt-shift blur, a
reflective pond and drifting cloud shadows. It runs pixel-perfect on any
monitor, from a Steam Deck to a 48:9 triple-wide.

> **Early prototype (v0.3.0).** A kid explores a backyard at day, golden hour
> and night, with his dog following him. No combat, menus or story yet. See the
> [roadmap](docs/ROADMAP.md) for what's next.

| Golden hour | Koi pond | Rose garden |
|---|---|---|
| ![golden hour](docs/screenshots/hd_golden_start.png) | ![pond](docs/screenshots/hd_golden_pond.png) | ![garden](docs/screenshots/hd_golden_garden.png) |

| Night: flashlight, fireflies, the phone's glow | Day: the fenced pen |
|---|---|
| ![night](docs/screenshots/hd_night_pond.png) | ![day](docs/screenshots/hd_day_pen.png) |

**32:9 super ultrawide:** the yard as a tilt-shift diorama.
![32:9](docs/screenshots/hd_ultrawide_32x9.png)

---

## Try it

There's no download yet; the prototype runs from source in the free Godot engine.

1. Install **Godot 4.7.x** (the standard build, not .NET) from
   <https://godotengine.org/download>. It's a single file; no installer.
2. Download this repo (**Code → Download ZIP**) and unzip it.
3. Open Godot, click **Import**, and pick the `project.godot` file.
4. Press **F5** to play.

It needs a graphics card with Vulkan or Direct3D 12 for the full look. On an
older computer, start Godot with `--rendering-method gl_compatibility`: it still
runs, without the light shafts, reflections and blur.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move (full tilt runs, partial walks) | WASD / Arrow keys | Left stick / D-pad |
| Phone flashlight | F | Y |
| Dog: stay / follow | E | X |
| Time of day (prototype) | F2 | |
| Classic 2D view (prototype) | F6 | |

## Found a bug?

Bug reports are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md). This is a
one-person project, so pull requests and feature requests aren't taken.

## Credits

* Art from the **LPC (Liberated Pixel Cup)** library: Eliza Wyatt, Lanea
  Zimmerman, Stephen Challener, Sevarihk, bluecarrot16, JaidynReiman and many
  more. Every artist and license is in [CREDITS.md](CREDITS.md).
* Code under the [MIT License](LICENSE). The art keeps its own licenses
  (CC-BY, CC-BY-SA, OGA-BY, GPL; see CREDITS.md).
* Developer notes: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

*Secret of Evermore is © Square Enix. This is a non-commercial fan project,
not affiliated with or endorsed by Square Enix. It contains no material from
the original game.*

Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
