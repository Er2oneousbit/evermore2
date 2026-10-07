#!/usr/bin/env python3
"""
build_audio.py  -  Rebuild every sound and music file the game ships with
-----------------------------------------------------------------------------
WHAT:  Takes the ORIGINAL audio packs (downloaded from OpenGameArt, cached in
       tools/audio/.cache/) and produces exactly what the game uses:

         assets/audio/sfx/<name>.ogg      one short sound each, mono, trimmed,
                                          peak-normalized (loudness per sound
                                          is set in autoload/audio.gd)
         assets/audio/music/<name>.ogg    looping music tracks, as released
         credits/audio/credits.txt        every source, author and license

       A few sounds are generated here (the text blip, the kid's whistle, the
       switch chime): they're original to this project.

       The outputs are committed to git, so nobody NEEDS to run this to play.
       Run it when changing which sounds are used or how they're cut.

USAGE:
  python3 tools/audio/build_audio.py            build (downloads packs if missing)
  python3 tools/audio/build_audio.py --offline  build from the cache only
  python3 tools/audio/build_audio.py --list     list packs, licenses, cache status

NEEDS: Python 3.9+, numpy, soundfile (pip install numpy soundfile), ffmpeg on
       PATH (OGG Vorbis encoding) and 7-Zip (`7z` on PATH, or installed in
       Program Files on Windows) for the .7z packs.

Written with help from Claude (Anthropic) via Claude Code.
Made with love from your friendly hacker - er2oneousbit
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request

try:
    import numpy as np
    import soundfile as sf
except ImportError:
    sys.exit("ERROR: numpy and soundfile are required:  pip install numpy soundfile")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.path.join(ROOT, "tools", "audio", ".cache")
SFX_OUT = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_OUT = os.path.join(ROOT, "assets", "audio", "music")
CREDITS_OUT = os.path.join(ROOT, "credits", "audio", "credits.txt")
OGA = "https://opengameart.org/sites/default/files/"
RATE = 44100

# -----------------------------------------------------------------------------
# Source packs. Each is downloaded once into tools/audio/.cache/<key>/.
# -----------------------------------------------------------------------------
PACKS = {
    "rpg_sound_pack": {
        "title": "RPG Sound Pack", "author": "artisticdude", "license": "CC0",
        "url": OGA + "rpg_sound_pack.zip", "page": "https://opengameart.org/content/rpg-sound-pack",
    },
    "kenney_rpg": {
        "title": "50 RPG sound effects", "author": "Kenney (www.kenney.nl)", "license": "CC0",
        "url": OGA + "RPGsounds_Kenney.zip", "page": "https://opengameart.org/content/50-rpg-sound-effects",
    },
    "punch": {
        "title": "Punch", "author": "Iwan 'qubodup' Gabovitch", "license": "CC0",
        "url": OGA + "qubodupPunch.7z", "page": "https://opengameart.org/content/punch",
    },
    "squeaky_rat": {
        "title": "Squeaky Rat", "author": "Iwan 'qubodup' Gabovitch", "license": "CC0",
        "url": OGA + "qubodupSqueakyRat.7z", "page": "https://opengameart.org/content/squeaky-rat",
    },
    "dog": {
        "title": "Dog sounds", "author": "pauliuw", "license": "CC0",
        "url": OGA + "dog.7z", "page": "https://opengameart.org/content/dog-sounds",
    },
    "footsteps": {
        "title": "Fantozzi's Footsteps (Grass/Sand & Stone)", "author": "Fantozzi (submitted by qubodup)",
        "license": "CC0", "url": OGA + "Fantozzi-footsteps.7z",
        "page": "https://opengameart.org/content/fantozzis-footsteps-grasssand-stone",
    },
    "jrpg_exploration": {
        "title": "JRPG Music Pack #1 [Exploration]", "author": "Juhani Junkala (SubspaceAudio)", "license": "CC0",
        "url": OGA + "JRPG%20Music%20Pack%20%231%20%5BExploration%5D%20by%20Juhani%20Junkala.zip",
        "page": "https://opengameart.org/content/jrpg-pack-1-exploration",
    },
    "jrpg_calm": {
        "title": "JRPG Music Pack #4 [Calm]", "author": "Juhani Junkala (SubspaceAudio)", "license": "CC0",
        "url": OGA + "JRPG%20Music%20Pack%20%234%20%5BCalm%5D%20by%20Juhani%20Junkala_0.zip",
        "page": "https://opengameart.org/content/jrpg-pack-4-calm",
    },
    "jrpg_action": {
        "title": "JRPG Music Pack #5 [Action]", "author": "Juhani Junkala (SubspaceAudio)", "license": "CC0",
        "url": OGA + "JRPG%20Music%20Pack%20%235%20%5BAction%5D%20by%20Juhani%20Junkala.zip",
        "page": "https://opengameart.org/content/jrpg-pack-5-action",
    },
}

# -----------------------------------------------------------------------------
# Sound effects: output name -> (pack, file inside the pack, [start, end] in
# seconds or None for the whole file). Cut points come from measuring the
# recordings (the dog takes have several barks each).
# -----------------------------------------------------------------------------
SFX = {
    # The kid's swing (three takes, picked at random).
    "swing_1": ("rpg_sound_pack", "RPG Sound Pack/battle/swing.wav", None),
    "swing_2": ("rpg_sound_pack", "RPG Sound Pack/battle/swing2.wav", None),
    "swing_3": ("rpg_sound_pack", "RPG Sound Pack/battle/swing3.wav", None),
    # A blow landing on a creature.
    "hit_1": ("punch", "qubodupPunch/qubodupPunch01.flac", [0.0, 0.32]),
    "hit_2": ("punch", "qubodupPunch/qubodupPunch02.flac", [0.0, 0.32]),
    "hit_3": ("punch", "qubodupPunch/qubodupPunch04.flac", [0.0, 0.32]),
    "hit_4": ("punch", "qubodupPunch/qubodupPunch05.flac", [0.0, 0.3]),
    # The stick's wooden crack, layered on charged hits.
    "thwack": ("kenney_rpg", "OGG/chop.ogg", None),
    # Something hits the kid.
    "hurt_1": ("punch", "qubodupPunch/qubodupPunch03.flac", [0.0, 0.25]),
    "hurt_2": ("kenney_rpg", "OGG/cloth1.ogg", [0.05, 0.4]),
    # The dog.
    "dog_bark_1": ("dog", "Dog/Dog 2.wav", [0.38, 0.64]),
    "dog_bark_2": ("dog", "Dog/Dog 2.wav", [8.78, 9.1]),
    "dog_bark_3": ("dog", "Dog/Dog 2.wav", [2.0, 2.28]),
    "dog_bark_4": ("dog", "Dog/Dog 1.wav", [6.15, 6.38]),
    "dog_yelp": ("dog", "Dog/Sad Dog.wav", [0.1, 0.36]),
    "dog_whine": ("dog", "Dog/Sad Dog.wav", [0.88, 1.62]),
    "dog_bite_1": ("rpg_sound_pack", "RPG Sound Pack/NPC/beetle/bite-small.wav", [0.0, 0.3]),
    "dog_bite_2": ("rpg_sound_pack", "RPG Sound Pack/NPC/beetle/bite-small3.wav", [0.0, 0.4]),
    # The giant rat.
    "rat_squeak": ("squeaky_rat", "qubodupSqueakyRat/qubodupSqueakyRatAttack.flac", None),
    "rat_pain": ("squeaky_rat", "qubodupSqueakyRat/qubodupSqueakyRatPain.flac", None),
    "rat_death": ("squeaky_rat", "qubodupSqueakyRat/qubodupSqueakyRatDeath.flac", None),
    "rat_bite": ("rpg_sound_pack", "RPG Sound Pack/NPC/beetle/bite-small2.wav", [0.0, 0.25]),
    # Footsteps: grass/sand and hard ground, left and right feet.
    **{"step_grass_%d" % (i + 1): ("footsteps", "Fantozzi-footsteps/flac/Fantozzi-Sand%s%d.flac" % (s, n), None)
       for i, (s, n) in enumerate([("L", 1), ("R", 1), ("L", 2), ("R", 2), ("L", 3), ("R", 3)])},
    **{"step_stone_%d" % (i + 1): ("footsteps", "Fantozzi-footsteps/flac/Fantozzi-Stone%s%d.flac" % (s, n), None)
       for i, (s, n) in enumerate([("L", 1), ("R", 1), ("L", 2), ("R", 2), ("L", 3), ("R", 3)])},
    # Menus.
    "ui_move": ("rpg_sound_pack", "RPG Sound Pack/interface/interface1.wav", None),
    "ui_confirm": ("rpg_sound_pack", "RPG Sound Pack/interface/interface6.wav", [0.0, 0.25]),
    "ui_back": ("rpg_sound_pack", "RPG Sound Pack/interface/interface2.wav", [0.0, 0.3]),
    "ui_open": ("rpg_sound_pack", "RPG Sound Pack/interface/interface3.wav", [0.0, 0.3]),
}

## Music: output name -> (pack, file). The tracks are seamless loops.
MUSIC = {
    "home": ("jrpg_calm", "Calm1 - A Place I Call Home.ogg"),        # dinner with Dad
    "lot": ("jrpg_calm", "Calm2 - Childhood Friends.ogg"),           # the dare
    "yard": ("jrpg_exploration", "Exploration1 - Grasslands.ogg"),    # the test yard
    "arena": ("jrpg_action", "Action3 - Preparing For Battle.ogg"),   # the combat arena
}


# -----------------------------------------------------------------------------
# Downloading and unpacking
# -----------------------------------------------------------------------------
def pack_dir(key):
    return os.path.join(CACHE, key)


def seven_zip():
    for c in [shutil.which("7z"), shutil.which("7za"), r"C:\Program Files\7-Zip\7z.exe"]:
        if c and os.path.exists(c):
            return c
    return None


def fetch(key, offline):
    d = pack_dir(key)
    if os.path.isdir(d) and os.listdir(d):
        return d
    if offline:
        sys.exit(f"ERROR: {key} isn't cached and --offline was given")
    os.makedirs(CACHE, exist_ok=True)
    url = PACKS[key]["url"]
    archive = os.path.join(CACHE, key + (".7z" if url.endswith(".7z") else ".zip"))
    print(f"  downloading {PACKS[key]['title']} ...")
    urllib.request.urlretrieve(url, archive)
    z = seven_zip()
    if z is None:
        sys.exit("ERROR: 7-Zip is needed to unpack the packs (7z on PATH)")
    os.makedirs(d, exist_ok=True)
    subprocess.run([z, "x", "-y", "-o" + d, archive], check=True, stdout=subprocess.DEVNULL)
    os.remove(archive)
    return d


def source(key, rel, offline):
    path = os.path.join(fetch(key, offline), rel)
    if not os.path.exists(path):
        sys.exit(f"ERROR: {rel} not found in pack {key}")
    return path


# -----------------------------------------------------------------------------
# Processing
# -----------------------------------------------------------------------------
def load_mono(path, cut):
    data, sr = sf.read(path, always_2d=True)
    data = data.mean(axis=1)
    if cut:
        data = data[int(cut[0] * sr):int(cut[1] * sr)]
    return data, sr


def finish(data, sr):
    """Trim silence, short fades (no clicks), peak at -1 dBFS."""
    env = np.abs(data)
    keep = np.where(env > env.max() * 0.02)[0]
    if len(keep):
        data = data[max(0, keep[0] - int(sr * 0.004)):keep[-1] + int(sr * 0.02)]
    fade_in = min(len(data), int(sr * 0.003))
    fade_out = min(len(data), int(sr * 0.015))
    data = data.copy()
    data[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    data[len(data) - fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    peak = np.abs(data).max()
    if peak > 0:
        data *= 10 ** (-1.0 / 20) / peak
    return data


def write_ogg(data, sr, out):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        sys.exit("ERROR: ffmpeg is needed for OGG encoding (ffmpeg on PATH)")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        sf.write(wav, data.astype(np.float32), sr, subtype="PCM_16")
        subprocess.run([ffmpeg, "-loglevel", "error", "-y", "-i", wav, "-ar", str(RATE), "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "5", out], check=True)


# --- Generated sounds (original to this project) -------------------------------
def synth_blip():
    """Dialogue text blip: a soft, short square-ish tick."""
    t = np.arange(int(RATE * 0.035)) / RATE
    tone = np.sign(np.sin(2 * np.pi * 620 * t)) * 0.35 + np.sin(2 * np.pi * 1240 * t) * 0.2
    return tone * np.exp(-t * 90)


def synth_whistle():
    """The kid's call-back whistle: two rising notes."""
    out = []
    for f0, f1, dur in [(1500, 1900, 0.16), (1700, 2300, 0.22)]:
        t = np.arange(int(RATE * dur)) / RATE
        freq = np.linspace(f0, f1, len(t))
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        env = np.minimum(1.0, t / 0.02) * np.minimum(1.0, (dur - t) / 0.05)
        vib = 1.0 + 0.004 * np.sin(2 * np.pi * 6 * t)
        out.append(np.sin(phase * vib) * env)
        out.append(np.zeros(int(RATE * 0.05)))
    return np.concatenate(out)


