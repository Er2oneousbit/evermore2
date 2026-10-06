# Credits

This game uses free art from the **Liberated Pixel Cup (LPC)** community.
Every license below requires attribution, so this file and the `credits/`
folder ship with the game. **Adding art? Credit it here in the same commit.**

Secret of Evermore is © Square Enix. This is a non-commercial fan project and
is not affiliated with Square Enix.

---

## The kid: `assets/characters/kid/kid_lpc.png`

Built with the [Universal LPC Spritesheet Character Generator](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/)
(recipe: `tools/lpc/characters.json`). Layers and their artists:

| Layer | Artists | Licenses |
|---|---|---|
| `body/bodies/teen` | bluecarrot16, Evert, TheraHedwig, Benjamin K. Smith (BenCreating), MuffinElZangano, Durrani, Pierre Vigier (pvigier), Eliza Wyatt (ElizaWy), Matthew Krohn (makrohn), Johannes Sjölund (wulax), Stephen Challener (Redshrike) | OGA-BY 3.0, CC-BY-SA 3.0, GPL 3.0 |
| `head/heads/human/male_small` | ElizaWy, Stephen Challener (Redshrike) | OGA-BY 3.0, CC-BY |
| `head/faces/male/neutral` | JaidynReiman, ElizaWy, Stephen Challener (Redshrike) | OGA-BY 3.0 |
| `hair/messy2/adult` | JaidynReiman, Manuel Riecke (MrBeast) | CC-BY-SA 3.0, GPL 3.0 |
| `torso/clothes/longsleeve/longsleeve2/teen` | ElizaWy, JaidynReiman, Stephen Challener (Redshrike), Johannes Sjölund (wulax) | OGA-BY 3.0 |
| `legs/pants/thin` | bluecarrot16, JaidynReiman, ElizaWy, Joe White, Matthew Krohn (makrohn), Johannes Sjölund (wulax), Stephen Challener (Redshrike) | OGA-BY 3.0, GPL 3.0, CC-BY-SA 3.0 |
| `feet/shoes/revised/thin` | ElizaWy, JaidynReiman | OGA-BY 3.0 |

Full detail (notes and source links per layer): `credits/kid/credits.txt` / `credits.csv`.

> **License note:** the hair layer is CC-BY-SA 3.0 / GPL 3.0 only, so the combined
> kid sheet is share-alike. Fine for this free fan project. If this ever ships on
> a DRM platform (Steam, consoles), swap the hair for an OGA-BY hairstyle in
> `tools/lpc/characters.json` and rebuild.

## The dog: `assets/characters/dog/dog_lpc.png`, `dog_lpc_shadow.png`

* **Shiba dog by Sevarihk**, adapted for LPC by **tapatilorenzo**, from
  [[LPC] Bears, deer, lions and more](https://opengameart.org/content/lpc-bears-deer-lions-and-more).
  License: **CC-BY 4.0**.
* Modified by this project: recolored from golden to a brown brindle coat
  (`tools/art/build_art.py`, `build_dog`).
* Detail: `credits/dog/credits.txt`.

## Ground tileset: `assets/tilesets/lpc_revised/terrain_summer.png`

* [LPC Revised - Fully Configured 4 Seasons Tilesets for Tiled Map Editor](https://opengameart.org/content/lpc-revised-fully-configured-4-seasons-tilesets-for-tiled-map-editor)
  compiled and configured by **JaidynReiman**. License: **OGA-BY 3.0** (page also lists CC-BY 3.0).
* Original LPC Revised artists: **Eliza Wyatt (DeathsDarling / ElizaWy)**, Lanea Zimmerman (Sharm),
  Stephen Challener (Redshrike), Johannes Sjölund (Wulax), BlueCarrot16, BenCreating, Durrani,
  YuriNikolai and Craftpix.net 2D Game Assets. Full list:
  <https://github.com/ElizaWy/LPC/blob/main/Credits.txt>
* The autotile lookup `data/tilesets/lpc_summer_wang.json` is generated from that pack's `.tsx`.
* `assets/textures/hd/wood_rail.png` and `wood_post.png` (the HD-2D view's 3D fence wood) are
  32x32 crops of this tileset's planks (`tools/art/build_art.py`, `build_hd_textures`).

## Trees, bushes, flowers, grass, rocks, mushrooms, pond plants: `assets/props/big_yard/`

* [LPC Revised - 4 Season Terrain](https://opengameart.org/content/lpc-revised-4-season-terrain)
  by **Eliza Wyatt (DeathsDarling)**, with work by Lanea Zimmerman (Sharm), Hyptosis,
  Stephen Challener (Redshrike), BlueCarrot16 and others. License: **OGA-BY 3.0**.
* Per-file artists: `credits/lpc_revised/Credits - Terrain Objects.txt` (and the other
  `Credits - *.txt` files copied from the pack).
* Modified by this project: trees composed from separate canopy / trunk / shadow sprites,
  sprites cropped and trimmed (`tools/art/build_art.py`).

## Code-made effects

Shaders (wind sway, water shimmer, color grade, cloud shadows, and the HD-2D
sprite / water / cloud shaders), particles, the HD-2D lighting, and the soft
shadow / glow textures were written for this project.

---

### License quick reference

| License | Short version | Text |
|---|---|---|
| OGA-BY 3.0 | Credit the authors. Like CC-BY 3.0 but without the anti-DRM clause | <https://static.opengameart.org/OGA-BY-3.0.txt> |
| CC-BY 3.0 / 4.0 | Credit the authors | <https://creativecommons.org/licenses/by/4.0/> |
| CC-BY-SA 3.0 | Credit the authors; derivatives use the same license | <https://creativecommons.org/licenses/by-sa/3.0/> |
| GPL 3.0 | Copyleft; offered as an alternative license by some LPC layers | <https://www.gnu.org/licenses/gpl-3.0.html> |

Written with help from Claude (Anthropic) via Claude Code.

Made with ❤️ from your friendly hacker - er2oneousbit
