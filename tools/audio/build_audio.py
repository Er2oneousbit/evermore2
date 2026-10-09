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
         assets/audio/voice/<name>.ogg    short voice clips ("Hey!", "What?"):
                                          real voice actors, one or two words
         assets/audio/ambience/<name>.ogg background loops (birds by day,
                                          crickets at night), stereo, with
                                          the end crossfaded into the start
                                          so they loop without a seam
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
AMBIENCE_OUT = os.path.join(ROOT, "assets", "audio", "ambience")
VOICE_OUT = os.path.join(ROOT, "assets", "audio", "voice")
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
    "forest_birds": {
        "title": "Forest bird sounds", "author": "pauliuw", "license": "CC0",
        "url": OGA + "forest_birds.7z", "page": "https://opengameart.org/content/forest-bird-sounds",
    },
    "dig": {
        "title": "Digging Underground", "author": "Almitory", "license": "CC0 (also CC-BY/CC-BY-SA/GPL/OGA-BY)",
        "url": OGA + "dig_underground_1.mp3", "page": "https://opengameart.org/node/138434",
    },
    "pickup": {
        "title": "Item Pickup / Key", "author": "Musheran", "license": "CC0",
        "url": OGA + "key-176034.mp3", "page": "https://opengameart.org/content/item-pickup-key",
    },
    "birds_wind": {
        "title": "Birds and Wind - Ambient", "author": "Spring Spring", "license": "CC0",
        "url": OGA + "Birds%20and%20Wind%20-%20Ambient_1.ogg",
        "page": "https://opengameart.org/content/birds-and-wind-ambient-birds-wind-and-synth",
    },
    "crickets": {
        "title": "Crickets Ambient Noise - loopable", "author": "Wolfgang_ (attribution notice: Ted Kerr)",
        "license": "CC0", "url": OGA + "crickets_1.mp3",
        "page": "https://opengameart.org/content/crickets-ambient-noise-loopable",
    },
    "voice_bright": {
        "title": "Free Voice Clips Pack - Bright Female", "author": "cicifyre", "license": "CC0",
        "url": OGA + "Free%20Voice%20Clips%20Pack%20-%20Bright%20Female_0.zip",
        "page": "https://opengameart.org/content/voice-clip-packs-for-visual-novels-and-rpgs",
    },
    "voice_adventurer": {
        "title": "Voice Clip Pack - Male Adventurer RPG", "author": "Brandon Song (wolfwoot)", "license": "CC0",
        "url": OGA + "RPG%20Male%20Adventurer.zip",
        "page": "https://opengameart.org/content/voice-clip-pack-male-adventurer-rpg",
    },
    "dog_snarl": {
        "title": "Dog Snarl Grunt Grumble", "author": "Iwan 'qubodup' Gabovitch", "license": "CC0",
        "url": OGA + "dog_0.7z", "page": "https://opengameart.org/content/dog-snarl-grunt-grumble",
    },
    "dog_frieda": {
        "title": "Dog Grunt", "author": "Iwan 'qubodup' Gabovitch", "license": "CC0",
        "url": OGA + "dog-frieda-grunt-96khz-01.flac", "page": "https://opengameart.org/content/dog-grunt",
    },
    "vicious": {
        "title": "Tiny vicious creature", "author": "Darsycho", "license": "CC0",
        "url": OGA + "tiny-vicious-creature_0.ogg", "page": "https://opengameart.org/content/tiny-vicious-creature",
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
    # Hidden items (the dog digs, the kid picks it up).
    "dig": ("dig", "dig_underground_1.mp3", [0.1, 2.1]),
    "pickup": ("pickup", "key-176034.mp3", None),
    # A bird now and then by day, on top of the ambience.
    "bird_1": ("forest_birds", "Forest Birds/Forest Birds 9.wav", None),
    "bird_2": ("forest_birds", "Forest Birds/Forest Birds 8.wav", None),
    "bird_3": ("forest_birds", "Forest Birds/Forest Birds 10.wav", None),
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
    # Music follows the time of day outdoors (autoload/audio.gd MUSIC_SETS):
    # day = yard + tropical (upbeat), night = lot + innocence (quiet).
    "tropical": ("jrpg_exploration", "Exploration6 - Tropical Island.ogg"),
    "innocence": ("jrpg_calm", "Calm6 - Innocence.ogg"),
}


