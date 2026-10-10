# =============================================================================
# sky_dial.gd  -  The HUD clock: a half-circle window of sky at the top centre
# -----------------------------------------------------------------------------
# WHAT:  A small dome of sky whose colour follows the time (pale blue by day,
#        warm orange at dawn and dusk, navy with twinkling stars at night).
#        Behind it a wheel carries the sun and the moon opposite each other:
#        the sun rises on the left at DayLight.SUNRISE (5:30), tops the dial at
#        noon and sets on the right at DayLight.SUNSET (18:30), the same hours
#        the world's sun does; the moon is on the far side of the wheel, so it
#        tops the dial at midnight. The wheel turns smoothly with Clock.hour().
#        Tick marks sit on the rim at 6, 9, 12, 15 and 18 (the 6s and 12 a bit
#        longer). Every 3 game hours the clock crosses one: it lights up and a
#        soft chime plays (bigger at 0, 6, 12 and 18). Under the dial, badges: a pause icon while the clock is held (prologue street) or
#        stopped (F7), "x10" / "x60" while sped up (F9).
# WHY:   Time matters now (shops close, enemies swap, night misses) and the
#        player had no way to read it. A dial reads at a glance and is
#        pretty; the owner wants no clock text at all.
# HOW:   _draw paints pixel rows (integer sizes, no antialiasing) in the HUD's
#        dark-card style; the static helpers (sky_colors, body_offset,
#        mark_for) are pure so tests check them directly. Game
#        time only: the twinkle counts process delta.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name SkyDial
extends Control

## A 3-hour mark was crossed: the mark's hour (0, 3, ... 21) and whether it is
## one of the big ones (0, 6, 12, 18). Tests listen.
signal ticked(hour: int, big: bool)

const R := 28
## Control size: dome with its outline, the sill, a text row.
const SIZE := Vector2(2 * R + 4, R + 1 + 4 + 10)
const CENTER := Vector2(R + 2, R + 1)
## Radius the sun and the moon travel on.
const WHEEL_R := 21.0
const BODY_R := 4
const OUTLINE := Color(0.05, 0.04, 0.09, 0.9)
const TEXT := Color(0.94, 0.94, 0.97)
const MARK := Color(1, 1, 1, 0.6)
const SUN_RIM := Color(1.0, 0.62, 0.15)
const SUN_CORE := Color(1.0, 0.92, 0.45)
const MOON := Color(0.88, 0.9, 0.98)
const MOON_CRATER := Color(0.68, 0.72, 0.86)
## Sky colours [zenith, horizon] at night, twilight and day.
const NIGHT := [Color(0.03, 0.05, 0.16), Color(0.08, 0.10, 0.28)]
const TWILIGHT := [Color(0.30, 0.30, 0.55), Color(1.0, 0.55, 0.25)]
const DAY := [Color(0.40, 0.65, 0.95), Color(0.72, 0.88, 1.0)]
## A few stars: x, y (pixels from the dome's top left) and twinkle phase.
const STARS := [Vector3(10, 14, 0.0), Vector3(19, 6, 1.7), Vector3(27, 17, 3.1), Vector3(33, 8, 4.4),
		Vector3(41, 15, 0.9), Vector3(47, 22, 2.6), Vector3(14, 23, 5.2), Vector3(38, 3, 3.8)]
const FLASH_SECONDS := 1.0
## Past this speed the chime stays quiet (x60 would ring every 3 seconds).
const CHIME_MAX_SPEED := 10.0

var _last_hour := -1.0
var _time := 0.0
var _flash := {}  # mark hour -> seconds of glow left


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	var h := Clock.hour()
	if _last_hour >= 0.0:
		var step := fposmod(h - _last_hour, 24.0)
		# A jump (F2, a dialogue's @time) is no tick: only ordinary running.
		if step > 0.0 and step < 1.5 and floori(h / 3.0) != floori(_last_hour / 3.0):
			_tick(floori(h / 3.0) * 3 % 24)
	_last_hour = h
	queue_redraw()


func _tick(hour: int) -> void:
	var big := hour % 6 == 0
	_flash[mark_for(hour)] = FLASH_SECONDS
	ticked.emit(hour, big)
	if is_visible_in_tree() and Clock.speed <= CHIME_MAX_SPEED:
		Audio.play("dial_chime_big" if big else "dial_chime")


## Badges: "pause" while held or stopped, "x10"/"x60" when sped up; [] = none.
func badges() -> Array[String]:
	var b: Array[String] = []
	if Clock.mode == "hold" or Clock.paused:
		b.append("pause")
	if Clock.speed > 1.0:
		b.append("x%d" % int(Clock.speed))
	return b


# --- Pure helpers (tests call these) -----------------------------------------
## Angle of the sun from straight up, clockwise, in radians: noon 0, the
## sunset a quarter turn right, midnight pi. The sun crosses the horizon at the
## SAME hours as the 3D sun (DayLight.SUNRISE / SUNSET), so dial and world agree.
static func sun_angle(hour: float) -> float:
	return DayLight.sun_angle(hour)


## Where the sun (or the moon, opposite it) sits relative to the wheel's
## centre, in pixels; y negative = up.
static func body_offset(hour: float, moon := false) -> Vector2:
	var a := sun_angle(hour) + (PI if moon else 0.0)
	return Vector2(sin(a), -cos(a)) * WHEEL_R


