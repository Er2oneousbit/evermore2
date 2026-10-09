# =============================================================================
# smoke_faces.gd  -  Every LPC character has a nose and mouth facing the camera
# -----------------------------------------------------------------------------
# WHAT:  Reads each character sheet (kid, dad, maya, dex, grocer, vendor) and
#        checks what tools/art/faces.py painted:
#          1. Front (down) walk frames and the idle frame: the eyes are found
#             (cyan glint pattern), the mouth sits 4 rows below the eye tops
#             and 2 px wide in a darker, rosy shade of the skin (not black),
#             the nose 2 rows below in a soft shade, and BOTH move with the eyes
#             when the head bobs (offsets are measured per frame)
#          2. Bearded men (dad, grocer): nose only, the beard stays untouched
#          3. Side (left/right) and back (up) frames of every animation: no
#             mouth-coloured pixel anywhere
#          4. Hurt frames where the head turns or drops: no mouth
#          5. No mouth pixel lands outside the head: opaque on all four sides
#
# WHY:   The original game shows a tiny mouth only when the hero faces the
#        camera. A bob that left the mouth behind would look like chewing.
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_faces.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const CHARACTERS := ["kid", "dad", "maya", "dex", "grocer", "vendor"]
const BEARDED := ["dad", "grocer"]
# Same numbers as tools/art/faces.py (skin * mix per channel).
const NOSE_MIX := Vector3(0.86, 0.80, 0.80)
const MOUTH_MIX := Vector3(0.66, 0.46, 0.44)
const GLINTS := [Vector2i(0, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(8, 0), Vector2i(11, 0), Vector2i(9, 1)]
const WALK_DOWN := 10
const IDLE_DOWN := 24
const HURT := 20
const BLOCK_FIRST_ROWS := [0, 4, 8, 12, 16, 22, 26, 30, 34, 38, 42, 46, 50]

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for who in CHARACTERS:
		var img := (load("res://assets/characters/%s/%s_lpc.png" % [who, who]) as Texture2D).get_image()
		_check_character(who, img)
	if _failures.is_empty():
		print("[TEST] PASS  smoke_faces")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failures.append(msg)


func _is_cyan(c: Color) -> bool:
	return c.a > 0.78 and c.b > 0.59 and c.r < 0.47


## Left outer eye glint of a frame as (x, y), or (-1, -1).
func _eyes(img: Image, col: int, row: int) -> Vector2i:
	var ox := col * 64
	var oy := row * 64
	for ey in range(20, 37):
		for ex in range(14, 42):
			var hits := 0
			for g: Vector2i in GLINTS:
				if _is_cyan(img.get_pixel(ox + ex + g.x, oy + ey + g.y)):
					hits += 1
			if hits >= 5 and not _is_cyan(img.get_pixel(ox + ex + 1, oy + ey)) and not _is_cyan(img.get_pixel(ox + ex + 2, oy + ey)):
				return Vector2i(ex, ey)
	return Vector2i(-1, -1)


func _shade(c: Color, mix: Vector3) -> Color:
	return Color8(clampi(roundi(c.r8 * mix.x), 0, 255), clampi(roundi(c.g8 * mix.y), 0, 255), clampi(roundi(c.b8 * mix.z), 0, 255))


func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _count_color(img: Image, col: int, row: int, color: Color) -> int:
	var n := 0
	for y in 64:
		for x in 64:
			var c := img.get_pixel(col * 64 + x, row * 64 + y)
			if c.a == 1.0 and c.r8 == color.r8 and c.g8 == color.g8 and c.b8 == color.b8:
				n += 1
	return n


func _check_character(who: String, img: Image) -> void:
	var first := _eyes(img, 0, WALK_DOWN)
	_check(first.x >= 0, "%s: eyes not found on walk-down frame 0" % who)
	if first.x < 0:
		return
	var skin0 := img.get_pixel(first.x + 5, WALK_DOWN * 64 + first.y + 1)
	var mouth0 := _shade(skin0, MOUTH_MIX)
	var nose0 := _shade(skin0, NOSE_MIX)
	var bearded := BEARDED.has(who)
	var ys := {}

	var fronts: Array = []
	for c in 9:
		fronts.append(Vector2i(c, WALK_DOWN))
	fronts.append(Vector2i(0, IDLE_DOWN))
	for cell: Vector2i in fronts:
		var tag := "%s col %d row %d" % [who, cell.x, cell.y]
		var e := _eyes(img, cell.x, cell.y)
		_check(e.x >= 0, "%s: eyes not found" % tag)
		if e.x < 0:
			continue
		ys[e.y] = true
		var ox := cell.x * 64
		var oy := cell.y * 64
		var skin := img.get_pixel(ox + e.x + 5, oy + e.y + 1)
		var mouth := _shade(skin, MOUTH_MIX)
		var nose := _shade(skin, NOSE_MIX)
		for dx in [5, 6]:
			var n := img.get_pixel(ox + e.x + dx, oy + e.y + 2)
			_check(n.is_equal_approx(nose), "%s: nose pixel %d missing or moved (%s, want %s)" % [tag, dx, n.to_html(), nose.to_html()])
			var m := img.get_pixel(ox + e.x + dx, oy + e.y + 4)
			if bearded:
				_check(not m.is_equal_approx(mouth), "%s: mouth painted over the beard" % tag)
			else:
				_check(m.is_equal_approx(mouth), "%s: mouth pixel %d missing or moved (%s, want %s)" % [tag, dx, m.to_html(), mouth.to_html()])
				_check(_lum(m) < _lum(skin) * 0.85, "%s: mouth not darker than the skin" % tag)
				_check(_lum(m) > 0.12, "%s: mouth is near black" % tag)
				# Inside the head: opaque all around.
				var mx: int = ox + e.x + dx
				var my: int = oy + e.y + 4
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					_check(img.get_pixel(mx + d.x, my + d.y).a == 1.0, "%s: mouth pixel %d touches the edge of the head" % [tag, dx])
		if not bearded:
			_check(_count_color(img, cell.x, cell.y, mouth) == 2, "%s: expected exactly 2 mouth pixels in the frame" % tag)
	# The walk bob moves the head: the mouth followed it (measured per frame above).
	_check(ys.size() >= 2, "%s: the walk-down head never bobbed (eye rows %s), so the follow-the-head check proves nothing" % [who, ys.keys()])

	# Side and back frames of every animation: not one mouth-coloured pixel.
	if not bearded:
		for first_row: int in BLOCK_FIRST_ROWS:
			for d in [0, 1, 3]:
				for c in 13:
					_check(_count_color(img, c, first_row + d, mouth0) == 0, "%s: mouth-coloured pixel on a side/back frame (row %d col %d)" % [who, first_row + d, c])
		# Hurt frames: the head turns or drops after frame 0; no mouth where
		# the eyes are not found.
		for c in 13:
			if _eyes(img, c, HURT).x < 0:
				_check(_count_color(img, c, HURT, mouth0) == 0, "%s: mouth on a hurt frame without a face (col %d)" % [who, c])
	# Nose colours never appear on the side or back either.
	for first_row: int in BLOCK_FIRST_ROWS:
		for d in [0, 1, 3]:
			for c in 13:
				_check(_count_color(img, c, first_row + d, nose0) == 0, "%s: nose-coloured pixel on a side/back frame (row %d col %d)" % [who, first_row + d, c])