## Layered sounds: output name -> list of layers (pack, file, [start, end] or
## None, when it starts in seconds, gain in dB). "click" as the pack adds a
## generated teeth click instead of a file.
## The dog's bite: a snarl, then the snap of teeth landing ~70 ms in, which is
## when the bite animation's hit frame comes (frame 1 at 14 fps). When it
## connects, the regular hit thump adds the weight.
_SNAP_AT = 0.07
MIX = {
    # Snarl first, quieter, as the lead-in; each chomp cut starts right at its
    # attack (measured), so the teeth land on _SNAP_AT.
    "dog_bite_1": [("dog_snarl", "dog/dog-snarl.flac", [0.0, 0.2], 0.0, -5.0),
                   ("vicious", "tiny-vicious-creature_0.ogg", [1.91, 2.0], _SNAP_AT, 0.0),
                   ("click", "", None, _SNAP_AT, -9.0)],
    "dog_bite_2": [("dog_snarl", "dog/dog-growl.flac", [0.1, 0.3], 0.0, -5.0),
                   ("vicious", "tiny-vicious-creature_0.ogg", [4.485, 4.6], _SNAP_AT, 0.0),
                   ("click", "", None, _SNAP_AT, -9.0)],
    "dog_bite_3": [("dog_frieda", "dog-frieda-grunt-96khz-01.flac", [0.1, 0.32], 0.0, -5.0),
                   ("vicious", "tiny-vicious-creature_0.ogg", [5.73, 5.85], _SNAP_AT, 0.0),
                   ("click", "", None, _SNAP_AT, -9.0)],
}

## Voice clips: output name -> (pack, file). One or two words each, played
## when someone starts talking to you or reacts (autoload/audio.gd VOICES).
_BRIGHT = "Free Voice Clips Pack - Bright Female/"
_ADV = "RPG Male Adventurer/"
VOICE = {
    **{f"bright_hey_{i}": ("voice_bright", f"{_BRIGHT}0{i}-hey.wav") for i in (1, 2, 3)},
    **{f"bright_hello_{i}": ("voice_bright", f"{_BRIGHT}0{i}-hello.wav") for i in (1, 2, 3)},
    **{f"bright_what_{i}": ("voice_bright", f"{_BRIGHT}0{i}-what.wav") for i in (1, 2, 3)},
    **{f"bright_why_{i}": ("voice_bright", f"{_BRIGHT}0{i}-why.wav") for i in (1, 2, 3)},
    **{f"bright_okay_{i}": ("voice_bright", f"{_BRIGHT}0{i}-okay.wav") for i in (1, 2, 3)},
    **{f"bright_bye_{i}": ("voice_bright", f"{_BRIGHT}0{i}-bye.wav") for i in (1, 2, 3)},
    **{f"bright_laugh_{i}": ("voice_bright", f"{_BRIGHT}0{i}-laughter.wav") for i in (1, 2)},
    "bright_gasp_1": ("voice_bright", f"{_BRIGHT}02-anime gasp.wav"),
    "adventurer_greet_1": ("voice_adventurer", f"{_ADV}greet0.wav"),
    "adventurer_yes_1": ("voice_adventurer", f"{_ADV}yes0.wav"),
    "adventurer_yes_2": ("voice_adventurer", f"{_ADV}yes1.wav"),
    "adventurer_no_1": ("voice_adventurer", f"{_ADV}no0.wav"),
    "adventurer_no_2": ("voice_adventurer", f"{_ADV}no1.wav"),
}

