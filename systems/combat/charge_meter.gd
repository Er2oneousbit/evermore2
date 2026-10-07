# =============================================================================
# charge_meter.gd  -  The auto-filling attack charge (no button holding)
# -----------------------------------------------------------------------------
# WHAT:  value runs from 0 up to max_level, filling by itself at one level per
#        seconds_per_level. A swing spends it: whatever level it reached sets
#        the damage multiplier, then it starts over from 0.
#          below 1   0.25 + 0.75 * value (a hurried swing still hurts a bit)
#          level 1   x1     level 2   x2     level 3   x4   (as in the original)
# WHY:   the original filled to 100% by itself but needed the attack button
#        held for levels 2 and 3; here waiting is enough (owner's call).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ChargeMeter
extends RefCounted

## Damage multiplier per full level (index = level).
const LEVEL_MULTIPLIER := [0.25, 1.0, 2.0, 4.0]

var value := 1.0
var max_level := 1
var seconds_per_level := 0.9


func _init(levels := 1, seconds := 0.9) -> void:
	max_level = clampi(levels, 1, 3)
	seconds_per_level = maxf(seconds, 0.05)
	value = 1.0


func tick(delta: float) -> void:
	value = minf(float(max_level), value + delta / seconds_per_level)


## Whole levels reached so far (0-3).
func level() -> int:
	return int(floorf(value + 0.0001))


## Damage multiplier if the swing happened right now.
func multiplier() -> float:
	var lvl := level()
	if lvl < 1:
		return LEVEL_MULTIPLIER[0] + (LEVEL_MULTIPLIER[1] - LEVEL_MULTIPLIER[0]) * value
	return LEVEL_MULTIPLIER[lvl]


## Use the charge for a swing: returns [multiplier, level] and starts over.
func spend() -> Array:
	var result := [multiplier(), level()]
	value = 0.0
	return result


## 0..1 progress toward the next level (for the HUD bar).
func progress_in_level() -> float:
	if value >= max_level:
		return 1.0
	return value - floorf(value)
