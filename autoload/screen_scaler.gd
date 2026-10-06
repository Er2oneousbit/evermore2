# =============================================================================
# screen_scaler.gd  (autoload: ScreenScaler)
# -----------------------------------------------------------------------------
# WHAT:  Pixel-perfect scaling that FILLS any monitor shape: 16:9, 16:10, 4:3,
#        21:9, 32:9, 48:9 triple-wide, Steam Deck, whatever.
#
# HOW:   1. Pick the biggest WHOLE-NUMBER scale where at least the base view
#           (384x216) still fits. Whole numbers keep every pixel crisp.
#        2. Make the game's view as big as the window allows at that scale.
#           Wider screen = more world visible sideways. Taller = more vertical.
#        Leftover black border is always smaller than one scaled pixel.
#
# WHY NOT GODOT'S BUILT-IN "expand" + "integer"? Tested at 5120x1440: it sized
#        the view for a 6.67x scale, then drew it at 6x, leaving 256 px black
#        bars left/right AND 72 px top/bottom. This does the math correctly.
#
# EXAMPLES (window -> scale -> visible game area in base pixels):
#        1920x1080 -> 5x ->  384x216      3440x1440 -> 6x ->  573x240
#        2560x1440 -> 6x ->  426x240      5120x1440 -> 6x ->  853x240
#        3840x1080 -> 5x ->  768x216      7680x1440 -> 6x -> 1280x240
#        1280x800  -> 3x ->  426x266      3840x2160 -> 10x -> 384x216
#
# OPTIONAL CAP: set max_aspect (e.g. 32.0 / 9.0) to pillarbox anything wider.
#        0 = no cap (default). Meant for a future video-settings menu.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Emitted after every recalculation (window resize, setting change).
signal view_changed(view_size: Vector2i, scale: int)

## The smallest game area any player ever sees. Gameplay must be designed to
## work inside this "safe frame" (see docs/art-spec.md).
const BASE_SIZE := Vector2i(384, 216)

## Widest allowed aspect ratio (width / height). 0 = unlimited.
var max_aspect := 0.0:
	set(value):
		max_aspect = maxf(value, 0.0)
		_recalculate()

## Current whole-number scale factor (read-only from outside, please).
var scale := 1
## Current visible game area in base pixels (read-only from outside, please).
var view_size := BASE_SIZE

var _window: Window


func _ready() -> void:
	_window = get_tree().root
	# KEEP aspect: we hand Godot an exact size, so it never needs to expand.
	_window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
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
