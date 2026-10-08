# =============================================================================
# running.gd  -  Running, paid for with the attack charge (kid and dog, driven)
# -----------------------------------------------------------------------------
# WHAT:  You walk by default; hold Run (Shift / gamepad LB) to run. Like the
#        original, running costs your attack: while you run the ChargeMeter
#        doesn't refill, it drains (charge_drain levels per second). Run it to
#        0% and he's winded: he walks, even holding Run, until the charge is
#        back to RECOVER_AT. So you choose: get there fast, or arrive with a
#        full swing ready. (The dog drains a quarter as fast: zoomies.)
#        Settings "Run button" can make Run a toggle instead (press once to
#        run, it switches off when you stand still a moment or get winded;
#        pressed while standing, it's ready for your next move).
#        The AI partner doesn't run on this: he has to keep up with you.
#
#          charge.tick(delta)    # as always, every frame
#          var running := run.tick(delta, run.wants_run(moving, delta), moving)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Running
extends RefCounted

## Winded: running comes back once the charge refills to this (in levels).
const RECOVER_AT := 0.5
## Toggle mode: standing still this long (s) ends a toggled run. Not one
## frame: turning around on a keyboard passes through a frame of no keys.
const TOGGLE_STILL := 0.25

## The attack charge running spends.
var charge: ChargeMeter
## Charge drained per second of running, in levels (1.0 = a full 100%).
var charge_drain := 0.5
## Ran the charge dry: no running until it refills to RECOVER_AT.
var winded := false

var _toggled := false
var _still := 0.0
## Moved since Run was pressed: only then can standing still end the run.
var _moved := false


func _init(meter: ChargeMeter, drain_per_second := 0.5) -> void:
	charge = meter
	charge_drain = drain_per_second


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


## Call after this frame's charge.tick(). Returns true if he runs this frame:
## then the charge takes back this frame's refill and drains on top.
func tick(delta: float, want_run: bool, moving: bool) -> bool:
	if want_run and moving and not winded and charge.value > 0.0:
		charge.value = maxf(0.0, charge.value - delta / charge.seconds_per_level - delta * charge_drain)
		if charge.value <= 0.0:
			winded = true
		return true
	if winded and charge.value >= RECOVER_AT:
		winded = false
	return false


## Control moved away: a toggled run doesn't carry over to next time.
func drop_toggle() -> void:
	_toggled = false
	_still = 0.0
	_moved = false


## A revive: not winded any more, no toggled run.
func reset() -> void:
	winded = false
	drop_toggle()
