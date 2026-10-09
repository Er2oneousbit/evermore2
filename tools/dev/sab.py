#!/usr/bin/env python3
"""
sab.py  -  Prove a test catches a bug: break one thing, run the test, restore
-----------------------------------------------------------------------------
WHAT:  Replaces the first occurrence of OLD with NEW in FILE, runs one
       headless smoke test, prints its [TEST] and SCRIPT ERROR lines, and
       always puts FILE back (even on Ctrl+C). A test that still prints PASS
       after the break doesn't cover that code.

USAGE: python tools/dev/sab.py FILE OLD NEW TEST [--label TEXT]
         python tools/dev/sab.py systems/items/nose.gd \
             "const NEAR_LEADER := 180.0" "const NEAR_LEADER := 9999.0" smoke_items
       OLD/NEW may span lines (quote them). TEST is the scene name in tests/.
       Godot: $GODOT, else ../godot/Godot_v4.7.2-stable_win64_console.exe
       next to the repo, else `godot` on PATH.

Written with help from Claude (Anthropic) via Claude Code.
Made with love from your friendly hacker - er2oneousbit
"""
import argparse
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def godot():
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    local = os.path.join(os.path.dirname(ROOT), "godot", "Godot_v4.7.2-stable_win64_console.exe")
    if os.path.isfile(local):
        return local
    return shutil.which("godot") or sys.exit("ERROR: Godot not found; set GODOT")


def main():
    ap = argparse.ArgumentParser(description="Break one thing, run a test, restore.")
    ap.add_argument("file")
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("test")
    ap.add_argument("--label", default="")
    a = ap.parse_args()
    path = os.path.join(ROOT, a.file)
    with open(path, encoding="utf-8", newline="") as f:
        original = f.read()
    if a.old not in original:
        sys.exit(f"ERROR: OLD text not found in {a.file}")
    print(f"== {a.label or a.file}")
    try:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(original.replace(a.old, a.new, 1))
        out = subprocess.run([godot(), "--headless", "--path", ROOT, "--audio-driver", "Dummy",
                              "--fixed-fps", "60", "--quit-after", "20000", f"res://tests/{a.test}.tscn"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
        lines = [l for l in (out.stdout + out.stderr).splitlines() if "[TEST]" in l or "SCRIPT ERROR" in l]
        print("\n".join(lines[:4]) or "(no [TEST] line: it didn't finish)")
    finally:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(original)


if __name__ == "__main__":
    main()