## Ambience loops: output name -> (pack, file, crossfade seconds for the seam).
AMBIENCE = {
    "day": ("birds_wind", "Birds%20and%20Wind%20-%20Ambient_1.ogg", 3.0),
    "night": ("crickets", "crickets_1.mp3", 0.6),
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
    print(f"  downloading {PACKS[key]['title']} ...")
    if not (url.endswith(".7z") or url.endswith(".zip")):
        # A single sound file: keep it under its own (URL) name.
        os.makedirs(d, exist_ok=True)
        urllib.request.urlretrieve(url, os.path.join(d, url.rsplit("/", 1)[1]))
        return d
    archive = os.path.join(CACHE, key + (".7z" if url.endswith(".7z") else ".zip"))
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


def teeth_click(sr):
    """A short, bright click: the crack of teeth closing."""
    n = int(sr * 0.012)
    rng = np.random.default_rng(7)
    noise = np.diff(rng.uniform(-1, 1, n + 1))  # differentiated noise = mostly highs
    return noise * np.exp(-np.arange(n) / (sr * 0.0025))


def build_mix(layers, offline):
    """Mix the layers of one sound at RATE, each normalized, then placed."""
    out = np.zeros(int(RATE * 1.0))
    for key, rel, cut, at, gain_db in layers:
        if key == "click":
            data = teeth_click(RATE)
        else:
            data, sr = load_mono(source(key, rel, offline), cut)
            if sr != RATE:  # simple linear resample; these are short one-shots
                data = np.interp(np.arange(0, len(data), sr / RATE), np.arange(len(data)), data)
            data = data / max(np.abs(data).max(), 1e-6)
        start = int(RATE * at)
        end = min(len(out), start + len(data))
        out[start:end] += data[:end - start] * 10 ** (gain_db / 20)
    return out


def make_loop(data, sr, xfade):
    """Seamless loop: the last `xfade` seconds fade into the first ones, and
    the loop is that much shorter, so the end runs straight into the start."""
    n = int(sr * xfade)
    ramp = np.linspace(0.0, 1.0, n)[:, None]
    body = data[:-n].copy()
    body[:n] = data[:n] * ramp + data[-n:] * (1.0 - ramp)
    return body


def write_ogg(data, sr, out, channels=1):
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        sys.exit("ERROR: ffmpeg is needed for OGG encoding (ffmpeg on PATH)")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        sf.write(wav, data.astype(np.float32), sr, subtype="PCM_16")
        subprocess.run([ffmpeg, "-loglevel", "error", "-y", "-i", wav, "-ar", str(RATE), "-ac", str(channels),
                        "-c:a", "libvorbis", "-q:a", "5",
                        # Same input, same bytes: no random stream serial or version
                        # tag, so a rebuild doesn't rewrite every file in git.
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", out], check=True)


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
    for name, layers in MIX.items():
        write_ogg(finish(build_mix(layers, offline), RATE), RATE, os.path.join(SFX_OUT, name + ".ogg"))
        print("  sfx   %s (layered)" % name)
    for name, fn in SYNTH.items():
        write_ogg(finish(fn(), RATE), RATE, os.path.join(SFX_OUT, name + ".ogg"))
        print("  sfx   %s (generated)" % name)
    for name, (key, rel) in MUSIC.items():
        shutil.copyfile(source(key, rel, offline), os.path.join(MUSIC_OUT, name + ".ogg"))
        print("  music %s" % name)
    os.makedirs(VOICE_OUT, exist_ok=True)
    for name, (key, rel) in VOICE.items():
        data, sr = load_mono(source(key, rel, offline), None)
        write_ogg(finish(data, sr), sr, os.path.join(VOICE_OUT, name + ".ogg"))
        print("  voice %s" % name)
    os.makedirs(AMBIENCE_OUT, exist_ok=True)
    for name, (key, rel, xfade) in AMBIENCE.items():
        data, sr = sf.read(source(key, rel, offline), always_2d=True)
        if data.shape[1] == 1:
            data = np.repeat(data, 2, axis=1)
        data = make_loop(data, sr, xfade)
        data *= 10 ** (-3.0 / 20) / max(np.abs(data).max(), 1e-6)  # peak -3 dBFS
        write_ogg(data, sr, os.path.join(AMBIENCE_OUT, name + ".ogg"), channels=2)
        print("  amb   %s" % name)
    write_credits()


def write_credits():
    os.makedirs(os.path.dirname(CREDITS_OUT), exist_ok=True)
    used = {}
    for name, (key, rel, _cut) in SFX.items():
        used.setdefault(key, []).append(f"{name}.ogg  <-  {rel}")
    for name, (key, rel) in MUSIC.items():
        used.setdefault(key, []).append(f"music/{name}.ogg  <-  {rel}")
    for name, (key, rel) in VOICE.items():
        used.setdefault(key, []).append(f"voice/{name}.ogg  <-  {rel}")
    for name, layers in MIX.items():
        for key, rel, _c, _a, _g in layers:
            if key != "click":
                used.setdefault(key, []).append(f"{name}.ogg  <-  {rel} (one layer)")
    for name, (key, rel, _x) in AMBIENCE.items():
        used.setdefault(key, []).append(f"ambience/{name}.ogg  <-  {rel} (looped)")
    lines = ["Audio used by Secret of Evermore 2: Return to Evermore",
             "Rebuilt by tools/audio/build_audio.py. Every source below is CC0 (public domain);",
             "credit is given anyway, with thanks. Sound effects are trimmed, mixed to mono and",
             "normalized; ambience loops have their end crossfaded into their start.", ""]
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
