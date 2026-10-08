#!/usr/bin/env python3
"""
build_art.py  -  Rebuild every third-party art asset the game ships with
-----------------------------------------------------------------------------
WHAT:  Takes the ORIGINAL art packs (downloaded from OpenGameArt, cached in
       tools/art/.cache/) and produces exactly what the game uses:

         assets/tilesets/lpc_revised/terrain_summer.png   ground tileset
         data/tilesets/lpc_summer_wang.json               its autotile lookup
         assets/props/big_yard/*.png                      trees, bushes, rocks...
         data/props/big_yard/*.tres                       PropData per prop
         assets/characters/dog/dog_lpc*.png               the dog (recolored)
         assets/textures/hd/*.png                         3D fence wood (HD-2D view)
         assets/characters/enemies/*/                     enemy sheets (the rat)
         assets/items/lpc_items.png                       32x32 item icons
         assets/weapons/*_fg.png, *_bg.png                weapons in hand while swinging
         credits/<pack>/...                               license + credit files

       The outputs are committed to git, so nobody NEEDS to run this to play.
       Run it when changing which art is used, recoloring, or re-slicing.

WHY A SCRIPT: every crop, recolor, and tree composition is written down and
       repeatable, instead of living in someone's image editor history.
       It also keeps the license trail intact (credits/ is rebuilt every run).

USAGE:
  python3 tools/art/build_art.py            build (downloads packs if missing)
  python3 tools/art/build_art.py --offline  build from the cache only
  python3 tools/art/build_art.py --list     list packs, licenses, cache status
  python3 tools/art/build_art.py --only props,dog   rebuild some steps only
  Steps: tileset, props, hd, dog, enemies, items, weapons, credits.     Needs: Python 3.9+, Pillow (pip install pillow)

Written with help from Claude (Anthropic) via Claude Code.
Made with love from your friendly hacker - er2oneousbit
"""
import argparse
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

try:
    from PIL import Image
except ImportError:
    sys.exit("ERROR: Pillow is required:  pip install pillow")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "art", ".cache")
VERBOSE = False
OFFLINE = False

# -----------------------------------------------------------------------------
# Source packs. Each is downloaded once into tools/art/.cache/<key>/.
# -----------------------------------------------------------------------------
PACKS = {
    "four_season": {
        "title": "LPC Revised - 4 Season Terrain (Eliza Wyatt et al.)",
        "url": "https://opengameart.org/sites/default/files/4-season_terrain.zip",
        "page": "https://opengameart.org/content/lpc-revised-4-season-terrain",
        "license": "OGA-BY 3.0",
    },
    "exterior": {
        "title": "LPC Revised - Fully Configured 4 Seasons Tilesets for Tiled (JaidynReiman)",
        "url": "https://opengameart.org/sites/default/files/lpc-revised-exterior-tilesets.zip",
        "page": "https://opengameart.org/content/lpc-revised-fully-configured-4-seasons-tilesets-for-tiled-map-editor",
        "license": "OGA-BY 3.0 / CC-BY 3.0",
    },
    "items": {
        "title": "[LPC] Items and game effects (Reemax et al.)",
        "url": "https://opengameart.org/sites/default/files/ItemsAndEffects_0.zip",
        "page": "https://opengameart.org/content/lpc-items-and-game-effects",
        "license": "CC-BY-SA 3.0 / GPL 3.0 / GPL 2.0",
    },
    "animals": {
        "title": "[LPC] Bears, deer, lions and more (tapatilorenzo; shiba dog by Sevarihk)",
        "url": "https://opengameart.org/sites/default/files/lpc_animals_2022_v1.1.zip",
        "page": "https://opengameart.org/content/lpc-bears-deer-lions-and-more",
        "license": "CC-BY 4.0",
    },
}

## Weapons in hand: layers from the Universal LPC Spritesheet Character
## Generator's repo (single PNGs, not a zip pack), pinned to one commit so a
## rebuild gets the same pixels. Each weapon: a front layer (over the kid)
## and a back layer (behind him), one row per direction (up, left, down,
## right), one column per frame of the swing. `frame` is the cell size.
LPC_GEN = ("https://raw.githubusercontent.com/LiberatedPixelCup/"
           "Universal-LPC-Spritesheet-Character-Generator/58ce1aa479e4df32845a73a5d0afc221c3a893c2/spritesheets/")
