# =============================================================================
# smoke_aspect.gd  -  Ultrawide / any-monitor scaling test
# -----------------------------------------------------------------------------
# PART A (always runs, headless OK): ScreenScaler.compute() against a table of
#   real monitors, plus invariants: integer scale, view never below 640x360,
#   black border always smaller than one scaled pixel.
#
# PART B (needs a real display or Xvfb; skipped in --headless): checks the
#   LIVE window it was launched at:
#   - the game view matches the math
#   - black bars measured from an actual screen capture are < 1 scaled pixel
#   - no "void" anywhere in the capture: the test clears the screen to pure
#     magenta, so any magenta left means the realm's apron art doesn't cover
#     everything a wide screen can see
#   - kid teleported to all 4 map corners: camera never shows past the apron
#   - map narrower than the screen: camera stays centered on it
#   - HUD SafeFrame is centered and capped at its aspect
#
# RUN ONE SIZE:
#   godot --path . --resolution 5120x1440 res://tests/smoke_aspect.tscn
# RUN THE WHOLE MONITOR MATRIX:
#   Linux/CI : tests/run_aspect_matrix.sh      (uses xvfb-run)
#   Windows  : pwsh tests/run_aspect_matrix.ps1
# Exit code 0 = PASS, 1 = FAIL. Set EVERMORE_SHOT_DIR to save screenshots.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD_SCENE := preload("res://realms/big_yard/prototype_yard.tscn")
const ScalerScript := preload("res://autoload/screen_scaler.gd")
const YardScript := preload("res://realms/big_yard/prototype_yard.gd")

## [window size, expected scale, expected view]. Real monitors, small to huge.
const MONITORS := [
	[Vector2i(1280, 800), 2, Vector2i(640, 400)],     # Steam Deck (16:10)
	[Vector2i(1366, 768), 2, Vector2i(683, 384)],     # budget laptop
	[Vector2i(1024, 768), 1, Vector2i(1024, 768)],    # 4:3 (small: 1x, sees extra world)
	[Vector2i(1920, 1080), 3, Vector2i(640, 360)],    # 1080p 16:9 (exact base)
	[Vector2i(2560, 1440), 4, Vector2i(640, 360)],    # 1440p 16:9 (exact base)
	[Vector2i(3840, 2160), 6, Vector2i(640, 360)],    # 4K 16:9 (exact base)
	[Vector2i(2560, 1080), 3, Vector2i(853, 360)],    # 21:9 ultrawide
	[Vector2i(3440, 1440), 4, Vector2i(860, 360)],    # 21:9 ultrawide 1440p
	[Vector2i(3840, 1600), 4, Vector2i(960, 400)],    # 24:10 ultrawide
	[Vector2i(5120, 2160), 6, Vector2i(853, 360)],    # 21:9 5K2K
	[Vector2i(3840, 1080), 3, Vector2i(1280, 360)],   # 32:9 super ultrawide
	[Vector2i(5120, 1440), 4, Vector2i(1280, 360)],   # 32:9 super ultrawide 1440p
	[Vector2i(7680, 2160), 6, Vector2i(1280, 360)],   # 32:9 57-inch dual 4K
	[Vector2i(5760, 1080), 3, Vector2i(1920, 360)],   # 48:9 triple 1080p
	[Vector2i(7680, 1440), 4, Vector2i(1920, 360)],   # 48:9 triple 1440p
	[Vector2i(1280, 720), 2, Vector2i(640, 360)],     # 720p / default window
	[Vector2i(640, 360), 1, Vector2i(640, 360)],      # tiny window
	[Vector2i(64, 64), 1, Vector2i(640, 360)],        # headless dummy window
]

## Sentinel clear color for the void check (see _part_b_live).
const VOID_COLOR := Color(1.0, 0.0, 1.0)

var _failures: PackedStringArray = []
var _shot_dir := OS.get_environment("EVERMORE_SHOT_DIR")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_part_a_math()
	if DisplayServer.get_name() == "headless":
		print("[TEST] (part B skipped: headless, no real window)")
	else:
		await _part_b_live()
	_report()


