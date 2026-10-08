# Art Spec: HD-2D on the LPC library

**Rule for every decision:** *Would this feel right in Secret of Evermore?
Then modernize how it's done.* Keep the original's soul, drop the 1995
hardware limits.

**The look (decided October 2026): HD-2D**, Square Enix's own way of
modernizing its SNES games (Octopath Traveler, Live A Live, Dragon Quest III
HD-2D): pixel-art sprites standing in a lit 3D world with real shadows,
depth-of-field blur, bloom and light shafts. Free assets only.

**Where the art comes from:** the **LPC (Liberated Pixel Cup)** library, mainly
**LPC Revised** by Eliza Wyatt and contributors. It was drawn to evoke the SNES
Mana games, which is the right family for Secret of Evermore, and it's free
to use with credit. Credits live in [`CREDITS.md`](../CREDITS.md).

---

## 1. Technical baseline (locked)

| Setting | Value | Notes |
|---|---|---|
| Base resolution | **640 × 360 = the MINIMUM view** | Every screen shows at least this. Wider/taller screens show more (section 2) |
| Tile size | **32 × 32** | 20 × 11.25 tiles on screen. Same field of view as 16px tiles at 320x180, twice the detail |
| Character frames | 64 × 64 (LPC universal sheet) | Kid art is ~28 × 52 px, feet at y = 62 in the frame |
| Dog frames | 48 × 48 (LPC animal sheet) | ~40 × 32 px side view, paws at y = 42 |
| Trees | ~100 × 100 to 100 × 115 | Composed from canopy + trunk + shadow (tools/art/build_art.py) |
| Bosses | 96 × 96 to 256 × 256 | |
| Perspective | 3/4 top-down | Same as the original and as LPC |

Why 32 px / 640x360 (decided October 2026): the LPC library is 32 px, and its
look matches the SNES Mana family. At 1080p it scales exactly 3x, at 1440p
exactly 4x, at 4K exactly 6x.

Already set in `project.godot` (plus the `ScreenScaler` autoload, below):

```
Display > Window > Stretch Mode ........ viewport
Display > Window > Stretch Scale Mode .. integer
Rendering > Textures > Default Filter .. Nearest
Rendering > 2D > Snap Transforms/Vertices to Pixel .. On
```

**Gotcha:** pixel snapping + a smoothed camera can make sprites jitter. If
it shows up, keep the camera on whole pixels and test one change at a time.

## 1b. HD-2D presentation (`systems/hd2d/hd_view.gd`)

**Gameplay is 2D, the picture is 3D.** Each realm still builds its 2D world
(tiles, props, actors, collision, AI). `HdView` draws that world in 3D and
mirrors the 2D actors every frame. F6 flips to the classic 2D view for
comparison. Nothing in gameplay code knows which view is on.

| Setting | Value | Notes |
|---|---|---|
| World scale | **32 px = 1 m**; 2D (x, y) → 3D (x, 0, y) | A tile is a 1 m square; the kid is ~1.6 m |
| Camera | Perspective, **pitch 40°, FOV 28°, distance 21 m** | Narrow FOV = the "diorama" feel. Exports on `HdView` |
| Sprite stretch | Upright sprites ×1/cos(pitch) vertically | Undoes the squash from looking down at them (HD-2D games do this too) |
| Ground | 2D tiles + flat decals rendered once into a texture, on a 3D plane | Autotiling stays pixel-exact |
| Props | Upright quads (`hd_sprite.gdshader`): alpha cutout, real sun shadows, texel-row wind sway, GPU-side frame animation | Lily pads lie flat on the water |
| Fences | Real 3D posts + rails, LPC wood at 32 px/m triplanar | Cast long shadows at golden hour |
| Water | Glossy plane over the water pixels (`hd_water.gdshader`): LPC water color + screen-space reflections + ripple normals | Sun glints for free |
| Same-row depth | Props 3 cm behind their base, kid 2 cm and dog 1 cm in front | Without it, sprites on one row z-fight and the kid vanishes into a trunk |
| Resolution | 3D at the window's **native** resolution; HUD/2D at integer scale (`ScreenScaler.native_3d`) | DoF/bloom/fog stay smooth, pixels stay crisp |

### Mood per time of day (`HdView.PRESETS`)

| Knob | What it does |
|---|---|
| `sun_color/energy/elev/yaw` | The key light. The sun sits in front (camera side), so shadows fall straight back, north (owner, 2026-10-08). Shadows stay light (`shadow_opacity` ~0.5) and short (sun 68° by day, 42° at golden hour): they must never hide a character |
| `ambient` | Fill light. Keep it **cooler** than the sun: warm light + cool shadow is what reads as "golden hour" |
| `fog_density/albedo` | Volumetric fog: light shafts through the trees. A little goes a long way (0.0025-0.008) |
| `exposure/saturation/contrast` | Final grade |
| `glow` | Bloom on bright things (sun glints, fireflies, flashlight) |
| `clouds` | Coverage of the invisible shadow-casting cloud layer |
| `dof` | Tilt-shift strength (top and bottom of the screen go soft) |
| `flashlight`, `phone_glow`, `water_glow` | Night readability: the phone's glow keeps the kid visible when the flashlight points away |

