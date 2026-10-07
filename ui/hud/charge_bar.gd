# =============================================================================
# charge_bar.gd  -  The kid's auto-filling attack charge on the HUD
# -----------------------------------------------------------------------------
# WHAT:  A thin bar that fills toward the next charge level, plus one pip per
#        level the weapon can reach. Lit pips = the level a swing would use
#        right now (x1 / x2 / x4). Reads a ChargeMeter every frame; no signals.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ChargeBar
extends Control

const PIP_COLORS := [Color(0.95, 0.95, 0.95), Color(0.55, 0.9, 1.0), Color(1.0, 0.82, 0.35)]
const BG := Color(0, 0, 0, 0.55)

var meter: ChargeMeter


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if meter == null:
		return
	var pip := 5.0
	var gap := 2.0
	var bar_w := size.x - (pip + gap) * 3
	draw_rect(Rect2(0, 1, bar_w, 3), BG)
	var lvl := meter.level()
	var fill := meter.progress_in_level()
	var color: Color = PIP_COLORS[clampi(lvl, 0, 2)] if lvl < meter.max_level else PIP_COLORS[clampi(meter.max_level - 1, 0, 2)]
	draw_rect(Rect2(0, 1, bar_w * fill, 3), color)
	for i in meter.max_level:
		var r := Rect2(bar_w + gap + i * (pip + gap), 0, pip, pip)
		draw_rect(r, BG)
		if lvl > i:
			draw_rect(r.grow(-1), PIP_COLORS[i])