WEAPON_ART = {
    # The stick: the club, a backhand swing (the body's slash played in
    # reverse, which is how the generator lines this art up).
    "stick": {"fg": "weapon/blunt/club/club.png", "bg": "weapon/blunt/club/background/club.png", "frame": 192,
              "title": "Club (LPC More Weapons)", "authors": "bluecarrot16",
              "license": "OGA-BY 3.0+ / GPL 3.0 / CC-BY 4.0", "page": "https://opengameart.org/content/lpc-more-weapons"},
    # The rusty sword: the arming sword in bronze (it reads as rust), a forward slash.
    "rusty_sword": {"fg": "weapon/sword/arming/attack_slash/fg/bronze.png",
                    "bg": "weapon/sword/arming/attack_slash/bg/bronze.png", "frame": 128,
                    "title": "Arming sword (LPC)", "authors": "ElizaWy; walk and down by JaidynReiman",
                    "license": "OGA-BY 3.0", "page": "https://github.com/ElizaWy/LPC"},
}

OBJ = ("four_season", "Terrain Objects")  # shorthand for the props folder
ANIMALS = ("animals", "lpc animals 2022 v1.1/individual creature spritesheets")


def log(msg):
    print(msg)


def vlog(msg):
    if VERBOSE:
        print("   " + msg)


def pack_dir(key):
    return os.path.join(CACHE, key)


def src(folder, name):
    """Path to a file inside an unpacked pack: src(OBJ, 'Trees, Generic.png')."""
    path = os.path.join(pack_dir(folder[0]), folder[1], name)
    if not os.path.isfile(path):
        sys.exit(f"ERROR: missing source file {path}\n  Re-run without --offline, or delete {pack_dir(folder[0])} to re-download.")
    return path


def ensure_packs(offline):
    os.makedirs(CACHE, exist_ok=True)
    for key, p in PACKS.items():
        d = pack_dir(key)
        if os.path.isdir(d) and os.listdir(d):
            vlog(f"cached: {key}")
            continue
        if offline:
            sys.exit(f"ERROR: pack '{key}' not in cache and --offline was given.\n  Download {p['url']} and unzip it into {d}")
        zpath = d + ".zip"
        log(f"Downloading {p['title']}\n   {p['url']}")
        try:
            with urllib.request.urlopen(p["url"], timeout=120) as r, open(zpath, "wb") as f:
                shutil.copyfileobj(r, f)
        except OSError as e:
            sys.exit(f"ERROR: download failed ({e}). Download it manually into {zpath} and re-run.")
        with zipfile.ZipFile(zpath) as z:
            z.extractall(d)
        os.remove(zpath)


# -----------------------------------------------------------------------------
# Small helpers
# -----------------------------------------------------------------------------
def out_path(*parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def crop(path, box):
    """box = (x, y, w, h)."""
    x, y, w, h = box
    return Image.open(path).convert("RGBA").crop((x, y, x + w, y + h))


def trim(img, pad=2):
    """Cut transparent margins, keep `pad` px (wind sway needs room to move)."""
    bbox = img.getbbox()
    if bbox is None:
        sys.exit("ERROR: tried to trim an empty image (wrong crop box?)")
    img = img.crop(bbox)
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad))
    out.alpha_composite(img, (pad, pad))
    return out


def vec(v):
    return f"Vector2({v[0]:g}, {v[1]:g})"