## [zenith, horizon] colours of the sky at an hour.
static func sky_colors(hour: float) -> Array:
	var e := cos(sun_angle(hour))  # sun height: 1 noon, 0 at sunrise and sunset, -1 midnight
	var a: Array
	var b: Array
	var t: float
	if e < -0.3:
		return NIGHT
	elif e < 0.0:
		a = NIGHT
		b = TWILIGHT
		t = (e + 0.3) / 0.3
	elif e < 0.4:
		a = TWILIGHT
		b = DAY
		t = e / 0.4
	else:
		return DAY
	return [a[0].lerp(b[0], t), a[1].lerp(b[1], t)]


## How starry the sky is, 0 (day) to 1 (night).
static func star_alpha(hour: float) -> float:
	return clampf((-cos(sun_angle(hour)) - 0.1) / 0.3, 0.0, 1.0)


## The rim mark that lights when the clock crosses `hour` (a multiple of 3):
## the sun's own mark while the sun is up, the moon's after dark.
static func mark_for(hour: int) -> int:
	return hour if hour >= 6 and hour <= 18 else (hour + 12) % 24


# --- Drawing -----------------------------------------------------------------
func _sky_at_row(y: int, cols: Array) -> Color:
	return cols[0].lerp(cols[1], clampf(float(y) / float(R + 1), 0.0, 1.0))


func _in_dome(p: Vector2) -> bool:
	return p.y < CENTER.y and p.distance_to(CENTER) <= R


func _draw() -> void:
	var h := Clock.hour()
	var cols := sky_colors(h)
	# Outline (a bigger dome plus the sill), then the sky rows.
	_dome_rows(R + 1, func(_y: int) -> Color: return OUTLINE)
	draw_rect(Rect2(0, CENTER.y, SIZE.x, 4), OUTLINE)
	_dome_rows(R, func(y: int) -> Color: return _sky_at_row(y, cols))
	# Stars.
	var sa := star_alpha(h)
	if sa > 0.0:
		for s: Vector3 in STARS:
			var p := Vector2(s.x, s.y) + Vector2(2, 2)
			if _in_dome(p):
				var tw := 0.55 + 0.45 * sin(_time * 2.2 + s.z)
				draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 0.9, sa * tw))
				if tw > 0.9:
					draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(1, 1, 0.9, sa * 0.35))
	_draw_marks()
	_draw_sun(CENTER + body_offset(h), cols)
	_draw_moon(CENTER + body_offset(h, true), cols)
	_draw_text_row()


## Fill the dome of radius r row by row with colour_of(row).
func _dome_rows(r: int, colour_of: Callable) -> void:
	for y in range(R + 1 - r, R + 1):
		var dy := CENTER.y - y - 0.5
		var hw := floorf(sqrt(maxf(float(r * r) - dy * dy, 0.0)))
		if hw <= 0.0:
			continue
		draw_rect(Rect2(CENTER.x - hw, y, hw * 2.0, 1), colour_of.call(y))


func _draw_marks() -> void:
	for m in [6, 9, 12, 15, 18]:
		var dir := Vector2(sin(sun_angle(m)), -cos(sun_angle(m)))
		var len := 4.0 if m % 6 == 0 else 2.0
		var lit: float = clampf(float(_flash.get(m, 0.0)) / FLASH_SECONDS, 0.0, 1.0)
		var c := MARK.lerp(Color(1, 0.95, 0.6, 1.0), lit)
		var a := (CENTER + dir * (R - 0.5)).round()
		var b := (CENTER + dir * (R - 0.5 - len - lit * 2.0)).round()
		if m == 6 or m == 18:  # on the horizon: draw upward so the sill stays clean
			a.y -= 1.0
			b.y -= 1.0
		draw_line(a, b, c, 1.0)


func _disc(centre: Vector2, r: int, colour: Callable) -> void:
	var c := centre.round()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + 1:
				var p := c + Vector2(dx, dy)
				if _in_dome(p + Vector2(0.5, 0.5)):
					draw_rect(Rect2(p, Vector2(1, 1)), colour.call(dx, dy))


func _draw_sun(centre: Vector2, _cols: Array) -> void:
	_disc(centre, BODY_R, func(dx: int, dy: int) -> Color:
		return SUN_CORE if dx * dx + dy * dy <= (BODY_R - 1) * (BODY_R - 1) else SUN_RIM)


func _draw_moon(centre: Vector2, cols: Array) -> void:
	var c := centre.round()
	_disc(centre, BODY_R, func(dx: int, dy: int) -> Color:
		# A bite out of the disc (in the sky's own colour) makes the crescent.
		var bx := dx - 2
		var by := dy + 1
		if bx * bx + by * by <= 10:
			return _sky_at_row(int(c.y) + dy, cols)
		if (dx == -2 and dy == 1) or (dx == -1 and dy == -2):
			return MOON_CRATER
		return MOON)


func _draw_text_row() -> void:
	var font := get_theme_default_font()
	var y := CENTER.y + 4.0 + 8.0
	for b in badges():
		if b == "pause":
			var x := 2.0
			draw_rect(Rect2(x - 1, y - 8, 7, 8), OUTLINE)
			draw_rect(Rect2(x + 0, y - 7, 2, 6), TEXT)
			draw_rect(Rect2(x + 3, y - 7, 2, 6), TEXT)
		else:
			draw_string_outline(font, Vector2(0, y), b, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 1, 8, 2, OUTLINE)
			draw_string(font, Vector2(0, y), b, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - 1, 8, Color(1, 0.85, 0.5))
