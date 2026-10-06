#!/usr/bin/env bash
# =============================================================================
# run_aspect_matrix.sh  -  Run tests/smoke_aspect at every monitor size (Linux)
# -----------------------------------------------------------------------------
# Launches the game once per resolution inside a virtual X display (Xvfb), so
# it works on headless Linux / CI with no monitor attached.
#
# USAGE:
#   tests/run_aspect_matrix.sh [path/to/godot] [screenshot_dir]
#   GODOT=/opt/godot/godot tests/run_aspect_matrix.sh
#
# NEEDS: xvfb-run (apt install xvfb) and Mesa (software OpenGL) for rendering.
# EXIT:  0 if every resolution passes, 1 otherwise.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
set -u

GODOT="${1:-${GODOT:-godot}}"
SHOT_DIR="${2:-}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Real monitors: Steam Deck -> 16:9 -> 21:9 -> 32:9 -> 48:9 triple-wide.
RESOLUTIONS=(
  1280x800 1366x768 1920x1080 2560x1440 3840x2160
  2560x1080 3440x1440 3840x1600
  3840x1080 5120x1440 7680x2160
  5760x1080 7680x1440
)

if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "ERROR: xvfb-run not found (sudo apt install xvfb)" >&2
  exit 1
fi
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "ERROR: Godot not found at '$GODOT'. Pass the path as the first argument." >&2
  exit 1
fi

fail=0
for res in "${RESOLUTIONS[@]}"; do
  w="${res%x*}"; h="${res#*x}"
  printf '%-10s ' "$res"
  output=$(EVERMORE_SHOT_DIR="$SHOT_DIR" timeout 120 \
    xvfb-run -a -s "-screen 0 ${w}x$((h + 64))x24" \
    "$GODOT" --path "$PROJECT_DIR" --audio-driver Dummy \
      --rendering-driver opengl3 --rendering-method gl_compatibility \
      --resolution "$res" --position 0,0 res://tests/smoke_aspect.tscn 2>&1)
  code=$?
  if [ $code -eq 0 ]; then
    echo "PASS  $(echo "$output" | grep -o 'scale [0-9]*x, view ([0-9, ]*)' | head -1)"
  else
    echo "FAIL (exit $code)"
    echo "$output" | grep -E '\[TEST\] FAIL|ERROR|SCRIPT' | sed 's/^/           /'
    fail=1
  fi
done

[ $fail -eq 0 ] && echo "ALL RESOLUTIONS PASSED" || echo "SOME RESOLUTIONS FAILED"
exit $fail
