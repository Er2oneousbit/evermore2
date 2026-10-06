# Art Spec: "Modern SNES"

**Rule for every decision:** *Would this feel right in Secret of Evermore?
Then modernize how it's done.* Keep the original's soul, drop the 1995
hardware limits.

---

## 1. Technical baseline (locked)

| Setting | Value | Notes |
|---|---|---|
| Base resolution | **384 × 216 = the MINIMUM view** | Every screen shows at least this. Wider/taller screens show more (section 2) |
| Tile size | **16 × 16** | 24 × 13.5 tiles on screen |
| Kid sprite | ~16 × 24 | Origin at the feet |
| Dog sprite | ~24 × 16 | Medium to large dog: wider than the kid |
| Bosses | 48 × 48 to 128 × 128 | |
| Perspective | 3/4 top-down | Same as the original |

Already set in `project.godot` (plus the `ScreenScaler` autoload, below):

```
Display > Window > Stretch Mode ........ viewport
Display > Window > Stretch Scale Mode .. integer
Rendering > Textures > Default Filter .. Nearest
Rendering > 2D > Snap Transforms/Vertices to Pixel .. On
```

**Gotcha:** pixel snapping + a smoothed camera can make sprites jitter. If
it shows up, keep the camera on whole pixels and test one change at a time.

## 2. Any-screen support (ultrawide, 32:9, 48:9, Steam Deck)

**How it works:** `autoload/screen_scaler.gd` picks the biggest whole-number
scale where 384×216 still fits, then grows the view to fill the rest of the
window. Pixels stay crisp, and black borders are always under one scaled pixel.

| Monitor | Scale | Visible game area |
|---|---|---|
| 1920×1080 (16:9) | 5x | 384×216 |
| 2560×1440 (16:9) | 6x | 426×240 |
| 3840×2160 (4K) | 10x | 384×216 |
| 1280×800 (Steam Deck) | 3x | 426×266 |
| 2560×1080 (21:9) | 5x | 512×216 |
| 3440×1440 (21:9) | 6x | 573×240 |
| 3840×1080 (32:9) | 5x | 768×216 |
| 5120×1440 (32:9) | 6x | 853×240 |
| 7680×2160 (32:9, 57") | 10x | 768×216 |
| 5760×1080 (48:9 triple) | 5x | 1152×216 |
| 7680×1440 (48:9 triple) | 6x | 1280×240 |

**Why not Godot's built-in "expand"?** Tested at 5120×1440: with integer
scaling it sized the view for 6.67x and drew at 6x, leaving 256 px bars on
the sides AND 72 px top/bottom. ScreenScaler does the math correctly.

### Rules every realm, cutscene, and system must follow

| Rule | Why |
|---|---|
| **The 384×216 "safe frame" around the kid must contain everything gameplay-critical** (puzzle pieces, boss telegraphs, cutscene subjects) | That's all a 16:9 player sees |
| **Every map needs an "apron":** decorative art past the playable edges, at least `(1280 - map width) / 2` px. The test yard uses 1024 px | Wide screens see past the map; no void allowed |
| **Use `GameCamera` with `set_world_bounds()`** | Clamps to the map, and centers maps narrower than the screen |
| **Enemies activate by distance from the kid, never by "on screen"** | Otherwise ultrawide players fight more enemies at once |
| **HUD goes inside a `SafeFrame`** (default 16:9, centered) | HUD in the far corners of a 49" monitor is miserable |
| **Visibility-based tricks need care** (e.g. the dog only warps while off-screen) | "Off-screen" means something very different at 1280 px wide |
| Optional `ScreenScaler.max_aspect` cap (off by default) | For a video-settings option or special scenes |

Verified by `tests/smoke_aspect` (math for 17 monitors) and
`tests/run_aspect_matrix.sh` (live run at 13 resolutions with screen capture).

## 2b. What stays from the original

| Element | Why |
|---|---|
| 16px tiles, 3/4 view | The core look |
| **Grounded art style** | SoE was more Western and less chibi than Secret of Mana |
| Ring menu, charge attacks | Combat identity |
| Alchemy with ingredient pairs | Signature system |
| Dog sniffing and form changes | The series hook |
| **Ambient soundscapes** | Jeremy Soule's original score leaned on atmosphere |

## 3. What gets modernized

| Area | 1995 | Modern |
|---|---|---|
| Lighting | Baked-in shading | Dynamic 2D lights (`PointLight2D`, `CanvasModulate`), day/night |
| Sprite depth | Flat | **Normal maps** on key sprites only (kid, dog, bosses, mansion) |
| Animation | 2 to 4 frames | 6 to 12 frames |
| Effects | Sprite limits | Particles, weather, screen shake, hit-stop |
| Color | Hardware palette | Limited realm palettes **by choice** + per-realm color grade |
| Camera | Tile scroll | Smooth follow, look-ahead, boss zoom |
| Screen | 4:3 | 16:9 |

## 4. Gameplay quality-of-life

| Original pain | Fix |
|---|---|
| Alchemy leveling could become a grind | XP from *useful* casts + mastery branches at level 3 |
| Clunky dog AI | Breadcrumb + string-pull follow (done), plus commands and P2 control |
| Limited saving | Autosave at realm transitions + save points |
| No quest tracking | Journal: Ruffleberg's pages + quest log |
| Fixed controls | Rebinding, controller + keyboard, accessibility (text size, colorblind swaps, shake toggle) |

## 5. Palettes

One master palette per realm, 32 to 48 colors. Start from <https://lospec.com/palette-list>.
A **palette-swap shader** handles dog form tints, enemy variants, damage
flashes, and the frozen effect.

| Realm | Mood |
|---|---|
| Hub mansion | Warm sepia, 1965 lamplight |
| The Big Yard | Saturated golden-hour greens and oranges |
| Saltreach | Teal, sand, storm grey |
| Frostheim | Deep navy, aurora greens, lantern orange |
| Vernia | Brass, copper, sky blue |
| The Grand Carlton | Black, gold, emerald (Art Deco) |
| The Off Switch | Desaturated lab greys, one red light |

## 6. SNES-style effects worth doing

| Effect | Where | How |
|---|---|---|
| Fake Mode 7 | Ship travel (Saltreach), airship travel (Vernia) | Shader on a map texture |
| 2D lighting | Frostheim lantern, prologue phone flashlight | `PointLight2D` + `CanvasModulate` (prototyped) |
| Parallax | Saltreach sea, Vernia sky | `Parallax2D` |
| Transitions | Carltron flash, realm entry | Fullscreen shader |

## 7. Tools

| Tool | Cost | Notes |
|---|---|---|
| Aseprite | ~$20 (free if built from source) | Standard. Use the **Aseprite Wizard** Godot plugin |
| Pixelorama | Free | Made in Godot |
| LibreSprite | Free | Fork of old open-source Aseprite |
| Laigter | Free | Generates normal maps from sprites |
| Kenney.nl | Free (CC0) | Placeholder assets |

## 8. Visual references

- **Sea of Stars**: SNES love letter with dynamic lighting. Closest overall match.
- **Eastward**: detailed pixel environments, rich lighting. Mood for the mansion.
- **CrossCode**: 16-bit action RPG with modern combat feel.
- **Chained Echoes**: SNES RPG feel with modern QoL.

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
