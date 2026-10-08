# =============================================================================
# stamina_bar.gd  -  The running meter on the HUD
# -----------------------------------------------------------------------------
# WHAT:  A thin bar above the charge bar of whoever you drive: how much
#        running is left (Stamina). Green; winded, it turns orange and blinks
#        until running comes back. The HUD hides it while the meter is full.
#        Reads a Stamina every frame; no signals.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name StaminaBar
extends Control

const FILL := Color(0.55, 0.95, 0.5)
const WINDED := Color(1.0, 0.55, 0.25)
const BG := Color(0, 0, 0, 0.55)
## Blinks per second while winded (game time, so it pauses with the game).
const BLINK_HZ := 4.0

var stamina: Stamina
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if stamina == null:
		return
	draw_rect(Rect2(0, 0, size.x, 2), BG)
	var color := FILL
	if stamina.winded:
		color = WINDED
		color.a = 0.55 + 0.45 * absf(sin(_t * PI * BLINK_HZ))
	draw_rect(Rect2(0, 0, size.x * stamina.value, 2), color)
