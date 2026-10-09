#!/usr/bin/env bash
# =============================================================================
# run_all.sh  -  Run every headless smoke test (Linux / macOS / CI)
# -----------------------------------------------------------------------------
# USAGE:  tests/run_all.sh [path/to/godot]        (or set GODOT=...)
# RUNS:   smoke_follow at 30, 60 and 120 RENDER fps (physics stays at 60 Hz;
#         this proves nothing depends on the render frame rate, e.g. a 144 Hz
#         monitor), smoke_visuals, smoke_hd, smoke_dialogue, smoke_combat, smoke_party, smoke_settings, smoke_audio, smoke_items, smoke_ring, smoke_rings, smoke_clock, smoke_enemy_clock, smoke_travel, smoke_aspect. No display needed. For the live ultrawide checks use run_aspect_matrix.sh.
# EXIT:   0 if everything passed, 1 otherwise.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
set -u
GODOT="${1:-${GODOT:-godot}}"
# Frame cap: a test whose script fails to compile never quits on its own.
# Real runs need a few thousand frames; past this cap the run ends without
# a PASS line and counts as a failure, in seconds instead of a long timeout.
MAX_FRAMES=20000
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "ERROR: Godot not found at '$GODOT'. Pass the path as the first argument." >&2
  exit 1
fi

fail=0
run() {  # run <label> <scene> [extra godot args...]
  local label="$1" scene="$2"; shift 2
  printf '%-22s ' "$label"
  local out
  out=$(timeout 300 "$GODOT" --headless --path "$PROJECT_DIR" --audio-driver Dummy --quit-after "$MAX_FRAMES" "$@" "$scene" 2>&1)
  local code=$?
  # A script error fails the run even if the test printed PASS: errors in
  # code a test doesn't check (a freed node after a scene change) hide there.
  if [ $code -eq 0 ] && echo "$out" | grep -q '\[TEST\] PASS' && ! echo "$out" | grep -q 'SCRIPT ERROR'; then
    echo "PASS  $(echo "$out" | grep -o '\[TEST\] PASS.*' | sed 's/\[TEST\] PASS *//')"
  else
    echo "FAIL (exit $code)"
    echo "$out" | grep -E '\[TEST\] FAIL|SCRIPT ERROR|^ERROR' | sed 's/^/      /'
    fail=1
  fi
}

run "follow @30fps"  res://tests/smoke_follow.tscn --fixed-fps 30
run "follow @60fps"  res://tests/smoke_follow.tscn --fixed-fps 60
run "follow @120fps" res://tests/smoke_follow.tscn --fixed-fps 120
run "visuals"        res://tests/smoke_visuals.tscn --fixed-fps 60
run "hd-2d view"     res://tests/smoke_hd.tscn --fixed-fps 60
run "dialogue"       res://tests/smoke_dialogue.tscn --fixed-fps 60
run "combat"         res://tests/smoke_combat.tscn --fixed-fps 60
run "party"          res://tests/smoke_party.tscn --fixed-fps 60
run "settings"       res://tests/smoke_settings.tscn --fixed-fps 60
run "audio"          res://tests/smoke_audio.tscn --fixed-fps 60
run "items"          res://tests/smoke_items.tscn --fixed-fps 60
run "ring menu"      res://tests/smoke_ring.tscn --fixed-fps 60
run "rings, slots"   res://tests/smoke_rings.tscn --fixed-fps 60
run "clock, shops"   res://tests/smoke_clock.tscn --fixed-fps 60
run "day/night foes" res://tests/smoke_enemy_clock.tscn --fixed-fps 60
run "map exits"      res://tests/smoke_travel.tscn --fixed-fps 60
run "aspect (math)"  res://tests/smoke_aspect.tscn

[ $fail -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $fail