def write_prop(name, img, base, *, footprint=(0, 0), footprint_offset=(0, 0), sway=0.0,
               sway_speed=0.5, rooted=0.4, occluder=(0, 0), shadow_size=(0, 0), shadow_alpha=0.45,
               shadow_img=None, shadow_offset=(0, 0), decal=False, frames=1, frame_fps=2.0):
    """Save the prop PNG (+ optional shadow PNG) and its PropData .tres."""
    img.save(out_path("assets", "props", "big_yard", name + ".png"))
    ext = [f'[ext_resource type="Script" path="res://realms/_shared/prop_data.gd" id="1_script"]',
           f'[ext_resource type="Texture2D" path="res://assets/props/big_yard/{name}.png" id="2_tex"]']
    lines = ['script = ExtResource("1_script")', 'texture = ExtResource("2_tex")', f"base = {vec(base)}"]
    if decal:
        lines.append("ground_decal = true")
    if frames > 1:
        lines += [f"frames = {frames}", f"frame_fps = {frame_fps:g}"]
    if footprint != (0, 0):
        lines += [f"footprint = {vec(footprint)}", f"footprint_offset = {vec(footprint_offset)}"]
    if shadow_img is not None:
        shadow_img.save(out_path("assets", "props", "big_yard", name + "_shadow.png"))
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/props/big_yard/{name}_shadow.png" id="3_shadow"]')
        lines += ['shadow_texture = ExtResource("3_shadow")', f"shadow_offset = {vec(shadow_offset)}", f"shadow_alpha = {shadow_alpha:g}"]
    elif shadow_size != (0, 0):
        lines += [f"shadow_size = {vec(shadow_size)}", f"shadow_alpha = {shadow_alpha:g}"]
    if sway > 0:
        lines += [f"sway_strength = {sway:g}", f"sway_speed = {sway_speed:g}", f"sway_rooted = {rooted:g}"]
    if occluder != (0, 0):
        lines.append(f"occluder_size = {vec(occluder)}")
    tres = (f'[gd_resource type="Resource" script_class="PropData" load_steps={len(ext) + 1} format=3]\n\n'
            + "\n".join(ext) + "\n\n[resource]\n" + "\n".join(lines) + "\n")
    with open(out_path("data", "props", "big_yard", name + ".tres"), "w", newline="\n") as f:
        f.write(tres)
    vlog(f"prop {name:18s} {img.width}x{img.height} base={base}")


def plant(name, path, box, *, sway=0.6, rooted=0.25, solid=None, shadow=None, decal=False):
    """Slice a single-cell plant/rock: trim it, base = bottom-center of the art."""
    img = trim(crop(path, box))
    base = (img.width / 2, img.height - 2)
    kw = {}
    if solid:
        kw.update(footprint=solid, footprint_offset=(0, -solid[1] / 2), occluder=solid)
    if shadow:
        kw.update(shadow_size=shadow)
    write_prop(name, img, base, sway=0.0 if decal else sway, rooted=rooted, decal=decal, **kw)


# -----------------------------------------------------------------------------
# Steps
# -----------------------------------------------------------------------------
def build_tileset():
    log("Tileset: LPC Revised summer terrain + autotile lookup")
    exterior = pack_dir("exterior")
    png = os.path.join(exterior, "lpc-tileset-terrain-summer.png")
    tsx = os.path.join(exterior, "lpc-tileset-terrain-summer.tsx")
    shutil.copyfile(png, out_path("assets", "tilesets", "lpc_revised", "terrain_summer.png"))
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "tiled", "tsx_wang_to_json.py"), tsx,
                    out_path("data", "tilesets", "lpc_summer_wang.json"), "--sets", "Summer Terrain,Fences",
                    "--image", "res://assets/tilesets/lpc_revised/terrain_summer.png"], check=True)