# -----------------------------------------------------------------------------
# PART A: pure math
# -----------------------------------------------------------------------------
func _part_a_math() -> void:
	for row in MONITORS:
		var win: Vector2i = row[0]
		var r := ScalerScript.compute(win)
		var s: int = r["scale"]
		var v: Vector2i = r["view"]
		_check(s == row[1], "%s: scale %d, expected %d" % [win, s, row[1]])
		_check(v == row[2], "%s: view %s, expected %s" % [win, v, row[2]])
		_check(v.x >= ScalerScript.BASE_SIZE.x and v.y >= ScalerScript.BASE_SIZE.y,
				"%s: view %s smaller than base" % [win, v])
		# Black border < 1 scaled pixel (only meaningful when the window fits the base).
		if win.x >= ScalerScript.BASE_SIZE.x and win.y >= ScalerScript.BASE_SIZE.y:
			var bars := win - v * s
			_check(bars.x >= 0 and bars.x < s and bars.y >= 0 and bars.y < s,
					"%s: leftover border %s not < scale %d" % [win, bars, s])

	# Optional cap: 32:9 capped to 21:9 -> pillarboxed, still >= base.
	var capped := ScalerScript.compute(Vector2i(5120, 1440), 21.0 / 9.0)
	_check(capped["view"] == Vector2i(840, 360), "cap 21:9 on 5120x1440: %s" % capped["view"])
	print("[TEST] part A: %d monitors checked" % MONITORS.size())
	_crisp_ui_checks()


## Text is sharp when the window stretches in CANVAS_ITEMS mode (UI and glyphs
## rasterized at window resolution) at the same whole-number scale as before.
func _crisp_ui_checks() -> void:
	var root := get_tree().root
	for hd in [false, true]:
		ScreenScaler.native_3d = hd
		_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
				"content scale mode is CANVAS_ITEMS with native_3d=%s (VIEWPORT blurs text)" % hd)
		_check(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP,
				"integer + keep stays on with native_3d=%s" % hd)
		_check(root.content_scale_size == ScreenScaler.view_size, "content_scale_size is view_size")
	ScreenScaler.native_3d = false
	# A label's glyphs are drawn through the window's final transform: its scale
	# must be the integer scale, so text is rasterized at scale x its font size.
	var f := root.get_final_transform().get_scale()
	_check(is_equal_approx(f.x, float(ScreenScaler.scale)) and is_equal_approx(f.y, float(ScreenScaler.scale)),
			"canvas transform scale %s != integer scale %d" % [f, ScreenScaler.scale])


# -----------------------------------------------------------------------------
# PART B: the live window
# -----------------------------------------------------------------------------
func _part_b_live() -> void:
	# Clear to pure magenta while testing: no art uses it, so any magenta in
	# the capture is guaranteed to be "nothing drawn here" (the engine's
	# default grey can also come from anti-aliased HUD text, a false alarm).
	RenderingServer.set_default_clear_color(VOID_COLOR)
	var yard := YARD_SCENE.instantiate()
	add_child(yard)
	var kid: Kid = yard.get_node("World/Kid")
	var cam: GameCamera = kid.get_node("Camera2D")
	var hud = yard.get_node("HUD")
	await _frames(10)

	var win := get_tree().root.size
	var expected := ScalerScript.compute(win)
	var view := Vector2i(get_viewport().get_visible_rect().size)
	print("[TEST] part B: window %s -> scale %dx, view %s" % [win, ScreenScaler.scale, view])

	# 1. Live view matches the math.
	_check(ScreenScaler.view_size == expected["view"], "ScreenScaler view %s != math %s" % [ScreenScaler.view_size, expected["view"]])
	_check(view == expected["view"], "viewport visible rect %s != %s" % [view, expected["view"]])

	# 2. Measure real black bars from a screen capture.
	await RenderingServer.frame_post_draw
	var screen := DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if screen and not screen.is_empty():
		var bars := _measure_black_bars(screen, win)
		var s := ScreenScaler.scale
		for side: String in bars:
			_check(bars[side] < s, "black bar %s = %d px (must be < %d)" % [side, bars[side], s])
		print("[TEST] part B: measured bars %s (scale %d)" % [bars, s])
		var void_hits := _find_void_pixels(screen, win, bars)
		_check(void_hits.is_empty(), "%d sampled pixels show the empty void (missing apron art?) first at %s"
				% [void_hits.size(), void_hits.slice(0, 5)])
		_save_shot(screen, "aspect_%dx%d" % [win.x, win.y])
	else:
		print("[TEST] (screen capture unavailable; bar check skipped)")

	# 3. Corners: camera never shows past the apron; narrow maps stay centered.
	var map := Rect2(0, 0, YardScript.LAYOUT[0].length() * YardScript.TILE,
			YardScript.LAYOUT.size() * YardScript.TILE)
	var apron := map.grow(YardScript.APRON_TILES * YardScript.TILE)
	var corners := [map.position + Vector2(24, 24), Vector2(map.end.x - 24, 24),
			Vector2(24, map.end.y - 24), map.end - Vector2(24, 24)]
	for c: Vector2 in corners:
		kid.global_position = c
		cam.reset_smoothing()
		await _frames(3)
		var center := cam.get_screen_center_position()
		var seen := Rect2(center - Vector2(view) * 0.5, Vector2(view))
		_check(apron.encloses(seen), "at %s camera sees %s, outside apron %s" % [c, seen, apron])
		if cam.is_centered_x():
			_check(absf(center.x - map.get_center().x) <= 1.0, "narrow map not centered on x (cam %.1f)" % center.x)
		else:
			_check(map.encloses(Rect2(seen.position.x, map.position.y, seen.size.x, 1)), "camera x left the map at %s" % c)
		if cam.is_centered_y():
			_check(absf(center.y - map.get_center().y) <= 1.0, "narrow map not centered on y (cam %.1f)" % center.y)

	# 4. HUD safe frame: centered, capped at its aspect.
	var frame: SafeFrame = hud.get_safe_frame()
	var cap := frame.effective_aspect()
	var want_w := float(view.x) if cap <= 0.0 else minf(view.x, roundf(view.y * cap))
	_check(absf(frame.size.x - want_w) <= 1.0, "SafeFrame width %.0f, expected %.0f" % [frame.size.x, want_w])
	var left_gap := frame.position.x
	var right_gap := view.x - frame.position.x - frame.size.x
	_check(absf(left_gap - right_gap) <= 1.0, "SafeFrame not centered (gaps %.0f / %.0f)" % [left_gap, right_gap])


