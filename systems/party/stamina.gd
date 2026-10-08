# =============================================================================
# stamina.gd  -  Running and the stamina meter (kid and dog, when driven)
# -----------------------------------------------------------------------------
# WHAT:  You walk by default; hold Run (Shift / gamepad LB) to run. Running
#        drains the meter; let go and, after a short breath, it refills. Run
#        it dry and he's winded: no running until it's back to RECOVER_AT.
#        Settings "Run button" can make Run a toggle instead (press once to
#        run, it switches off when you stand still a moment or get winded;
#        pressed while standing, it's ready for your next move).
#        The AI partner doesn't use stamina: he has to keep up with you.
#
#          var running := stamina.tick(delta, stamina.wants_run(moving, delta), moving)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Stamina
extends RefCounted

## Winded: running comes back once the meter refills to this much.
const RECOVER_AT := 0.35
## After running, the meter waits this long (s) before it starts to refill.
const REST_DELAY := 0.6
## Toggle mode: standing still this long (s) ends a toggled run. Not one
## frame: turning around on a keyboard passes through a frame of no keys.
const TOGGLE_STILL := 0.25

## Seconds of running on a full meter.
var run_seconds := 4.0
## Seconds to refill from empty.
var refill_seconds := 2.5
## 0..1.
var value := 1.0
## Ran it dry: no running until it refills to RECOVER_AT.
var winded := false

var _rest := 0.0
var _toggled := false
var _still := 0.0
## Moved since Run was pressed: only then can standing still end the run.
var _moved := false


func _init(seconds_of_running := 4.0, seconds_to_refill := 2.5) -> void:
	run_seconds = seconds_of_running
	refill_seconds = seconds_to_refill


## Whether the player is asking to run right now (hold or toggle, per the
## "run_mode" setting). Call once per physics frame while driven.
func wants_run(moving: bool, delta: float) -> bool:
	if Settings.get_value("run_mode") == "toggle":
		_still = 0.0 if moving else _still + delta
		_moved = _moved or moving
		if Input.is_action_just_pressed("run"):
			_toggled = not _toggled
			_moved = moving  # a press while standing arms it for the next move
			_still = 0.0
		elif (_moved and _still >= TOGGLE_STILL) or winded:
			_toggled = false
		return _toggled
	return Input.is_action_pressed("run")


## Advance the meter. Returns true if he actually runs this frame.
func tick(delta: float, want_run: bool, moving: bool) -> bool:
	if want_run and moving and not winded and value > 0.0:
		value = maxf(0.0, value - delta / run_seconds)
		_rest = REST_DELAY
		if value <= 0.0:
			winded = true
		return true
	_rest -= delta
	if _rest <= 0.0:
		value = minf(1.0, value + delta / refill_seconds)
		if winded and value >= RECOVER_AT:
			winded = false
	return false


## Control moved away: a toggled run doesn't carry over to next time.
func drop_toggle() -> void:
	_toggled = false
	_still = 0.0
	_moved = false


## Back to a full meter (a revive). Also drops a toggled run.
func reset() -> void:
	value = 1.0
	winded = false
	_rest = 0.0
	drop_toggle()
