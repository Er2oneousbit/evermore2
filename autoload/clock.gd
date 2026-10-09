# =============================================================================
# clock.gd  -  The game clock: morning, day, golden hour, night, and around
# -----------------------------------------------------------------------------
# WHAT:  One running clock for the whole game (autoload "Clock"). The day has
#        four phases in PHASES order with unequal lengths (PHASE_START hours:
#        morning 5-11, day 11-17, golden 17-20, night 20-5; owner, 2026-10-09).
#        One real minute is one game hour (DAY_MINUTES = 24). It counts GAME
#        time (process delta, so it pauses with the tree, slows with hit-stop and
#        never reads the wall clock). When a phase ends it announces the next
#        one on `phase_changed` with a long FADE_SECONDS blend, and every
#        realm's Atmosphere (and through it HdView, music, ambience, the kid's
#        flashlight) fades to the new look.
#
# MODES (owner, 2026-10-09: "can we have it both?"):
#        free      runs on its own (outside villages, where the script doesn't care)
#        set(t)    jump to a time, then run on from there        -> set_time()
#        hold(t)   jump to a time and freeze until released       -> hold() / release()
#        A realm picks its mode on load with the CLOCK_MODE constant (see
#        AsciiRealm.DEFAULTS): "free" keeps whatever time it is (the first
#        realm of a run starts at its Atmosphere.start_time), "set" starts at
#        start_time and runs, "hold" freezes at start_time (the prologue: its
#        story picks the time with @time).
#
# WHY AN AUTOLOAD (not inside Atmosphere): time is game state, not mood. It
#        has to survive scene changes (indoors and back), and shops, enemies
#        and the kid's night misses ask it without finding a realm's node; it
#        also works in tests that build no realm. Atmosphere stays the look:
#        it follows `phase_changed`, and its set_time() (F2, @time) is a jump.
#
# DEBUG: F7 pauses / resumes, F9 cycles the speed (SPEEDS), F2 (Atmosphere)
#        jumps to the next phase. The F3 overlay shows status_text().
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## A new phase began. blend_seconds = how long the look should fade (0 = cut).
signal phase_changed(phase: String, blend_seconds: float)
## Mode, pause or speed changed (debug overlay, tests).
signal state_changed

const PHASES: Array[String] = ["morning", "day", "golden", "night"]
## One whole game day at 1x, in real minutes (1 per game hour). The one knob.
const DAY_MINUTES := 24.0
## The hour (0-24) each phase starts at. Night runs 20:00 to 5:00.
const PHASE_START := {"morning": 5.0, "day": 11.0, "golden": 17.0, "night": 20.0}
## How long the look fades when the clock moves on by itself.
const FADE_SECONDS := 6.0
## Debug speeds (F9 cycles them).
const SPEEDS: Array[float] = [1.0, 10.0, 60.0]
const REALM_MODES: Array[String] = ["free", "set", "hold"]

## The current phase ("morning", "day", "golden", "night").
var phase := "golden"
## Game seconds spent in the current phase.
var elapsed := 0.0
## "free" (running) or "hold" (frozen by a scene).
var mode := "free"
## Debug pause (F7). Separate from hold: a scene's hold survives an F7.
var paused := false
## Debug multiplier (F9).
var speed := 1.0
## Counts every phase change (jumps too): "once per phase" things compare it.
var phase_count := 0
## The blend of the last change; HdView and the kid fade by it.
var last_blend := 0.0
## False until a realm (or a jump) sets the time for the first time.
var started := false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_clock_pause"):
		toggle_pause()
	elif event.is_action_pressed("debug_clock_speed"):
		cycle_speed()


func _process(delta: float) -> void:
	if is_running():
		advance(delta * speed)


## True while time passes (free, not debug-paused).
func is_running() -> bool:
	return mode == "free" and not paused


## Game seconds in one game hour.
func hour_seconds() -> float:
	return DAY_MINUTES * 60.0 / 24.0