Lesson from tuning: a saturated orange sun + orange fog + orange ambient
turns everything into soup. Tint the **sun** warm, the **ambient** cool, keep
fog thin, and let the LPC colors do the rest.

### Renderer support

Checked by running the HD-2D scene in Godot 4.7.2 with each renderer.
`HdView.renderer_caps()` only switches on what the running renderer supports.

| Feature | Forward+ | Mobile | Compatibility (old GPUs/VMs) |
|---|---|---|---|
| Sun/flashlight shadows, glow | yes | yes | yes |
| Depth of field (tilt-shift) | yes | yes | **no** |
| Volumetric fog (light shafts) | yes | no | no |
| Screen-space reflections (pond) | yes | no | no |
| SSAO | yes | no | no |
| Contact-shadow decals | yes | yes | no |

Forward+ is the target. Lower renderers still run the HD-2D view with fewer
effects (and harsher contrast without the fog). A graphics settings menu
should expose these toggles for weaker GPUs too.

## 2. Any-screen support (ultrawide, 32:9, 48:9, Steam Deck)

**How it works:** `autoload/screen_scaler.gd` picks the biggest whole-number
scale where 640×360 still fits, then grows the view to fill the rest of the
window. Pixels stay crisp, and black borders are always under one scaled pixel.

| Monitor | Scale | Visible game area |
|---|---|---|
| 1280×720 (default window) | 2x | 640×360 |
| 1920×1080 (16:9) | 3x | 640×360 |
| 2560×1440 (16:9) | 4x | 640×360 |
| 3840×2160 (4K) | 6x | 640×360 |
| 1280×800 (Steam Deck) | 2x | 640×400 |
| 2560×1080 (21:9) | 3x | 853×360 |
| 3440×1440 (21:9) | 4x | 860×360 |
| 3840×1080 (32:9) | 3x | 1280×360 |
| 5120×1440 (32:9) | 4x | 1280×360 |
| 7680×2160 (32:9, 57") | 6x | 1280×360 |
| 5760×1080 (48:9 triple) | 3x | 1920×360 |
| 7680×1440 (48:9 triple) | 4x | 1920×360 |

**Why not Godot's built-in "expand"?** Tested at 5120×1440: with integer
scaling it sized the view for a fractional scale and drew at the integer one,
leaving big black bars on the sides AND top/bottom. ScreenScaler does the math
correctly.

### Rules every realm, cutscene, and system must follow

| Rule | Why |
|---|---|
| **The 640×360 "safe frame" around the kid must contain everything gameplay-critical** (puzzle pieces, boss telegraphs, cutscene subjects) | That's all a 16:9 player sees |
| **Every map needs an "apron":** decorative art past the playable edges, at least `(1920 - map width) / 2` px on the sides. The test yard uses woods 14 tiles deep | Wide screens see past the map; no void allowed |
| **No tall apron art right next to the map** (trees ≥ 52 px from the sides, ≥ 112 px below) | A canopy hanging over the map is Y-sorted after the kid and would hide him |
| **Use `GameCamera` with `set_world_bounds()`** | Clamps to the map, and centers maps narrower than the screen |
| **Enemies activate by distance from the kid, never by "on screen"** | Otherwise ultrawide players fight more enemies at once |
| **HUD goes inside a `SafeFrame`** (default 16:9, centered) | HUD in the far corners of a 49" monitor is miserable |
| **Visibility-based tricks need care** (e.g. the dog only warps while off-screen) | "Off-screen" means something very different at 1920 px wide |
| Optional `ScreenScaler.max_aspect` cap (off by default) | For a video-settings option or special scenes |

Verified by `tests/smoke_aspect` (math for 18 monitors) and
`tests/run_aspect_matrix.sh` (live run at 13 resolutions with screen capture;
the screen is cleared to magenta during the test so any hole in the apron
shows up as magenta and fails it).

## 3. Using LPC art

| Rule | Why |
|---|---|
| **Prefer LPC Revised** (Eliza Wyatt) for terrain and props; older LPC packs only when Revised has nothing | Revised is color-balanced and consistent; mixing eras shows |
| **Prefer OGA-BY / CC-BY / CC0.** CC-BY-SA / GPL is OK for this free project but note it in CREDITS.md | Share-alike and the CC anti-DRM clause matter if the game ever ships on Steam/consoles |
| **Never hand-edit an imported asset.** Crops, recolors, compositions go in `tools/art/build_art.py` | Rebuildable, reviewable, and the credit trail stays intact |
| **Credit in the same commit** (CREDITS.md + `credits/`) | License requirement |
| Characters come from the LPC generator (`tools/lpc/`), recipes in `characters.json` | One command rebuilds a character after an outfit change |
| Gaps (no LPC squirrel exists, for example) get drawn **in LPC style**: 32 px grid, dark outline, 3-4 shades, light from top-left | So hand-made art sits next to library art without clashing |

### Draw order (z_index, every realm)

| z | What |
|---|---|
| -20 | Ground tiles (TileMapLayer), including water |
| -15 | Flat decals: wildflowers, grass tufts, pebbles, lily pads |
| -10 | All drop shadows (actors, trees, rocks) |
| 0 | Y-sorted world: actors, trees, bushes, fences, tall grass |

Shadows live on their own layer so a tree's shadow never draws on top of the
kid walking behind the tree.

## 4. What stays from the original

| Element | Why |
|---|---|
| 3/4 view, tile-based worlds | The core look |
| **Grounded art style** | SoE was more Western and less chibi than Secret of Mana; LPC Revised fits |
| Ring menu, charge attacks | Combat identity |
| Alchemy with ingredient pairs | Signature system |
| Dog sniffing and form changes | The series hook (the dog sheet's head-down "eat" row becomes sniffing) |
| **Ambient soundscapes** | Jeremy Soule's original score leaned on atmosphere |

## 5. What gets modernized (status)

| Area | 1995 | Modern | Status |
|---|---|---|---|
| Lighting | Baked-in shading | Dynamic 2D lights + per-time-of-day mood (`systems/atmosphere/`) | **Done:** day / golden / night, flashlight with real shadows |
| Color | Hardware palette | Per-realm color grade: split toning, contrast, saturation, vignette | **Done** (`assets/shaders/color_grade.gdshader`) |
| Sky | None | Drifting cloud shadows, volumetric light shafts | **Done** (HD-2D) |
| Depth | Flat layers | HD-2D: 3D world, real shadows, tilt-shift DoF, reflective water | **Done** (proof of concept) |
| Life | Static scenery | Wind sway on plants, animated water, rippling sheen, lily pads, pollen, fireflies | **Done** |
| Sprite depth | Flat | Normal maps on key sprites (kid, dog, bosses) | Later |
| Animation | 2 to 4 frames | LPC: 8-9 frame walk/run, slash, hurt, more | **Done** for movement |
| Effects | Sprite limits | Particles, weather, screen shake, hit-stop | Prototype 1 (combat) |
| Camera | Tile scroll | Smooth follow, look-ahead, boss zoom | Follow done |
| Screen | 4:3 | Any shape, pixel-perfect | **Done** |

## 6. Gameplay quality-of-life

| Original pain | Fix |
|---|---|
| Alchemy leveling could become a grind | XP from *useful* casts + mastery branches at level 3 |
| Clunky dog AI | Breadcrumb + string-pull follow (done), plus commands and P2 control |
| Limited saving | Autosave at realm transitions + save points |
| No quest tracking | Journal: Ruffleberg's pages + quest log |
| Fixed controls | Rebinding, controller + keyboard, accessibility (text size, colorblind swaps, shake toggle) |

## 7. Realm moods

Each realm gets its own `Atmosphere` presets (tint, grade, particles). LPC
Revised ships summer, spring, autumn and winter tilesets, which cover a lot of
ground before any recolors.

The realms are being redesigned (design-bible.md section 8). Places the story
already has:

| Place | Mood | Likely base |
|---|---|---|
| Podunk at dusk (prologue) | Cool October dusk turning to night, porch lights, the phone flashlight | Revised autumn + night preset |
| The mansion (prologue) | Dust, moonlight through sheets, one flashlight beam | LPC interiors + night grade |
| Hub: The Mansion That Was | Warm sepia, 1965 lamplight | LPC interiors + sepia grade |
| Dad's dream: Main Street, 1995 | Dusk, the theater marquee glowing | Town tiles + golden preset |
| The test yard (tech demo only) | Saturated golden-hour greens and oranges | LPC Revised summer (in use) |

## 8. SNES-style effects worth doing

| Effect | Where | How | Status |
|---|---|---|---|
| Fake Mode 7 | Overworld or vehicle travel, if a realm needs it | Shader on a map texture | Later |
| Lighting | Prologue phone flashlight, night scenes | 3D lights in HD-2D (`HdView`); `PointLight2D` in the 2D view | **Done** (flashlight) |
| Parallax | Skies and seas, if a realm needs them | `Parallax2D` / 3D backdrop | Later |
| Transitions | Carltron flash, realm entry | Fullscreen shader | Later |
| Wading | Shallow water in every realm | LPC Revised ships splash/ripple FX + a wading overlay | Later |

## 9. Tools

| Tool | Cost | Notes |
|---|---|---|
| `tools/art/build_art.py` | Free | Rebuilds every imported asset from the original packs |
| `tools/lpc/build_character.js` | Free | Exports LPC characters from the web generator |
| Tiled | Free | Browse LPC Revised `.tsx` tilesets and their terrain sets |
| Aseprite | ~$20 (free if built from source) | Drawing LPC-style gap art. **Aseprite Wizard** Godot plugin |
| Pixelorama / LibreSprite | Free | Alternatives to Aseprite |
| Laigter | Free | Generates normal maps from sprites |

## 10. Visual references

- **Sea of Stars**: SNES love letter with dynamic lighting. Closest overall match.
- **Eastward**: detailed pixel environments, rich lighting. Mood for the mansion.
- **CrossCode**: 16-bit action RPG with modern combat feel.
- **Chained Echoes**: SNES RPG feel with modern QoL.

---
Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
