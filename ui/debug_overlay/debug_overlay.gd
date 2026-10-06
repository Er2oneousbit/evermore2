# =============================================================================
# debug_overlay.gd  -  F3 overlay: FPS, positions, dog AI state, realm
# -----------------------------------------------------------------------------
# WHAT:  A text panel drawn above everything (CanvasLayer 100). Owned by the
#        Debug autoload, so it exists in every scene automatically.
# HOW TO ADD A LINE: append to `lines` in _process(). Keep each line short;
#        the screen is only 384 px wide at base resolution.
# NOTE:  The overlay finds actors through groups ("kid", "dog"), so it never
#        crashes when a scene has no kid or dog. It just prints "n/a".
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

## Refresh rate for the text (seconds). Updating every frame is wasteful.
const REFRESH_INTERVAL := 0.1

@onready var _label: Label = $Panel/Label

var _timer := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH_INTERVAL
	_label.text = _build_text()


func _build_text() -> String:
	var lines: PackedStringArray = []
	lines.append("FPS %d  |  %s" % [Engine.get_frames_per_second(), Names.text(GameState.current_realm)])

	var kid := get_tree().get_first_node_in_group("kid") as Node2D
	var dog := get_tree().get_first_node_in_group("dog") as Dog

	if kid:
		lines.append("%s  %s" % [GameState.get_kid_name(), _fmt_pos(kid.global_position)])
	else:
		lines.append("Kid  n/a")

	if dog:
		lines.append("%s  %s  %s" % [GameState.get_dog_name(), _fmt_pos(dog.global_position), dog.get_state_name()])
		var dist := dog.global_position.distance_to(kid.global_position) if kid else -1.0
		lines.append("dist %.0f  crumbs %d  warps %d" % [dist, dog.get_trail_size(), dog.warp_count])
	else:
		lines.append("Dog  n/a")

	lines.append("F2 time  F3 overlay  F4 warp dog")
	return "\n".join(lines)


func _fmt_pos(p: Vector2) -> String:
	return "(%d,%d)" % [roundi(p.x), roundi(p.y)]