## Hours phase `p` lasts (the current phase when empty): 6, 6, 3 and 9.
func phase_hours(p := "") -> float:
	if p == "":
		p = phase
	var next: String = next_of(p)
	return fposmod(float(PHASE_START[next]) - float(PHASE_START[p]), 24.0)


## Game seconds in phase `p` (the current phase when empty).
func phase_seconds(p := "") -> float:
	return phase_hours(p) * hour_seconds()


## The time of day as a float hour, 0 to 24 (the sky dial turns by it).
func hour() -> float:
	return fposmod(float(PHASE_START[phase]) + elapsed / hour_seconds(), 24.0)


## Move time on by `seconds` of game time (what _process does each frame;
## tests call it to skip ahead). Crosses as many phases as it needs.
func advance(seconds: float) -> void:
	elapsed += seconds
	while elapsed >= phase_seconds():
		elapsed -= phase_seconds()
		_change(next_of(phase), FADE_SECONDS)


## The phase after `p` (night wraps to morning).
static func next_of(p: String) -> String:
	return PHASES[(PHASES.find(p) + 1) % PHASES.size()]


func is_night() -> bool:
	return phase == "night"


## Jump to a phase and let it run on from there (the "set" mode).
func set_time(p: String, blend := FADE_SECONDS) -> void:
	if jump(p, blend):
		_set_mode("free")


## Freeze the clock, at phase `p` if given, until release().
func hold(p := "", blend := FADE_SECONDS) -> void:
	if p != "" and not jump(p, blend):
		return
	_set_mode("hold")


## Let a held clock run again from where it stands.
func release() -> void:
	_set_mode("free")


## Change the phase without touching the mode (a held clock stays held):
## F2, a dialogue's @time. Restarts the phase's minutes. False if unknown.
func jump(p: String, blend := FADE_SECONDS) -> bool:
	if not PHASES.has(p):
		Debug.log_warn("Clock: unknown phase '%s'" % p)
		return false
	elapsed = 0.0
	started = true
	_change(p, blend)
	return true


## The next phase now (F2), mode unchanged.
func next_phase(blend := FADE_SECONDS) -> void:
	jump(next_of(phase), blend)


## A realm loaded: apply its CLOCK_MODE. No signal; the realm's Atmosphere
## applies `phase` itself, without a fade.
func enter_realm(realm_mode: String, start_phase: String) -> void:
	if not REALM_MODES.has(realm_mode):
		Debug.log_warn("Clock: unknown CLOCK_MODE '%s', using free" % realm_mode)
		realm_mode = "free"
	if realm_mode != "free" or not started:
		if PHASES.has(start_phase):
			phase = start_phase
		elapsed = 0.0
	started = true
	last_blend = 0.0
	_set_mode("hold" if realm_mode == "hold" else "free")


func toggle_pause() -> void:
	paused = not paused
	Debug.log_info("Clock %s" % ("paused" if paused else "running"))
	state_changed.emit()


func cycle_speed() -> void:
	var i := SPEEDS.find(speed)
	speed = SPEEDS[(i + 1) % SPEEDS.size()]
	Debug.log_info("Clock speed x%d" % int(speed))
	state_changed.emit()


## Game minutes into the current phase (the overlay shows it).
func minutes_into_phase() -> float:
	return elapsed / 60.0


## One line for the F3 overlay, e.g. "clock golden 2.5/3.0 min  17:30  free  x10".
func status_text() -> String:
	var state := "paused" if paused else mode
	var h := hour()
	return "clock %s %.1f/%.1f min  %02d:%02d  %s  x%d" % [phase, minutes_into_phase(), phase_seconds() / 60.0,
			int(h), int(fposmod(h, 1.0) * 60.0), state, int(speed)]


func _change(p: String, blend: float) -> void:
	phase = p
	phase_count += 1
	last_blend = maxf(blend, 0.0)
	Debug.log_verbose("Clock: %s (fade %.1fs)" % [p, last_blend])
	phase_changed.emit(p, last_blend)


func _set_mode(m: String) -> void:
	if mode != m:
		mode = m
		state_changed.emit()
