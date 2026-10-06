# =============================================================================
# safe_frame.gd  -  Keeps HUD elements inside a centered, aspect-capped frame
# -----------------------------------------------------------------------------
# WHAT:  A Control that resizes itself to the middle of the screen, never
#        wider than max_aspect. Anchor HUD pieces to ITS corners, not the
#        screen's, and they stay comfortably in view on any monitor.
#
# WHY:   On a 32:9 monitor the screen corners are a long way from the center
#        of your vision. Health bars glued to the far edges are a well-known
#        ultrawide annoyance. The world still fills the whole screen; only
#        the HUD is pulled inward.
#
# SETTING: max_aspect = 16/9 by default. A future settings menu can offer
#        16:9 / 21:9 / 32:9 / full (0 = full width). Change it on the class
#        default (SafeFrame.default_max_aspect) to affect every HUD at once.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name SafeFrame
extends Control

## Game-wide default for every SafeFrame (settings menu changes this).
static var default_max_aspect := 16.0 / 9.0

## Widest aspect (width / height) the frame may be. 0 = full screen width.
## Negative = use default_max_aspect.
@export var max_aspect := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_fit)
	_fit()


func effective_aspect() -> float:
	return default_max_aspect if max_aspect < 0.0 else max_aspect


func _fit() -> void:
	var view := get_viewport_rect().size
	var aspect := effective_aspect()
	var width := view.x if aspect <= 0.0 else minf(view.x, roundf(view.y * aspect))
	position = Vector2(floorf((view.x - width) * 0.5), 0.0)
	size = Vector2(width, view.y)
