# =============================================================================
# day_light.gd  -  One sun for the whole game: the hour decides the light
# -----------------------------------------------------------------------------
# WHAT:  Pure static helpers that turn Clock.hour() into a look. The sun is up
#        from SUNRISE to SUNSET (and the moon the rest of the day, opposite it).
#        The sky dial, the 3D sun and moon, and the 2D grade all ask HERE, so
#        they cannot disagree about whether it is day.
#          - sun_angle(): where the dial's wheel is (radians from straight up)
#          - sun_up(), sun_pose(), moon_pose(): the 3D lights' aim and envelope
#          - sample(): a preset table (Atmosphere / HdView PRESETS) blended
#            between KEYS by the hour, instead of four hard presets
# WHY:   The look used to jump between four presets with a 6 s fade while the
#        dial put the sun at 6:00 and 18:00 (owner, 2026-10-09: "the sun dial
#        doesn't match the actual lighting"). Phases stay for gameplay (shops,
#        enemies, music); only the LOOK is continuous now.
# HOW:   KEYS is a list of [hour, preset name]; sample() lerps the two around
#        the hour (wrapping midnight). The sun's elevation is an arc between
#        SUN_FLOOR (readability: never below ~30 degrees while it is up) and
#        SUN_PEAK; a small yaw swing east to west; its light fades in/out over
#        the first/last stretch of the day so the floor never shows at the
#        horizon. The moon light takes over after sunset.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DayLight
extends RefCounted

## An hour gap bigger than this in one step is a jump (F2, @time), not running.
const JUMP_HOURS := 0.5
const SUNRISE := 5.5
const SUNSET := 18.5
## Elevation (degrees) of the 3D sun/moon: never lower than the floor while up.
const SUN_FLOOR := 30.0
const SUN_PEAK := 68.0
const MOON_PEAK := 52.0
## Yaw swing (degrees) east to west. Small: the owner wants shadows north.
const YAW_SWING := 14.0
## Hours the sun's light takes to fade in after sunrise / out before sunset.
const SUN_FADE_IN := 1.0
const SUN_FADE_OUT := 1.0
## Hours the moon takes to fade in after sunset / out before sunrise.
const MOON_FADE_IN := 0.8
const MOON_FADE_OUT := 0.6
## [hour, preset name]: the look is blended between neighbours.
const KEYS := [[2.0, "night"], [4.5, "night"], [6.5, "morning"], [9.0, "morning"], [12.0, "day"],
		[16.0, "day"], [17.5, "golden"], [20.5, "night"]]


## True while the sun is above the horizon (the moon is below, and vice versa).
static func sun_up(hour: float) -> bool:
	return hour >= SUNRISE and hour < SUNSET


## 0 at sunrise to 1 at sunset while the sun is up, else the night's progress
## (0 at sunset to 1 at the next sunrise).
static func progress(hour: float) -> float:
	if sun_up(hour):
		return (hour - SUNRISE) / (SUNSET - SUNRISE)
	return fposmod(hour - SUNSET, 24.0) / (24.0 - (SUNSET - SUNRISE))


## The dial wheel's angle: radians clockwise from straight up. Noon 0, the
## sunrise a quarter turn left, the sunset a quarter turn right, and the night
## carries on round to midnight at pi. Its sine is the sun's side, its cosine
## > 0 exactly while the sun is up.
static func sun_angle(hour: float) -> float:
	var p := progress(hour)
	if sun_up(hour):
		return (p - 0.5) * PI
	return PI * 0.5 + p * PI


## The sun's aim while it is up: elevation (degrees) and yaw, and whether up.
static func sun_pose(hour: float) -> Dictionary:
	var up := sun_up(hour)
	var p := clampf(progress(hour), 0.0, 1.0) if up else 0.0
	return {"up": up, "elev": SUN_FLOOR + (SUN_PEAK - SUN_FLOOR) * sin(p * PI),
			"yaw": lerpf(-YAW_SWING, YAW_SWING, p)}


## The moon's aim: up exactly when the sun is down.
static func moon_pose(hour: float) -> Dictionary:
	var up := not sun_up(hour)
	var p := clampf(progress(hour), 0.0, 1.0) if up else 0.0
	return {"up": up, "elev": SUN_FLOOR + (MOON_PEAK - SUN_FLOOR) * sin(p * PI),
			"yaw": lerpf(-YAW_SWING, YAW_SWING, p)}


## 0..1 strength of the sun's light: 0 outside the day, fading in after sunrise
## and out before sunset.
static func sun_env(hour: float) -> float:
	if not sun_up(hour):
		return 0.0
	return minf(smoothstep(0.0, SUN_FADE_IN, hour - SUNRISE), smoothstep(0.0, SUN_FADE_OUT, SUNSET - hour))


## 0..1 strength of the moon's light: only while the sun is down.
static func moon_env(hour: float) -> float:
	if sun_up(hour):
		return 0.0
	var since := fposmod(hour - SUNSET, 24.0)
	var until := fposmod(SUNRISE - hour, 24.0)
	return minf(smoothstep(0.0, MOON_FADE_IN, since), smoothstep(0.0, MOON_FADE_OUT, until))


## Blend two same-shaped value dictionaries (Colors and floats) by t.
static func mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var v := {}
	for k: String in b:
		var x: Variant = a.get(k, b[k])
		var y: Variant = b[k]
		v[k] = x.lerp(y, t) if x is Color else lerpf(x, y, t)
	return v


## The look at an hour from a preset table keyed by phase names.
static func sample(presets: Dictionary, hour: float) -> Dictionary:
	var h := fposmod(hour, 24.0)
	var first: Array = KEYS[0]
	if h < float(first[0]):
		h += 24.0
	for i in KEYS.size():
		var a: Array = KEYS[i]
		var b: Array = KEYS[(i + 1) % KEYS.size()]
		var ah := float(a[0])
		var bh := float(b[0]) + (24.0 if i + 1 >= KEYS.size() else 0.0)
		if h >= ah and h <= bh:
			var t := smoothstep(0.0, 1.0, (h - ah) / maxf(bh - ah, 0.001))
			return mix(presets[a[1]], presets[b[1]], t)
	return presets["night"].duplicate()


## Hours between two clock readings, the short way round (a jump is > ~0.5).
static func hour_gap(a: float, b: float) -> float:
	var d := fposmod(b - a, 24.0)
	return d if d <= 12.0 else d - 24.0