def synth_chime():
    """Switching control: a soft two-note chime."""
    t = np.arange(int(RATE * 0.5)) / RATE
    a = np.sin(2 * np.pi * 784 * t) * np.exp(-t * 7)
    b = np.zeros_like(t)
    off = int(RATE * 0.08)
    b[off:] = np.sin(2 * np.pi * 1175 * t[:len(t) - off]) * np.exp(-t[:len(t) - off] * 7)
    return (a + b) * 0.5


SYNTH = {"text_blip": synth_blip, "whistle": synth_whistle, "switch": synth_chime}


# -----------------------------------------------------------------------------
def build(offline):
    os.makedirs(SFX_OUT, exist_ok=True)
    os.makedirs(MUSIC_OUT, exist_ok=True)
    for name, (key, rel, cut) in SFX.items():
        data, sr = load_mono(source(key, rel, offline), cut)
        write_ogg(finish(data, sr), sr, os.path.join(SFX_OUT, name + ".ogg"))
        print("  sfx   %s" % name)
    for name, fn in SYNTH.items():
        write_ogg(finish(fn(), RATE), RATE, os.path.join(SFX_OUT, name + ".ogg"))
        print("  sfx   %s (generated)" % name)
    for name, (key, rel) in MUSIC.items():
        shutil.copyfile(source(key, rel, offline), os.path.join(MUSIC_OUT, name + ".ogg"))
        print("  music %s" % name)
    write_credits()


