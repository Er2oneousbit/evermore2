#!/usr/bin/env python3
"""
faces.py  -  Paint a tiny nose and mouth on every front-facing LPC frame
-----------------------------------------------------------------------------
WHAT:  The Universal LPC generator draws eyes only. In the original game the
       hero shows a tiny mouth (and a hint of a nose) when he faces the camera
       and nothing from the side. This step post-processes each character
       sheet (assets/characters/<name>/<name>_lpc.png): for every FRONT
       ("down") frame of every animation row it finds the eyes, then paints
         - a 2 px nose, 2 rows below the eye tops, a soft shade of the skin
         - a 2 px mouth, 4 rows below the eye tops, a darker rosy shade
       at a fixed offset from the eyes, so both ride the head bob frame by
       frame. Side and back rows are never touched.

WHY:   The generator's own "button nose" layer is GPL 3.0 / CC-BY-SA 3.0 only,
       which would make every sheet share-alike (see CREDITS.md). Drawing two
       pixels by hand keeps the sheets under their current licenses and needs
       no credit entry.

HOW:   Eyes are found by their cyan glints: six pixels at fixed offsets
       (3 per eye), at least 5 of 6 present, with the dark eye interior
       between them. Frames where that fails (hurt and spellcast frames that
       turn or drop the head) are skipped and logged. The skin color is the
       pixel between the eyes; nose and mouth are computed from it. A target
       pixel that is not skin (a beard) is left alone, so bearded men get a
       nose and no mouth. The step is idempotent: running it again changes
       nothing, because painted pixels no longer look like skin.
       Rebuild a sheet: node tools/lpc/build_character.js <key> <dir>, copy the
       sheet over the asset, then python tools/art/faces.py (or
       build_art.py --only faces).

USAGE:
  python tools/art/faces.py [--verbose] [--check]   (--check changes nothing,
                                                     exits 1 if a sheet would change)

Written with help from Claude (Anthropic) via Claude Code.
Made with <3 from your friendly hacker - er2oneousbit
"""
import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("ERROR: Pillow is required:  pip install pillow")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CHARACTERS = ["kid", "dad", "maya", "dex", "grocer", "vendor"]
FRAME = 64
COLUMNS = 13
# First row of each 4-direction animation block (up, left, down, right), from
# systems/animation/lpc_sprite.gd. The DOWN row is first + 2. Hurt (row 20) is
# one-direction and faces the camera.
BLOCK_FIRST_ROWS = [0, 4, 8, 12, 16, 22, 26, 30, 34, 38, 42, 46, 50]
FRONT_ROWS = [r + 2 for r in BLOCK_FIRST_ROWS] + [20]

# Eye glints (cyan), relative to the left eye's outer glint: 3 per eye.
GLINTS = [(0, 0), (3, 0), (2, 1), (8, 0), (11, 0), (9, 1)]
# The dark/white eye interior between a pair of glints must NOT be cyan (this
# rejects solid blue shirts, which would otherwise match the glint pattern).
GAPS = [(1, 0), (2, 0), (9, 0), (10, 0)]
MIN_HITS = 5
# Placement, relative to the same anchor: x is the gap between the eyes (the
# face is 2 px wide there), y is below the eye tops.
CENTER_X = (5, 6)
NOSE_Y = 2
MOUTH_Y = 4
NOSE_MIX = (0.86, 0.80, 0.80)    # per channel: skin * factor (soft shade)
MOUTH_MIX = (0.66, 0.46, 0.44)   # rosy dark, never black
SKIN_TOLERANCE = 30              # max per-channel distance to count as skin
SEARCH_Y = range(20, 37)
SEARCH_X = range(14, 42)


def _cyan(p):
    return p[3] > 200 and p[2] > 150 and p[0] < 120


def find_eyes(px, ox, oy):
    """Return the (x, y) anchor of the left outer glint, or None."""
    for ey in SEARCH_Y:
        for ex in SEARCH_X:
            hits = sum(1 for dx, dy in GLINTS if _cyan(px[ox + ex + dx, oy + ey + dy]))
            if hits < MIN_HITS:
                continue
            if any(_cyan(px[ox + ex + dx, oy + ey + dy]) for dx, dy in GAPS):
                continue
            return ex, ey
    return None


def _shade(c, mix):
    return tuple(max(0, min(255, round(c[i] * mix[i]))) for i in range(3)) + (255,)


def _is_skin(p, skin):
    return p[3] == 255 and all(abs(p[i] - skin[i]) <= SKIN_TOLERANCE for i in range(3))


def colors_for(skin):
    """Nose and mouth colors for a skin color (used by the test too)."""
    return _shade(skin, NOSE_MIX), _shade(skin, MOUTH_MIX)


def process_sheet(path, log, write=True):
    """Paint faces on one sheet. Returns (frames with a face, skipped frames, changed)."""
    img = Image.open(path).convert("RGBA")
    px = img.load()
    painted = skipped = 0
    changed = False
    for row in FRONT_ROWS:
        for col in range(COLUMNS):
            ox, oy = col * FRAME, row * FRAME
            if all(px[ox + x, oy + y][3] == 0 for x in range(FRAME) for y in range(FRAME)):
                continue  # empty cell
            eyes = find_eyes(px, ox, oy)
            if eyes is None:
                skipped += 1
                log(f"    skip row {row} col {col}: eyes not found")
                continue
            ex, ey = eyes
            sx, sy = ex + CENTER_X[0], ey + 1
            skin = px[ox + sx, oy + sy]
            if skin[3] != 255:
                skipped += 1
                log(f"    skip row {row} col {col}: no skin between the eyes")
                continue
            nose, mouth = colors_for(skin)
            frame_painted = False
            for dy, color in ((NOSE_Y, nose), (MOUTH_Y, mouth)):
                for dx in CENTER_X:
                    x, y = ox + ex + dx, oy + ey + dy
                    if px[x, y] == color:
                        frame_painted = True
                    elif _is_skin(px[x, y], skin):
                        px[x, y] = color
                        frame_painted = changed = True
                    else:
                        log(f"    row {row} col {col}: ({ex + dx},{ey + dy}) is not skin (beard?), left alone")
            painted += 1 if frame_painted else 0
    if write and changed:
        img.save(path)
    return painted, skipped, changed


def run(log=print, verbose=False, write=True):
    vlog = log if verbose else (lambda m: None)
    any_changed = False
    for name in CHARACTERS:
        path = os.path.join(ROOT, "assets", "characters", name, f"{name}_lpc.png")
        painted, skipped, changed = process_sheet(path, vlog, write)
        any_changed = any_changed or changed
        log(f"Faces: {name}: {painted} frames with a face, {skipped} front frames skipped (head turned)")
    return any_changed


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Paint a nose and mouth on front-facing LPC frames.")
    ap.add_argument("--verbose", action="store_true", help="log every skipped frame")
    ap.add_argument("--check", action="store_true", help="change nothing; exit 1 if a sheet would change")
    a = ap.parse_args()
    changed = run(print, a.verbose, write=not a.check)
    sys.exit(1 if (a.check and changed) else 0)
