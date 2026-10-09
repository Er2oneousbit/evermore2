# =============================================================================
# screen_scaler.gd  (autoload: ScreenScaler)
# -----------------------------------------------------------------------------
# WHAT:  Pixel-perfect scaling that FILLS any monitor shape: 16:9, 16:10, 4:3,
#        21:9, 32:9, 48:9 triple-wide, Steam Deck, whatever.
#
# HOW:   1. Pick the biggest WHOLE-NUMBER scale where at least the base view
#           (640x360) still fits. Whole numbers keep every pixel crisp.
#        2. Make the game's view as big as the window allows at that scale.
#           Wider screen = more world visible sideways. Taller = more vertical.
#        Leftover black border is always smaller than one scaled pixel.
#
# WHY NOT GODOT'S BUILT-IN "expand" + "integer"? Tested at 5120x1440: it sized
#        the view for a 6.67x scale, then drew it at 6x, leaving 256 px black
#        bars left/right AND 72 px top/bottom (measured back when the base was
#        384x216). This does the math correctly at any base size.
#
# EXAMPLES (window -> scale -> visible game area in base pixels):
#        1920x1080 -> 3x ->  640x360      3440x1440 -> 4x ->  860x360
#        2560x1440 -> 4x ->  640x360      5120x1440 -> 4x -> 1280x360
#        3840x2160 -> 6x ->  640x360      7680x1440 -> 4x -> 1920x360
#        1280x800  -> 2x ->  640x400      5760x1080 -> 3x -> 1920x360
#
# OPTIONAL CAP: set max_aspect (e.g. 32.0 / 9.0) to pillarbox anything wider.
#        0 = no cap (default). Meant for a future video-settings menu.
#
# SHARP TEXT: the window always uses CANVAS_ITEMS stretch (never VIEWPORT), so
#        menus, HUD, dialogue and text render at the window's native resolution
#        while layout stays 640x360 units at a whole-number scale. Pixel art
#        stays crisp (nearest filter, integer scale, 2D pixel snapping).
# HD-2D MODE: native_3d = true when the world is drawn in 3D (systems/hd2d);
#        depth of field, bloom and fog stay smooth. Same view_size math either way.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Emitted after every recalculation (window resize, setting change).
signal view_changed(view_size: Vector2i, scale: int)

## The smallest game area any player ever sees. Gameplay must be designed to
## work inside this "safe frame" (see docs/art-spec.md).
const BASE_SIZE := Vector2i(640, 360)

## Widest allowed aspect ratio (width / height). 0 = unlimited.
var max_aspect := 0.0:
	set(value):
		max_aspect = maxf(value, 0.0)
		_recalculate()

## true = the world is drawn in 3D at full window resolution (HD-2D); false =
## classic 2D view. Menus, HUD and text are window-resolution in both.
var native_3d := false:
	set(value):
		native_3d = value
		if is_instance_valid(_window):
			Debug.log_verbose("ScreenScaler: native_3d=%s" % value)

## Current whole-number scale factor (read-only from outside, please).
var scale := 1
## Current visible game area in base pixels (read-only from outside, please).
var view_size := BASE_SIZE

var _window: Window


func _ready() -> void:
	_window = get_tree().root
	# CANVAS_ITEMS in BOTH views: the layout is still 640x360 units at a whole-number
	# scale, but every control and glyph is rasterized at window resolution.
	# VIEWPORT mode drew the UI at 640x360 and blew it up (soft, chunky text).
	# Sprites stay crisp: nearest filter + integer scale + 2D pixel snapping.
	# KEEP aspect: we hand Godot an exact size, so it never needs to expand.
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	_window.size_changed.connect(_recalculate)
	_recalculate()


## Pure math, no side effects: what scale/view would a window this size get?
## Static so tests and settings menus can preview results for any monitor.
## (Integer division is intentional: we want whole-number scales and sizes.)
@warning_ignore("integer_division")
static func compute(window_size: Vector2i, aspect_cap: float = 0.0) -> Dictionary:
	var w := maxi(window_size.x, 1)
	var h := maxi(window_size.y, 1)
	var s := maxi(1, mini(w / BASE_SIZE.x, h / BASE_SIZE.y))
	# Never show LESS than the base view, even in a tiny window (or headless
	# mode, which reports a dummy 64x64 window). Godot shrinks it to fit.
	var view := Vector2i(maxi(w / s, BASE_SIZE.x), maxi(h / s, BASE_SIZE.y))
	if aspect_cap > 0.0:
		view.x = clampi(roundi(view.y * aspect_cap), BASE_SIZE.x, view.x)
	return {"scale": s, "view": view}


func _recalculate() -> void:
	if not is_instance_valid(_window):
		return
	var result := compute(_window.size, max_aspect)
	var new_scale: int = result["scale"]
	var new_view: Vector2i = result["view"]
	if new_scale == scale and new_view == view_size and _window.content_scale_size == new_view:
		return
	scale = new_scale
	view_size = new_view
	_window.content_scale_size = new_view
	view_changed.emit(view_size, scale)
	Debug.log_verbose("ScreenScaler: window %s -> %dx, view %s" % [_window.size, scale, view_size])