def write_credits():
    os.makedirs(os.path.dirname(CREDITS_OUT), exist_ok=True)
    used = {}
    for name, (key, rel, _cut) in SFX.items():
        used.setdefault(key, []).append(f"{name}.ogg  <-  {rel}")
    for name, (key, rel) in MUSIC.items():
        used.setdefault(key, []).append(f"music/{name}.ogg  <-  {rel}")
    lines = ["Audio used by Secret of Evermore 2: Return to Evermore",
             "Rebuilt by tools/audio/build_audio.py. Every source below is CC0 (public domain);",
             "credit is given anyway, with thanks.", ""]
    for key, files in used.items():
        p = PACKS[key]
        lines += [f"{p['title']}", f"  by {p['author']}", f"  license: {p['license']}", f"  {p['page']}"]
        lines += ["  " + f for f in files] + [""]
    lines += ["Generated by this project (original, same license as the code):",
              "  " + ", ".join(n + ".ogg" for n in SYNTH), ""]
    with open(CREDITS_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("  credits/audio/credits.txt")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--offline", action="store_true", help="use cached packs only")
    ap.add_argument("--list", action="store_true", help="list packs and cache status")
    args = ap.parse_args()
    if args.list:
        for key, p in PACKS.items():
            cached = "cached" if os.path.isdir(pack_dir(key)) else "not cached"
            print(f"{key:18} {p['license']:6} {cached:11} {p['title']} by {p['author']}")
        return
    build(args.offline)


if __name__ == "__main__":
    main()