def build_props():
    log("Props: Big Yard trees, bushes, flowers, rocks, decals")
    trees = src(OBJ, "Trees, Generic.png")
    trunks = src(OBJ, "Trees, Trunks.png")
    shadows = src(OBJ, "Trees, Generic - Shadows.png")

    # --- Trees: canopy + trunk composed into one sprite; canopy shadow kept
    # separate so it can sit on the ground layer under everything. -----------
    canopy_summer = crop(trees, (33, 176, 94, 80))
    canopy_spring = crop(trees, (33, 16, 94, 80))     # lighter green, for variety
    trunk_roots = crop(trunks, (26, 21, 43, 31))
    trunk_tall = crop(trunks, (100, 13, 25, 64))
    canopy_shadow = crop(shadows, (16, 23, 64, 31))
    for name, canopy, trunk, overlap in [("oak_a", canopy_summer, trunk_roots, 14),
                                         ("oak_b", canopy_summer, trunk_tall, 30),
                                         ("oak_light", canopy_spring, trunk_roots, 14)]:
        pad = 3
        w = canopy.width + pad * 2
        h = pad + canopy.height + trunk.height - overlap
        img = Image.new("RGBA", (w, h))
        trunk_y = pad + canopy.height - overlap
        img.alpha_composite(trunk, ((w - trunk.width) // 2, trunk_y))
        img.alpha_composite(canopy, (pad, pad))
        base = (w / 2, h - (6 if trunk is trunk_roots else 3))  # where the trunk meets the ground
        write_prop(name, img, base, footprint=(20, 10), footprint_offset=(0, -4), occluder=(20, 10),
                   sway=1.0, sway_speed=0.35, rooted=0.42,
                   shadow_img=canopy_shadow, shadow_offset=(10, -8), shadow_alpha=0.33)

    # --- Bushes and leafy plants (summer rows) -------------------------------
    bush_c = src(OBJ, "Bush - Seasonal C.png")
    plant("bush_round_a", bush_c, (0, 64, 32, 32), sway=0.5, rooted=0.2, solid=(20, 8), shadow=(30, 10))
    plant("bush_round_b", bush_c, (32, 64, 32, 32), sway=0.5, rooted=0.2, solid=(20, 8), shadow=(30, 10))
    bush_b = src(OBJ, "Bush - Seasonal B.png")
    for i, x in enumerate((0, 32, 64)):
        plant(f"shrub_{'abc'[i]}", bush_b, (x, 32, 32, 32), sway=0.6, shadow=(22, 7))
    bush_a = src(OBJ, "Bush - Seasonal A.png")
    for i, x in enumerate((0, 32, 64, 96)):
        plant(f"leafy_{'abcd'[i]}", bush_a, (x, 32, 32, 32), sway=0.4, shadow=(24, 7))

    # --- Tall grass (spring row: lusher green that matches the summer ground)
    grass = src(OBJ, "Grasses, Tall.png")
    for i, x in enumerate((64, 96, 128, 160)):
        plant(f"tall_grass_{'abcd'[i]}", grass, (x, 0, 32, 64), sway=1.5, rooted=0.08)
    for i, x in enumerate((0, 32)):
        plant(f"grass_clump_{'ab'[i]}", grass, (x, 32, 32, 32), sway=1.0, rooted=0.08)

    # --- Garden flowers: rose bushes (row 0) and single flowers (row 3) ------
    garden = src(OBJ, "Flowers - Garden.png")
    colors = ["white", "pink", "red", "blue", "purple", "yellow", "orange", "peach", "cyan"]
    for i, c in enumerate(colors):
        plant(f"rose_{c}", garden, (i * 32, 0, 32, 32), sway=0.4, shadow=(24, 7))
        plant(f"flower_{c}", garden, (i * 32, 96, 32, 32), sway=0.9, rooted=0.15)

    # --- Rocks (grey-brown set) ----------------------------------------------
    rocks = src(OBJ, "Rocks, Grasslands.png")
    plant("rock_big", rocks, (0, 0, 64, 64), solid=(46, 14), shadow=(60, 14))
    plant("rock_wide", rocks, (64, 64, 64, 32), solid=(44, 10), shadow=(56, 12))
    plant("rock_small_a", rocks, (128, 64, 32, 32), solid=(18, 8), shadow=(24, 8))
    plant("rock_small_b", rocks, (128, 96, 32, 32), solid=(18, 8), shadow=(24, 8))
    plant("pebble", rocks, (160, 96, 32, 32), decal=True)

    # --- Mushrooms -------------------------------------------------------------
    shrooms = src(OBJ, "Mushrooms.png")
    for name, box in [("mushroom_red", (96, 32, 32, 32)), ("mushroom_cluster_a", (0, 96, 32, 32)),
                      ("mushroom_cluster_b", (32, 96, 32, 32)), ("mushroom_brown", (128, 32, 32, 32))]:
        plant(name, shrooms, box, sway=0.0, shadow=(14, 5))

    # --- Pond life: 2-frame animated lily pads (flat on the water) and reeds.
    # Frames sit side by side (32x32 each); not trimmed, so frames stay aligned.
    aquatic = src(OBJ, "Aquatic Plants (Animated).png")
    for name, y in [("lily_big", 0), ("lily_small", 32), ("lily_mid", 64), ("lily_flower", 96)]:
        img = crop(aquatic, (0, y, 64, 32))
        write_prop(name, img, (16, 24), decal=True, frames=2, frame_fps=1.6)
    for name, y in [("reeds_a", 0), ("reeds_b", 32), ("reeds_c", 64)]:
        img = crop(aquatic, (64, y, 64, 32))
        write_prop(name, img, (16, 26), frames=2, frame_fps=1.2)

    # --- Flat ground decals: scattered wildflowers and grass tufts -----------
    wild = src(OBJ, "Flowers - Wildflowers (Summer).png")
    n = 0
    for y in range(0, 160, 32):
        for x in range(0, 128, 32):
            plant(f"wildflowers_{n:02d}", wild, (x, y, 32, 32), decal=True)
            n += 1
    tufts = src(OBJ, "Grass Tuffs (Blending).png")
    for i, x in enumerate(range(0, 192, 32)):
        plant(f"tuft_{'abcdef'[i]}", tufts, (x, 0, 32, 32), decal=True)


def build_hd_textures():
    """Textures for the HD-2D view's real 3D geometry (fence posts and rails),
    cut from the same LPC Revised tileset so the palette matches the sprites."""
    log("HD-2D textures: fence wood from the LPC Revised tileset")
    atlas = os.path.join(pack_dir("exterior"), "lpc-tileset-terrain-summer.png")
    rail = crop(atlas, (1536, 32, 32, 32))  # weathered horizontal planks
    rail.save(out_path("assets", "textures", "hd", "wood_rail.png"))
    rail.rotate(90).save(out_path("assets", "textures", "hd", "wood_post.png"))  # grain runs up the post


def build_enemies():
    """Enemy sheets. The LPC 2022 giant rat: 80x64 frames, 12 per row, rows
    down/left/right/up; frames 0-3 walk, 4-7 attack, 8-11 die (the down/up
    rows have 3 death frames and a solid magenta filler cell, cleared here)."""
    log("Enemies: the giant rat")
    for name, out in [("giant rat (Sevarihk).png", "rat_lpc.png"), ("giant rat shadow (Sevarihk).png", "rat_lpc_shadow.png")]:
        img = Image.open(src(ANIMALS, name)).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                if a and r > 240 and g < 20 and b > 200:  # the magenta filler
                    px[x, y] = (0, 0, 0, 0)
        img.save(out_path("assets", "characters", "enemies", "rat", out))


def build_items():
    """Item icons for hidden items, equipment and the ring menu later: a 16x16
    grid of 32x32 icons (weapons, armor, potions, food, keys, tools, maps).
    Copied as-is; slicing into item data comes with the items milestone."""
    log("Items: the LPC item icon sheet")
    shutil.copyfile(src(("items", "ItemsAndEffects"), "items1.png"), out_path("assets", "items", "lpc_items.png"))


def build_weapons():
    """Weapons in the kid's hand while he swings (WeaponData.overlay_*)."""
    log("Weapons: in-hand swing layers from the LPC generator")
    cache = os.path.join(CACHE, "lpc_generator")
    for name, w in WEAPON_ART.items():
        for layer in ("fg", "bg"):
            cached = os.path.join(cache, w[layer])
            if not os.path.isfile(cached):
                if OFFLINE:
                    sys.exit(f"ERROR: {w[layer]} not cached and --offline was given.")
                os.makedirs(os.path.dirname(cached), exist_ok=True)
                with urllib.request.urlopen(LPC_GEN + w[layer], timeout=120) as r, open(cached, "wb") as f:
                    shutil.copyfileobj(r, f)
            img = Image.open(cached).convert("RGBA")
            if img.width % w["frame"] or img.height != w["frame"] * 4:
                sys.exit(f"ERROR: {w[layer]} is {img.size}, expected 4 rows of {w['frame']} px frames")
            img.save(out_path("assets", "weapons", f"{name}_{layer}.png"))
            vlog(f"{name}_{layer}.png  ({img.width // w['frame']} frames x 4 directions)")


def build_dog():
    """Golden shiba -> brown brindle shelter mutt (see docs/design-bible.md #7)."""
    log("Dog: recoloring the shiba into a brown brindle mutt")
    sheet = Image.open(src(ANIMALS, "dog, shiba (Sevarihk).png")).convert("RGBA")
    shadow = Image.open(src(ANIMALS, "dog, shiba shadow (Sevarihk).png")).convert("RGBA")
    MAIN, SHADE, LINE, CREAM = (243, 195, 95), (209, 148, 40), (148, 107, 68), (253, 245, 204)
    palette = {MAIN: (156, 108, 64), SHADE: (110, 74, 44), LINE: (66, 44, 36), CREAM: (222, 196, 156)}
    STRIPE = (124, 84, 50)  # brindle stripes, painted over the main coat only
    px = sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            # Stripes use frame-local coords (48x48 frames) so they sit the same
            # way in every frame instead of sliding across the body.
            if c == MAIN and ((x % 48) * 2 + (y % 48)) % 9 < 2:
                px[x, y] = STRIPE + (a,)
            elif c in palette:
                px[x, y] = palette[c] + (a,)
    sheet.save(out_path("assets", "characters", "dog", "dog_lpc.png"))
    shadow.save(out_path("assets", "characters", "dog", "dog_lpc_shadow.png"))


def build_credits():
    log("Credits: copying license/credit files")
    four = pack_dir("four_season")
    for folder in ("Terrain", "Terrain Objects", "FX"):
        p = os.path.join(four, folder, "Credits.txt")
        if os.path.isfile(p):
            shutil.copyfile(p, out_path("credits", "lpc_revised", f"Credits - {folder}.txt"))
    with open(out_path("credits", "lpc_revised", "README.txt"), "w", newline="\n") as f:
        f.write(
            "LPC Revised art used by this game\n"
            "=================================\n\n"
            f"1. {PACKS['four_season']['title']}\n   {PACKS['four_season']['page']}\n   License: {PACKS['four_season']['license']}\n"
            "   Per-file artists and details: the 'Credits - *.txt' files in this folder.\n"
            "   Used for: trees, bushes, flowers, grass, rocks, mushrooms (assets/props/big_yard/).\n\n"
            f"2. {PACKS['exterior']['title']}\n   {PACKS['exterior']['page']}\n   License: {PACKS['exterior']['license']}\n"
            "   Copyright/Attribution Notice (from the page): JaidynReiman for compiling the assets from\n"
            "   LPC Revised and configuring the Tiled Map Editor tilesets for it. Original LPC Revised\n"
            "   (https://github.com/ElizaWy/LPC) asset contributors include Eliza Wyatt (DeathsDarling),\n"
            "   Lanea Zimmerman (Sharm), Stephen Challener (Redshrike), Johannes Sjolund (Wulax),\n"
            "   BlueCarrot16, BenCreating, Durrani, YuriNikolai and Craftpix.net 2D Game Assets.\n"
            "   Full list: https://github.com/ElizaWy/LPC/blob/main/Credits.txt\n"
            "   Used for: assets/tilesets/lpc_revised/terrain_summer.png (+ data/tilesets/lpc_summer_wang.json).\n\n"
            "Modifications by this project: trees composed from separate canopy/trunk/shadow sprites,\n"
            "sprites cropped and trimmed (tools/art/build_art.py).\n")
    with open(out_path("credits", "dog", "credits.txt"), "w", newline="\n") as f:
        f.write(
            "Dog sprite (assets/characters/dog/dog_lpc.png, dog_lpc_shadow.png)\n"
            "==================================================================\n\n"
            "Shiba dog by Sevarihk, adapted for LPC by tapatilorenzo.\n"
            f"Pack: {PACKS['animals']['title']}\n{PACKS['animals']['page']}\nLicense: {PACKS['animals']['license']}\n"
            "Copyright/Attribution Notice (from the page): Adapted from work by Sevarihk under CC-BY 4.0\n"
            "license, including the shiba dog, shark, giant rat, walking mushroom, and underwater tile sprites.\n\n"
            "Modifications by this project: recolored from golden to brown with brindle stripes\n"
            "(tools/art/build_art.py, build_dog).\n")
    shutil.copyfile(src(("items", "ItemsAndEffects"), "credits.txt"), out_path("credits", "items", "credits_from_pack.txt"))
    with open(out_path("credits", "items", "credits.txt"), "w", newline="\n") as f:
        f.write(
            "Item icons (assets/items/lpc_items.png)\n"
            "=======================================\n\n"
            f"Pack: {PACKS['items']['title']}\n{PACKS['items']['page']}\nLicense: {PACKS['items']['license']}\n"
            "Collaborators listed on the page: Sharm, ETTiNGRiNDER, wulax, Nila122, daneeklu, JaidynReiman,\n"
            "pennomi, laetissima, makrohn and Jetrel. Per-item artists: credits_from_pack.txt (from the pack).\n"
            "Modifications by this project: none (copied as items1.png -> lpc_items.png).\n")
    with open(out_path("credits", "weapons", "credits.txt"), "w", newline="\n") as f:
        f.write("Weapons in hand (assets/weapons/)\n=================================\n\n"
                "From the Universal LPC Spritesheet Character Generator\n"
                "(https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).\n\n")
        for name, w in WEAPON_ART.items():
            f.write(f"{name}_fg.png, {name}_bg.png: {w['title']} by {w['authors']}\n"
                    f"   License: {w['license']}\n   {w['page']}\n"
                    f"   Files: spritesheets/{w['fg']}, spritesheets/{w['bg']}\n\n")
        f.write("Modifications by this project: none (copied as-is).\n")
    with open(out_path("credits", "enemies", "credits.txt"), "w", newline="\n") as f:
        f.write(
            "Enemy sprites\n"
            "=============\n\n"
            "assets/characters/enemies/rat/: the giant rat by Sevarihk, adapted for LPC by tapatilorenzo.\n"
            f"Pack: {PACKS['animals']['title']}\n{PACKS['animals']['page']}\nLicense: {PACKS['animals']['license']}\n"
            "Modifications by this project: the magenta filler cells cleared (tools/art/build_art.py, build_enemies).\n")


STEPS = {"tileset": build_tileset, "props": build_props, "hd": build_hd_textures, "dog": build_dog,
         "enemies": build_enemies, "items": build_items, "weapons": build_weapons, "credits": build_credits}


def main():
    global VERBOSE, OFFLINE
    ap = argparse.ArgumentParser(description="Rebuild the game's third-party art from the original packs.",
                                 epilog="Example: python3 tools/art/build_art.py --only props --verbose")
    ap.add_argument("--offline", action="store_true", help="never download; use tools/art/.cache only")
    ap.add_argument("--only", default="", help="comma-separated steps: " + ", ".join(STEPS))
    ap.add_argument("--list", action="store_true", help="list source packs, licenses, and cache status")
    ap.add_argument("--verbose", action="store_true", help="print every prop as it is written")
    args = ap.parse_args()
    VERBOSE = args.verbose
    OFFLINE = args.offline

    if args.list:
        for key, p in PACKS.items():
            status = "cached" if os.path.isdir(pack_dir(key)) else "not downloaded"
            print(f"{key:12s} [{status}]  {p['license']}\n             {p['title']}\n             {p['page']}")
        return

    steps = [s.strip() for s in args.only.split(",") if s.strip()] or list(STEPS)
    unknown = [s for s in steps if s not in STEPS]
    if unknown:
        sys.exit(f"ERROR: unknown step(s) {unknown}. Choose from: {', '.join(STEPS)}")
    ensure_packs(args.offline)
    for s in steps:
        STEPS[s]()
    log("Done. Re-open Godot (or run --import) so it picks up the new files.")


if __name__ == "__main__":
    main()