## Count fully-black rows/columns from each edge along the middle lines.
func _measure_black_bars(img: Image, win: Vector2i) -> Dictionary:
	var w := mini(img.get_width(), win.x)
	var h := mini(img.get_height(), win.y)
	var mid_y := h / 2
	var mid_x := w / 2
	var bars := {"left": 0, "right": 0, "top": 0, "bottom": 0}
	while bars["left"] < w and _is_black(img.get_pixel(bars["left"], mid_y)):
		bars["left"] += 1
	while bars["right"] < w and _is_black(img.get_pixel(w - 1 - bars["right"], mid_y)):
		bars["right"] += 1
	while bars["top"] < h and _is_black(img.get_pixel(mid_x, bars["top"])):
		bars["top"] += 1
	while bars["bottom"] < h and _is_black(img.get_pixel(mid_x, h - 1 - bars["bottom"])):
		bars["bottom"] += 1
	return bars


## Samples the capture on a grid (inside the black bars) and returns the
## screen positions of pixels matching the sentinel clear color, which only
## shows where nothing is drawn. Tolerance covers the color grade and
## vignette shifting the magenta a little.
func _find_void_pixels(img: Image, win: Vector2i, bars: Dictionary) -> Array[Vector2i]:
	var x0: int = bars["left"]
	var x1: int = mini(img.get_width(), win.x) - bars["right"]
	var y0: int = bars["top"]
	var y1: int = mini(img.get_height(), win.y) - bars["bottom"]
	var hits: Array[Vector2i] = []
	for y in range(y0, y1, 8):
		for x in range(x0, x1, 8):
			var c := img.get_pixel(x, y)
			if c.r > 0.55 and c.b > 0.55 and c.g < 0.25:
				hits.append(Vector2i(x, y))
	return hits


func _is_black(c: Color) -> bool:
	return c.r < 0.03 and c.g < 0.03 and c.b < 0.03


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _save_shot(img: Image, shot_name: String) -> void:
	if _shot_dir.is_empty():
		return
	# Quarter size keeps 7680-wide captures small enough to look at.
	var small := img.duplicate() as Image
	small.resize(maxi(img.get_width() / 4, 1), maxi(img.get_height() / 4, 1), Image.INTERPOLATE_NEAREST)
	var path := _shot_dir.path_join(shot_name + ".png")
	if small.save_png(path) == OK:
		print("[TEST] screenshot -> ", path)


func _report() -> void:
	if _failures.is_empty():
		print("[TEST] PASS  smoke_aspect")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)
